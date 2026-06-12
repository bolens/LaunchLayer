# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=cli.sh
# shellcheck source=steam.sh
# shellcheck source=inspect.sh
# shellcheck source=setup.sh
# lib/tui.sh — Interactive terminal UI (fzf with select fallback).

[[ -n "${LAUNCHLAYER_TUI_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_LOADED=1

TUI_PRESETS=(standard competitive lightweight native)
TUI_GAME_FILTERS=(all configured unconfigured)

# Boolean keys exposed in the quick-toggle menu (per-game overrides).
TUI_TOGGLE_KEYS=(
	GAMEMODE MANGOHUD GAMESCOPE GAMESCOPE_ADAPTIVE_SYNC VRAM_HOGS
	NETWORK_TUNE PIPEWIRE_LOW_LATENCY SHADER_CACHE_TRIM GPU_POWER_CHECK
	LAUNCH_WATCHDOG GAME_PERFORMANCE BENCHMARK DEBUG
	FORCE_NATIVE FORCE_PROTON DISABLE_CPU_AFFINITY
)

# ---------------------------------------------------------------------------
# TUI preferences (~/.config/launchlayer/tui.conf)
# ---------------------------------------------------------------------------

# tui_config_path — User TUI settings file.
tui_config_path() {
	printf '%s/launchlayer/tui.conf' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# tui_load_config — Load saved TUI preferences (safe defaults when missing).
tui_load_config() {
	local file line key val
	TUI_GAME_FILTER=${TUI_GAME_FILTER:-all}
	TUI_CACHE_MIN_GB=${TUI_CACHE_MIN_GB:-5}
	TUI_DEFAULT_PRESET=${TUI_DEFAULT_PRESET:-standard}
	export LAUNCHLAYER_TUI_HEIGHT="${LAUNCHLAYER_TUI_HEIGHT:-40%}"
	export LAUNCHLAYER_TUI_PREVIEW="${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}"

	file="$(tui_config_path)"
	[[ -f "$file" ]] || return 0
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		key="${key#"${key%%[![:space:]]*}"}"
		val="${line#*=}"
		case "$key" in
			game_filter) TUI_GAME_FILTER=$val ;;
			cache_min_gb) TUI_CACHE_MIN_GB=$val ;;
			default_preset) TUI_DEFAULT_PRESET=$val ;;
			fzf_height) LAUNCHLAYER_TUI_HEIGHT=$val ;;
			fzf_preview) LAUNCHLAYER_TUI_PREVIEW=$val ;;
		esac
	done < "$file"
}

# tui_save_config — Persist TUI preferences.
tui_save_config() {
	local file dir
	file="$(tui_config_path)"
	dir="$(dirname "$file")"
	mkdir -p "$dir"
	cat > "$file" <<EOF
# launchlayer TUI preferences
game_filter=${TUI_GAME_FILTER:-all}
cache_min_gb=${TUI_CACHE_MIN_GB:-5}
default_preset=${TUI_DEFAULT_PRESET:-standard}
fzf_height=${LAUNCHLAYER_TUI_HEIGHT:-40%}
fzf_preview=${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}
EOF
	echo "Saved TUI settings to $file"
}

# ---------------------------------------------------------------------------
# Per-game .env helpers
# ---------------------------------------------------------------------------

# tui_appid_env_path — Path to launch.d/<AppID>.env.
tui_appid_env_path() {
	printf '%s/%s.env' "$LAUNCHD_DIR" "$1"
}

# tui_ensure_appid_env — Create per-game config from suggested preset when missing.
tui_ensure_appid_env() {
	local appid=$1
	[[ -f "$(tui_appid_env_path "$appid")" ]] || init_appid_config "$appid" "" 0
}

# tui_env_file_get — Read KEY=value from a .env file (last match wins).
tui_env_file_get() {
	local file=$1 key=$2
	grep -E "^[[:space:]]*${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2-
}

# tui_env_upsert — Set or replace KEY=value in a .env file.
tui_env_upsert() {
	local file=$1 key=$2 value=$3
	local tmp found=0 line
	tmp="$(mktemp)"
	if [[ -f "$file" ]]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$line" =~ ^[[:space:]]*${key}= ]]; then
				printf '%s=%s\n' "$key" "$value"
				found=1
			else
				printf '%s\n' "$line"
			fi
		done < "$file" > "$tmp"
	fi
	(( found )) || printf '%s=%s\n' "$key" "$value" >> "$tmp"
	mv "$tmp" "$file"
}

