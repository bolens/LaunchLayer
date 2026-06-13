# shellcheck shell=bash
# lib/tui/settings-menu.sh — Shared helpers for compact preference menus.

[[ -n "${LAUNCHLAYER_TUI_SETTINGS_MENU_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_SETTINGS_MENU_LOADED=1

# tui_prefs_path_short — Home-relative path for menu rows.
tui_prefs_path_short() {
	local p=${1:-}
	case "$p" in
		"$HOME"/*) printf '~/%s' "${p#"$HOME/"}" ;;
		"") printf '(not set)' ;;
		*) printf '%s' "$p" ;;
	esac
}

# tui_prefs_truncate — Trim long values for menu labels.
tui_prefs_truncate() {
	local text=${1:-} max=${2:-48}
	[[ ${#text} -le $max ]] && printf '%s' "$text" && return 0
	printf '%s…' "${text:0:$((max - 1))}"
}

# tui_prefs_footer — Standard show / reset / save / back rows.
tui_prefs_footer() {
	local arr_name=$1 mode=${2:-save}
	# shellcheck disable=SC2178 # nameref to caller's array
	local -n footer_items=$arr_name
	footer_items+=("" "[·] Show all" "[·] Reset defaults")
	case "$mode" in
		interface)
			footer_items+=("[·] Save and return" "Back without saving")
			;;
		*)
			footer_items+=("[·] Save" "Back")
			;;
	esac
}

# tui_prefs_hub_menu — Top-level settings hub (all .conf files).
tui_prefs_hub_menu() {
	local action
	tui_crumb_enter "Settings"
	tui_remember_main_menu "Settings"

	while true; do
		TUI_MENU_CONTEXT=settings
		action="$(tui_menu "tui.conf · backup.conf · hub.conf" \
			"Interface" \
			"Backup" \
			"Community hub" \
			"Back")" || {
			tui_crumb_leave
			return 0
		}

		case "$action" in
			Interface) tui_interface_settings_menu ;;
			Backup) tui_backup_settings_menu ;;
			"Community hub") tui_hub_settings_menu ;;
			*) tui_crumb_leave; return 0 ;;
		esac
	done
}

# tui_settings_menu — Alias for resume / legacy dispatch.
tui_settings_menu() {
	tui_interface_settings_menu
}
