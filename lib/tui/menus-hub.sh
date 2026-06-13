# shellcheck shell=bash
# lib/tui/menus-hub.sh — Community hub menus (CLI parity for --hub-*).

# tui_hub_load_context — Load config layers before hub fingerprint/API calls.
tui_hub_load_context() {
	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults
}

# tui_hub_status_brief — Short hub connection label for menus and banner.
tui_hub_status_brief() {
	load_hub_prefs
	if [[ -n "${HUB_PREFS_URL:-}" ]]; then
		printf 'url · fp:%s' "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
	else
		printf 'not configured · fp:%s' "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
	fi
}

# tui_hub_fingerprint_level_help — Explain fingerprint tiers before choosing.
tui_hub_fingerprint_level_help() {
	cat <<'EOF'
Fingerprint levels control how much machine data is sent for hub
publish, recommend, and similar-machine matching.

  minimal  — GPU vendor, OS, session, profiles, display/refresh tiers,
             desktop compositor, X3D flag, platform flags (VRR, WSL, …)

  standard — minimal + audio stack, VRAM tier, monitor layout, aspect,
             exact primary resolution, X3D CPU mask, iGPU presence

  detailed — standard + every GPU (model/VRAM/PCI), all monitors,
             output connector names, OS id

Saved to hub.conf as fingerprint_level=. Default is minimal.
EOF
	tui_press_enter
}

# tui_hub_fingerprint_level_menu — Pick and persist fingerprint_level in hub.conf.
tui_hub_fingerprint_level_menu() {
	local val level current
	load_hub_prefs
	current="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"

	val="$(tui_menu "Fingerprint privacy (current: ${current})" \
		"minimal — GPU/OS/tiers/desktop only" \
		"standard — + audio, VRAM tier, monitors, exact display" \
		"detailed — + full GPU/monitor lists and output names" \
		"What does each level share?" \
		"Back")" || return 0

	case "$val" in
		"minimal "*) level=minimal ;;
		"standard "*) level=standard ;;
		"detailed "*) level=detailed ;;
		"What does each level share?"*)
			tui_hub_fingerprint_level_help
			tui_hub_fingerprint_level_menu
			return 0
			;;
		*) return 0 ;;
	esac

	[[ "$level" == "$current" ]] && return 0

	HUB_PREFS_FINGERPRINT_LEVEL=$level
	save_hub_prefs
	printf 'Fingerprint level set to %s (%s).\n' "$level" "$(hub_fingerprint_level_desc "$level")"
	printf 'Saved to %s\n' "$(hub_prefs_path)"
	tui_press_enter
}

# tui_hub_require_ready — curl + hub_url must be available.
tui_hub_require_ready() {
	command -v curl >/dev/null 2>&1 || {
		echo "Hub requires curl$(tool_warn_suffix curl)." >&2
		tui_press_enter
		return 1
	}
	if ! hub_require_url; then
		tui_press_enter
		return 1
	fi
	load_hub_prefs
	return 0
}

# tui_hub_require_json_parser — jq or python3 for picking hub results.
tui_hub_require_json_parser() {
	command -v jq >/dev/null 2>&1 && return 0
	command -v python3 >/dev/null 2>&1 && return 0
	echo "Hub browsing requires jq or python3." >&2
	tui_press_enter
	return 1
}

