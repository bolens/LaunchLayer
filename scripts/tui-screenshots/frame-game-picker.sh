#!/usr/bin/env bash
# shellcheck shell=bash
# frame-game-picker.sh — Game picker with live preview for README screenshots.
set -euo pipefail
FRAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bootstrap.sh
source "$FRAME_DIR/bootstrap.sh"

picker_lines() {
	if [[ "${LAUNCHLAYER_SCREENSHOT_FIXTURES:-}" == 1 ]]; then
		cat "$FRAME_DIR/fixtures/games.txt"
		return 0
	fi
	tui_build_game_picker_lines
}

header="Select a game ([recent] at top, Ctrl-E: editor, Ctrl-D: dry-run, filter=${TUI_GAME_FILTER:-all})"
preview_cmd="${LAUNCHLAYER_MAIN_SCRIPT} --tui-game-preview \$(echo {} | grep -oE '[0-9]+' | head -1) 2>/dev/null"
fixture_preview="cat ${FRAME_DIR}/fixtures/preview-2357570.txt"

mapfile -t lines < <(picker_lines)
if ((${#lines[@]} == 0)) || [[ "${LAUNCHLAYER_SCREENSHOT_FIXTURES:-}" == 1 ]]; then
	[[ "${LAUNCHLAYER_SCREENSHOT_FIXTURES:-}" != 1 ]] && mapfile -t lines < <(cat "$FRAME_DIR/fixtures/games.txt")
	preview_cmd="$fixture_preview"
fi

fzf_args=(
	--header="$header"
	--height="${LAUNCHLAYER_TUI_HEIGHT:-45%}"
	--border
	--layout=reverse
	--info=inline
	--pointer='▶'
	--preview "$preview_cmd"
	--preview-window="${LAUNCHLAYER_TUI_PREVIEW:-right:50%:wrap}"
)
cli_uses_color && fzf_args+=(--ansi)

printf '%s\n' "${lines[@]}" | fzf "${fzf_args[@]}"
