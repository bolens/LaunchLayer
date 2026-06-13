# shellcheck shell=bash
# lib/platform/os.sh — Kernel, OS identity, WSL/container, and CPU count.
# nproc_portable — Online CPU count without requiring GNU nproc.
nproc_portable() {
	local count=""
	count="$(nproc 2>/dev/null || true)"
	[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] && { echo "$count"; return 0; }
	count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
	[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] && { echo "$count"; return 0; }
	count="$(sysctl -n hw.ncpu 2>/dev/null || true)"
	[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] && { echo "$count"; return 0; }
	echo 1
}

# detect_uname_kernel — Lowercase uname -s (linux, freebsd, darwin, …).
detect_uname_kernel() {
	uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# is_linux — True on Linux kernels.
is_linux() {
	[[ "$(detect_uname_kernel)" == linux ]]
}

# is_darwin — True on macOS.
is_darwin() {
	[[ "$(detect_uname_kernel)" == darwin ]]
}

# is_bsd — True on BSD kernels (excluding macOS).
is_bsd() {
	case "$(detect_uname_kernel)" in
		freebsd|openbsd|netbsd) return 0 ;;
	esac
	return 1
}

# read_os_release_field — Print one KEY from /etc/os-release.
read_os_release_field() {
	local key=$1 val=""
	[[ -f /etc/os-release ]] || return 1
	val="$(awk -F= -v k="$key" '$1 == k {
		sub(/^"/, "", $2); sub(/"$/, "", $2); print $2; exit
	}' /etc/os-release)"
	[[ -n "$val" ]] && printf '%s\n' "$val"
}

# detect_os_id — Normalized OS identifier (arch, ubuntu, freebsd, macos, …).
detect_os_id() {
	local id kernel
	kernel="$(detect_uname_kernel)"
	case "$kernel" in
		darwin) echo macos; return 0 ;;
		freebsd) echo freebsd; return 0 ;;
		openbsd) echo openbsd; return 0 ;;
		netbsd) echo netbsd; return 0 ;;
	esac
	id="$(read_os_release_field ID 2>/dev/null | tr '[:upper:]' '[:lower:]')"
	echo "${id:-unknown}"
}

# detect_os_family — Broad family for profile selection (arch, debian, fedora, …).
detect_os_family() {
	local id id_like kernel combined
	kernel="$(detect_uname_kernel)"
	case "$kernel" in
		darwin) echo darwin; return 0 ;;
		freebsd|openbsd|netbsd) echo bsd; return 0 ;;
	esac
	id="$(detect_os_id)"
	id_like="$(read_os_release_field ID_LIKE 2>/dev/null | tr '[:upper:]' '[:lower:]')"
	combined="$id $id_like"

	case "$id" in
		nixos) echo nixos; return 0 ;;
		alpine) echo alpine; return 0 ;;
		void) echo void; return 0 ;;
		gentoo) echo gentoo; return 0 ;;
		solus) echo solus; return 0 ;;
		arch|cachyos|manjaro|garuda|endeavouros|arcolinux) echo arch; return 0 ;;
		ubuntu|debian|pop|linuxmint|elementary|zorin|neon|kubuntu|xubuntu|lubuntu|mint) echo debian; return 0 ;;
		fedora|nobara|ultramarine|bazzite|aurora|bluefin|ublue|centos|rocky|alma|mageia) echo fedora; return 0 ;;
		opensuse*|sles|sled) echo suse; return 0 ;;
		clear-linux|clearlinux) echo clearlinux; return 0 ;;
		steamos|holoiso) echo steamos; return 0 ;;
	esac
	[[ "$combined" == *arch* ]] && { echo arch; return 0; }
	[[ "$combined" == *debian* ]] && { echo debian; return 0; }
	[[ "$combined" == *rhel* || "$combined" == *fedora* || "$combined" == *centos* ]] \
		&& { echo fedora; return 0; }
	[[ "$combined" == *suse* ]] && { echo suse; return 0; }
	echo "${id:-unknown}"
}

# detect_os_pretty_name — Human-readable OS name for display.
detect_os_pretty_name() {
	local pretty
	pretty="$(read_os_release_field PRETTY_NAME 2>/dev/null || true)"
	[[ -n "$pretty" ]] && { echo "$pretty"; return 0; }
	case "$(detect_uname_kernel)" in
		darwin) echo "macOS $(sw_vers -productVersion 2>/dev/null || true)"; return 0 ;;
		freebsd) echo "FreeBSD $(freebsd-version 2>/dev/null || uname -r)"; return 0 ;;
		openbsd) echo "OpenBSD $(uname -r)"; return 0 ;;
		netbsd) echo "NetBSD $(uname -r)"; return 0 ;;
	esac
	echo "$(detect_os_id)"
}

# is_immutable_os — True on rpm-ostree / OSTree immutable variants (Silverblue, Bazzite, …).
is_immutable_os() {
	local variant image id
	[[ -f /run/ostree-booted ]] && return 0
	[[ -d /sysroot/ostree ]] && return 0
	variant="$(read_os_release_field VARIANT_ID 2>/dev/null | tr '[:upper:]' '[:lower:]')"
	[[ "$variant" == *immutable* ]] && return 0
	image="$(read_os_release_field IMAGE_ID 2>/dev/null | tr '[:upper:]' '[:lower:]')"
	case "$image" in
		*silverblue*|*kinoite*|*sericea*|*onyx*|*ucore*|*bazzite*|*aurora*) return 0 ;;
	esac
	id="$(detect_os_id)"
	case "$id" in
		bazzite|aurora|bluefin|ublue|steamboat*) return 0 ;;
	esac
	return 1
}
# default_online_cpus — taskset range covering all online CPUs.
default_online_cpus() {
	local count last
	count="$(nproc_portable)"
	[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] || { echo "0"; return 0; }
	last=$((count - 1))
	if (( last == 0 )); then
		echo "0"
	else
		echo "0-$last"
	fi
}

# is_wsl2 — True when running under Windows Subsystem for Linux.
is_wsl2() {
	is_linux || return 1
	[[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] && return 0
	[[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
	grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

# is_container — True in Docker/LXC-style environments (best effort).
is_container() {
	[[ -f /.dockerenv ]] && return 0
	[[ -f /run/.containerenv ]] && return 0
	is_linux || return 1
	grep -qE 'docker|lxc|container' /proc/1/cgroup 2>/dev/null
}
