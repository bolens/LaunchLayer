# shellcheck shell=bash
# lib/setup/sysctl.sh

[[ -n "${LAUNCHLAYER_SETUP_LOADED:-}" ]] && return 0
LAUNCHLAYER_SETUP_LOADED=1
# sysctl_required_value — Target vm.max_map_count for Proton stability.
sysctl_required_value() {
	echo "$LAUNCHLAYER_VM_MAX_MAP_COUNT_DEFAULT"
}

# sysctl_current_value — Read current vm.max_map_count or empty (Linux only).
sysctl_current_value() {
	is_linux || return 0
	sysctl -n vm.max_map_count 2>/dev/null || true
}

# sysctl_status — Print vm.max_map_count state.
sysctl_status() {
	local current required installed
	if ! is_linux; then
		echo "vm.max_map_count: n/a ($(detect_os_pretty_name) — Linux Proton sysctl only)"
		return 0
	fi
	current="$(sysctl_current_value)"
	required="$(sysctl_required_value)"
	installed=no
	[[ -f /etc/sysctl.d/elasticsearch.conf ]] && installed=yes
	echo "vm.max_map_count=${current:-unknown} (required >= $required)"
	echo "elasticsearch.conf installed: $installed"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		echo "action: run '$LAUNCHLAYER_MAIN_SCRIPT --sysctl install' as root"
	fi
}

# sysctl_install — Install elasticsearch.conf when run as root (Linux only).
sysctl_install() {
	if ! is_linux; then
		echo "vm.max_map_count tuning is Linux-only (current: $(detect_os_pretty_name))" >&2
		return 1
	fi
	local src dest
	if [[ $EUID -ne 0 ]]; then
		echo "Run as root: sudo $LAUNCHLAYER_MAIN_SCRIPT --sysctl install" >&2
		return 1
	fi
	src="$(sysctl_dropin_source)"
	dest="/etc/sysctl.d/elasticsearch.conf"
	[[ -f "$src" ]] || {
		echo "Missing $src" >&2
		return 1
	}
	if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
		echo "Already installed: $dest"
	else
		install -Dm644 "$src" "$dest"
		echo "Installed $dest"
	fi
	sysctl --system >/dev/null 2>&1 || sysctl -p "$dest" >/dev/null 2>&1 || true
	sysctl_status
}

# handle_sysctl_subcommand — Dispatch --sysctl status|install.
handle_sysctl_subcommand() {
	local action=${1:-status}
	case "$action" in
		status) sysctl_status ;;
		install) sysctl_install ;;
		*)
			echo "Usage: $0 --sysctl [status|install]" >&2
			return 1
			;;
	esac
}
