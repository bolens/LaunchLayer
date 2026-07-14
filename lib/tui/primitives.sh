# shellcheck shell=bash
# lib/tui/primitives.sh — Core TUI helpers: footers, menus, breadcrumbs, status chrome.

# tui_require_tty — TUI needs interactive stdin/stdout.
tui_require_tty() {
	[[ -t 0 && -t 1 ]] || {
		echo "launchlayer: --tui requires an interactive terminal." >&2
		return 1
	}
}

# tui_has_fzf — True when fzf is available for fuzzy selection.
tui_has_fzf() {
	command -v fzf >/dev/null 2>&1
}

# tui_fzf_footer_for — Contextual key-hint line (lazygit/k9s-style footer).
tui_fzf_footer_for() {
	case "${1:-menu}" in
		game)
			printf '%s' '↑↓ move · home/end jump · pgup/pgdn page · alt-s sort · enter select · ctrl-e editor · ctrl-d dry-run · ? help · esc back'
			;;
		multi)
			printf '%s' 'tab toggle · shift-tab prev · alt-s sort · enter confirm · ? help · esc cancel'
			;;
		confirm)
			printf '%s' 'enter confirm · esc cancel · ? help'
			;;
		help)
			printf '%s' 'esc close'
			;;
		main)
			printf '%s' '↑↓ navigate · enter select · ? shortcuts · esc quit'
			;;
		actions)
			printf '%s' '↑↓ navigate · enter select · ctrl-d dry-run · ? help · esc back'
			;;
		toggles)
			printf '%s' 'enter flip toggle · ? help · esc back'
			;;
		advanced)
			printf '%s' 'enter edit group/key · ? help · esc back'
			;;
		*)
			printf '%s' '↑↓ navigate · home/end jump · pgup/pgdn page · alt-s sort · enter select · ? help · esc back'
			;;
	esac
}

# tui_games_footer_brief — Game hub status for menu footers (non-blocking).
tui_games_footer_brief() {
	tui_games_cache_start
	printf 'filter:%s · %s games' "${TUI_GAME_FILTER:-all}" "$(tui_games_cache_count)"
}

# tui_backup_footer_brief — Backup hub status for menu footers.
tui_backup_footer_brief() {
	printf '%s · maint:%s' \
		"$(backup_prune_summary 2>/dev/null || echo keep?)" \
		"$(tui_maintenance_timer_brief 2>/dev/null || echo off)"
}

# tui_fzf_context_footer — Contextual hint line plus live hub status when relevant.
tui_fzf_context_footer() {
	local context=${1:-menu} hint extra=""
	hint="$(tui_fzf_footer_for "$context")"
	case "$context" in
		main)
			extra="$(tui_status_footer_brief)"
			if [[ -n "${TUI_FZF_FOOTER_SUFFIX:-}" ]]; then
				hint="${hint} · ${TUI_FZF_FOOTER_SUFFIX}"
			fi
			;;
		games)
			extra="$(tui_games_footer_brief)"
			;;
		backup)
			extra="$(tui_backup_footer_brief)"
			;;
		hub)
			extra="hub:$(tui_hub_status_brief 2>/dev/null || echo off)"
			;;
		actions)
			[[ -n "${TUI_ACTION_APPID:-}" ]] && extra="appid:${TUI_ACTION_APPID}"
			;;
	esac
	if [[ -n "$extra" ]]; then
		printf '%s │ %s' "$hint" "$extra"
	else
		printf '%s' "$hint"
	fi
}

# tui_status_footer_brief — One-line live status for menu footers.
tui_status_footer_brief() {
	local issues required current vm_label backup_timer maint_timer
	issues="$(doctor_issue_count 2>/dev/null || echo 0)"
	required="$(sysctl_required_value 2>/dev/null || echo 0)"
	current="$(sysctl_current_value 2>/dev/null || echo "")"
	backup_timer="$(tui_backup_timer_brief 2>/dev/null || echo off)"
	maint_timer="$(tui_maintenance_timer_brief 2>/dev/null || echo off)"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -ge "$required" ]]; then
		vm_label="ok"
	else
		vm_label="low"
	fi
	printf 'filter:%s · doctor:%s · vm:%s · backup:%s · maint:%s · hub:%s' \
		"${TUI_GAME_FILTER:-all}" \
		"$(tui_glyph_doctor "$issues")" \
		"$(tui_glyph_vm "$vm_label")" \
		"$(tui_glyph_timer "$backup_timer")" \
		"$(tui_glyph_timer "$maint_timer")" \
		"$(tui_hub_status_brief 2>/dev/null || echo off)"
}

