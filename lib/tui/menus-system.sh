# shellcheck shell=bash
# lib/tui/menus-system.sh — System tools, setup, completions, and settings.
# tui_sysctl_menu — vm.max_map_count status and drop-in install.
tui_sysctl_menu() {
	local action
	while true; do
		action="$(tui_menu "vm.max_map_count (sysctl)" \
			"Show status" \
			"Install drop-in (needs root)" \
			"Back")" || return 0

		case "$action" in
			"Show status")
				tui_run_paged sysctl_status || true
				;;
			"Install drop-in (needs root)")
				if [[ $EUID -ne 0 ]]; then
					echo "Run: sudo $LAUNCHLAYER_MAIN_SCRIPT --sysctl install"
				else
					sysctl_install
				fi
				;;
			*) return 0 ;;
		esac
	done
}

# tui_vram_menu — Manual VRAM hog pause/resume and stale launch cleanup.
tui_vram_menu() {
	local action
	while true; do
		action="$(tui_menu "VRAM hogs & launch cleanup" \
			"Pause VRAM hogs" \
			"Resume VRAM hogs (force)" \
			"Cleanup stale launch session" \
			"Back")" || return 0

		case "$action" in
			"Pause VRAM hogs")
				pause_vram_hogs
				echo "VRAM hogs paused (refcount incremented)"
				;;
			"Resume VRAM hogs (force)")
				resume_vram_hogs_force
				echo "VRAM hogs resumed"
				;;
			"Cleanup stale launch session")
				cleanup_stale_launch
				echo "Stale launch cleanup finished"
				;;
			*) return 0 ;;
		esac
	done
}

# tui_format_completion_shell_option — Menu line showing per-shell completion install state.
tui_format_completion_shell_option() {
	local shell=$1 brief label suffix=""
	brief="$(completions_shell_status_brief "$shell")"
	[[ "$shell" == osh ]] && suffix=" (uses bash)"
	case "$brief" in
		enabled)
			if cli_uses_color; then
				label="$(printf '\033[1;32m%s: enabled\033[0m' "$shell")"
			else
				label="${shell}: enabled"
			fi
			;;
		partial)
			if cli_uses_color; then
				label="$(printf '\033[1;33m%s: partial\033[0m' "$shell")"
			else
				label="${shell}: partial"
			fi
			;;
		*)
			if cli_uses_color; then
				label="$(printf '\033[1;31m%s: disabled\033[0m' "$shell")"
			else
				label="${shell}: disabled"
			fi
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
	printf '%s' "${option%%:*}" | tr -d '[:space:]'
}

# tui_toggle_completion_shell — Enable or disable completions for one shell.
tui_toggle_completion_shell() {
	local shell=$1
	if completions_shell_is_enabled "$shell"; then
		completions_disable "$shell"
	else
		completions_enable "$shell"
	fi
}

# tui_completions_menu — Shell tab-completion install status and toggles.
tui_completions_menu() {
	local action shell login_shell -a options=()
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
		action="$(tui_menu "Shell completions" "${options[@]}")" || return 0

		case "$action" in
			"Show status")
				tui_run_paged completions_show_status 0 || true
				;;
			"Enable (login shell:"*)
				completions_enable "$login_shell"
				;;
			"Enable all shells")
				completions_enable all
				;;
			"Disable (login shell:"*)
				completions_disable "$login_shell"
				;;
			"Disable all shells")
				completions_disable all
				;;
			"[Shell]"*)
				shell="$(tui_completion_shell_from_option "$action")"
				if profile_list_contains "${LAUNCHLAYER_COMPLETION_SHELLS[*]}" "$shell"; then
					tui_toggle_completion_shell "$shell"
				fi
				;;
			"Back"|*)
				return 0
				;;
		esac
	done
}

# tui_system_menu — Diagnostics, runtime info, and onboarding.
tui_system_menu() {
	local action
	tui_crumb_enter "System & tools"
	tui_remember_main_menu "System & tools"

	while true; do
		action="$(tui_menu "Diagnostics & setup" \
			"Doctor (health check)" \
			"Detect environment" \
			"Runtime status" \
			"CPU topology" \
			"vm.max_map_count (sysctl)" \
			"VRAM hogs & launch cleanup" \
			"Cache report" \
			"Setup / onboarding" \
			"Back")" || {
			tui_crumb_leave
			return 0
		}

		case "$action" in
			"Doctor (health check)")
				tui_run_paged show_doctor "$(tui_json_flag)" || true
				;;
			"Detect environment")
				tui_run_paged show_detect_environment "$(tui_json_flag)" || true
				;;
			"Runtime status")
				tui_run_paged show_status "" "$(tui_json_flag)" || true
				;;
			"CPU topology")
				tui_run_paged show_cpu_topology || true
				;;
			"vm.max_map_count (sysctl)")
				tui_sysctl_menu
				;;
			"VRAM hogs & launch cleanup")
				tui_vram_menu
				;;
			"Cache report")
				tui_cache_report_menu
				;;
			"Setup / onboarding")
				tui_setup_menu
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}

