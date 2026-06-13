# shellcheck shell=bash
# lib/inspect/backup/import.sh

[[ -n "${LAUNCHLAYER_BACKUP_IMPORT_LOADED:-}" ]] && return 0
LAUNCHLAYER_BACKUP_IMPORT_LOADED=1

# _filter_import_files_by_appid — Keep only games/<AppID>.env when restoring one game.
_filter_import_files_by_appid() {
	local filter_appid=$1
	local -n _files=$2
	local -a kept=() rel want="games/${filter_appid}.env"

	for rel in "${_files[@]}"; do
		[[ "$rel" == "$want" ]] && kept+=("$rel")
	done
	if ((${#kept[@]} == 0)); then
		echo "Archive does not contain $want" >&2
		return 1
	fi
	_files=("${kept[@]}")
}

# import_config — Restore configs from an export/backup tarball.
import_config() {
	local archive=$1 dry_run=${2:-1} mode=${3:-merge} yes=${4:-0} include_local=${5:-1}
	local include_profiles=${6:-1} include_tui=${7:-0} json=${8:-0} filter_appid=${9:-}
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
	if [[ -n "$filter_appid" ]]; then
		_filter_import_files_by_appid "$filter_appid" files || return 1
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
		if [[ -n "$filter_appid" ]]; then
			echo "=== Restore config (games/${filter_appid}.env) ==="
		else
			echo "=== Import config ==="
		fi
	else
		if [[ -n "$filter_appid" ]]; then
			echo "=== Restore config (preview, games/${filter_appid}.env) ==="
		else
			echo "=== Import config (preview) ==="
		fi
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