# tui_hub_settings_menu — Edit hub.conf (parity with backup settings).
tui_hub_settings_menu() {
	local action val url_label token_label label_label level_label
	load_hub_prefs
	url_label="${HUB_PREFS_URL:-(not set)}"
	token_label="$([[ -n "${HUB_PREFS_PUBLISH_TOKEN:-}" ]] && echo '(set)' || echo '(not set)')"
	label_label="${HUB_PREFS_MACHINE_LABEL:-(not set)}"
	level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"

	while true; do
		action="$(tui_menu "Hub settings (saved to $(hub_prefs_path))" \
			"[Connection] hub_url: ${url_label}" \
			"[Connection] publish_token: ${token_label}" \
			"[Identity] machine_label: ${label_label}" \
			"[Privacy] fingerprint_level: ${level_label}" \
			"Show current preferences" \
			"Open hub.conf in \$EDITOR" \
			"Reset to example defaults" \
			"Save settings" \
			"Back")" || return 0

		case "$action" in
			"[Connection] hub_url:"*)
				read -r -p "Hub base URL [${HUB_PREFS_URL}]: " val </dev/tty || continue
				[[ -n "$val" ]] && HUB_PREFS_URL="$val"
				url_label="${HUB_PREFS_URL:-(not set)}"
				;;
			"[Connection] publish_token:"*)
				read -r -p "Publish token (empty to clear) [hidden]: " val </dev/tty || continue
				HUB_PREFS_PUBLISH_TOKEN="$val"
				token_label="$([[ -n "$val" ]] && echo '(set)' || echo '(not set)')"
				;;
			"[Identity] machine_label:"*)
				read -r -p "Machine label [${HUB_PREFS_MACHINE_LABEL}]: " val </dev/tty || continue
				HUB_PREFS_MACHINE_LABEL="$val"
				label_label="${HUB_PREFS_MACHINE_LABEL:-(not set)}"
				;;
			"[Privacy] fingerprint_level:"*)
				tui_hub_fingerprint_level_menu
				load_hub_prefs
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"Show current preferences")
				show_hub_prefs 0
				tui_press_enter
				;;
			"Open hub.conf in \$EDITOR")
				if [[ ! -f "$(hub_prefs_path)" ]]; then
					save_hub_prefs
					echo "Created $(hub_prefs_path)"
				fi
				tui_open_in_editor "$(hub_prefs_path)"
				load_hub_prefs
				url_label="${HUB_PREFS_URL:-(not set)}"
				token_label="$([[ -n "${HUB_PREFS_PUBLISH_TOKEN:-}" ]] && echo '(set)' || echo '(not set)')"
				label_label="${HUB_PREFS_MACHINE_LABEL:-(not set)}"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"Reset to example defaults")
				tui_confirm "Reset hub settings to repo example?" || continue
				reset_hub_prefs || continue
				load_hub_prefs
				url_label="${HUB_PREFS_URL:-(not set)}"
				token_label="$([[ -n "${HUB_PREFS_PUBLISH_TOKEN:-}" ]] && echo '(set)' || echo '(not set)')"
				label_label="${HUB_PREFS_MACHINE_LABEL:-(not set)}"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"Save settings")
				save_hub_prefs
				echo "Saved hub settings to $(hub_prefs_path)"
				tui_press_enter
				return 0
				;;
			*) return 0 ;;
		esac
	done
}

# tui_hub_show_fingerprint — View machine fingerprint.
tui_hub_show_fingerprint() {
	tui_hub_load_context
	tui_run_paged hub_show_fingerprint "$(tui_json_flag)" || true
}

# tui_hub_search_machines — List machines similar to this one.
tui_hub_search_machines() {
	local limit=10 action
	tui_hub_require_ready || return 0
	tui_hub_load_context
	action="$(tui_menu "Similar machines limit" \
		"Top 5" \
		"Top 10" \
		"Top 20" \
		"Back")" || return 0
	case "$action" in
		"Top 5") limit=5 ;;
		"Top 10") limit=10 ;;
		"Top 20") limit=20 ;;
		*) return 0 ;;
	esac
	tui_run_paged hub_search_machines --limit "$limit" "$(tui_json_flag)" || true
}

# tui_hub_parse_recommendation_lines — Build picker rows from recommend JSON.
tui_hub_parse_recommendation_lines() {
	local response=$1
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$response" | jq -r "$(hub_jq_recommend_picker_filter)" 2>/dev/null
		return 0
	fi
	HUB_JSON_RESPONSE=$response python3 -c '
import json, os
from datetime import datetime, timezone

def fmt(ms):
    if not isinstance(ms, (int, float)) or ms <= 0:
        return "unknown"
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d")

data = json.loads(os.environ["HUB_JSON_RESPONSE"])
for row in data.get("results") or []:
    cid = row.get("config_id", "")
    sim = row.get("similarity", 0)
    label = row.get("machine_label") or row.get("gpu_vendor") or "unknown"
    note = row.get("note") or "-"
    updated = fmt(row.get("published_at"))
    print(f"{cid}\t{sim}% match · {label} · updated {updated} · {note}")
' 2>/dev/null
}