# tui_effective_key — Return effective value for a config key after loading layers.
tui_effective_key() {
	local appid=$1 key=$2
	prepare_launch_context "$appid"
	printf '%s' "${!key-}"
}

# tui_toggle_game_key — Flip a boolean-ish key in the per-game .env file.
tui_toggle_game_key() {
	local appid=$1 key=$2 effective new_val file
	tui_ensure_appid_env "$appid"
	file="$(tui_appid_env_path "$appid")"
	effective="$(tui_effective_key "$appid" "$key")"
	case "$effective" in
		1|yes|true|on|YES|TRUE|ON) new_val=0 ;;
		*) new_val=1 ;;
	esac
	tui_env_upsert "$file" "$key" "$new_val"
	echo "Set $key=$new_val in $(basename "$file") (was: ${effective:-unset})"
}

# tui_set_include_preset — Point per-game INCLUDE= at a named preset.
tui_set_include_preset() {
	local appid=$1 preset=$2 file
	tui_ensure_appid_env "$appid"
	file="$(tui_appid_env_path "$appid")"
	tui_env_upsert "$file" "INCLUDE" "presets/${preset}.env"
	echo "Set INCLUDE=presets/${preset}.env in $(basename "$file")"
}

# tui_prompt_env_key — Prompt for a string key and write to per-game .env.
tui_prompt_env_key() {
	local appid=$1 key=$2 prompt=$3
	local file current new_val
	tui_ensure_appid_env "$appid"
	file="$(tui_appid_env_path "$appid")"
	current="$(tui_env_file_get "$file" "$key")"
	[[ -z "$current" ]] && current="$(tui_effective_key "$appid" "$key")"
	read -r -p "${prompt} [${current:-empty}]: " new_val </dev/tty || return 1
	[[ -z "$new_val" ]] && new_val="$current"
	tui_env_upsert "$file" "$key" "$new_val"
	echo "Set $key=$new_val"
}

# tui_open_in_editor — Open a config file in \$EDITOR.
tui_open_in_editor() {
	local path=$1 editor
	editor="${EDITOR:-${VISUAL:-nano}}"
	[[ -f "$path" ]] || {
		echo "File not found: $path" >&2
		return 1
	}
	"$editor" "$path"
}

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

