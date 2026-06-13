# shellcheck shell=bash
# lib/tui/hub/publish.sh — Hub publish, update, and delete

[[ -n "${LAUNCHLAYER_TUI_HUB_PUBLISH_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HUB_PUBLISH_LOADED=1

# tui_hub_publish_for_appid — Upload one game's config with optional note.
tui_hub_publish_for_appid() {
	local appid=$1 note="" config_id="" name path action
	tui_hub_require_ready || return 0
	tui_hub_load_context

	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	path="$(resolve_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		tui_show_text "No config at $path — scaffold one first." "Publish"
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
			tui_run_capture "Publishing to hub…" hub_publish_config "$appid" --note "$note" --config-id "$config_id" || true
		else
			tui_run_capture "Publishing to hub…" hub_publish_config "$appid" --config-id "$config_id" || true
		fi
	elif [[ -n "$note" ]]; then
		tui_run_capture "Publishing to hub…" hub_publish_config "$appid" --note "$note" || true
	else
		tui_run_capture "Publishing to hub…" hub_publish_config "$appid" || true
	fi
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
						tui_run_capture "Publishing to hub…" hub_publish_config --all-configured --note "$note" --config-id "$config_id" || true
					else
						tui_run_capture "Publishing to hub…" hub_publish_config --all-configured --config-id "$config_id" || true
					fi
					;;
				"Auto config ID per game")
					if [[ -n "$note" ]]; then
						tui_run_capture "Publishing to hub…" hub_publish_config --all-configured --note "$note" || true
					else
						tui_run_capture "Publishing to hub…" hub_publish_config --all-configured || true
					fi
					;;
				*) return 0 ;;
			esac
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
			tui_run_capture "Applying shared config…" hub_apply_config "$config_id" || true
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
		tui_show_text "No config at $path — scaffold one first." "Update"
		return 1
	}

	existing_id="$(tui_spinner_capture "Checking hub…" hub_find_my_config_id "$appid" || true)"
	if [[ -z "$existing_id" ]]; then
		tui_show_text "No shared hub config for $name on this machine yet." "Update"
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
		tui_run_capture "Updating hub config…" hub_update_config "$appid" --note "$note" || true
	else
		tui_run_capture "Updating hub config…" hub_update_config "$appid" || true
	fi
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
						tui_run_capture "Updating hub configs…" hub_update_config --all-configured --note "$note" || true
					else
						tui_run_capture "Updating hub configs…" hub_update_config --all-configured || true
					fi
					;;
				"Include games without hub config (--include-new)")
					if [[ -n "$note" ]]; then
						tui_run_capture "Updating hub configs…" hub_update_config --all-configured --note "$note" --include-new || true
					else
						tui_run_capture "Updating hub configs…" hub_update_config --all-configured --include-new || true
					fi
					;;
				*) return 0 ;;
			esac
			;;
		"Update by config ID")
			tui_hub_load_context
			read -r -p "Hub config ID to update: " config_id </dev/tty || return 0
			[[ -n "$config_id" ]] || return 0
			read -r -p "Optional note: " note </dev/tty || true
			if [[ -n "$note" ]]; then
				tui_run_capture "Updating hub config…" hub_update_config "$config_id" --note "$note" || true
			else
				tui_run_capture "Updating hub config…" hub_update_config "$config_id" || true
			fi
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
	tui_run_capture "Deleting hub config…" hub_delete_config "$config_id" --yes || true
}