# tui_hub_pick_recommendation — Pick one config_id from recommend response.
tui_hub_pick_recommendation() {
	local response=$1
	local -a rows=() row config_id
	mapfile -t rows < <(tui_hub_parse_recommendation_lines "$response")
	((${#rows[@]})) || {
		echo "No community configs from similar machines."
		return 1
	}
	row="$(tui_menu "Pick a shared config" "${rows[@]}")" || return 1
	config_id="${row%%$'\t'*}"
	[[ -n "$config_id" ]] || return 1
	printf '%s\n' "$config_id"
}

# tui_hub_recommend_for_appid — Fetch and optionally apply recommendations for one game.
tui_hub_recommend_for_appid() {
	local appid=$1 limit=${2:-10} config_id response name
	tui_hub_require_ready || return 0
	tui_hub_require_json_parser || return 0
	tui_hub_load_context

	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	response="$(hub_recommend_configs "$appid" --limit "$limit" --json 2>&1)" || {
		printf '%s\n' "$response"
		tui_press_enter
		return 1
	}

	if tui_json_enabled; then
		tui_run_paged printf '%s\n' "$response" || true
		return 0
	fi

	config_id="$(tui_hub_pick_recommendation "$response")" || {
		tui_press_enter
		return 0
	}

	action="$(tui_menu "Config $config_id" \
		"Preview apply (dry-run)" \
		"Apply to $name" \
		"Back")" || return 0

	case "$action" in
		"Preview apply (dry-run)")
			tui_run_paged hub_apply_config "$config_id" --dry-run || true
			;;
		"Apply to"*)
			tui_confirm "Apply hub config $config_id to $name?" || return 0
			hub_apply_config "$config_id" || true
			tui_press_enter
			;;
		*) ;;
	esac
}

# tui_hub_recommend_menu — Pick a game then browse recommendations.
tui_hub_recommend_menu() {
	local appid limit action
	tui_hub_require_ready || return 0
	appid="$(tui_pick_game_appid)" || return 0
	action="$(tui_menu "Recommendation limit" \
		"Top 5" \
		"Top 10" \
		"Top 20" \
		"Back")" || return 0
	case "$action" in
		"Top 5") limit=5 ;;
		"Top 10") limit=10 ;;
		"Top 20") limit=20 ;;
		*) return 0 ;;
	esac
	tui_hub_recommend_for_appid "$appid" "$limit"
}

# tui_hub_publish_for_appid — Upload one game's config with optional note.
tui_hub_publish_for_appid() {
	local appid=$1 note="" config_id="" name path action
	tui_hub_require_ready || return 0
	tui_hub_load_context

	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	path="$(resolve_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		echo "No config at $path — scaffold one first."
		tui_press_enter
		return 1
	}

	read -r -p "Optional note for hub [$name]: " note </dev/tty || true
	action="$(tui_menu "Publish options" \
		"Publish (auto config ID)" \
		"Publish with specific config ID" \
		"Back")" || return 0
	case "$action" in
		"Publish with specific config ID")
			read -r -p "Hub config ID: " config_id </dev/tty || return 0
			[[ -n "$config_id" ]] || return 0
			;;
		"Publish (auto config ID)")
			;;
		*) return 0 ;;
	esac

	if [[ -n "$config_id" ]]; then
		if [[ -n "$note" ]]; then
			hub_publish_config "$appid" --note "$note" --config-id "$config_id"
		else
			hub_publish_config "$appid" --config-id "$config_id"
		fi
	elif [[ -n "$note" ]]; then
		hub_publish_config "$appid" --note "$note"
	else
		hub_publish_config "$appid"
	fi
	tui_press_enter
}