# tui_fzf_pick — Fuzzy-select one line; returns 1 on cancel.
tui_fzf_pick() {
	local header=$1
	shift
	local result
	[[ $# -gt 0 ]] || return 1
	result="$(printf '%s\n' "$@" | fzf \
		--header="$header" \
		--height="${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
		--border \
		--layout=reverse \
		--info=inline)" || return 1
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
	local line appid header="Select a game (Esc: cancel, filter=${TUI_GAME_FILTER:-all})"
	if tui_has_fzf; then
		line="$(tui_list_games_lines | fzf \
			--header="$header" \
			--height="${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
			--border \
			--layout=reverse \
			--preview "$LAUNCHLAYER_MAIN_SCRIPT --show-config {1} 2>/dev/null | head -n 45" \
			--preview-window="${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}" \
			--info=inline)" || return 1
	else
		local -a lines=()
		mapfile -t lines < <(tui_list_games_lines)
		((${#lines[@]})) || {
			echo "No games match filter: ${TUI_GAME_FILTER:-all}" >&2
			return 1
		}
		line="$(tui_select_pick "$header" "${lines[@]}")" || return 1
	fi
	appid="${line%% *}"
	[[ "$appid" =~ ^[0-9]+$ ]] || return 1
	printf '%s\n' "$appid"
}

# tui_pick_preset — Choose a launch preset name.
tui_pick_preset() {
	local default=${TUI_DEFAULT_PRESET:-standard}
	tui_menu "Choose preset (default: $default)" "${TUI_PRESETS[@]}"
}

# ---------------------------------------------------------------------------
# Configuration menus
# ---------------------------------------------------------------------------

# tui_format_toggle_option — Menu line using already-loaded effective settings.
tui_format_toggle_option() {
	local appid=$1 key=$2 effective override file
	file="$(tui_appid_env_path "$appid")"
	effective="${!key-}"
	override=""
	[[ -f "$file" ]] && override="$(tui_env_file_get "$file" "$key")"
	if [[ -n "$override" ]]; then
		printf '%s=%s  (override)' "$key" "${effective:-0}"
	else
		printf '%s=%s  (inherited)' "$key" "${effective:-0}"
	fi
}

# tui_quick_toggles — Toggle boolean launch settings in per-game .env.
tui_quick_toggles() {
	local appid=$1 action key -a options=()
	tui_ensure_appid_env "$appid"

	while true; do
		prepare_launch_context "$appid"
		options=()
		for key in "${TUI_TOGGLE_KEYS[@]}"; do
			options+=("$(tui_format_toggle_option "$appid" "$key")")
		done
		options+=("Back")

		action="$(tui_menu "Quick toggles — flips per-game override" "${options[@]}")" || return 0
		[[ "$action" == Back ]] && return 0
		key="${action%%=*}"
		key="${key// /}"
		tui_toggle_game_key "$appid" "$key"
		tui_press_enter
	done
}

# tui_advanced_config — String keys and preset INCLUDE changes.
tui_advanced_config() {
	local appid=$1 name preset action
	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"

	while true; do
		action="$(tui_menu "Advanced config: $name" \
			"Change INCLUDE preset" \
			"Edit GAME_EXTRA_ARGS" \
			"Edit LAUNCH_WRAPPERS" \
			"Edit LAUNCH_WRAPPERS_BEFORE" \
			"Edit GAMESCOPE_W / H / R" \
			"Edit SHADER_CACHE_MAX_GB" \
			"Edit MANGOHUD_CONFIG" \
			"Edit UNSET_VARS" \
			"Back")" || return 0

		case "$action" in
			"Change INCLUDE preset")
				preset="$(tui_pick_preset)" || continue
				tui_set_include_preset "$appid" "$preset"
				tui_press_enter
				;;
			"Edit GAME_EXTRA_ARGS")
				tui_prompt_env_key "$appid" GAME_EXTRA_ARGS "Game CLI args"
				tui_press_enter
				;;
			"Edit LAUNCH_WRAPPERS")
				tui_prompt_env_key "$appid" LAUNCH_WRAPPERS "Wrappers after game-performance"
				tui_press_enter
				;;
			"Edit LAUNCH_WRAPPERS_BEFORE")
				tui_prompt_env_key "$appid" LAUNCH_WRAPPERS_BEFORE "Wrappers before gamemoderun"
				tui_press_enter
				;;
			"Edit GAMESCOPE_W / H / R")
				tui_prompt_env_key "$appid" GAMESCOPE_W "Gamescope width"
				tui_prompt_env_key "$appid" GAMESCOPE_H "Gamescope height"
				tui_prompt_env_key "$appid" GAMESCOPE_R "Gamescope refresh Hz"
				tui_press_enter
				;;
			"Edit SHADER_CACHE_MAX_GB")
				tui_prompt_env_key "$appid" SHADER_CACHE_MAX_GB "Shader cache max GB"
				tui_press_enter
				;;
			"Edit MANGOHUD_CONFIG")
				tui_prompt_env_key "$appid" MANGOHUD_CONFIG "MangoHUD config string"
				tui_press_enter
				;;
			"Edit UNSET_VARS")
				tui_prompt_env_key "$appid" UNSET_VARS "Space-separated vars to unset"
				tui_press_enter
				;;
			*) return 0 ;;
		esac
	done
}

# tui_init_game_config — Scaffold or overwrite per-game config interactively.
tui_init_game_config() {
	local appid=$1 preset force=0 name
	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	if [[ -f "$(tui_appid_env_path "$appid")" ]]; then
		tui_confirm "Overwrite existing config for $name?" || return 0
		force=1
	fi
	preset="$(tui_pick_preset)" || return 0
	init_appid_config "$appid" "$preset" "$force"
	tui_press_enter
}

# tui_delete_game_config — Remove per-game .env after confirmation.
tui_delete_game_config() {
	local appid=$1 path
	path="$(tui_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		echo "No per-game config at $path"
		tui_press_enter
		return 0
	}
	if tui_confirm "Delete $(basename "$path")? (preset auto-selection will apply)"; then
		rm -f "$path"
		echo "Deleted $path"
	fi
	tui_press_enter
}

# tui_show_dry_run — Print resolved launch chain without running a game.
tui_show_dry_run() {
	local appid=$1
	prepare_launch_context "$appid"
	print_dry_run /bin/true
}

