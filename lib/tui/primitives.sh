# shellcheck shell=bash
# lib/tui/primitives.sh — fzf/select menus, pickers, and UI chrome.
# ---------------------------------------------------------------------------
# UI primitives
# ---------------------------------------------------------------------------

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

# tui_press_enter — Wait for Enter after showing command output.
tui_press_enter() {
	echo
	read -r -p "Press Enter to continue… " _ </dev/tty
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
	tui_save_config 1
}

# tui_run_paged — Run a command and only pause when output spans multiple lines.
tui_run_paged() {
	local output lines rc=0
	output="$("$@" 2>&1)" || rc=$?
	if tui_json_enabled && [[ "$output" =~ ^[[:space:]]*[\{\[] ]]; then
		output="$(tui_pretty_json "$output")"
	fi
	lines="$(printf '%s\n' "$output" | wc -l)"
	printf '%s\n' "$output"
	if (( lines >= TUI_PRESS_ENTER_LINES )); then
		tui_press_enter
	fi
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
		"TUI settings") tui_settings_menu ;;
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
			printf '  %s=%s *\n' "$key" "${val:-0}"
		else
			printf '  %s=%s\n' "$key" "${val:-0}"
		fi
	done
	echo
	print_effective_config_summary 2>/dev/null | head -n 10 || true
}

# tui_fzf_pick — Fuzzy-select one line; returns 1 on cancel.
tui_fzf_pick() {
	local header=$1
	shift
	local result
	local -a fzf_args=(
		--header="$header"
		--height="${LAUNCHLAYER_TUI_HEIGHT:-40%}"
		--border
		--layout=reverse
		--info=inline
	)
	[[ $# -gt 0 ]] || return 1
	if cli_uses_color; then
		fzf_args+=(--ansi)
	fi
	result="$(printf '%s\n' "$@" | fzf "${fzf_args[@]}")" || return 1
	[[ -n "$result" ]] || return 1
	printf '%s\n' "$result"
}

# tui_select_pick — Numbered menu fallback when fzf is missing.
tui_select_pick() {
	local prompt=$1
	shift
	local -a items=("$@")
	local i choice

	[[ $# -gt 0 ]] || return 1
	echo "$prompt"
	for i in "${!items[@]}"; do
		printf '  %2d) %s\n' "$((i + 1))" "${items[$i]}"
	done
	printf '  %2d) %s\n' "$(( ${#items[@]} + 1 ))" "Back"
	while true; do
		read -r -p "Choice: " choice </dev/tty || return 1
		[[ "$choice" =~ ^[0-9]+$ ]] || continue
		if (( choice >= 1 && choice <= ${#items[@]} )); then
			printf '%s\n' "${items[choice - 1]}"
			return 0
		fi
		if (( choice == ${#items[@]} + 1 )); then
			return 1
		fi
	done
}

# tui_menu — Pick one item via fzf or numbered menu.
tui_menu() {
	local header=$1
	shift
	header="$(tui_crumb_label "$header")"
	if tui_has_fzf; then
		tui_fzf_pick "$header" "$@"
	else
		tui_select_pick "$header" "$@"
	fi
}

# tui_confirm — Ask yes/no; returns 0 for yes.
tui_confirm() {
	local prompt=$1 choice
	if tui_has_fzf; then
		choice="$(tui_fzf_pick "$prompt" "Yes" "No")" || return 1
		[[ "$choice" == Yes ]]
	else
		read -r -p "$prompt [y/N]: " choice </dev/tty || return 1
		[[ "${choice,,}" == y || "${choice,,}" == yes ]]
	fi
}

# tui_recent_game_appids — AppIDs from launch.log ordered by most recent play.
tui_recent_game_appids() {
	local limit=${1:-8}
	[[ -f "$LAUNCH_LOG_FILE" ]] || return 0
	tac "$LAUNCH_LOG_FILE" 2>/dev/null | awk -v limit="$limit" '
		function parse_line(    i) {
			appid = ""
			for (i = 2; i <= NF; i++) {
				if ($i ~ /^appid=/) {
					sub(/^appid=/, "", $i)
					appid = $i
				}
			}
		}
		{
			parse_line()
			if (appid == "" || appid == "unknown" || appid in seen) next
			seen[appid] = 1
			print appid
			if (++count >= limit) exit
		}
	'
}

# tui_build_game_picker_lines — Recent games first, then full library (deduped).
tui_build_game_picker_lines() {
	local -a all_lines=() recent_ids=() line appid
	local -A seen=()
	mapfile -t all_lines < <(tui_list_games_lines)
	mapfile -t recent_ids < <(tui_recent_game_appids 8)
	for appid in "${recent_ids[@]}"; do
		for line in "${all_lines[@]}"; do
			[[ "${line%% *}" == "$appid" ]] || continue
			printf '[recent] %s\n' "$line"
			seen["$appid"]=1
			break
		done
	done
	for line in "${all_lines[@]}"; do
		appid="${line%% *}"
		[[ -n "${seen[$appid]:-}" ]] && continue
		printf '%s\n' "$line"
	done
}

# tui_parse_game_picker_line — Extract AppID from a picker row (strips [recent] prefix).
tui_parse_game_picker_line() {
	local line=$1
	line="${line#\[recent\] }"
	printf '%s' "${line%% *}"
}

# tui_backup_timer_brief — Short backup timer label for status banner.
tui_backup_timer_brief() {
	local timer
	timer="$(systemd_user_dir)/launchlayer-backup.timer"
	if command -v systemctl >/dev/null 2>&1 \
		&& systemctl --user is-enabled launchlayer-backup.timer >/dev/null 2>&1; then
		printf 'enabled'
	elif [[ -f "$timer" ]]; then
		printf 'installed'
	else
		printf 'off'
	fi
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

# tui_print_status_banner — One-line summary shown when the TUI starts.
tui_print_status_banner() {
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
	echo "── filter: ${TUI_GAME_FILTER:-all} │ doctor: ${issues} issue(s) │ vm.max_map_count: ${vm_label}"
	echo "── backup: ${backup_timer} │ maintenance: ${maint_timer} │ ${prune} │ hub: $(tui_hub_status_brief)"
	echo
}

# tui_change_game_filter — Quick filter change (saved to tui.conf).
tui_change_game_filter() {
	local val
	val="$(tui_menu "Game picker filter" "${TUI_GAME_FILTERS[@]}")" || return 0
	TUI_GAME_FILTER=$val
	tui_save_config
}

# tui_list_games_lines — Game list rows for the picker, honoring TUI_GAME_FILTER.
tui_list_games_lines() {
	local filter=${TUI_GAME_FILTER:-all}
	"$LAUNCHLAYER_MAIN_SCRIPT" --list-games 2>/dev/null | tail -n +2 | {
		if [[ "$filter" == configured ]]; then
			awk '$2 == "yes"'
		elif [[ "$filter" == unconfigured ]]; then
			awk '$2 == "no"'
		else
			cat
		fi
	}
}

# tui_pick_game_appid — Select an installed game; prints AppID.
tui_pick_game_appid() {
	local line appid header script_q
	script_q="$(printf '%q' "$LAUNCHLAYER_MAIN_SCRIPT")"
	header="Select a game ([recent] at top, Ctrl-E: editor, Ctrl-D: dry-run, filter=${TUI_GAME_FILTER:-all})"
	if tui_has_fzf; then
		line="$(tui_build_game_picker_lines | fzf \
			--header="$header" \
			--height="${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
			--border \
			--layout=reverse \
			--preview "${script_q} --tui-game-preview \$(echo {} | grep -oE '[0-9]+' | head -1) 2>/dev/null" \
			--preview-window="${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}" \
			--bind "ctrl-e:execute-silent(${script_q} --edit-appid \$(echo {} | grep -oE '[0-9]+' | head -1) < /dev/tty)+abort" \
			--bind "ctrl-d:execute(${script_q} --dry-run \$(echo {} | grep -oE '[0-9]+' | head -1) 2>&1 | head -n 35)+abort" \
			--info=inline)" || return 1
	else
		local -a lines=()
		mapfile -t lines < <(tui_build_game_picker_lines)
		((${#lines[@]})) || {
			echo "No games match filter: ${TUI_GAME_FILTER:-all}" >&2
			return 1
		}
		line="$(tui_select_pick "$header" "${lines[@]}")" || return 1
	fi
	appid="$(tui_parse_game_picker_line "$line")"
	[[ "$appid" =~ ^[0-9]+$ ]] || return 1
	printf '%s\n' "$appid"
}

# tui_pick_preset — Choose a launch preset name.
tui_pick_preset() {
	local default=${TUI_DEFAULT_PRESET:-standard}
	tui_menu "Choose preset (default: $default)" "${TUI_PRESETS[@]}"
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

# tui_game_scope_count — Count games for bulk preset scopes.
tui_game_scope_count() {
	local mode=$1
	case "$mode" in
		filter)
			tui_list_games_lines | wc -l
			;;
		configured)
			"$LAUNCHLAYER_MAIN_SCRIPT" --list-games 2>/dev/null \
				| tail -n +2 | awk '$2 == "yes"' | wc -l
			;;
		*)
			printf '0\n'
			;;
	esac
}

# tui_collect_appids — Collect AppIDs for a bulk preset scope.
tui_collect_appids() {
	local scope=$1 line appid -a appids=()
	case "$scope" in
		filter)
			while IFS= read -r line || [[ -n "$line" ]]; do
				appid="${line%% *}"
				[[ "$appid" =~ ^[0-9]+$ ]] && appids+=("$appid")
			done < <(tui_list_games_lines)
			;;
		configured)
			while IFS= read -r line || [[ -n "$line" ]]; do
				appid="${line%% *}"
				[[ "$appid" =~ ^[0-9]+$ ]] && appids+=("$appid")
			done < <("$LAUNCHLAYER_MAIN_SCRIPT" --list-games 2>/dev/null | tail -n +2 | awk '$2 == "yes"')
			;;
		multi)
			mapfile -t appids < <(tui_pick_game_appids_multi)
			;;
	esac
	((${#appids[@]})) || return 1
	printf '%s\n' "${appids[@]}"
}

# tui_pick_game_appids_multi — Fuzzy multi-select installed games; prints AppIDs.
tui_pick_game_appids_multi() {
	local -a lines=() selected=() line appid
	tui_has_fzf || {
		echo "Multi-select requires fzf$(tool_warn_suffix fzf)." >&2
		return 1
	}
	mapfile -t lines < <(tui_build_game_picker_lines)
	((${#lines[@]})) || {
		echo "No games match filter: ${TUI_GAME_FILTER:-all}" >&2
		return 1
	}
	mapfile -t selected < <(printf '%s\n' "${lines[@]}" | fzf \
		--multi \
		--header="Select games (Tab/Shift-Tab toggle, Enter confirm)" \
		--height="${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
		--border \
		--layout=reverse \
		--info=inline) || return 1
	((${#selected[@]})) || return 1
	for line in "${selected[@]}"; do
		appid="$(tui_parse_game_picker_line "$line")"
		[[ "$appid" =~ ^[0-9]+$ ]] && printf '%s\n' "$appid"
	done
}

# tui_bulk_preset_menu — Apply INCLUDE preset to many games at once.
tui_bulk_preset_menu() {
	local action scope preset appid -a appids=()
	local filter_n configured_n
	filter_n="$(tui_game_scope_count filter)"
	configured_n="$(tui_game_scope_count configured)"

	action="$(tui_menu "Bulk INCLUDE preset" \
		"Current filter ($filter_n games)" \
		"All configured ($configured_n games)" \
		"Pick games (multi-select)" \
		"Back")" || return 0

	case "$action" in
		"Current filter"*) scope=filter ;;
		"All configured"*) scope=configured ;;
		"Pick games (multi-select)")
			scope=multi
			;;
		*) return 0 ;;
	esac

	mapfile -t appids < <(tui_collect_appids "$scope") || {
		echo "No games matched that scope."
		return 0
	}
	preset="$(tui_pick_preset)" || return 0
	tui_confirm "Set INCLUDE=presets/${preset}.env on ${#appids[@]} game(s)?" || return 0
	for appid in "${appids[@]}"; do
		tui_set_include_preset "$appid" "$preset"
	done
	echo "Updated INCLUDE preset on ${#appids[@]} game(s)."
}

