# shellcheck shell=bash
# lib/tui/menus-backup/restore.sh — Restore configs from backup archives.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_RESTORE_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_RESTORE_LOADED=1

# tui_pick_backup_archive — Pick a backup archive from the configured backup dir.
tui_pick_backup_archive() {
	local dir=$1
	local -a archives=() labels=() choice a

	load_backup_prefs
	[[ -n "$dir" ]] || dir="${BACKUP_PREFS_DIR}"
	mapfile -t archives < <(list_backup_archives "$dir" 2>/dev/null) || {
		tui_show_text "No launchlayer backup archives in $dir" "Restore"
		return 1
	}
	for a in "${archives[@]}"; do
		labels+=("$(basename "$a")")
	done
	choice="$(tui_menu "Pick backup archive  (${dir})" "${labels[@]}")" || return 1
	for a in "${archives[@]}"; do
		[[ "$(basename "$a")" == "$choice" ]] || continue
		printf '%s\n' "$a"
		return 0
	done
	return 1
}

# tui_restore_backup_flow — Preview/apply restore for one archive.
tui_restore_backup_flow() {
	local archive=$1 mode=$2 filter_appid=${3:-}
	local include_local include_profiles include_tui action

	load_backup_prefs
	include_local="${BACKUP_PREFS_INCLUDE_LOCAL:-1}"
	include_profiles="${BACKUP_PREFS_INCLUDE_PROFILES:-1}"
	include_tui="${BACKUP_PREFS_INCLUDE_TUI:-0}"

	tui_run_paged restore_backup "$archive" "" 1 "$mode" 0 \
		"$include_local" "$include_profiles" "$include_tui" 0 "$filter_appid" || return 1

	if [[ "$mode" == merge ]]; then
		action="Import new files only (skip existing)?"
	else
		action="Overwrite existing config files from backup?"
	fi
	tui_confirm "$action" || return 0
	tui_run_paged restore_backup "$archive" "" 0 "$mode" 1 \
		"$include_local" "$include_profiles" "$include_tui" 0 "$filter_appid" || return 1
}

# tui_backup_restore_latest — Preview then apply restore of the latest archive.
tui_backup_restore_latest() {
	local dir=$1 mode=$2
	local confirm_msg

	tui_run_paged restore_backup "" "$dir" 1 "$mode" 0 \
		"${BACKUP_PREFS_INCLUDE_LOCAL}" \
		"${BACKUP_PREFS_INCLUDE_PROFILES}" \
		"${BACKUP_PREFS_INCLUDE_TUI}" 0 || return 0
	if [[ "$mode" == merge ]]; then
		confirm_msg="Restore latest backup (merge — skip existing files)?"
	else
		confirm_msg="Restore all configs from the latest backup (replace)?"
	fi
	tui_confirm "$confirm_msg" || return 0
	tui_run_paged restore_backup "" "$dir" 0 "$mode" 1 \
		"${BACKUP_PREFS_INCLUDE_LOCAL}" \
		"${BACKUP_PREFS_INCLUDE_PROFILES}" \
		"${BACKUP_PREFS_INCLUDE_TUI}" 0 || true
}

# tui_backup_restore_game_from_latest — Restore one game from the latest archive.
tui_backup_restore_game_from_latest() {
	local dir=$1 filter_appid mode action archive

	read -r -p "AppID or game name: " filter_appid </dev/tty || return 0
	[[ -n "$filter_appid" ]] || return 0
	action="$(tui_menu "Restore mode for $filter_appid" \
		"Replace existing" \
		"Merge (skip existing)" \
		"Back")" || return 0
	case "$action" in
		"Replace existing") mode=replace ;;
		"Merge (skip existing)") mode=merge ;;
		*) return 0 ;;
	esac
	archive="$(resolve_restore_archive "" "$dir")" || return 0
	tui_restore_backup_flow "$archive" "$mode" "$filter_appid"
}

# tui_backup_restore_menu — Restore from latest or chosen backup archive.
tui_backup_restore_menu() {
	local action archive dir

	load_backup_prefs
	dir="${BACKUP_PREFS_DIR}"
	action="$(tui_menu "Restore from backup  (${dir})" \
		"List backup archives" \
		"Preview latest backup" \
		"Restore latest (replace existing)" \
		"Restore latest (merge, skip existing)" \
		"Pick archive → preview" \
		"Pick archive → restore (replace)" \
		"Pick archive → restore (merge)" \
		"Restore game from latest backup" \
		"Back")" || return 0

	case "$action" in
		"List backup archives")
			tui_run_paged list_backups "$dir" 0 || true
			;;
		"Preview latest backup")
			tui_run_paged restore_backup "" "$dir" 1 replace 0 \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0 || true
			;;
		"Restore latest (replace existing)")
			tui_backup_restore_latest "$dir" replace
			;;
		"Restore latest (merge, skip existing)")
			tui_backup_restore_latest "$dir" merge
			;;
		"Pick archive → preview")
			archive="$(tui_pick_backup_archive "$dir")" || return 0
			tui_run_paged restore_backup "$archive" "" 1 replace 0 \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0 || true
			;;
		"Pick archive → restore (replace)")
			archive="$(tui_pick_backup_archive "$dir")" || return 0
			tui_restore_backup_flow "$archive" replace
			;;
		"Pick archive → restore (merge)")
			archive="$(tui_pick_backup_archive "$dir")" || return 0
			tui_restore_backup_flow "$archive" merge
			;;
		"Restore game from latest backup")
			tui_backup_restore_game_from_latest "$dir"
			;;
		*) return 0 ;;
	esac
	tui_maybe_press_enter
}
