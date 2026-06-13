# shellcheck shell=bash
# lib/tui/menus-system-core.sh

[[ -n "${LAUNCHLAYER_TUI_SYSTEM_CORE_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_SYSTEM_CORE_LOADED=1

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
					tui_show_text "Run: sudo $LAUNCHLAYER_MAIN_SCRIPT --sysctl install" "Sysctl"
				else
					tui_run_paged sysctl_install || true
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
				tui_show_text "VRAM hogs paused (refcount incremented)" "VRAM"
				;;
			"Resume VRAM hogs (force)")
				resume_vram_hogs_force
				tui_show_text "VRAM hogs resumed" "VRAM"
				;;
			"Cleanup stale launch session")
				cleanup_stale_launch
				tui_show_text "Stale launch cleanup finished" "Launch cleanup"
				;;
			*) return 0 ;;
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
			"Backup timer settings" \
			"Print Steam launch option" \
			"Back")" || return 0

		case "$action" in
			"Run full setup (completions + launch option)")
				tui_run_paged run_setup --completions --print-launch-option || true
				tui_maybe_press_enter
				;;
			"Shell completions")
				tui_completions_menu
				;;
			"Install launchlayer symlink")
				tui_run_paged run_setup --symlink || true
				tui_maybe_press_enter
				;;
			"Install maintenance timer")
				tui_run_paged run_setup --systemd || true
				tui_maybe_press_enter
				;;
			"Backup timer settings")
				tui_backup_settings_menu
				;;
			"Print Steam launch option")
				tui_run_paged run_setup --print-launch-option || true
				tui_maybe_press_enter
				;;
			*) return 0 ;;
		esac
	done
}
