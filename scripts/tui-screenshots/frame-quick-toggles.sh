#!/usr/bin/env bash
# shellcheck shell=bash
# frame-quick-toggles.sh — Per-game quick toggles for README screenshots.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap.sh
source "$SCRIPT_DIR/bootstrap.sh"

appid=${1:-2357570}
name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
tui_crumb_enter "Games"
tui_crumb_enter "$name"
tui_crumb_enter "Quick toggles"

prepare_launch_context "$appid"
options=()
for key in "${TUI_TOGGLE_KEYS[@]}"; do
	options+=("$(tui_format_toggle_option "$appid" "$key")")
done
options+=(
	"Clear override (inherit from layers)"
	"Clear ALL overrides"
	Back
)

fzf_menu "$(tui_crumb_label "Flip per-game override")" "${options[@]}"
