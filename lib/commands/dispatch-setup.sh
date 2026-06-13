# shellcheck shell=bash
# lib/commands/dispatch-setup.sh

[[ -n "${LAUNCHLAYER_DISPATCH_SETUP_LOADED:-}" ]] && return 0
LAUNCHLAYER_DISPATCH_SETUP_LOADED=1

# dispatch_setup_subcommand — Return 0 when verb is handled.
dispatch_setup_subcommand() {
	local verb=${1:-}
	shift || true
	case "$verb" in
		--backup-timer)
			handle_backup_timer_subcommand "$@"
			;;
		--backup-prefs)
			handle_backup_prefs_subcommand "$@"
			;;
		--tui-prefs)
			handle_tui_prefs_subcommand "$@"
			;;
		--completions)
			handle_completions_subcommand "$@"
			;;
		--doctor)
			local doctor_json=0
			[[ "${1:-}" == --json ]] && doctor_json=1
			show_doctor "$doctor_json"
			;;
		--setup)
			run_setup "$@"
			;;
		--install-systemd)
			install_systemd_user_units
			;;
		--sysctl)
			handle_sysctl_subcommand "${1:-status}"
			;;
		*)
			return 1
			;;
	esac
}
