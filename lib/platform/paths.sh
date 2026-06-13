# shellcheck shell=bash
# lib/platform/paths.sh — Portable path, sizing, and command helpers.

[[ -n "${LAUNCHLAYER_PLATFORM_LOADED:-}" ]] && return 0
LAUNCHLAYER_PLATFORM_LOADED=1
# realpath_portable — Resolve symlinks without requiring GNU readlink -f.
realpath_portable() {
	local path=$1 resolved=""
	[[ -n "$path" ]] || return 1

	if resolved="$(readlink -f "$path" 2>/dev/null)" && [[ -n "$resolved" ]]; then
		printf '%s\n' "$resolved"
		return 0
	fi

	if command -v python3 >/dev/null 2>&1; then
		python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null && return 0
	fi

	# Last resort: cd + pwd (works for existing paths).
	if [[ -e "$path" ]]; then
		( cd "$(dirname "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")" )
		return 0
	fi
	return 1
}

# timestamp_iso — ISO-8601 timestamp without GNU date -Iseconds.
timestamp_iso() {
	if date -Iseconds >/dev/null 2>&1; then
		date -Iseconds
	else
		date '+%Y-%m-%dT%H:%M:%S%z'
	fi
}

# dir_size_bytes — Directory size in bytes (prefers du -b, falls back to 512-byte blocks).
dir_size_bytes() {
	local dir=$1 bytes=""
	[[ -d "$dir" ]] || return 1
	if bytes="$(du -sb "$dir" 2>/dev/null | awk '{print $1}')" && [[ "$bytes" =~ ^[0-9]+$ ]]; then
		echo "$bytes"
		return 0
	fi
	bytes="$(du -s "$dir" 2>/dev/null | awk '{print $1 * 512}')"
	[[ "$bytes" =~ ^[0-9]+$ ]] || return 1
	echo "$bytes"
}

# bytes_to_gb — Round bytes up to whole GB for display.
bytes_to_gb() {
	local size_bytes=${1:-0}
	echo $(( (size_bytes + 512 * 1024 * 1024) / 1024 / 1024 / 1024 ))
}

# dir_size_gb — Return directory size rounded up to whole GB (0 when missing/empty).
dir_size_gb() {
	local dir=$1 size_bytes
	size_bytes="$(dir_size_bytes "$dir" 2>/dev/null || true)"
	[[ -n "$size_bytes" && "$size_bytes" =~ ^[0-9]+$ ]] || {
		echo 0
		return 0
	}
	bytes_to_gb "$size_bytes"
}

# command_available — True when a binary is on PATH.
command_available() {
	command -v "$1" >/dev/null 2>&1
}

# df_avail_gb — Free space on a mount in whole GB.
df_avail_gb() {
	local path=$1 avail=""
	[[ -d "$path" ]] || return 1
	if avail="$(df -BG "$path" 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print $4}')" \
		&& [[ "$avail" =~ ^[0-9]+$ ]]; then
		echo "$avail"
		return 0
	fi
	avail="$(df -Pk "$path" 2>/dev/null | awk 'NR==2 {print int($4 / 1024 / 1024)}')"
	[[ "$avail" =~ ^[0-9]+$ ]] || return 1
	echo "$avail"
}

# has_systemd_user — True when systemd user session is available.
has_systemd_user() {
	command -v systemctl >/dev/null 2>&1 \
		&& systemctl --user show-environment >/dev/null 2>&1
}
