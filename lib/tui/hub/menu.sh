# shellcheck shell=bash
# lib/tui/hub/menu.sh — Hub top-level and per-game menus

[[ -n "${LAUNCHLAYER_TUI_HUB_MENU_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HUB_MENU_LOADED=1

# tui_hub_menu — Top-level community hub (parity with --hub-* CLI).
tui_hub_menu() {
	local action status_label
	tui_crumb_enter "Community hub"
	tui_remember_main_menu "Community hub"
	load_hub_prefs
	status_label="$(tui_hub_status_brief)"

	while true; do
		TUI_MENU_CONTEXT=hub
		action="$(tui_menu "(${status_label})" \
			"Hub settings" \
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
				"Hub settings" \
				"Open full hub menu" \
				"Back")" || {
				tui_crumb_leave
				return 0
			}
		else
			load_hub_prefs
			action="$(tui_menu "Community hub (not configured · fp: ${HUB_PREFS_FINGERPRINT_LEVEL:-minimal})" \
				"Hub settings" \
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
			"Hub settings"|"Configure hub settings")
				tui_hub_settings_menu
				;;
			"Machine fingerprint (offline)")
				tui_hub_show_fingerprint
				;;
			*) tui_crumb_leave; return 0 ;;
		esac
	done
}
