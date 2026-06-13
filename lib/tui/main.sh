# shellcheck shell=bash
# lib/tui/main.sh — Main menu loop and TUI entry point.
# tui_cache_report — Cache audit using TUI min-GB preference.
tui_cache_report() {
	local min_gb=${TUI_CACHE_MIN_GB:-5}
	[[ "$min_gb" =~ ^[0-9]+$ ]] || min_gb=5
	cache_report "$min_gb" both "" 0
}

# tui_main_menu — Top-level menu loop.
run_tui() {
	local choice issues -a main_items=() prefix_items=() suffix_items=(
		"Quit"
	)
	local i hub

	tui_require_tty || return 1
	tui_load_config
	load_backup_prefs
	TUI_PRESS_ENTER_LINES=${TUI_PRESS_ENTER_LINES:-8}

	if ! tui_has_fzf; then
		echo "Note: install fzf for fuzzy search and live config previews$(tool_warn_suffix fzf)." >&2
	fi

	tui_print_status_banner

	issues="$(doctor_issue_count)"
	(( issues > 0 )) && prefix_items+=("Doctor: ${issues} issue(s)")

	if [[ -n "${TUI_LAST_MENU:-}" ]]; then
		prefix_items+=("▶ Resume: ${TUI_LAST_MENU}")
	fi

	main_items=(
		"Games"
		"Config library"
		"Backup & restore"
		"System & tools"
		"TUI settings"
	)

	if [[ -n "${TUI_LAST_MENU:-}" ]]; then
		for i in "${!main_items[@]}"; do
			[[ "${main_items[$i]}" == "$TUI_LAST_MENU" ]] \
				&& main_items[$i]="${main_items[$i]}  ← last visit"
		done
	fi

	main_items=("${prefix_items[@]}" "${main_items[@]}" "${suffix_items[@]}")

	if [[ "${TUI_RESUME_LAST_MENU:-0}" == "1" && -n "${TUI_LAST_MENU:-}" ]]; then
		tui_open_last_menu || true
	fi

	while true; do
		choice="$(tui_menu "LaunchLayer ${LAUNCHLAYER_VERSION}" "${main_items[@]}")" || break

		case "$choice" in
			Doctor:*)
				tui_run_paged show_doctor "$(tui_json_flag)" || true
				;;
			"▶ Resume:"*)
				hub="${choice#▶ Resume: }"
				TUI_LAST_MENU=$hub
				tui_open_last_menu
				;;
			Games|"Games  ← last visit")
				tui_games_menu
				;;
			"Config library"|"Config library  ← last visit")
				tui_config_menu
				;;
			"Backup & restore"|"Backup & restore  ← last visit")
				tui_backup_menu
				;;
			"System & tools"|"System & tools  ← last visit")
				tui_system_menu
				;;
			"TUI settings"|"TUI settings  ← last visit")
				tui_settings_menu
				;;
			Quit|"")
				break
				;;
		esac
	done
}
