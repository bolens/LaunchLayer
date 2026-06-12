# shellcheck shell=bash
# lib/vdf.sh — Minimal VDF helpers for Steam libraryfolders.vdf parsing.

[[ -n "${LAUNCHLAYER_VDF_LOADED:-}" ]] && return 0
LAUNCHLAYER_VDF_LOADED=1

# vdf_unescape_path — Convert VDF path escapes to a normal filesystem path.
vdf_unescape_path() {
	local path=$1
	path="${path//\\\\/\\}"
	path="${path//\\/\//}"
	printf '%s' "$path"
}

# parse_libraryfolders_paths — Print library root paths from a libraryfolders.vdf file.
parse_libraryfolders_paths() {
	local vdf_file=$1
	[[ -f "$vdf_file" ]] || return 0

	local line value
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ \"path\"[[:space:]]+\"(.+)\"[[:space:]]*$ ]] || continue
		value="${BASH_REMATCH[1]}"
		printf '%s\n' "$(vdf_unescape_path "$value")"
	done < "$vdf_file"
}
