# shellcheck shell=bash
# lib/tools.sh — Optional dependency detection and distro-aware install hints.

[[ -n "${LAUNCHLAYER_TOOLS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TOOLS_LOADED=1

# Optional tools surfaced in --detect-environment / --doctor (order preserved).
LAUNCHLAYER_OPTIONAL_TOOLS=(
	gamemoderun
	game-performance
	gamescope
	mangohud
	dlss-swapper
	dlss-updater
	fzf
	taskset
	cpupower
	powerprofilesctl
	ethtool
	pw-metadata
	nvidia-smi
	nvidia-settings
	jq
)

# detect_package_manager — Best-effort package manager id for install hints.
detect_package_manager() {
	local pm=""

	if is_immutable_os && command_available rpm-ostree; then
		echo rpm-ostree
		return 0
	fi

	case "$(detect_os_family)" in
		nixos) echo nix; return 0 ;;
		arch) pm=pacman ;;
		debian) pm=apt ;;
		fedora) pm=dnf ;;
		suse) pm=zypper ;;
		alpine) pm=apk ;;
		void) pm=xbps ;;
		gentoo) pm=emerge ;;
		solus) pm=eopkg ;;
		clearlinux) pm=swupd ;;
		darwin) pm=brew ;;
		bsd)
			case "$(detect_os_id)" in
				freebsd) pm=pkg ;;
			esac
			;;
	esac

	case "$pm" in
		pacman) command_available pacman && { echo pacman; return 0; } ;;
		apt) command_available apt-get && { echo apt; return 0; } ;;
		dnf) command_available dnf && { echo dnf; return 0; } ;;
		zypper) command_available zypper && { echo zypper; return 0; } ;;
		apk) command_available apk && { echo apk; return 0; } ;;
		emerge) command_available emerge && { echo emerge; return 0; } ;;
		xbps) command_available xbps-install && { echo xbps; return 0; } ;;
		eopkg) command_available eopkg && { echo eopkg; return 0; } ;;
		swupd) command_available swupd && { echo swupd; return 0; } ;;
		brew) command_available brew && { echo brew; return 0; } ;;
		pkg) command_available pkg && { echo pkg; return 0; } ;;
	esac

	command_available pacman && { echo pacman; return 0; }
	command_available apt-get && { echo apt; return 0; }
	command_available dnf && { echo dnf; return 0; }
	command_available zypper && { echo zypper; return 0; }
	command_available apk && { echo apk; return 0; }
	command_available emerge && { echo emerge; return 0; }
	command_available xbps-install && { echo xbps; return 0; }
	command_available brew && { echo brew; return 0; }
	command_available pkg && { echo pkg; return 0; }
	echo unknown
}

# optional_tool_relevant — Skip tools that do not apply on this machine.
optional_tool_relevant() {
	local tool=$1
	case "$tool" in
		nvidia-smi|nvidia-settings|dlss-swapper)
			[[ "$(detect_gpu_vendor 2>/dev/null || true)" == nvidia ]]
			;;
		dlss-updater)
			# GUI DLL updater (DLSS/XeSS/FSR); relevant on any GPU that ships those DLLs.
			return 0
			;;
		pw-metadata)
			[[ "$(detect_audio_server 2>/dev/null || true)" == pipewire ]]
			;;
		cpupower|powerprofilesctl)
			! optional_tool_installed game-performance
			;;
		*)
			return 0
			;;
	esac
}

# optional_tool_installed — True when the tool (or accepted fallback) is available.
optional_tool_installed() {
	local tool=$1
	case "$tool" in
		game-performance)
			command_available game-performance \
				|| command_available cpupower \
				|| command_available powerprofilesctl
			;;
		gamemoderun)
			command_available gamemoderun
			;;
		powerprofilesctl)
			command_available powerprofilesctl
			;;
		dlss-swapper)
			command_available dlss-swapper || command_available dlss-swapper-dll
			;;
		dlss-updater)
			command_available dlss-updater \
				|| command_available DLSS_Updater \
				|| { command_available flatpak && flatpak info io.github.recol.dlss-updater >/dev/null 2>&1; }
			;;
		*)
			command_available "$tool"
			;;
	esac
}

