# shellcheck shell=bash
# lib/inspect/backup.sh
# user_tui_config_path — XDG path for TUI preferences (mirrors lib/prefs.sh).
user_tui_config_path() {
	tui_config_path
}

# config_bundle_sha256 — SHA-256 digest for bundle manifest checksums.
config_bundle_sha256() {
	local file=$1
	sha256sum "$file" 2>/dev/null | awk '{print $1}'
}

# _config_bundle_default_output — Timestamped archive path in dir (file or directory).
_config_bundle_default_output() {
	local dir=${1:-.} prefix=${2:-launchlayer-export} ts
	ts="$(date -u +%Y%m%d-%H%M%S)"
	if [[ -d "$dir" ]]; then
		printf '%s/%s-%s.tar.gz' "$dir" "$prefix" "$ts"
	else
		printf '%s-%s.tar.gz' "$prefix" "$ts"
	fi
}

# _write_config_bundle_manifest — Write manifest.json into a staging directory.
_write_config_bundle_manifest() {
	local staging=$1 include_local=$2 include_profiles=$3 include_tui=$4
	local -a manifest_files=()
	local rel abs checksum first=1

	collect_managed_config_files "$include_local" "$include_profiles" manifest_files
	if [[ "$include_tui" == "1" && -f "$(user_tui_config_path)" ]]; then
		manifest_files+=("tui.conf")
	fi

	{
		printf '{'
		json_object_pair "format" "$(json_string "launchlayer-config")"
		json_object_pair "version" "$(json_string "$LAUNCHLAYER_VERSION")" 1
		json_object_pair "exported_at" "$(json_string "$(date -u +%Y-%m-%dT%H:%M:%SZ)")" 1
		json_object_pair "config_dir" "$(json_string "$CONFIG_DIR")" 1
		printf ',"includes":{"local":%s,"profiles":%s,"tui":%s}' \
			"$(json_bool "$([[ "$include_local" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$include_profiles" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$include_tui" == "1" ]] && echo 1 || echo 0)")"
		printf ',"files":['
		for rel in "${manifest_files[@]}"; do
			if [[ "$rel" == tui.conf ]]; then
				abs="$(user_tui_config_path)"
			else
				abs="$(config_file_abs_from_rel "$rel")"
			fi
			[[ -f "$abs" ]] || continue
			checksum="$(config_bundle_sha256 "$abs")"
			(( first )) || printf ','
			first=0
			printf '{"path":%s,"sha256":%s}' \
				"$(json_string "$rel")" \
				"$(json_string "$checksum")"
		done
		printf ']}\n'
	} > "$staging/manifest.json"
}

