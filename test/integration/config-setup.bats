#!/usr/bin/env bash
# Integration tests for setup, status, and TUI entry points.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

teardown() {
	bats_integration_teardown
}

@test "status json runs" {
	run "$SCRIPT" --status --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_dir"'* || "$output" == *'"version"'* || "$output" == *'"steam_root"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "setup print launch option" {
	run "$SCRIPT" --setup --print-launch-option
	[[ $status -eq 0 ]]
	[[ "$output" == *"%command%"* ]]
}

@test "setup symlink creates launchlayer" {
	local tmp_home bindir
	tmp_home="$(mktemp -d)"
	bindir="$tmp_home/.local/bin"
	mkdir -p "$bindir"
	run env HOME="$tmp_home" "$SCRIPT" --setup --symlink
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer"* || "$output" == *"symlink"* || "$output" == *".local/bin"* ]]
	[[ -L "$bindir/launchlayer" ]]
	[[ "$(readlink "$bindir/launchlayer")" == *"launchlayer"* ]]
	rm -rf "$tmp_home"
}

@test "tui requires interactive terminal" {
	run bash -c "$SCRIPT --tui </dev/null"
	[[ $status -ne 0 ]]
	[[ "$output" == *"interactive terminal"* ]]
}

@test "tui-prefs show reports defaults" {
	local tmp
	tmp="$(mktemp -d)"
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --tui-prefs show
	[[ $status -eq 0 ]]
	[[ "$output" == *"game_filter"* ]]
	[[ "$output" == *"default_preset"* ]]
	rm -rf "$tmp"
}