# launch_wrapper_available — True when a LAUNCH_WRAPPERS* entry can be executed.
# Mirrors build_launch_chain availability rules for known launch tools.
launch_wrapper_available() {
	local wrapper=$1
	case "$wrapper" in
		game-performance)
			command_available game-performance
			;;
		dlss-swapper|dlss-swapper-dll)
			command_available "$wrapper"
			;;
		gamemoderun|gamescope|mangohud|taskset)
			optional_tool_installed "$wrapper"
			;;
		*)
			command_available "$wrapper"
			;;
	esac
}

# resolve_dlss_swapper_bin — Print dlss-swapper binary for DLSS_SWAPPER; return 1 when off.
# Values: 1 → dlss-swapper (NGX updater + latest preset), dll → dlss-swapper-dll (presets only).
# See: https://wiki.cachyos.org/configuration/gaming/#forcing-the-latest-dlss-preset
resolve_dlss_swapper_bin() {
	case "${DLSS_SWAPPER:-0}" in
		1|yes|true|on|YES|TRUE|ON)
			printf '%s' dlss-swapper
			;;
		dll|DLL)
			printf '%s' dlss-swapper-dll
			;;
		*)
			return 1
			;;
	esac
}

# tool_packages_data_file — Shipped TSV mapping logical tools to distro packages.
tool_packages_data_file() {
	printf '%s/tool-packages.tsv' "$(launchlayer_share_dir)"
}

# _tool_package_from_tsv — Lookup package for tool+PM; prints package or returns 1.
_tool_package_from_tsv() {
	local tool=$1 pm=$2 file=$3
	local row_tool row_pm row_pkg
	[[ -f "$file" ]] || return 1

	while IFS=$'\t' read -r row_tool row_pm row_pkg || [[ -n "$row_tool" ]]; do
		[[ "$row_tool" =~ ^# ]] && continue
		[[ -z "$row_tool" ]] && continue
		[[ "$row_tool" == "$tool" && "$row_pm" == "$pm" ]] || continue
		[[ "$row_pkg" == "-" ]] && return 0
		printf '%s' "$row_pkg"
		return 0
	done < "$file"

	while IFS=$'\t' read -r row_tool row_pm row_pkg || [[ -n "$row_tool" ]]; do
		[[ "$row_tool" =~ ^# ]] && continue
		[[ -z "$row_tool" ]] && continue
		[[ "$row_tool" == "$tool" && "$row_pm" == "*" ]] || continue
		[[ "$row_pkg" == "-" ]] && return 0
		printf '%s' "$row_pkg"
		return 0
	done < "$file"
	return 1
}

# tool_package_name — Package or bundle name(s) for a logical tool on this OS.
tool_package_name() {
	local tool=$1
	local pm=${2:-$(detect_package_manager)}
	local pkg=""

	pkg="$(_tool_package_from_tsv "$tool" "$pm" "$(tool_packages_data_file)")"
	if (( $? == 0 )); then
		printf '%s' "$pkg"
		return 0
	fi
	printf '%s' "$tool"
}

# format_install_command — Human-readable install command for a package name.
format_install_command() {
	local pm=$1 pkg=$2
	[[ -n "$pkg" ]] || return 1
	case "$pm" in
		pacman) printf 'sudo pacman -S %s' "$pkg" ;;
		apt) printf 'sudo apt install %s' "$pkg" ;;
		dnf) printf 'sudo dnf install %s' "$pkg" ;;
		zypper) printf 'sudo zypper install %s' "$pkg" ;;
		apk) printf 'sudo apk add %s' "$pkg" ;;
		emerge) printf 'sudo emerge --ask=n %s' "$pkg" ;;
		xbps) printf 'sudo xbps-install -Sy %s' "$pkg" ;;
		eopkg) printf 'sudo eopkg install %s' "$pkg" ;;
		swupd) printf 'sudo swupd bundle-add %s' "$pkg" ;;
		rpm-ostree) printf 'rpm-ostree install %s' "$pkg" ;;
		brew) printf 'brew install %s' "$pkg" ;;
		pkg) printf 'sudo pkg install %s' "$pkg" ;;
		nix) printf 'nix-shell -p %s  # or add to configuration.nix' "$pkg" ;;
		unknown) printf 'install package providing %s' "$pkg" ;;
	esac
}