# export_config — Pack managed launch.d files (and optional TUI prefs) into a tarball.
export_config() {
	local output=${1:-} include_local=${2:-0} include_profiles=${3:-1} include_tui=${4:-0} json=${5:-0}
	local -a files=()
	local staging tmpdir rel abs output_abs file_count tui_path
	local -a tar_members=(manifest.json)

	command_required_or_fail tar "Config export" || return 1

	[[ -n "$output" ]] || output="$(_config_bundle_default_output . launchlayer-export)"
	if [[ -d "$output" ]]; then
		output="$(_config_bundle_default_output "$output" launchlayer-export)"
	fi
	output_abs="$(cd "$(dirname "$output")" 2>/dev/null && pwd)/$(basename "$output")" \
		|| output_abs="$output"
	mkdir -p "$(dirname "$output_abs")"

	collect_managed_config_files "$include_local" "$include_profiles" files
	tui_path="$(user_tui_config_path)"
	[[ "$include_tui" == "1" && -f "$tui_path" ]] && files+=("tui.conf")

	if ((${#files[@]} == 0)); then
		echo "No config files to export under $LAUNCHD_DIR" >&2
		return 1
	fi

	tmpdir="$(mktemp -d)"
	trap 'rm -rf "'"$tmpdir"'"' RETURN
	staging="$tmpdir/staging"
	mkdir -p "$staging/launch.d/profiles" "$staging/launch.d/presets" "$staging/games"

	file_count=0
	for rel in "${files[@]}"; do
		if [[ "$rel" == tui.conf ]]; then
			cp "$tui_path" "$staging/tui.conf"
			tar_members+=(tui.conf)
			((file_count++)) || true
			continue
		fi
		abs="$(config_file_abs_from_rel "$rel")"
		[[ -f "$abs" ]] || continue
		if [[ "$rel" == games/* ]]; then
			mkdir -p "$staging/games"
		else
			mkdir -p "$(dirname "$staging/$rel")"
		fi
		if [[ "$rel" == games/* ]]; then
			cp "$abs" "$staging/games/$(basename "$rel")"
			tar_members+=("games/$(basename "$rel")")
		else
			cp "$abs" "$staging/$rel"
			tar_members+=("$rel")
		fi
		((file_count++)) || true
	done

	_write_config_bundle_manifest "$staging" "$include_local" "$include_profiles" "$include_tui"

	(
		cd "$staging" || exit 1
		tar -czf "$output_abs" "${tar_members[@]}"
	)

	if [[ "$json" == "1" ]]; then
		printf '{"output":%s,"file_count":%s,"includes":{"local":%s,"profiles":%s,"tui":%s}}\n' \
			"$(json_string "$output_abs")" \
			"$file_count" \
			"$(json_bool "$([[ "$include_local" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$include_profiles" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$include_tui" == "1" ]] && echo 1 || echo 0)")"
		return 0
	fi

	echo "=== Export config ==="
	echo "Wrote $output_abs ($file_count file(s))"
	echo "Includes: local=$([[ "$include_local" == "1" ]] && echo yes || echo no) profiles=$([[ "$include_profiles" == "1" ]] && echo yes || echo no) tui=$([[ "$include_tui" == "1" ]] && echo yes || echo no)"
}

# backup_config — Timestamped export alias (defaults to \$HOME).
backup_config() {
	local output=${1:-$HOME} include_local=${2:-1} include_profiles=${3:-1} include_tui=${4:-0} json=${5:-0}
	local path

	if [[ -n "$output" && -f "$output" ]]; then
		echo "Output path is an existing file: $output" >&2
		return 1
	fi
	if [[ -z "$output" || -d "$output" ]]; then
		path="$(_config_bundle_default_output "${output:-$HOME}" launchlayer-backup)"
	else
		path="$output"
	fi
	export_config "$path" "$include_local" "$include_profiles" "$include_tui" "$json"
}

# default_backup_dir — Directory for scheduled backups and pruning.
default_backup_dir() {
	if [[ -z "${LAUNCHLAYER_BACKUP_DIR:-}" ]]; then
		load_backup_prefs 2>/dev/null || true
		LAUNCHLAYER_BACKUP_DIR="${BACKUP_PREFS_DIR:-$HOME/launchlayer-backups}"
	fi
	printf '%s\n' "$LAUNCHLAYER_BACKUP_DIR"
}

# default_backup_keep — Archive retention count from preferences.
default_backup_keep() {
	if [[ -z "${LAUNCHLAYER_BACKUP_KEEP:-}" ]]; then
		load_backup_prefs 2>/dev/null || true
		LAUNCHLAYER_BACKUP_KEEP="${BACKUP_PREFS_KEEP:-7}"
	fi
	printf '%s\n' "$LAUNCHLAYER_BACKUP_KEEP"
}

# prune_backup_archives — Remove oldest launchlayer-backup-*.tar.gz files beyond --keep.
# keep=0 means unlimited retention (no files removed).
prune_backup_archives() {
	local dir=${1:-$(default_backup_dir)} keep=${2:-$(default_backup_keep)}
	local dry_run=${3:-0} json=${4:-0}
	local -a archives=() sorted=() to_remove=()
	local removed=0 scanned=0 file first=1

	[[ "$keep" =~ ^[0-9]+$ ]] || keep=7
	if [[ "$keep" == "0" ]]; then
		if [[ "$json" == "1" ]]; then
			printf '{"dir":%s,"keep":0,"dry_run":%s,"scanned":%s,"removed":0,"files":[],"policy":%s}\n' \
				"$(json_string "$dir")" \
				"$(json_bool "$([[ "$dry_run" == "1" ]] && echo 1 || echo 0)")" \
				"$(json_number_or_string "$( [[ -d "$dir" ]] && find "$dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' 2>/dev/null | wc -l || echo 0 )")" \
				"$(json_string "unlimited retention")"
			return 0
		fi
		echo "=== Prune backups $( [[ "$dry_run" == "1" ]] && echo '(dry-run)' ) ==="
		echo "dir=$dir keep=0 (unlimited retention — no files removed)"
		echo "Done: removed=0"
		return 0
	fi
	[[ -d "$dir" ]] || {
		if [[ "$json" == "1" ]]; then
			printf '{"dir":%s,"keep":%s,"scanned":0,"removed":0,"files":[]}\n' \
				"$(json_string "$dir")" "$keep"
			return 0
		fi
		echo "=== Prune backups (dry-run) ==="
		echo "Backup directory does not exist: $dir"
		echo "Done: removed=0 scanned=0"
		return 0
	}

	for file in "$dir"/launchlayer-backup-*.tar.gz; do
		[[ -f "$file" ]] || continue
		archives+=("$file")
	done
	scanned=${#archives[@]}
	if (( scanned > keep )); then
		mapfile -t sorted < <(ls -1t "${archives[@]}" 2>/dev/null)
		to_remove=("${sorted[@]:keep}")
	fi

	if [[ "$json" == "1" ]]; then
		printf '{"dir":%s,"keep":%s,"dry_run":%s,"scanned":%s,"removed":%s,"files":[' \
			"$(json_string "$dir")" "$keep" \
			"$(json_bool "$([[ "$dry_run" == "1" ]] && echo 1 || echo 0)")" \
			"$scanned" "${#to_remove[@]}"
		for file in "${to_remove[@]}"; do
			(( first )) || printf ','
			first=0
			printf '%s' "$(json_string "$file")"
			if [[ "$dry_run" != "1" ]]; then
				rm -f "$file"
				((removed++)) || true
			fi
		done
		printf ']}\n'
		return 0
	fi

	if [[ "$dry_run" == "1" ]]; then
		echo "=== Prune backups (dry-run) ==="
	else
		echo "=== Prune backups ==="
	fi
	echo "dir=$dir keep=$keep scanned=$scanned"
	if ((${#to_remove[@]} == 0)); then
		echo "No archives to prune"
	else
		for file in "${to_remove[@]}"; do
			if [[ "$dry_run" == "1" ]]; then
				echo "would remove: $file"
			else
				rm -f "$file"
				echo "Removed $file"
				((removed++)) || true
			fi
		done
	fi
	echo "Done: removed=$removed scanned=$scanned"
}

# run_scheduled_backup — Backup configs then optionally prune old archives (systemd oneshot).
# Reads live ~/.config/launchlayer/backup.conf (keep, auto_prune, includes).
run_scheduled_backup() {
	local dir=${1:-} keep=${2:-} json=${3:-0}
	local include_local include_profiles include_tui auto_prune

	load_backup_prefs
	[[ -z "$dir" ]] && dir="${BACKUP_PREFS_DIR}"
	[[ -z "$keep" ]] && keep="${BACKUP_PREFS_KEEP}"
	include_local="${BACKUP_PREFS_INCLUDE_LOCAL:-1}"
	include_profiles="${BACKUP_PREFS_INCLUDE_PROFILES:-1}"
	include_tui="${BACKUP_PREFS_INCLUDE_TUI:-0}"
	auto_prune="${BACKUP_PREFS_AUTO_PRUNE:-1}"

	mkdir -p "$dir"
	backup_config "$dir" "$include_local" "$include_profiles" "$include_tui" "$json" || return $?
	if [[ "$auto_prune" == "1" ]]; then
		prune_backup_archives "$dir" "$keep" 0 "$json"
	else
		if [[ "$json" == "1" ]]; then
			printf '{"prune_skipped":true,"reason":%s}\n' "$(json_string "auto_prune=0")"
		else
			echo "Skipping prune (auto_prune=0 in $(backup_prefs_path))"
		fi
	fi
}

# _find_config_bundle_root — Locate manifest.json or launch.d/ inside an extracted archive.
_find_config_bundle_root() {
	local extract_dir=$1 sub

	if [[ -f "$extract_dir/manifest.json" || -d "$extract_dir/launch.d" || -d "$extract_dir/games" ]]; then
		printf '%s\n' "$extract_dir"
		return 0
	fi
	for sub in "$extract_dir"/*; do
		[[ -d "$sub" ]] || continue
		if [[ -f "$sub/manifest.json" || -d "$sub/launch.d" || -d "$sub/games" ]]; then
			printf '%s\n' "$sub"
			return 0
		fi
	done
	return 1
}

# _config_import_destination — Map bundle-relative path to absolute destination.
_config_import_destination() {
	local rel=$1
	if [[ "$rel" == tui.conf ]]; then
		user_tui_config_path
	elif [[ "$rel" == games/* ]]; then
		printf '%s/%s\n' "$GAMES_DIR" "$(basename "$rel")"
	elif [[ "$rel" == launch.d/* ]]; then
		printf '%s/%s\n' "$CONFIG_DIR" "$rel"
	else
		printf '%s/%s\n' "$CONFIG_DIR" "$rel"
	fi
}

# _collect_bundle_import_files — List bundle-relative paths available for import.
_collect_bundle_import_files() {
	local bundle_root=$1 include_local=$2 include_profiles=$3 include_tui=$4
	local -n _out=$5
	local file base

	_out=()
	for file in "$bundle_root"/games/*.env "$bundle_root"/launch.d/*.env "$bundle_root"/launch.d/*.txt; do
		[[ -f "$file" ]] || continue
		base="$(basename "$file")"
		if [[ "$base" =~ ^[0-9]+\.env$ ]]; then
			_out+=("games/$base")
			continue
		fi
		[[ "$base" == local.env && "$include_local" != "1" ]] && continue
		_out+=("launch.d/$base")
	done
	if [[ "$include_profiles" == "1" && -d "$bundle_root/launch.d/profiles" ]]; then
		for file in "$bundle_root"/launch.d/profiles/*.env; do
			[[ -f "$file" ]] || continue
			_out+=("launch.d/profiles/$(basename "$file")")
		done
	fi
	if [[ -d "$bundle_root/launch.d/presets" ]]; then
		for file in "$bundle_root"/launch.d/presets/*.env; do
			[[ -f "$file" ]] || continue
			_out+=("launch.d/presets/$(basename "$file")")
		done
	fi
	if [[ "$include_tui" == "1" && -f "$bundle_root/tui.conf" ]]; then
		_out+=("tui.conf")
	fi
}

# import_config — Restore configs from an export/backup tarball.
import_config() {
	local archive=$1 dry_run=${2:-1} mode=${3:-merge} yes=${4:-0} include_local=${5:-1}
	local include_profiles=${6:-1} include_tui=${7:-0} json=${8:-0}
	local tmpdir bundle_root rel src dest action
	local -a files=() actions=()
	local added=0 replaced=0 skipped=0 applied=0 first=1 entry

	[[ -n "$archive" && -f "$archive" ]] || {
		echo "Usage: $0 --import-config ARCHIVE [--dry-run] [--merge|--replace] [--yes] [--json]" >&2
		return 1
	}
	command_required_or_fail tar "Config import" || return 1
	[[ "$mode" == merge || "$mode" == replace ]] || {
		echo "Import mode must be merge or replace (got: $mode)" >&2
		return 1
	}

	tmpdir="$(mktemp -d)"
	trap 'rm -rf "'"$tmpdir"'"' RETURN
	tar -xzf "$archive" -C "$tmpdir" || {
		echo "Failed to extract archive: $archive" >&2
		return 1
	}

	bundle_root="$(_find_config_bundle_root "$tmpdir")" || {
		echo "Archive does not contain a launchlayer config bundle: $archive" >&2
		return 1
	}

	_collect_bundle_import_files "$bundle_root" "$include_local" "$include_profiles" "$include_tui" files
	if ((${#files[@]} == 0)); then
		echo "No importable files found in $archive" >&2
		return 1
	fi

	local apply=0
	if [[ "$dry_run" != "1" && "$yes" == "1" ]]; then
		apply=1
	fi

	for rel in "${files[@]}"; do
		if [[ "$rel" == tui.conf ]]; then
			src="$bundle_root/tui.conf"
		elif [[ "$rel" == games/* ]]; then
			if [[ -f "$bundle_root/$rel" ]]; then
				src="$bundle_root/$rel"
			else
				src="$bundle_root/launch.d/$(basename "$rel")"
			fi
		else
			src="$bundle_root/$rel"
		fi
		dest="$(_config_import_destination "$rel")"
		[[ -f "$src" ]] || continue
		if [[ "$rel" == games/* ]]; then
			mkdir -p "$GAMES_DIR"
		fi

		if [[ -f "$dest" ]]; then
			if [[ "$mode" == merge ]]; then
				action=skip
				((skipped++)) || true
			else
				action=replace
				((replaced++)) || true
			fi
		else
			action=add
			((added++)) || true
		fi

		actions+=("$rel|$action|$dest")
		if [[ "$apply" == "1" && "$action" != skip ]]; then
			mkdir -p "$(dirname "$dest")"
			cp "$src" "$dest"
			((applied++)) || true
		fi
	done

	if [[ "$json" == "1" ]]; then
		printf '{"archive":%s,"mode":%s,"dry_run":%s,"added":%s,"replaced":%s,"skipped":%s,"applied":%s,"actions":[' \
			"$(json_string "$archive")" \
			"$(json_string "$mode")" \
			"$(json_bool "$([[ "$apply" == "1" ]] && echo 0 || echo 1)")" \
			"$added" "$replaced" "$skipped" "$applied"
		for entry in "${actions[@]}"; do
			IFS='|' read -r rel action dest <<< "$entry"
			(( first )) || printf ','
			first=0
			printf '{"path":%s,"action":%s,"destination":%s}' \
				"$(json_string "$rel")" \
				"$(json_string "$action")" \
				"$(json_string "$dest")"
		done
		printf ']}\n'
		return 0
	fi

	if [[ "$apply" == "1" ]]; then
		echo "=== Import config ==="
	else
		echo "=== Import config (preview) ==="
	fi
	printf '%-8s %s\n' ACTION PATH
	for entry in "${actions[@]}"; do
		IFS='|' read -r rel action dest <<< "$entry"
		printf '%-8s %s\n' "$action" "$rel"
	done
	echo "Summary: add=$added replace=$replaced skip=$skipped"
	if [[ "$apply" == "1" ]]; then
		echo "Applied $applied file(s)"
		validate_config all 0 || true
	elif (( added + replaced > 0 )); then
		echo "Re-run with --yes to apply (use --replace to overwrite existing files)."
	fi
}