# tui_hub_publish_menu — Publish one or all configured games.
tui_hub_publish_menu() {
	local action appid note config_id
	tui_hub_require_ready || return 0

	action="$(tui_menu "Publish to hub" \
		"Publish selected game" \
		"Publish all configured games" \
		"Back")" || return 0

	case "$action" in
		"Publish selected game")
			appid="$(tui_pick_game_appid)" || return 0
			tui_hub_publish_for_appid "$appid"
			;;
		"Publish all configured games")
			read -r -p "Optional note for all uploads: " note </dev/tty || true
			action="$(tui_menu "Publish all — config ID" \
				"Auto config ID per game" \
				"Use one config ID for all (--config-id)" \
				"Back")" || return 0
			case "$action" in
				"Use one config ID for all (--config-id)")
					read -r -p "Hub config ID: " config_id </dev/tty || return 0
					[[ -n "$config_id" ]] || return 0
					if [[ -n "$note" ]]; then
						hub_publish_config --all-configured --note "$note" --config-id "$config_id"
					else
						hub_publish_config --all-configured --config-id "$config_id"
					fi
					;;
				"Auto config ID per game")
					if [[ -n "$note" ]]; then
						hub_publish_config --all-configured --note "$note"
					else
						hub_publish_config --all-configured
					fi
					;;
				*) return 0 ;;
			esac
			tui_press_enter
			;;
		*) ;;
	esac
}

# tui_hub_apply_menu — Apply a shared config by id.
tui_hub_apply_menu() {
	local config_id action
	tui_hub_require_ready || return 0
	tui_hub_require_json_parser || return 0

	read -r -p "Hub config ID: " config_id </dev/tty || return 0
	[[ -n "$config_id" ]] || return 0

	action="$(tui_menu "Apply hub config" \
		"Preview (dry-run)" \
		"Apply" \
		"Back")" || return 0

	case "$action" in
		"Preview (dry-run)")
			tui_run_paged hub_apply_config "$config_id" --dry-run || true
			;;
		"Apply")
			tui_confirm "Apply hub config $config_id?" || return 0
			hub_apply_config "$config_id" || true
			tui_press_enter
			;;
		*) ;;
	esac
}

# tui_hub_update_for_appid — Update this machine's shared config for one game.
tui_hub_update_for_appid() {
	local appid=$1 note="" name path existing_id action
	tui_hub_require_ready || return 0
	tui_hub_load_context

	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	path="$(resolve_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		echo "No config at $path — scaffold one first."
		tui_press_enter
		return 1
	}

	existing_id="$(hub_find_my_config_id "$appid" 2>/dev/null || true)"
	if [[ -z "$existing_id" ]]; then
		echo "No shared hub config for $name on this machine yet."
		action="$(tui_menu "Publish instead?" \
			"Publish new hub config" \
			"Back")" || return 0
		case "$action" in
			"Publish new hub config")
				tui_hub_publish_for_appid "$appid"
				;;
			*) ;;
		esac
		return 0
	fi

	read -r -p "Optional note for hub update [$name]: " note </dev/tty || true
	if [[ -n "$note" ]]; then
		hub_update_config "$appid" --note "$note" || true
	else
		hub_update_config "$appid" || true
	fi
	tui_press_enter
}

# tui_hub_update_menu — Update one, all, or by config id.
tui_hub_update_menu() {
	local action appid note config_id
	tui_hub_require_ready || return 0

	action="$(tui_menu "Update shared configs" \
		"Update selected game" \
		"Update all my shared configs" \
		"Update by config ID" \
		"Back")" || return 0

	case "$action" in
		"Update selected game")
			appid="$(tui_pick_game_appid)" || return 0
			tui_hub_update_for_appid "$appid"
			;;
		"Update all my shared configs")
			read -r -p "Optional note for all updates: " note </dev/tty || true
			action="$(tui_menu "Update all — scope" \
				"Existing shared configs only (default)" \
				"Include games without hub config (--include-new)" \
				"Back")" || return 0
			case "$action" in
				"Existing shared configs only (default)")
					if [[ -n "$note" ]]; then
						hub_update_config --all-configured --note "$note" || true
					else
						hub_update_config --all-configured || true
					fi
					;;
				"Include games without hub config (--include-new)")
					if [[ -n "$note" ]]; then
						hub_update_config --all-configured --note "$note" --include-new || true
					else
						hub_update_config --all-configured --include-new || true
					fi
					;;
				*) return 0 ;;
			esac
			tui_press_enter
			;;
		"Update by config ID")
			tui_hub_load_context
			read -r -p "Hub config ID to update: " config_id </dev/tty || return 0
			[[ -n "$config_id" ]] || return 0
			read -r -p "Optional note: " note </dev/tty || true
			if [[ -n "$note" ]]; then
				hub_update_config "$config_id" --note "$note" || true
			else
				hub_update_config "$config_id" || true
			fi
			tui_press_enter
			;;
		*) ;;
	esac
}