# tui_game_actions — Action menu for one game.
tui_game_actions() {
	local appid=$1 name action
	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"

	while true; do
		action="$(tui_menu "Game: $name ($appid)" \
			"Show resolved config" \
			"Show dry-run launch chain" \
			"Quick toggles (GameMode, MangoHUD, …)" \
			"Advanced config (args, wrappers, Gamescope)" \
			"Show paths (cache / install)" \
			"Launch stats" \
			"Edit per-game config (\$EDITOR)" \
			"Set preset (re-init scaffold)" \
			"Validate config" \
			"Delete per-game config" \
			"Back to main menu")" || return 0

		case "$action" in
			"Show resolved config")
				show_config "$appid" 0
				tui_press_enter
				;;
			"Show dry-run launch chain")
				tui_show_dry_run "$appid"
				tui_press_enter
				;;
			"Quick toggles (GameMode, MangoHUD, …)")
				tui_quick_toggles "$appid"
				;;
			"Advanced config (args, wrappers, Gamescope)")
				tui_advanced_config "$appid"
				;;
			"Show paths (cache / install)")
				show_paths "$appid" 0
				tui_press_enter
				;;
			"Launch stats")
				launch_stats "$appid" 0
				tui_press_enter
				;;
			"Edit per-game config (\$EDITOR)")
				edit_appid_config "$appid"
				;;
			"Set preset (re-init scaffold)")
				tui_init_game_config "$appid"
				;;
			"Validate config")
				validate_config "$appid" 0 || true
				tui_press_enter
				;;
			"Delete per-game config")
				tui_delete_game_config "$appid"
				;;
			"Back to main menu"|*)
				return 0
				;;
		esac
	done
}