# tool_install_hint — Install hint for a logical tool (empty when already installed).
tool_install_hint() {
	local tool=$1 pm pkg hint alt=""
	optional_tool_installed "$tool" && return 0
	optional_tool_relevant "$tool" || return 0

	pm="$(detect_package_manager)"

	# Distro-specific messaging before generic package lookup (some tools map to "-").
	case "$tool" in
		game-performance)
			case "$pm" in
				pacman)
					hint="yay -S game-performance  # AUR"
					alt="$(format_install_command "$pm" cpupower 2>/dev/null || true)"
					[[ -n "$alt" ]] && hint+="; or: $alt"
					printf '%s\n' "$hint"
					return 0
					;;
				apt|dnf|rpm-ostree|zypper)
					hint="$(format_install_command "$pm" "$(tool_package_name cpupower "$pm")" 2>/dev/null || true)"
					alt="$(format_install_command "$pm" "$(tool_package_name powerprofilesctl "$pm")" 2>/dev/null || true)"
					[[ -n "$hint" && -n "$alt" ]] && printf '%s; or: %s\n' "$hint" "$alt"
					[[ -n "$hint" ]] && printf '%s\n' "$hint"
					return 0
					;;
			esac
			;;
		dlss-swapper)
			case "$pm" in
				pacman)
					printf 'sudo pacman -S cachyos-settings  # CachyOS; provides dlss-swapper\n'
					return 0
					;;
			esac
			printf 'install dlss-swapper (CachyOS: cachyos-settings) — https://wiki.cachyos.org/configuration/gaming/#forcing-the-latest-dlss-preset\n'
			return 0
			;;
		dlss-updater)
			case "$pm" in
				pacman)
					printf 'sudo pacman -S dlss-updater  # GUI; no launch CLI — or Flatpak from https://github.com/Recol/DLSS-Updater\n'
					return 0
					;;
			esac
			printf 'install dlss-updater (GUI DLL updater) — https://github.com/Recol/DLSS-Updater\n'
			return 0
			;;
		nvidia-smi)
			case "$pm" in
				apt)
					printf 'sudo apt install nvidia-utils  # driver version suffix may vary\n'
					return 0
					;;
			esac
			;;
	esac

	pkg="$(tool_package_name "$tool" "$pm")"
	[[ -n "$pkg" ]] || {
		printf 'install %s manually (no package mapping for this OS)\n' "$tool"
		return 0
	}

	format_install_command "$pm" "$pkg"
}

# tool_warn_suffix — Install-hint suffix for warn messages (empty when tool is present).
tool_warn_suffix() {
	local tool=$1 hint=""
	optional_tool_installed "$tool" && return 0
	hint="$(tool_install_hint "$tool" 2>/dev/null || true)"
	[[ -n "$hint" ]] && printf ' — %s' "$hint"
}

# warn_if_tool_missing — Warn when a tool is absent; always returns 0 (non-fatal).
warn_if_tool_missing() {
	local tool=$1 message=$2
	optional_tool_installed "$tool" && return 0
	warn "${message}$(tool_warn_suffix "$tool")"
}

# warn_if_feature_enabled_needs_tool — Warn when FLAG=1 but tool is missing.
warn_if_feature_enabled_needs_tool() {
	local flag=$1 tool=$2 message=$3
	[[ "${!flag:-0}" == "1" ]] || return 0
	warn_if_tool_missing "$tool" "$message"
}

# require_tool_or_skip — Return 0 when tool exists; warn and return 1 to skip the operation.
require_tool_or_skip() {
	local tool=$1 message=$2
	optional_tool_installed "$tool" && return 0
	warn_if_tool_missing "$tool" "$message"
	return 1
}

# command_required_or_fail — Exit 1 when a CLI dependency is missing (includes install hint).
command_required_or_fail() {
	local tool=$1 purpose=$2
	command_available "$tool" && return 0
	local hint=""
	hint="$(tool_install_hint "$tool" 2>/dev/null || true)"
	echo "${purpose}: ${tool} is required${hint:+ — $hint}" >&2
	return 1
}