# tui_hub_delete_menu — Delete a shared config by id (privileged).
tui_hub_delete_menu() {
	local config_id
	tui_hub_require_ready || return 0

	read -r -p "Hub config ID to delete: " config_id </dev/tty || return 0
	[[ -n "$config_id" ]] || return 0

	tui_confirm "Delete hub config ${config_id}? This cannot be undone." || return 0
	hub_delete_config "$config_id" --yes || true
	tui_press_enter
}

# tui_hub_menu — Top-level community hub (parity with --hub-* CLI).
tui_hub_menu() {
	local action status_label level_label
	tui_crumb_enter "Community hub"
	tui_remember_main_menu "Community hub"
	load_hub_prefs
	status_label="$(tui_hub_status_brief)"
	level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"

	while true; do
		action="$(tui_menu "(${status_label})" \
			"Hub settings" \
			"Fingerprint level: ${level_label}" \
			"Machine fingerprint" \
			"Similar machines" \
			"Recommend configs (pick game)" \
			"Publish config" \
			"Update shared configs" \
			"Delete config by ID" \
			"Apply config by ID" \
			"Back")" || {
			tui_crumb_leave
			return 0
		}

		case "$action" in
			"Hub settings")
				tui_hub_settings_menu
				load_hub_prefs
				status_label="$(tui_hub_status_brief)"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"Fingerprint level:"*)
				tui_hub_fingerprint_level_menu
				load_hub_prefs
				status_label="$(tui_hub_status_brief)"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"Machine fingerprint")
				tui_hub_show_fingerprint
				;;
			"Similar machines")
				tui_hub_search_machines
				;;
			"Recommend configs (pick game)")
				tui_hub_recommend_menu
				;;
			"Publish config")
				tui_hub_publish_menu
				;;
			"Update shared configs")
				tui_hub_update_menu
				;;
			"Delete config by ID")
				tui_hub_delete_menu
				;;
			"Apply config by ID")
				tui_hub_apply_menu
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}

# tui_hub_game_actions — Hub shortcuts from the per-game menu.
tui_hub_game_actions() {
	local appid=$1 action
	tui_crumb_enter "Hub"

	while true; do
		if hub_url_configured; then
			load_hub_prefs
			action="$(tui_menu "Community hub (fp: ${HUB_PREFS_FINGERPRINT_LEVEL:-minimal})" \
				"Recommend configs from similar machines" \
				"Publish my config for this game" \
				"Update my shared config for this game" \
				"Fingerprint privacy level" \
				"Open full hub menu" \
				"Back")" || {
				tui_crumb_leave
				return 0
			}
		else
			load_hub_prefs
			action="$(tui_menu "Community hub (not configured · fp: ${HUB_PREFS_FINGERPRINT_LEVEL:-minimal})" \
				"Configure hub settings" \
				"Fingerprint privacy level" \
				"Machine fingerprint (offline)" \
				"Back")" || {
				tui_crumb_leave
				return 0
			}
		fi

		case "$action" in
			"Recommend configs from similar machines")
				tui_hub_recommend_for_appid "$appid" 10
				;;
			"Publish my config for this game")
				tui_hub_publish_for_appid "$appid"
				;;
			"Update my shared config for this game")
				tui_hub_update_for_appid "$appid"
				;;
			"Open full hub menu")
				tui_hub_menu
				;;
			"Fingerprint privacy level")
				tui_hub_fingerprint_level_menu
				;;
			"Configure hub settings")
				tui_hub_settings_menu
				;;
			"Machine fingerprint (offline)")
				tui_hub_show_fingerprint
				;;
			*) tui_crumb_leave; return 0 ;;
		esac
	done
}
