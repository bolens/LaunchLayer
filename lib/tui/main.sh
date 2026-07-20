# shellcheck shell=bash
# lib/tui/main.sh — Main menu loop and TUI entry point.

# tui_main_menu — Top-level menu loop.
run_tui() {
	local choice issues hub
	local -a main_items=() prefix_items=() suffix_items=(
		"Quit"
	)

	tui_require_tty || return 1
	tui_load_config
	load_backup_prefs
	TUI_PRESS_ENTER_LINES=${TUI_PRESS_ENTER_LINES:-8}

	if ! tui_has_fzf; then
		echo "Note: install fzf for fuzzy search and live config previews$(tool_warn_suffix fzf)." >&2
	else
		export TUI_PANEL_ACTIVE=1
		tui_panel_init
	fi

	tui_games_cache_bootstrap

	issues="$(doctor_issue_count)"
	(( issues > 0 )) && prefix_items+=("Doctor $(tui_glyph_doctor "$issues")")

	if [[ -n "${TUI_LAST_MENU:-}" ]]; then
		prefix_items+=("▶ Resume: ${TUI_LAST_MENU}")
	fi

	main_items=(
		"Status"
		"Games"
		"Config library"
		"Backup & restore"
		"Community hub"
		"System & tools"
		"Settings"
	)

	main_items=("${prefix_items[@]}" "${main_items[@]}" "${suffix_items[@]}")

	if [[ "${TUI_RESUME_LAST_MENU:-0}" == "1" && -n "${TUI_LAST_MENU:-}" ]]; then
		tui_open_last_menu || true
	fi

	while true; do
		TUI_MENU_CONTEXT=main
		if (( issues > 0 )) && tui_has_fzf; then
			local script_q
			script_q="$(printf '%q' "$LAUNCHLAYER_MAIN_SCRIPT")"
			TUI_FZF_FOOTER_SUFFIX="ctrl-d doctor"
			TUI_FZF_EXTRA_BINDS=(
				"ctrl-d:execute(${script_q} --doctor $(tui_json_flag) 2>&1 | head -n 30 < /dev/tty)+abort"
			)
		fi
		choice="$(tui_menu "LaunchLayer ${LAUNCHLAYER_VERSION}" "${main_items[@]}")" || break
		unset TUI_MENU_CONTEXT TUI_FZF_EXTRA_BINDS TUI_FZF_FOOTER_SUFFIX

		case "$choice" in
			Doctor*)
				tui_run_paged show_doctor "$(tui_json_flag)" || true
				;;
			Status)
				tui_status_menu
				;;
			"▶ Resume:"*)
				hub="${choice#▶ Resume: }"
				TUI_LAST_MENU=$hub
				tui_open_last_menu
				;;
			Games)
				tui_games_menu
				;;
			"Config library")
				tui_config_menu
				;;
			"Backup & restore")
				tui_backup_menu
				;;
			"Community hub")
				tui_hub_menu
				;;
			"System & tools")
				tui_system_menu
				;;
			Settings)
				tui_prefs_hub_menu
				;;
			Quit|"")
				break
				;;
		esac
	done
}
