#!/usr/bin/env bash
# Unit tests for dispatch-tui games-cache fzf hooks (non-interactive).
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_tui_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$(mktemp -d)}"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli load-modules
		launchlayer_source_tui
		'"$1"'
	'
}

_seed_ready_games_cache() {
	cat <<'EOF'
		tui_games_cache_purge
		tui_games_cache_paths
		mkdir -p "$TUI_GAMES_CACHE_DIR"
		printf "ready\n" > "$TUI_GAMES_CACHE_STATUS"
		printf "%s\n" "42424242 yes no yes listed unknown TestGame" > "$TUI_GAMES_CACHE_FILE"
EOF
}

@test "dispatch_tui_subcommand tui-games-menu-reload prints hub menu rows" {
	run _dispatch_tui_shell '
		tui_games_cache_purge
		dispatch_tui_subcommand --tui-games-menu-reload
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Browse & configure game"* ]]
}

@test "dispatch_tui_subcommand tui-games-menu-resize-reload consumes refresh-list marker" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		touch "${TUI_GAMES_CACHE_DIR}/refresh-list"
		dispatch_tui_subcommand --tui-games-menu-resize-reload
		[[ -f "${TUI_GAMES_CACHE_DIR}/refresh-list" ]] && echo marker:present || echo marker:absent
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Browse & configure game"* ]]
	[[ "$output" == *"marker:absent"* ]]
}

@test "dispatch_tui_subcommand tui-games-menu-resize-reload no-ops without marker" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		dispatch_tui_subcommand --tui-games-menu-resize-reload
		echo exit:$?
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"exit:1"* ]]
}

@test "dispatch_tui_subcommand tui-games-picker-reload prints picker rows from cache" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		dispatch_tui_subcommand --tui-games-picker-reload
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" == *"TestGame"* ]]
}

@test "dispatch_tui_subcommand tui-games-picker-reload shows loading placeholder while busy" {
	run _dispatch_tui_shell '
		tui_games_cache_purge
		tui_games_cache_paths
		mkdir -p "$TUI_GAMES_CACHE_DIR"
		printf "loading\n" > "$TUI_GAMES_CACHE_STATUS"
		sleep 300 &
		loader_pid=$!
		printf "%s\n" "$loader_pid" > "$TUI_GAMES_CACHE_PID_FILE"
		dispatch_tui_subcommand --tui-games-picker-reload
		kill "$loader_pid" 2>/dev/null || true
		wait "$loader_pid" 2>/dev/null || true
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Loading installed games"* ]]
}

@test "dispatch_tui_subcommand tui-games-picker-header reports ready base title" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		export TUI_GAMES_FZF_HEADER_BASE="Pick game"
		dispatch_tui_subcommand --tui-games-picker-header
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Pick game"* ]]
}

@test "dispatch_tui_subcommand tui-games-picker-footer includes filter and game count" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		export TUI_GAME_FILTER=all
		dispatch_tui_subcommand --tui-games-picker-footer
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"filter:all"* ]]
	[[ "$output" == *"1 games"* ]]
}

@test "dispatch_tui_subcommand tui-games-picker-resize-reload reloads picker after cache refresh" {
	run _dispatch_tui_shell '
		'"$(_seed_ready_games_cache)"'
		touch "${TUI_GAMES_CACHE_DIR}/refresh-list"
		dispatch_tui_subcommand --tui-games-picker-resize-reload
		[[ -f "${TUI_GAMES_CACHE_DIR}/refresh-list" ]] && echo marker:present || echo marker:absent
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" == *"marker:absent"* ]]
}
