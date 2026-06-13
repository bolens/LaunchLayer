#!/usr/bin/env bash
setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../helpers.bash"
	SCRIPT="$(launchlayer_script)"
	export REPO_ROOT="$(launchlayer_root)"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
}

@test "help exits zero" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--show-config"* ]]
}


@test "version exits zero" {
	run "$SCRIPT" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer"* ]]
	[[ "$output" == *"config_dir="* ]]
}


@test "unknown subcommand suggests similar flag" {
	run "$SCRIPT" --show-confg
	[[ $status -eq 1 ]]
	[[ "$output" == *"unknown subcommand"* ]]
	[[ "$output" == *"--show-config"* ]]
}


@test "help shows grouped sections" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"Onboarding & health"* ]]
	[[ "$output" == *"Games & config"* ]]
}


@test "launchlayer symlink resolves lib modules" {
	local tmp_home bindir
	tmp_home="$(mktemp -d)"
	bindir="$tmp_home/.local/bin"
	mkdir -p "$bindir"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	"$SCRIPT" --setup --symlink >/dev/null
	run "$bindir/launchlayer" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer"* ]]
	[[ "$output" == *"script="* ]]
	rm -rf "$tmp_home"
}


@test "help documents tui" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--tui"* ]]
}


@test "version reports 0.9.0" {
	run "$SCRIPT" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"0.9.0"* ]]
}


@test "parse_json_focused_vrr detects adaptive sync" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform hardware
		printf "%s\n" "[{\"name\":\"DP-1\",\"focused\":true,\"vrr\":true}]" \
			| parse_json_focused_vrr && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]
}

