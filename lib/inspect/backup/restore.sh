# shellcheck shell=bash
# lib/inspect/backup/restore.sh — Restore configs from scheduled backup archives.

[[ -n "${LAUNCHLAYER_BACKUP_RESTORE_LOADED:-}" ]] && return 0
LAUNCHLAYER_BACKUP_RESTORE_LOADED=1

# resolve_restore_archive — Resolve explicit archive path or newest backup in dir.
resolve_restore_archive() {
	local archive=${1:-} dir=${2:-}

	load_backup_prefs 2>/dev/null || true
	[[ -n "$dir" ]] || dir="$(default_backup_dir)"

	if [[ -n "$archive" && -f "$archive" ]]; then
		printf '%s\n' "$archive"
		return 0
	fi
	if [[ -n "$archive" && -d "$archive" ]]; then
		dir="$archive"
		archive=""
	fi
	if [[ -z "$archive" ]]; then
		archive="$(latest_backup_archive "$dir")" || archive=""
	fi
	if [[ -z "$archive" || ! -f "$archive" ]]; then
		if [[ -z "$archive" ]]; then
			echo "No launchlayer backup archives in $dir" >&2
		else
			echo "Backup archive not found: $archive" >&2
		fi
		return 1
	fi
	printf '%s\n' "$archive"
}

# list_backups — Print backup archives in dir (newest first).
list_backups() {
	local dir=${1:-} json=${2:-0}
	local -a archives=() first=1 file

	load_backup_prefs 2>/dev/null || true
	[[ -n "$dir" ]] || dir="$(default_backup_dir)"

	if ! mapfile -t archives < <(list_backup_archives "$dir" 2>/dev/null); then
		if [[ "$json" == "1" ]]; then
			printf '{"dir":%s,"count":0,"archives":[]}\n' "$(json_string "$dir")"
			return 0
		fi
		echo "=== Backup archives ==="
		echo "dir=$dir"
		echo "No launchlayer backup archives found"
		return 0
	fi

	if [[ "$json" == "1" ]]; then
		printf '{"dir":%s,"count":%s,"archives":[' \
			"$(json_string "$dir")" "${#archives[@]}"
		for file in "${archives[@]}"; do
			(( first )) || printf ','
			first=0
			printf '%s' "$(json_string "$file")"
		done
		printf ']}\n'
		return 0
	fi

	echo "=== Backup archives ==="
	echo "dir=$dir"
	for file in "${archives[@]}"; do
		printf '%s\n' "$file"
	done
}

# restore_backup — Restore configs from a backup archive (latest when omitted).
restore_backup() {
	local archive=${1:-} dir=${2:-} dry_run=${3:-1} mode=${4:-replace} yes=${5:-0}
	local include_local=${6:-1} include_profiles=${7:-1} include_tui=${8:-0} json=${9:-0}
	local filter_query=${10:-} filter_appid="" resolved

	load_backup_prefs 2>/dev/null || true
	[[ -n "$dir" ]] || dir="$(default_backup_dir)"
	include_local="${include_local:-${BACKUP_PREFS_INCLUDE_LOCAL:-1}}"
	include_profiles="${include_profiles:-${BACKUP_PREFS_INCLUDE_PROFILES:-1}}"
	include_tui="${include_tui:-${BACKUP_PREFS_INCLUDE_TUI:-0}}"

	resolved="$(resolve_restore_archive "$archive" "$dir")" || return 1
	if [[ -n "$filter_query" ]]; then
		filter_appid="$(resolve_restore_filter_appid "$filter_query")" || return 1
	fi

	if [[ "$json" != "1" ]]; then
		echo "=== Restore backup ==="
		echo "archive=$resolved"
		[[ -n "$filter_appid" ]] && echo "filter=games/${filter_appid}.env"
	fi

	import_config "$resolved" "$dry_run" "$mode" "$yes" \
		"$include_local" "$include_profiles" "$include_tui" "$json" "$filter_appid"
}
