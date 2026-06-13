# shellcheck shell=bash
# lib/tui/config.sh — Per-game .env helpers and override management.

[[ -n "${LAUNCHLAYER_TUI_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_LOADED=1
TUI_PRESETS=(standard competitive lightweight native)
TUI_GAME_FILTERS=(all configured unconfigured)
TUI_PRESS_ENTER_LINES=${TUI_PRESS_ENTER_LINES:-8}
declare -a TUI_CRUMB_STACK=()

# tui_json_enabled — True when TUI view commands should use --json output.
tui_json_enabled() {
	[[ "${TUI_JSON_OUTPUT:-0}" == "1" ]]
}

# tui_json_flag — Return 1 or 0 for command json arguments.
tui_json_flag() {
	if tui_json_enabled; then
		printf '1'
	else
		printf '0'
	fi
}

# Boolean keys exposed in the quick-toggle menu (per-game overrides).
TUI_TOGGLE_KEYS=(
	GAMEMODE MANGOHUD GAMESCOPE GAMESCOPE_ADAPTIVE_SYNC VRAM_HOGS
	NETWORK_TUNE PIPEWIRE_LOW_LATENCY SHADER_CACHE_TRIM GPU_POWER_CHECK
	LAUNCH_WATCHDOG GAME_PERFORMANCE BENCHMARK DEBUG
	FORCE_NATIVE FORCE_PROTON DISABLE_CPU_AFFINITY
)

# tui_appid_env_path — Preferred write path for per-game configs (GAMES_DIR).
tui_appid_env_path() {
	appid_env_write_path "$1"
}

# tui_ensure_appid_env — Create per-game config from suggested preset when missing.
tui_ensure_appid_env() {
	local appid=$1
	appid_env_exists "$appid" || init_appid_config "$appid" "" 0
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

# tui_validate_game_config_brief — One-line validation hint after per-game edits.
tui_validate_game_config_brief() {
	local appid=$1 file
	file="$(tui_appid_env_path "$appid")"
	[[ -f "$file" ]] || return 0
	if ! validate_single_config_file "$file" >/dev/null 2>&1; then
		echo "validation: issues in $(basename "$file") — use [Manage] Validate"
	fi
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

# tui_open_or_create_in_editor — Open a config file, creating an empty file when missing.
tui_open_or_create_in_editor() {
	local path=$1
	if [[ ! -f "$path" ]]; then
		mkdir -p "$(dirname "$path")"
		touch "$path"
		echo "Created $path"
	fi
	tui_open_in_editor "$path"
}

# tui_env_remove_key — Remove KEY= lines from a per-game .env file.
tui_env_remove_key() {
	local file=$1 key=$2
	local tmp found=0 line
	[[ -f "$file" ]] || return 1
	tmp="$(mktemp)"
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ "$line" =~ ^[[:space:]]*${key}= ]]; then
			found=1
			continue
		fi
		printf '%s\n' "$line"
	done < "$file" > "$tmp"
	if (( ! found )); then
		rm -f "$tmp"
		return 1
	fi
	mv "$tmp" "$file"
	return 0
}

# tui_game_override_keys — List keys explicitly set in a per-game .env file.
tui_game_override_keys() {
	local appid=$1 file
	file="$(tui_appid_env_path "$appid")"
	[[ -f "$file" ]] || return 0
	grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$file" 2>/dev/null \
		| sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/' \
		| sort -u
}

# tui_clear_game_key_override — Drop a per-game override so layers inherit again.
tui_clear_game_key_override() {
	local appid=$1 key=$2 file effective
	file="$(tui_appid_env_path "$appid")"
	if tui_env_remove_key "$file" "$key"; then
		effective="$(tui_effective_key "$appid" "$key")"
		echo "Cleared $key override in $(basename "$file") (now inherits: ${effective:-unset})"
		return 0
	fi
	echo "No override for $key in $(basename "$file")"
	return 1
}

# tui_clear_all_game_overrides — Remove every per-game override key.
tui_clear_all_game_overrides() {
	local appid=$1 file key -a keys=()
	file="$(tui_appid_env_path "$appid")"
	mapfile -t keys < <(tui_game_override_keys "$appid")
	((${#keys[@]})) || {
		echo "No per-game overrides in $(basename "$file")"
		return 0
	}
	tui_confirm "Clear all ${#keys[@]} override(s) in $(basename "$file")?" || return 0
	for key in "${keys[@]}"; do
		tui_env_remove_key "$file" "$key"
	done
	echo "Cleared ${#keys[@]} override(s) — all keys now inherit from layers"
	tui_validate_game_config_brief "$appid"
}

# tui_game_validation_label — Short validation summary for game action headers.
tui_game_validation_label() {
	local appid=$1 file
	file="$(tui_appid_env_path "$appid")"
	[[ -f "$file" ]] || {
		printf 'inherits layers'
		return 0
	}
	if validate_single_config_file "$file" >/dev/null 2>&1; then
		printf 'config ok'
	else
		printf 'validation issues'
	fi
}

# tui_build_recent_picker_lines — Recent games only (from launch.log).
tui_build_recent_picker_lines() {
	local -a all_lines=() recent_ids=() line appid
	mapfile -t all_lines < <(tui_list_games_lines)
	mapfile -t recent_ids < <(tui_recent_game_appids 12)
	for appid in "${recent_ids[@]}"; do
		for line in "${all_lines[@]}"; do
			[[ "${line%% *}" == "$appid" ]] || continue
			printf '[recent] %s\n' "$line"
			break
		done
	done
}

# tui_pick_recent_game_appid — Select from recent games only; prints AppID.
tui_pick_recent_game_appid() {
	local line appid header script_q
	script_q="$(printf '%q' "$LAUNCHLAYER_MAIN_SCRIPT")"
	header="Recent games (from launch.log, Ctrl-E: editor, Ctrl-D: dry-run)"
	if tui_has_fzf; then
		line="$(tui_build_recent_picker_lines | fzf \
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
		mapfile -t lines < <(tui_build_recent_picker_lines)
		((${#lines[@]})) || {
			echo "No recent games in launch.log — launch a game through LaunchLayer first." >&2
			return 1
		}
		line="$(tui_select_pick "$header" "${lines[@]}")" || return 1
	fi
	appid="$(tui_parse_game_picker_line "$line")"
	[[ "$appid" =~ ^[0-9]+$ ]] || return 1
	printf '%s\n' "$appid"
}

# tui_recent_games_menu — Jump straight to a recently played title.
tui_recent_games_menu() {
	local appid
	appid="$(tui_pick_recent_game_appid)" || return 0
	tui_game_actions "$appid"
}

# tui_clear_override_menu — Pick and remove a per-game override key.
tui_clear_override_menu() {
	local appid=$1 key -a keys=()
	mapfile -t keys < <(tui_game_override_keys "$appid")
	((${#keys[@]})) || {
		echo "No per-game overrides in $(basename "$(tui_appid_env_path "$appid")")"
		return 0
	}
	key="$(tui_menu "Pick key to clear" \
		"Clear ALL overrides" \
		"${keys[@]}")" || return 0
	if [[ "$key" == "Clear ALL overrides" ]]; then
		tui_clear_all_game_overrides "$appid"
		return 0
	fi
	tui_clear_game_key_override "$appid" "$key"
	tui_validate_game_config_brief "$appid"
}
