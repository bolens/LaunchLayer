# shellcheck shell=bash
# lib/tui/menus-status.sh — Status dashboard and quick diagnostics.

[[ -n "${LAUNCHLAYER_TUI_MENUS_STATUS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_STATUS_LOADED=1

# tui_status_menu — Glanceable status in the sidebar plus common checks.
tui_status_menu() {
	local action
	tui_crumb_enter "Status"

	while true; do
		TUI_MENU_CONTEXT=status
		action="$(tui_menu "At-a-glance system health" \
			"Run doctor" \
			"Runtime status" \
			"Detect environment" \
			"Back")" || {
			tui_crumb_leave
			return 0
		}

		case "$action" in
			"Run doctor")
				tui_run_paged show_doctor "$(tui_json_flag)" || true
				;;
			"Runtime status")
				tui_run_paged show_status "" "$(tui_json_flag)" || true
				;;
			"Detect environment")
				tui_run_paged show_detect_environment "$(tui_json_flag)" || true
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}
