# shellcheck shell=bash
# lib/tui/games-cache/state.sh — Cache paths, status, and reconciliation.

[[ -n "${LAUNCHLAYER_TUI_GAMES_CACHE_STATE_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_GAMES_CACHE_STATE_LOADED=1

# Menu rows that need the installed-games list before they can run.
TUI_GAMES_MENU_NEED_LIST=(
	"Browse & configure game"
	"Recent games"
	"Bulk change INCLUDE preset"
)

# tui_games_cache_dir — Persistent cache directory under XDG cache.
tui_games_cache_dir() {
	printf '%s/launchlayer/tui-games' "${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}"
}

# tui_games_cache_paths — Set TUI_GAMES_CACHE_* path variables.
tui_games_cache_paths() {
	TUI_GAMES_CACHE_DIR="$(tui_games_cache_dir)"
	TUI_GAMES_CACHE_FILE="${TUI_GAMES_CACHE_DIR}/lines"
	TUI_GAMES_CACHE_STATUS="${TUI_GAMES_CACHE_DIR}/status"
	TUI_GAMES_CACHE_PID_FILE="${TUI_GAMES_CACHE_DIR}/pid"
	TUI_GAMES_CACHE_CHROME_HEADER="${TUI_GAMES_CACHE_DIR}/fzf-header"
	TUI_GAMES_CACHE_CHROME_FOOTER="${TUI_GAMES_CACHE_DIR}/fzf-footer"
}

# tui_games_cache_purge — Remove cache entirely (tests / manual reset).
tui_games_cache_purge() {
	tui_games_cache_kill_loader
	tui_games_cache_paths
	rm -rf "$TUI_GAMES_CACHE_DIR"
	unset TUI_GAMES_CACHE_DIR TUI_GAMES_CACHE_FILE TUI_GAMES_CACHE_STATUS
	unset TUI_GAMES_CACHE_PID_FILE TUI_GAMES_CACHE_CHROME_HEADER TUI_GAMES_CACHE_CHROME_FOOTER
}

# tui_games_cache_invalidate — Drop in-flight work; keep persisted lines on disk.
tui_games_cache_invalidate() {
	tui_games_cache_kill_loader
	tui_games_cache_paths
	rm -f \
		"$TUI_GAMES_CACHE_PID_FILE" \
		"${TUI_GAMES_CACHE_DIR}/refresh-list"
	tui_games_cache_discard_orphans
}

# tui_games_cache_status — Print loading, ready, error, or missing.
tui_games_cache_status() {
	tui_games_cache_paths
	[[ -f "$TUI_GAMES_CACHE_STATUS" ]] || {
		printf 'missing\n'
		return 0
	}
	cat "$TUI_GAMES_CACHE_STATUS"
}

# tui_games_cache_has_lines — True when cached lines file is non-empty.
tui_games_cache_has_lines() {
	tui_games_cache_paths
	[[ -s "$TUI_GAMES_CACHE_FILE" ]]
}

# tui_games_cache_loader_alive — True when the background loader process is running.
tui_games_cache_loader_alive() {
	local pid
	tui_games_cache_paths
	[[ -f "$TUI_GAMES_CACHE_PID_FILE" ]] || return 1
	pid="$(cat "$TUI_GAMES_CACHE_PID_FILE" 2>/dev/null || true)"
	[[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# tui_games_cache_discard_orphans — Remove partial loader artifacts after an interrupted scan.
tui_games_cache_discard_orphans() {
	tui_games_cache_paths
	rm -f "${TUI_GAMES_CACHE_FILE}.new" "${TUI_GAMES_CACHE_DIR}"/lines.work.*
}

# tui_games_cache_reconcile — Recover from stale loading state or dead loader PIDs.
tui_games_cache_reconcile() {
	local st
	tui_games_cache_paths
	mkdir -p "$TUI_GAMES_CACHE_DIR"
	st="$(tui_games_cache_status)"
	if [[ "$st" == loading || "$st" == refreshing ]]; then
		if ! tui_games_cache_loader_alive; then
			tui_games_cache_discard_orphans
			if tui_games_cache_has_lines; then
				printf 'ready\n' > "$TUI_GAMES_CACHE_STATUS"
			else
				printf 'error\n' > "$TUI_GAMES_CACHE_STATUS"
			fi
			rm -f "$TUI_GAMES_CACHE_PID_FILE"
		fi
	elif [[ "$st" == missing && -f "$TUI_GAMES_CACHE_PID_FILE" ]] && ! tui_games_cache_loader_alive; then
		rm -f "$TUI_GAMES_CACHE_PID_FILE"
		if tui_games_cache_has_lines; then
			printf 'ready\n' > "$TUI_GAMES_CACHE_STATUS"
		fi
	elif tui_games_cache_has_lines && [[ "$st" != ready ]]; then
		printf 'ready\n' > "$TUI_GAMES_CACHE_STATUS"
	fi
}

# tui_games_cache_ready — True when cached lines are available for menus/pickers.
tui_games_cache_ready() {
	tui_games_cache_reconcile
	[[ "$(tui_games_cache_status)" == ready ]] && tui_games_cache_has_lines
}

# tui_games_cache_loading — True during first load before any lines exist.
tui_games_cache_loading() {
	tui_games_cache_reconcile
	tui_games_cache_loader_alive && ! tui_games_cache_has_lines
}

# tui_games_cache_refreshing — True when a background rescan is updating persisted lines.
tui_games_cache_refreshing() {
	tui_games_cache_reconcile
	tui_games_cache_loader_alive && tui_games_cache_has_lines
}

# tui_games_cache_busy — True while any background scan is running.
tui_games_cache_busy() {
	tui_games_cache_reconcile
	tui_games_cache_loader_alive
}

# tui_games_cache_apply_filter — Filter full cached lines on stdin to stdout.
tui_games_cache_apply_filter() {
	case "${TUI_GAME_FILTER:-all}" in
		configured) awk '$2 == "yes"' ;;
		unconfigured) awk '$2 == "no"' ;;
		*) cat ;;
	esac
}

# tui_games_cache_kill_loader — Stop an in-flight background list-games job.
tui_games_cache_kill_loader() {
	local pid
	tui_games_cache_paths
	[[ -f "$TUI_GAMES_CACHE_PID_FILE" ]] || return 0
	pid="$(cat "$TUI_GAMES_CACHE_PID_FILE" 2>/dev/null || true)"
	[[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
	rm -f "$TUI_GAMES_CACHE_PID_FILE"
}

# tui_games_cache_persist_lines — Atomically replace cached list-games rows (CLI or loader).
tui_games_cache_persist_lines() {
	local work
	(($# == 0)) && return 1
	tui_games_cache_paths
	mkdir -p "$TUI_GAMES_CACHE_DIR"
	tui_games_cache_kill_loader
	tui_games_cache_discard_orphans
	work="${TUI_GAMES_CACHE_FILE}.work.$$"
	printf '%s\n' "$@" >"$work"
	mv -f "$work" "$TUI_GAMES_CACHE_FILE"
	printf 'ready\n' >"$TUI_GAMES_CACHE_STATUS"
	touch "${TUI_GAMES_CACHE_DIR}/refresh-list"
}