# tui_defaults_menu — Edit global and profile layers.
tui_defaults_menu() {
	local action profile path
	action="$(tui_menu "Global config files" \
		"Edit launch.d/default.env" \
		"Edit a machine profile" \
		"Validate default + presets" \
		"Back")" || return 0

	case "$action" in
		"Edit launch.d/default.env")
			tui_open_in_editor "$LAUNCHD_DIR/default.env"
			;;
		"Edit a machine profile")
			local -a profiles=()
			for path in "$PROFILES_DIR"/*.env; do
				[[ -f "$path" ]] || continue
				profiles+=("$(basename "$path" .env)")
			done
			((${#profiles[@]})) || {
				echo "No profiles in $PROFILES_DIR"
				tui_press_enter
				return 0
			}
			profile="$(tui_menu "Choose profile" "${profiles[@]}")" || return 0
			tui_open_in_editor "$PROFILES_DIR/${profile}.env"
			;;
		"Validate default + presets")
			validate_config default 0 || true
			validate_config presets 0 || true
			tui_press_enter
			;;
		*) return 0 ;;
	esac
}

# tui_init_unconfigured_menu — Bulk scaffold missing per-game configs.
tui_init_unconfigured_menu() {
	local action preset
	action="$(tui_menu "Init unconfigured games" \
		"Preview (dry-run, suggested presets)" \
		"Create all (suggested presets)" \
		"Create all with chosen preset" \
		"Create EAC/BattlEye only (suggested)" \
		"Back")" || return 0

	case "$action" in
		"Preview (dry-run, suggested presets)")
			init_unconfigured "" 1 0
			;;
		"Create all (suggested presets)")
			tui_confirm "Create .env for every unconfigured game?" || return 0
			init_unconfigured "" 0 0
			;;
		"Create all with chosen preset")
			preset="$(tui_pick_preset)" || return 0
			tui_confirm "Create .env for every unconfigured game with preset $preset?" || return 0
			init_unconfigured "$preset" 0 0
			;;
		"Create EAC/BattlEye only (suggested)")
			tui_confirm "Scaffold anticheat titles only?" || return 0
			init_unconfigured "" 0 1
			;;
		*) return 0 ;;
	esac
	tui_press_enter
}

# tui_setup_menu — Interactive setup shortcuts.
tui_setup_menu() {
	local action flags=()
	action="$(tui_menu "Setup" \
		"Enable completions (login shell)" \
		"Install launchlayer symlink" \
		"Install systemd maintenance timer" \
		"Print Steam launch option" \
		"Run full setup (completions + launch option)" \
		"Back")" || return 0

	case "$action" in
		"Enable completions (login shell)") flags=(--completions) ;;
		"Install launchlayer symlink") flags=(--symlink) ;;
		"Install systemd maintenance timer") flags=(--systemd) ;;
		"Print Steam launch option") flags=(--print-launch-option) ;;
		"Run full setup (completions + launch option)") flags=(--completions --print-launch-option) ;;
		*) return 0 ;;
	esac
	run_setup "${flags[@]}"
	tui_press_enter
}

# tui_settings_menu — Persisted TUI preferences.
tui_settings_menu() {
	local action val filter_label
	filter_label="${TUI_GAME_FILTER:-all}"

	while true; do
		action="$(tui_menu "TUI settings (saved to $(tui_config_path))" \
			"Game picker filter: $filter_label" \
			"Cache report min GB: ${TUI_CACHE_MIN_GB:-5}" \
			"Default init preset: ${TUI_DEFAULT_PRESET:-standard}" \
			"fzf height: ${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
			"fzf preview layout: ${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}" \
			"Save and return" \
			"Back without saving")" || return 0

		case "$action" in
			"Game picker filter:"*)
				val="$(tui_menu "Game picker filter" "${TUI_GAME_FILTERS[@]}")" || continue
				TUI_GAME_FILTER=$val
				filter_label=$val
				;;
			"Cache report min GB:"*)
				read -r -p "Min GB [${TUI_CACHE_MIN_GB:-5}]: " val </dev/tty || continue
				[[ -n "$val" ]] && TUI_CACHE_MIN_GB=$val
				;;
			"Default init preset:"*)
				val="$(tui_menu "Default preset" "${TUI_PRESETS[@]}")" || continue
				TUI_DEFAULT_PRESET=$val
				;;
			"fzf height:"*)
				read -r -p "fzf height [${LAUNCHLAYER_TUI_HEIGHT:-40%}]: " val </dev/tty || continue
				[[ -n "$val" ]] && LAUNCHLAYER_TUI_HEIGHT=$val
				;;
			"fzf preview layout:"*)
				read -r -p "Preview window [${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}]: " val </dev/tty || continue
				[[ -n "$val" ]] && LAUNCHLAYER_TUI_PREVIEW=$val
				;;
			"Save and return")
				tui_save_config
				tui_press_enter
				return 0
				;;
			*) return 0 ;;
		esac
	done
}

# tui_cache_report — Cache audit using TUI min-GB preference.
tui_cache_report() {
	local min_gb=${TUI_CACHE_MIN_GB:-5}
	[[ "$min_gb" =~ ^[0-9]+$ ]] || min_gb=5
	cache_report "$min_gb" both "" 0
}

# tui_main_menu — Top-level menu loop.
run_tui() {
	local choice appid

	tui_require_tty || return 1
	tui_load_config

	if ! tui_has_fzf; then
		echo "Note: install fzf for fuzzy search and live config previews." >&2
	fi

	while true; do
		choice="$(tui_menu "LaunchLayer ${LAUNCHLAYER_VERSION}  (filter: ${TUI_GAME_FILTER:-all})" \
			"Browse games" \
			"Quick toggles / config (pick game)" \
			"Init unconfigured games" \
			"Edit global defaults & profiles" \
			"Doctor (health check)" \
			"Detect environment" \
			"Runtime status" \
			"Setup / onboarding" \
			"Cache report" \
			"Validate all configs" \
			"TUI settings" \
			"Quit")" || break

		case "$choice" in
			"Browse games")
				appid="$(tui_pick_game_appid)" || continue
				tui_game_actions "$appid"
				;;
			"Quick toggles / config (pick game)")
				appid="$(tui_pick_game_appid)" || continue
				tui_quick_toggles "$appid"
				;;
			"Init unconfigured games")
				tui_init_unconfigured_menu
				;;
			"Edit global defaults & profiles")
				tui_defaults_menu
				;;
			"Doctor (health check)")
				show_doctor 0 || true
				tui_press_enter
				;;
			"Detect environment")
				show_detect_environment 0
				tui_press_enter
				;;
			"Runtime status")
				show_status "" 0
				tui_press_enter
				;;
			"Setup / onboarding")
				tui_setup_menu
				;;
			"Cache report")
				tui_cache_report
				tui_press_enter
				;;
			"Validate all configs")
				validate_config all 0 || true
				tui_press_enter
				;;
			"TUI settings")
				tui_settings_menu
				;;
			Quit|"")
				break
				;;
		esac
	done
}