# warn_enabled_missing_tools — Pre-launch warnings for enabled features with missing tools.
warn_enabled_missing_tools() {
	local wrapper hint dlss_bin
	warn_if_feature_enabled_needs_tool GAMEMODE gamemoderun \
		"GAMEMODE=1 but gamemoderun is not installed"
	if [[ "${GAME_PERFORMANCE:-1}" == "1" ]] && ! optional_tool_installed game-performance; then
		hint="$(tool_install_hint game-performance 2>/dev/null || true)"
		warn "GAME_PERFORMANCE=1 but no game-performance/cpupower/powerprofilesctl${hint:+ — $hint}"
	fi
	warn_if_feature_enabled_needs_tool GAMESCOPE gamescope \
		"GAMESCOPE=1 but gamescope is not installed"
	warn_if_feature_enabled_needs_tool MANGOHUD mangohud \
		"MANGOHUD=1 but mangohud is not installed"
	if dlss_bin="$(resolve_dlss_swapper_bin)"; then
		if ! command_available "$dlss_bin"; then
			hint="$(tool_install_hint dlss-swapper 2>/dev/null || true)"
			warn "DLSS_SWAPPER=${DLSS_SWAPPER} but $dlss_bin is not installed${hint:+ — $hint}"
		fi
	fi
	if [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]]; then
		warn_if_tool_missing taskset \
			"CPU affinity enabled but taskset is not installed — launch continues without pinning"
	fi
	warn_if_feature_enabled_needs_tool NETWORK_TUNE ethtool \
		"NETWORK_TUNE=1 but ethtool is not installed"
	if [[ "${PIPEWIRE_LOW_LATENCY:-0}" == "1" ]] \
		&& [[ "$(detect_audio_server 2>/dev/null || true)" == pipewire ]]; then
		warn_if_tool_missing pw-metadata \
			"PIPEWIRE_LOW_LATENCY=1 but pw-metadata is not installed"
	fi
	if [[ "${NVIDIA_POWER_MODE:-0}" == "1" ]] \
		&& [[ "$(detect_gpu_vendor 2>/dev/null || true)" == nvidia ]]; then
		warn_if_tool_missing nvidia-settings \
			"NVIDIA_POWER_MODE=1 but nvidia-settings is not installed"
	fi
	if [[ "${GPU_POWER_CHECK:-0}" == "1" ]] \
		&& [[ "$(detect_gpu_vendor 2>/dev/null || true)" == nvidia ]]; then
		warn_if_tool_missing nvidia-smi \
			"GPU_POWER_CHECK=1 but nvidia-smi is not installed"
	fi
	if [[ "${VRAM_HOGS:-0}" == "1" ]] && ! has_systemd_user \
		&& [[ -z "${VRAM_HOG_PIDS:-}" ]]; then
		warn "VRAM_HOGS=1 but systemd user session is unavailable and VRAM_HOG_PIDS is unset — hogs will not be paused"
	fi
	for wrapper in ${LAUNCH_WRAPPERS_BEFORE:-} ${LAUNCH_WRAPPERS:-}; do
		launch_wrapper_available "$wrapper" && continue
		hint="$(tool_install_hint "$wrapper" 2>/dev/null || true)"
		warn "LAUNCH_WRAPPERS expects '$wrapper' but it is not installed${hint:+ — $hint}"
	done
}

# collect_missing_optional_tools — Print missing relevant tool names (one per line).
collect_missing_optional_tools() {
	local tool
	for tool in "${LAUNCHLAYER_OPTIONAL_TOOLS[@]}"; do
		optional_tool_relevant "$tool" || continue
		optional_tool_installed "$tool" && continue
		printf '%s\n' "$tool"
	done
}

# print_optional_tool_install_hints — Missing tools with install commands (plain text).
print_optional_tool_install_hints() {
	local tool hint count=0
	while IFS= read -r tool; do
		[[ -n "$tool" ]] || continue
		hint="$(tool_install_hint "$tool")"
		[[ -n "$hint" ]] || continue
		printf '  %s: %s\n' "$tool" "$hint"
		(( count++ )) || true
	done < <(collect_missing_optional_tools)
	(( count == 0 ))
}

# foreach_relevant_optional_tool — Invoke callback(tool, installed_flag) for catalog tools.
foreach_relevant_optional_tool() {
	local callback=$1 tool installed_flag
	[[ "$(type -t "$callback")" == function ]] || return 1
	for tool in "${LAUNCHLAYER_OPTIONAL_TOOLS[@]}"; do
		optional_tool_relevant "$tool" || continue
		if optional_tool_installed "$tool"; then
			installed_flag=1
		else
			installed_flag=0
		fi
		"$callback" "$tool" "$installed_flag"
	done
}
