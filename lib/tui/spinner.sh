# shellcheck shell=bash
# lib/tui/spinner.sh — Braille loading spinners (gum/lazygit-style) for slow TUI work.

[[ -n "${LAUNCHLAYER_TUI_SPINNER_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_SPINNER_LOADED=1

# Braille frames used by gum, lazygit, and similar TUIs.
TUI_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
TUI_SPINNER_DELAY_MS=${TUI_SPINNER_DELAY_MS:-200}

# tui_spinner_enabled — True when stderr is a TTY and spinners are not disabled.
tui_spinner_enabled() {
	[[ "${TUI_SPINNER:-1}" != 0 && -t 2 && -z "${TUI_SPINNER_SUPPRESS:-}" ]]
}

# tui_spinner_message_for — Friendly label for a command name shown during tui_run_paged.
tui_spinner_message_for() {
	local cmd=${1:-}
	case "$cmd" in
		init_unconfigured) printf '%s' 'Initializing game configs…' ;;
		prune_uninstalled_configs) printf '%s' 'Scanning installed games…' ;;
		show_doctor) printf '%s' 'Running health checks…' ;;
		hub_search_machines) printf '%s' 'Searching similar machines…' ;;
		hub_apply_config) printf '%s' 'Applying shared config…' ;;
		hub_show_fingerprint) printf '%s' 'Building machine fingerprint…' ;;
		validate_config) printf '%s' 'Validating configs…' ;;
		scan_anticheat) printf '%s' 'Scanning anticheat database…' ;;
		scan_detections) printf '%s' 'Scanning game detections…' ;;
		show_detected_defaults) printf '%s' 'Loading detected defaults…' ;;
		write_local_config) printf '%s' 'Writing local config…' ;;
		show_detect_environment) printf '%s' 'Detecting environment…' ;;
		show_status) printf '%s' 'Loading status…' ;;
		show_cpu_topology) printf '%s' 'Reading CPU topology…' ;;
		tui_cache_report) printf '%s' 'Scanning cache directories…' ;;
		completions_show_status) printf '%s' 'Checking shell completions…' ;;
		sysctl_status) printf '%s' 'Reading sysctl settings…' ;;
		sysctl_install) printf '%s' 'Installing sysctl drop-in…' ;;
		install_systemd_backup_units) printf '%s' 'Installing backup timer…' ;;
		tui_backup_settings_reinstall_units_preserve) printf '%s' 'Refreshing backup timer units…' ;;
		uninstall_systemd_backup_units) printf '%s' 'Removing backup timer…' ;;
		enable_systemd_backup_timer) printf '%s' 'Enabling backup timer…' ;;
		disable_systemd_backup_timer) printf '%s' 'Disabling backup timer…' ;;
		enable_systemd_backup_service) printf '%s' 'Enabling backup service…' ;;
		disable_systemd_backup_service) printf '%s' 'Disabling backup service…' ;;
		handle_backup_timer_subcommand) printf '%s' 'Managing backup timer…' ;;
		completions_enable) printf '%s' 'Enabling shell completions…' ;;
		completions_disable) printf '%s' 'Disabling shell completions…' ;;
		init_appid_config) printf '%s' 'Initializing game config…' ;;
		set_include_preset) printf '%s' 'Setting INCLUDE preset…' ;;
		bulk_set_include_preset) printf '%s' 'Applying INCLUDE preset…' ;;
		show_config) printf '%s' 'Loading game config…' ;;
		show_paths) printf '%s' 'Resolving paths…' ;;
		launch_stats) printf '%s' 'Loading launch stats…' ;;
		suggest_config) printf '%s' 'Fetching ProtonDB suggestions…' ;;
		hub_history_config) printf '%s' 'Loading hub history…' ;;
		tui_show_dry_run) printf '%s' 'Building launch chain…' ;;
		show_tui_prefs) printf '%s' 'Loading TUI preferences…' ;;
		show_backup_prefs) printf '%s' 'Loading backup preferences…' ;;
		show_hub_prefs) printf '%s' 'Loading hub preferences…' ;;
		backup_config) printf '%s' 'Creating backup…' ;;
		run_scheduled_backup) printf '%s' 'Running scheduled backup…' ;;
		prune_backup_archives) printf '%s' 'Pruning backup archives…' ;;
		systemd_backup_status) printf '%s' 'Checking backup timer…' ;;
		list_backups) printf '%s' 'Listing backup archives…' ;;
		restore_backup) printf '%s' 'Restoring from backup…' ;;
		export_config) printf '%s' 'Exporting config bundle…' ;;
		import_config) printf '%s' 'Importing config bundle…' ;;
		run_setup) printf '%s' 'Running setup…' ;;
		hub_publish_config) printf '%s' 'Publishing to hub…' ;;
		hub_update_config) printf '%s' 'Updating hub config…' ;;
		hub_delete_config) printf '%s' 'Deleting hub config…' ;;
		hub_recommend_configs) printf '%s' 'Fetching recommendations…' ;;
		*) printf '%s' 'Working…' ;;
	esac
}

# tui_spinner_draw — Render one spinner frame on stderr (caller clears line when done).
tui_spinner_draw() {
	local frame=$1 msg=$2
	if cli_uses_color; then
		printf '\r%s %s' "$(cli_cyan "$frame")" "$(cli_dim "$msg")" >&2
	else
		printf '\r%s %s' "$frame" "$msg" >&2
	fi
}

# tui_spinner_clear — Erase the active spinner line on stderr.
tui_spinner_clear() {
	printf '\r\033[2K' >&2
}

# tui_spinner_now_ms — Millisecond timestamp for spinner delay (GNU date).
tui_spinner_now_ms() {
	date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
}

# tui_spinner_capture — Run a command; capture merged stdout/stderr; optional braille spinner.
tui_spinner_capture() {
	local msg=$1
	shift
	local tmp rc=0 delay_ms=${TUI_SPINNER_DELAY_MS:-200}
	local -a frames=("${TUI_SPINNER_FRAMES[@]}")
	local cmd_pid i=0 shown=0 start_ms elapsed now_ms

	tmp="$(mktemp "${TMPDIR:-/tmp}/launchlayer-spinner.XXXXXX")"
	if ! tui_spinner_enabled; then
		"$@" > "$tmp" 2>&1
		rc=$?
		cat "$tmp"
		rm -f "$tmp"
		return "$rc"
	fi

	("$@" > "$tmp" 2>&1) &
	cmd_pid=$!
	start_ms="$(tui_spinner_now_ms)"

	while kill -0 "$cmd_pid" 2>/dev/null; do
		now_ms="$(tui_spinner_now_ms)"
		elapsed=$((now_ms - start_ms))
		if (( elapsed >= delay_ms || shown )); then
			shown=1
			tui_spinner_draw "${frames[i]}" "$msg"
			i=$(( (i + 1) % ${#frames[@]} ))
		fi
		sleep 0.08
	done

	wait "$cmd_pid" || rc=$?
	(( shown )) && tui_spinner_clear
	cat "$tmp"
	rm -f "$tmp"
	return "$rc"
}