# tui_setup_menu — Interactive setup shortcuts.
tui_setup_menu() {
	local action
	while true; do
		action="$(tui_menu "Setup / onboarding" \
			"Run full setup (completions + launch option)" \
			"Shell completions" \
			"Install launchlayer symlink" \
			"Install maintenance timer" \
			"Install backup timer" \
			"Print Steam launch option" \
			"Back")" || return 0

		case "$action" in
			"Run full setup (completions + launch option)")
				run_setup --completions --print-launch-option
				tui_press_enter
				;;
			"Shell completions")
				tui_completions_menu
				;;
			"Install launchlayer symlink")
				run_setup --symlink
				tui_press_enter
				;;
			"Install maintenance timer")
				run_setup --systemd
				tui_press_enter
				;;
			"Install backup timer")
				run_setup --backup-timer
				tui_press_enter
				;;
			"Print Steam launch option")
				run_setup --print-launch-option
				tui_press_enter
				;;
			*) return 0 ;;
		esac
	done
}

# tui_settings_menu — Persisted TUI preferences.
tui_settings_menu() {
	local action val filter_label json_label resume_label
	filter_label="${TUI_GAME_FILTER:-all}"
	json_label=$([[ "${TUI_JSON_OUTPUT:-0}" == "1" ]] && echo on || echo off)
	resume_label=$([[ "${TUI_RESUME_LAST_MENU:-0}" == "1" ]] && echo on || echo off)
	tui_crumb_enter "TUI settings"
	tui_remember_main_menu "TUI settings"

	while true; do
		action="$(tui_menu "saved to $(basename "$(tui_config_path)")" \
			"Show current preferences" \
			"Game picker filter: $filter_label" \
			"JSON view output: $json_label" \
			"Auto-resume last hub: $resume_label" \
			"Press-enter line threshold: ${TUI_PRESS_ENTER_LINES:-8}" \
			"Cache report min GB: ${TUI_CACHE_MIN_GB:-5}" \
			"Default init preset: ${TUI_DEFAULT_PRESET:-standard}" \
			"fzf height: ${LAUNCHLAYER_TUI_HEIGHT:-40%}" \
			"fzf preview layout: ${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}" \
			"Reset to defaults" \
			"Save and return" \
			"Back without saving")" || return 0

		case "$action" in
			"Show current preferences")
				tui_run_paged show_tui_prefs "$(tui_json_flag)" || true
				;;
			"Game picker filter:"*)
				val="$(tui_menu "Game picker filter" "${TUI_GAME_FILTERS[@]}")" || continue
				TUI_GAME_FILTER=$val
				filter_label=$val
				;;
			"JSON view output:"*)
				if [[ "${TUI_JSON_OUTPUT:-0}" == "1" ]]; then
					TUI_JSON_OUTPUT=0
				else
					TUI_JSON_OUTPUT=1
				fi
				json_label=$([[ "${TUI_JSON_OUTPUT:-0}" == "1" ]] && echo on || echo off)
				;;
			"Auto-resume last hub:"*)
				if [[ "${TUI_RESUME_LAST_MENU:-0}" == "1" ]]; then
					TUI_RESUME_LAST_MENU=0
				else
					TUI_RESUME_LAST_MENU=1
				fi
				resume_label=$([[ "${TUI_RESUME_LAST_MENU:-0}" == "1" ]] && echo on || echo off)
				;;
			"Press-enter line threshold:"*)
				read -r -p "Lines before pause [${TUI_PRESS_ENTER_LINES:-8}]: " val </dev/tty || continue
				[[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && TUI_PRESS_ENTER_LINES=$val
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
			"Reset to defaults")
				tui_confirm "Reset TUI settings to repo defaults?" || continue
				reset_tui_prefs || continue
				filter_label="${TUI_GAME_FILTER:-all}"
				json_label=$([[ "${TUI_JSON_OUTPUT:-0}" == "1" ]] && echo on || echo off)
				resume_label=$([[ "${TUI_RESUME_LAST_MENU:-0}" == "1" ]] && echo on || echo off)
				;;
			"Save and return")
				tui_save_config
				tui_crumb_leave
				return 0
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}

# tui_cache_report — Cache audit using TUI min-GB preference.
tui_cache_report() {
	local min_gb=${1:-${TUI_CACHE_MIN_GB:-5}} mode=${2:-both} grep_pattern=${3:-}
	[[ "$min_gb" =~ ^[0-9]+$ ]] || min_gb=5
	cache_report "$min_gb" "$mode" "$grep_pattern" 0
}

# tui_cache_report_menu — Cache audit with CLI-parity filters.
tui_cache_report_menu() {
	local action val min_gb mode grep_pattern
	min_gb=${TUI_CACHE_MIN_GB:-5}
	while true; do
		action="$(tui_menu "Cache report (min ${min_gb} GB)" \
			"Full report (shader + compatdata)" \
			"Shader cache only" \
			"Compatdata only" \
			"Filter by game name (--grep)" \
			"Change min GB threshold" \
			"Back")" || return 0

		case "$action" in
			"Full report (shader + compatdata)")
				tui_run_paged tui_cache_report "$min_gb" both "" || true
				;;
			"Shader cache only")
				tui_run_paged tui_cache_report "$min_gb" shader "" || true
				;;
			"Compatdata only")
				tui_run_paged tui_cache_report "$min_gb" compat "" || true
				;;
			"Filter by game name (--grep)")
				read -r -p "Name substring: " grep_pattern </dev/tty || continue
				[[ -n "$grep_pattern" ]] || continue
				tui_run_paged tui_cache_report "$min_gb" both "$grep_pattern" || true
				;;
			"Change min GB threshold")
				read -r -p "Min GB [${min_gb}]: " val </dev/tty || continue
				[[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && min_gb=$val
				;;
			*) return 0 ;;
		esac
	done
}
