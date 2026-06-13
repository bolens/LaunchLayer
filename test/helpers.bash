# shellcheck shell=bash
# Shared helpers for LaunchLayer bats tests.

launchlayer_root() {
	if [[ -n "${CONFIG_DIR:-}" ]]; then
		printf '%s\n' "$CONFIG_DIR"
		return
	fi
	local helpers_dir
	helpers_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	printf '%s\n' "$(cd "$helpers_dir/.." && pwd)"
}

launchlayer_script() {
	printf '%s\n' "$(launchlayer_root)/launchlayer"
}

# seed_fake_steam_game — Write a minimal appmanifest + installdir for tests.
seed_fake_steam_game() {
	local steam_root=$1 appid=$2 name=$3 installdir=${4:-TestGame${appid}}
	mkdir -p "$steam_root/steamapps/common/$installdir"
	cat > "$steam_root/steamapps/appmanifest_${appid}.acf" <<EOF
"AppState"
{
	"appid"		"$appid"
	"name"		"$name"
	"installdir"		"$installdir"
}
EOF
}

# fake_steam_root — Temp Steam root with one installed game.
fake_steam_root() {
	local appid=$1 name=$2 installdir=${3:-}
	local tmp
	tmp="$(mktemp -d)"
	seed_fake_steam_game "$tmp" "$appid" "$name" "${installdir:-TestGame${appid}}"
	printf '%s\n' "$tmp"
}

temp_config_dir() {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/games"
	printf '%s\n' 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	printf '%s\n' 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	printf '%s\n' "$tmp"
}

# temp_state_dir — Isolated XDG state for unit tests touching STATE_DIR.
temp_state_dir() {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/state/launchlayer"
	printf '%s\n' "$tmp"
}

# _source_lib_module — Source one lib module or modular subtree.
_source_lib_module() {
	local root=$1 module=$2
	case "$module" in
		platform) launchlayer_source_platform ;;
		hardware) launchlayer_source_hardware ;;
		inspect) launchlayer_source_inspect ;;
		prefs) launchlayer_source_prefs ;;
		completions) launchlayer_source_completions ;;
		setup) launchlayer_source_setup ;;
		commands) launchlayer_source_commands ;;
		tui) launchlayer_source_tui ;;
		*) source "$root/lib/${module}.sh" ;;
	esac
}

# source_lib — Source lib modules with CONFIG_DIR and LIB_DIR set.
# Pass modular tree names (platform, hardware, inspect, …) or single-file modules (cli, steam, …).
# LIB_DIR always points at the repo lib/ tree; CONFIG_DIR may be a temp dir for isolated tests.
source_lib() {
	local repo module
	repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	export CONFIG_DIR="${CONFIG_DIR:-$repo}"
	export LIB_DIR="$repo/lib"
	# shellcheck disable=SC1091
	source "$LIB_DIR/common.sh"
	# shellcheck disable=SC1091
	[[ -n "${LAUNCHLAYER_LOAD_MODULES_LOADED:-}" ]] || source "$LIB_DIR/load-modules.sh"
	for module in "$@"; do
		_source_lib_module "$repo" "$module"
	done
}
