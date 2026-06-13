# shellcheck shell=bash
# lib/tui/menus-system-completions.sh

[[ -n "${LAUNCHLAYER_TUI_SYSTEM_COMPLETIONS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_SYSTEM_COMPLETIONS_LOADED=1

# tui_format_completion_shell_option — Menu line showing per-shell completion install state.
tui_format_completion_shell_option() {
	local shell=$1 brief label suffix=""
	brief="$(completions_shell_status_brief "$shell")"
	[[ "$shell" == osh ]] && suffix=" (uses bash)"
	case "$brief" in
		enabled)
			label="$(printf '%s %s' "$shell" "$(tui_glyph_ok)")"
			;;
		partial)
			label="$(printf '%s %s' "$shell" "$(tui_glyph_mid)")"
			;;
		*)
			label="$(printf '%s %s' "$shell" "$(tui_glyph_off)")"
			;;
	esac
	if [[ -n "$suffix" ]]; then
		printf '%s%s' "$label" "$(cli_dim "$suffix")"
	else
		printf '%s' "$label"
	fi
}

# tui_completion_shell_from_option — Extract shell name from a completions menu line.
tui_completion_shell_from_option() {
	local option=$1
	option="$(printf '%s' "$option" | tui_strip_ansi)"
	option="${option#\[Shell\] }"
	read -r option _ <<< "$option"
	printf '%s' "$option"
}

# tui_toggle_completion_shell — Enable or disable completions for one shell.
tui_toggle_completion_shell() {
	local shell=$1
	if completions_shell_is_enabled "$shell"; then
		tui_run_paged completions_disable "$shell" || true
	else
		tui_run_paged completions_enable "$shell" || true
	fi
}

# tui_completions_menu — Shell tab-completion install status and toggles.
tui_completions_menu() {
	local action shell login_shell last_anchor="" -a options=()
	login_shell="$(detect_login_shell_name)"
	while true; do
		options=("Show status")
		for shell in "${LAUNCHLAYER_COMPLETION_SHELLS[@]}"; do
			options+=("[Shell] $(tui_format_completion_shell_option "$shell")")
		done
		options+=(
			"Enable (login shell: ${login_shell})"
			"Enable all shells"
			"Disable (login shell: ${login_shell})"
			"Disable all shells"
			"Back"
		)
		tui_menu_set_start_pos "$last_anchor" "${options[@]}"
		action="$(tui_menu_anchored "Shell completions" "$last_anchor" "${options[@]}")" || return 0

		case "$action" in
			"Show status")
				tui_run_paged completions_show_status 0 || true
				;;
			"Enable (login shell:"*)
				tui_run_paged completions_enable "$login_shell" || true
				;;
			"Enable all shells")
				tui_run_paged completions_enable all || true
				;;
			"Disable (login shell:"*)
				tui_run_paged completions_disable "$login_shell" || true
				;;
			"Disable all shells")
				tui_run_paged completions_disable all || true
				;;
			"[Shell]"*)
				shell="$(tui_completion_shell_from_option "$action")"
				if profile_list_contains "${LAUNCHLAYER_COMPLETION_SHELLS[*]}" "$shell"; then
					last_anchor="[Shell] ${shell}:"
					tui_toggle_completion_shell "$shell"
				fi
				;;
			"Back"|*)
				return 0
				;;
		esac
	done
}
