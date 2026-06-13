#!/usr/bin/env bash
# shellcheck shell=bash
# frame-main-menu.sh — Main TUI hub for README screenshots.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap.sh
source "$SCRIPT_DIR/bootstrap.sh"

tui_print_status_banner

main_items=(
	Games
	"Config library"
	"Backup & restore"
	"Community hub"
	"System & tools"
	"TUI settings"
	Quit
)

fzf_menu "LaunchLayer ${LAUNCHLAYER_VERSION}" "${main_items[@]}"
