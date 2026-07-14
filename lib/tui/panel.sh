# shellcheck shell=bash
# lib/tui/panel.sh — Right-pane command output and status dashboard for fzf menus.

[[ -n "${LAUNCHLAYER_TUI_PANEL_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_PANEL_LOADED=1

TUI_PANEL_ACTIVITY_MAX_LINES=${TUI_PANEL_ACTIVITY_MAX_LINES:-200}
TUI_PANEL_RENDER_LINES=${TUI_PANEL_RENDER_LINES:-60}

# tui_panel_dir — Cache directory for TUI panel files.
tui_panel_dir() {
	printf '%s/launchlayer/tui' "${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}"
}

# tui_panel_paths — Set TUI_PANEL_ACTIVITY_FILE and related paths.
tui_panel_paths() {
	TUI_PANEL_DIR="$(tui_panel_dir)"
	TUI_PANEL_ACTIVITY_FILE="${TUI_PANEL_DIR}/panel-activity"
}

# tui_panel_active_p — True when output should route to the side panel.
tui_panel_active_p() {
	[[ "${TUI_PANEL_ACTIVE:-0}" == "1" && -t 1 ]] && tui_has_fzf
}

# tui_fzf_panel_context_p — True when fzf should show the output panel.
tui_fzf_panel_context_p() {
	case "${1:-menu}" in
		game|multi|actions|help|toggles|advanced) return 1 ;;
		*) return 0 ;;
	esac
}

# tui_fzf_panel_window — Preview pane layout for hub menus.
tui_fzf_panel_window() {
	printf '%s' "${LAUNCHLAYER_TUI_PANEL:-${LAUNCHLAYER_TUI_PREVIEW:-right:38%:wrap}}"
}

# tui_panel_init — Reset panel activity log at TUI startup.
tui_panel_init() {
	tui_panel_paths
	mkdir -p "$TUI_PANEL_DIR"
	: >"$TUI_PANEL_ACTIVITY_FILE"
}

# tui_panel_trim_activity — Keep only the newest activity lines.
tui_panel_trim_activity() {
	local path=$1 max=${2:-$TUI_PANEL_ACTIVITY_MAX_LINES} lines
	tui_panel_paths
	path="${path:-$TUI_PANEL_ACTIVITY_FILE}"
	[[ -f "$path" ]] || return 0
	lines="$(wc -l <"$path" | tr -d '[:space:]')"
	(( lines > max )) || return 0
	tail -n "$max" "$path" >"${path}.trim"
	mv -f "${path}.trim" "$path"
}

# tui_panel_append_text — Append command or note output to the activity log.
tui_panel_append_text() {
	local _label=$1 content=$2
	tui_panel_paths
	mkdir -p "$TUI_PANEL_DIR"
	{
		[[ -s "$TUI_PANEL_ACTIVITY_FILE" ]] && printf '\n'
		printf '%s\n' "$content"
	} >>"$TUI_PANEL_ACTIVITY_FILE"
	tui_panel_trim_activity "$TUI_PANEL_ACTIVITY_FILE"
}

# tui_panel_append_command — Record paged command output in the activity log.
tui_panel_append_command() {
	local cmd=$1 content=$2
	tui_panel_append_text "$(tui_spinner_message_for "$cmd")" "$content"
}

# tui_panel_render — Print recent command output for fzf --preview (no section headers).
tui_panel_render() {
	local max=${TUI_PANEL_RENDER_LINES:-60}
	tui_panel_paths
	[[ -s "$TUI_PANEL_ACTIVITY_FILE" ]] || return 0
	tail -n "$max" "$TUI_PANEL_ACTIVITY_FILE"
}

# tui_status_section — Section heading for the status dashboard.
tui_status_section() {
	local title=$1
	printf '\n'
	if cli_uses_color; then
		printf '%s\n' "$(cli_bold "$title")"
	else
		printf '%s\n' "$title"
	fi
}

# tui_status_row — One labeled row in the status dashboard.
tui_status_row() {
	local label=$1 value=$2
	printf '  %-22s %s\n' "$label" "$value"
}

# tui_render_status_page — Multi-line status dashboard for the Status menu preview.
tui_render_status_page() {
	local issues required current vm_label backup_timer maint_timer prune hub_line doctor_val vm_val
	issues="$(doctor_issue_count 2>/dev/null || echo 0)"
	required="$(sysctl_required_value 2>/dev/null || echo 0)"
	current="$(sysctl_current_value 2>/dev/null || echo "")"
	backup_timer="$(tui_backup_timer_brief 2>/dev/null || echo off)"
	maint_timer="$(tui_maintenance_timer_brief 2>/dev/null || echo off)"
	prune="$(backup_prune_summary 2>/dev/null || echo keep?)"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -ge "$required" ]]; then
		vm_label="ok"
	else
		vm_label="low"
	fi
	if [[ "$issues" =~ ^[0-9]+$ ]] && (( issues > 0 )); then
		doctor_val="$(tui_glyph_doctor "$issues") issues"
	else
		doctor_val="$(tui_glyph_doctor 0) clean"
	fi
	if [[ "$vm_label" == ok ]]; then
		vm_val="$(tui_glyph_vm ok)"
		[[ -n "$current" && "$current" =~ ^[0-9]+$ ]] && vm_val+="  $current"
	else
		vm_val="$(tui_glyph_vm low)"
		[[ -n "$current" && "$current" =~ ^[0-9]+$ ]] \
			&& vm_val+="  $current / $required required"
	fi
	load_hub_prefs 2>/dev/null || true
	hub_line="$(tui_hub_status_brief 2>/dev/null || echo off)"

	if cli_uses_color; then
		printf '%s\n' "$(cli_bold 'System status')"
	else
		printf '%s\n' 'System status'
	fi

	tui_status_section "Health"
	tui_status_row "Doctor" "$doctor_val"
	tui_status_row "vm.max_map_count" "$vm_val"

	tui_status_section "Automation"
	tui_status_row "Backup timer" "$(tui_glyph_timer "$backup_timer")  $backup_timer"
	tui_status_row "Maintenance timer" "$(tui_glyph_timer "$maint_timer")  $maint_timer"
	tui_status_row "Backup retention" "$prune"

	tui_status_section "Library"
	tui_status_row "Game filter" "${TUI_GAME_FILTER:-all}"
	tui_status_row "Default preset" "${TUI_DEFAULT_PRESET:-standard}"

	tui_status_section "Community"
	tui_status_row "Hub" "$hub_line"
	printf '\n'
}

# tui_panel_preview_for_selection — Main-menu preview: status page or command output.
tui_panel_preview_for_selection() {
	local selection=${1:-}
	selection="${selection%%$'\t'*}"
	case "$selection" in
		Status)
			tui_render_status_page
			;;
		*)
			tui_panel_render
			;;
	esac
}