# tui_press_enter — Wait for Enter after showing command output.
tui_press_enter() {
	echo
	read -r -p "Press Enter to continue… " _ </dev/tty
}

# tui_maybe_press_enter — Skip the pause when output is shown in the side panel.
tui_maybe_press_enter() {
	tui_panel_active_p && return 0
	tui_press_enter
}

# tui_show_text — Show a short message in the panel or above the menu.
tui_show_text() {
	local text=$1 label=${2:-Note}
	if tui_panel_active_p; then
		tui_panel_append_text "$label" "$text"
		return 0
	fi
	printf '%s\n' "$text"
	tui_press_enter
}

# tui_panel_note — Record feedback without pausing (toggles, saves, inline edits).
tui_panel_note() {
	local text=$1 label=${2:-Note}
	if tui_panel_active_p; then
		tui_panel_append_text "$label" "$text"
		return 0
	fi
	printf '%s\n' "$text"
}

# tui_run_capture — Run a command with a custom spinner label; route output to the panel.
tui_run_capture() {
	local msg=$1
	shift
	local output rc=0
	output="$(tui_spinner_capture "$msg" "$@")" || rc=$?
	if tui_json_enabled && [[ "$output" =~ ^[[:space:]]*[\{\[] ]]; then
		output="$(tui_pretty_json "$output")"
	fi
	if tui_panel_active_p; then
		tui_panel_append_text "$msg" "$output"
		return "$rc"
	fi
	printf '%s\n' "$output"
	tui_maybe_press_enter
	return "$rc"
}

# tui_crumb_init — Ensure breadcrumb stack exists (set -u safe).
tui_crumb_init() {
	[[ -v TUI_CRUMB_STACK ]] || TUI_CRUMB_STACK=()
}

# tui_crumb_enter — Push a breadcrumb segment for nested menu headers.
tui_crumb_enter() {
	tui_crumb_init
	TUI_CRUMB_STACK+=("$1")
}

# tui_crumb_leave — Pop the innermost breadcrumb segment.
tui_crumb_leave() {
	tui_crumb_init
	((${#TUI_CRUMB_STACK[@]})) && unset 'TUI_CRUMB_STACK[-1]'
}

# tui_crumb_label — Prefix a menu title with the breadcrumb trail.
tui_crumb_label() {
	local header=$1 joined
	tui_crumb_init
	((${#TUI_CRUMB_STACK[@]})) || {
		printf '%s' "$header"
		return 0
	}
	joined="$(IFS=' › '; echo "${TUI_CRUMB_STACK[*]}")"
	printf '%s › %s' "$joined" "$header"
}

# tui_remember_main_menu — Persist last top-level hub for resume hint on next launch.
tui_remember_main_menu() {
	TUI_LAST_MENU=$1
	tui_save_config_quiet
}

# tui_run_paged — Run a command; show output in the side panel or above the menu.
tui_run_paged() {
	local output lines rc=0 msg cmd=$1
	msg="$(tui_spinner_message_for "$cmd")"
	output="$(tui_spinner_capture "$msg" "$@")" || rc=$?
	if tui_json_enabled && [[ "$output" =~ ^[[:space:]]*[\{\[] ]]; then
		output="$(tui_pretty_json "$output")"
	fi
	if tui_panel_active_p; then
		tui_panel_append_command "$cmd" "$output"
		return "$rc"
	fi
	lines="$(printf '%s\n' "$output" | wc -l)"
	printf '%s\n' "$output"
	if (( lines >= TUI_PRESS_ENTER_LINES )); then
		tui_press_enter
	fi
	return "$rc"
}

# tui_run_side_effect — Run a command; route stdout to the panel without pausing.
tui_run_side_effect() {
	local output msg cmd=$1 rc=0
	shift
	msg="$(tui_spinner_message_for "$cmd")"
	output="$(tui_spinner_capture "$msg" "$cmd" "$@")" || rc=$?
	if tui_panel_active_p; then
		[[ -n "$output" ]] && tui_panel_append_command "$cmd" "$output"
		return "$rc"
	fi
	printf '%s\n' "$output"
	return "$rc"
}

# tui_pretty_json — Best-effort pretty-print of JSON text.
tui_pretty_json() {
	local data=$1
	if command -v python3 >/dev/null 2>&1; then
		printf '%s\n' "$data" | python3 -m json.tool 2>/dev/null && return 0
	fi
	if command -v jq >/dev/null 2>&1; then
		printf '%s\n' "$data" | jq . 2>/dev/null && return 0
	fi
	printf '%s\n' "$data"
}

# tui_open_last_menu — Dispatch the saved main-menu hub by name.
tui_open_last_menu() {
	case "${TUI_LAST_MENU:-}" in
		Games) tui_games_menu ;;
		"Config library") tui_config_menu ;;
		"Backup & restore") tui_backup_menu ;;
		"Community hub") tui_hub_menu ;;
		"System & tools") tui_system_menu ;;
		Settings|"TUI settings") tui_prefs_hub_menu ;;
		Status) tui_status_menu ;;
		*) return 1 ;;
	esac
}

# tui_render_game_preview — Compact INCLUDE + toggles preview for fzf game picker.
tui_render_game_preview() {
	local appid=$1 resolved name key val override file
	[[ -n "$appid" ]] || return 1
	if [[ "$appid" =~ ^[0-9]+$ ]]; then
		resolved="$appid"
	else
		resolved="$(resolve_appid_query "$appid" 2>/dev/null)" || return 1
	fi
	prepare_launch_context "$resolved"
	name="${steam_game_name:-unknown}"
	file="$(tui_appid_env_path "$resolved")"

	echo "=== $name ($resolved) ==="
	echo "INCLUDE=${INCLUDE:-auto}"
	echo "native=$is_native  anticheat=$is_anticheat  engine=${game_engine_hint:-?}"
	echo
	echo "Toggles (* = per-game override):"
	for key in "${TUI_TOGGLE_KEYS[@]}"; do
		val="${!key-}"
		override=""
		[[ -f "$file" ]] && override="$(tui_env_file_get "$file" "$key")"
		if [[ -n "$override" ]]; then
			printf '  %s=%s *\n' "$key" "$(tui_glyph_bool_onoff "${val:-0}")"
		else
			printf '  %s=%s\n' "$key" "$(tui_glyph_bool_onoff "${val:-0}" 1)"
		fi
	done
	echo
	print_effective_config_summary 2>/dev/null | head -n 10 || true
}

# tui_select_pick — Numbered menu fallback when fzf is missing.
tui_select_pick() {
	local prompt=$1
	shift
	local -a items=("$@")
	local i choice

	[[ $# -gt 0 ]] || return 1
	echo "$prompt"
	if ! tui_has_fzf; then
		printf '%s\n' "$(cli_dim "$(tui_fzf_footer_for "${TUI_MENU_CONTEXT:-menu}") (install fzf for fuzzy search)")" >&2
	fi
	for i in "${!items[@]}"; do
		[[ -z "${items[$i]}" ]] && continue
		printf '  %2d) %s\n' "$((i + 1))" "${items[$i]}"
	done
	printf '  %2d) %s\n' "$(( ${#items[@]} + 1 ))" "Back"
	local default_choice="" prompt="Choice: "
	if [[ -n "${TUI_FZF_START_POS:-}" && "${TUI_FZF_START_POS}" =~ ^[0-9]+$ ]]; then
		default_choice=$TUI_FZF_START_POS
		prompt="Choice [${default_choice}]: "
	fi
	unset TUI_FZF_START_POS
	while true; do
		read -r -p "$prompt" choice </dev/tty || return 1
		[[ -z "$choice" && -n "$default_choice" ]] && choice=$default_choice
		[[ "$choice" =~ ^[0-9]+$ ]] || continue
		if (( choice >= 1 && choice <= ${#items[@]} )); then
			[[ -n "${items[choice - 1]}" ]] || continue
			printf '%s\n' "${items[choice - 1]}"
			return 0
		fi
		if (( choice == ${#items[@]} + 1 )); then
			return 1
		fi
	done
}

# tui_menu_items_skip_empty — Drop blank separator rows for numbered fallback.
tui_menu_items_skip_empty() {
	local item
	for item in "$@"; do
		[[ -n "$item" ]] && printf '%s\n' "$item"
	done
}

# tui_menu_set_start_pos — Re-select a row on the next tui_menu call (1-based fzf position).
# Anchor is a stable prefix: toggle key (GAMEMODE), "JSON view output:", "[Includes] local.env:", etc.
tui_menu_set_start_pos() {
	local anchor=$1
	shift
	local i=0 item stripped item_key
	unset TUI_FZF_START_POS
	[[ -n "$anchor" ]] || return 0
	for item in "$@"; do
		stripped="$(printf '%s' "$item" | tui_strip_ansi)"
		if [[ "$anchor" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
			item_key="$(tui_toggle_key_from_option "$stripped")"
			if [[ "$item_key" == "$anchor" ]]; then
				export TUI_FZF_START_POS=$((i + 1))
				return 0
			fi
		elif [[ "$stripped" == "$anchor"* ]]; then
			export TUI_FZF_START_POS=$((i + 1))
			return 0
		fi
		((i++)) || true
	done
	return 0
}

# tui_menu_anchored — Pick one menu row; restore selection via anchor when set.
# Build items once: local -a items=(...); tui_menu_anchored "header" "$anchor" "${items[@]}"
tui_menu_anchored() {
	local header=$1 anchor=$2
	shift 2
	tui_menu_set_start_pos "$anchor" "$@"
	tui_menu "$header" "$@"
}

# tui_menu — Pick one item via fzf or numbered menu.
# Set TUI_MENU_CONTEXT for footer hints (main, games, backup, hub, actions, toggles).
# Set TUI_ACTION_APPID when TUI_MENU_CONTEXT=actions for preview + ctrl-d dry-run.
# Set TUI_FZF_START_POS (or call tui_menu_set_start_pos) to keep selection after in-menu edits.
tui_menu() {
	local header=$1 context
	shift
	header="$(tui_crumb_label "$header")"
	context="${TUI_MENU_CONTEXT:-menu}"
	if tui_has_fzf; then
		tui_fzf_pick "$header" "$context" "$@"
	else
		mapfile -t _tui_menu_items < <(tui_menu_items_skip_empty "$@")
		tui_select_pick "$header" "${_tui_menu_items[@]}"
	fi
}

# tui_confirm — Ask yes/no; returns 0 for yes.
tui_confirm() {
	local prompt=$1 choice
	if tui_has_fzf; then
		choice="$(tui_fzf_pick "$prompt" confirm "Yes" "No")" || return 1
		[[ "$choice" == Yes ]]
	else
		read -r -p "$prompt [y/N]: " choice </dev/tty || return 1
		[[ "${choice,,}" == y || "${choice,,}" == yes ]]
	fi
}

# tui_backup_timer_brief — Short backup timer label for status banner.
tui_backup_timer_brief() {
	systemd_backup_timer_brief_state 2>/dev/null || printf 'off\n'
}

# tui_maintenance_timer_brief — Short maintenance timer label for status banner.
tui_maintenance_timer_brief() {
	local timer
	timer="$(systemd_user_dir)/launchlayer-maintenance.timer"
	if command -v systemctl >/dev/null 2>&1 \
		&& systemctl --user is-enabled launchlayer-maintenance.timer >/dev/null 2>&1; then
		printf 'enabled'
	elif [[ -f "$timer" ]]; then
		printf 'installed'
	else
		printf 'off'
	fi
}

# tui_print_status_banner — Status summary at TUI start (non-fzf fallback only).
tui_print_status_banner() {
	tui_panel_active_p && return 0
	local banner
	banner="$(tui_spinner_capture "Loading status…" tui_print_status_banner_body)" || true
	printf '%s\n' "$banner"
}

# tui_print_status_banner_body — Status lines without spinner (used by tui_print_status_banner).
tui_print_status_banner_body() {
	local issues required current vm_label backup_timer maint_timer prune
	issues="$(doctor_issue_count)"
	required="$(sysctl_required_value)"
	current="$(sysctl_current_value)"
	backup_timer="$(tui_backup_timer_brief)"
	maint_timer="$(tui_maintenance_timer_brief)"
	prune="$(backup_prune_summary)"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -ge "$required" ]]; then
		vm_label="ok"
	else
		vm_label="low"
	fi
	printf '%s\n' "── filter: ${TUI_GAME_FILTER:-all} │ doctor: $(tui_glyph_doctor "$issues") │ vm: $(tui_glyph_vm "$vm_label")"
	printf '%s\n' "── backup: $(tui_glyph_timer "$backup_timer") │ maint: $(tui_glyph_timer "$maint_timer") │ ${prune} │ hub: $(tui_hub_status_brief)"
}

# tui_change_game_filter — Quick filter change (saved to tui.conf).
tui_change_game_filter() {
	local val
	val="$(tui_menu "Game picker filter" "${TUI_GAME_FILTERS[@]}")" || return 0
	TUI_GAME_FILTER=$val
	tui_save_config
}

# tui_strip_ansi — Remove ANSI escape sequences from a string.
tui_strip_ansi() {
	sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'
}

# tui_toggle_key_from_option — Extract config key from a quick-toggle menu line.
tui_toggle_key_from_option() {
	local option=$1
	option="$(printf '%s' "$option" | tui_strip_ansi)"
	option="${option%%=*}"
	option="${option%% *}"
	printf '%s' "${option// /}"
}

# tui_bool_on — True when a config value is enabled.
tui_bool_on() {
	case "${1:-}" in
		1|yes|true|on|YES|TRUE|ON) return 0 ;;
		*) return 1 ;;
	esac
}
