# shellcheck shell=bash
# scripts/tui-screenshots/bootstrap.sh — Load LaunchLayer modules for static TUI frames.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$ROOT"
CONFIG_DIR="$ROOT"
LIB_DIR="$ROOT/lib"
LAUNCHLAYER_MAIN_SCRIPT="$ROOT/launchlayer"
export SCRIPT_DIR CONFIG_DIR LIB_DIR LAUNCHLAYER_MAIN_SCRIPT LAUNCHLAYER_CONFIG_DIR="$ROOT"

# shellcheck source=../../lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=../../lib/keys.sh
source "$LIB_DIR/keys.sh"
# shellcheck source=../../lib/load-modules.sh
source "$LIB_DIR/load-modules.sh"

launchlayer_load_pre_main
launchlayer_load_post_main

tui_load_config 2>/dev/null || true
load_backup_prefs 2>/dev/null || true
TUI_GAME_FILTER=${TUI_GAME_FILTER:-all}
TUI_PRESS_ENTER_LINES=${TUI_PRESS_ENTER_LINES:-8}

fzf_menu() {
	local header=$1
	shift
	local -a fzf_args=(
		--header="$header"
		--height="${LAUNCHLAYER_TUI_HEIGHT:-45%}"
		--border
		--layout=reverse
		--info=inline
		--pointer='▶'
	)
	cli_uses_color && fzf_args+=(--ansi)
	printf '%s\n' "$@" | fzf "${fzf_args[@]}"
}
