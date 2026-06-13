#!/usr/bin/env bash
# shellcheck shell=bash
# frame-main-menu.sh — Main TUI hub for README screenshots.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap.sh
source "$SCRIPT_DIR/bootstrap.sh"

tui_print_status_banner
export TUI_PANEL_ACTIVE=1
tui_panel_init

main_items=(
	Games
	"Config library"
	"Backup & restore"
	"Community hub"
	"System & tools"
	"Settings"
	Quit
)

TUI_MENU_CONTEXT=main
fzf_menu "LaunchLayer ${LAUNCHLAYER_VERSION}" "${main_items[@]}"
