#!/usr/bin/env bash
# Integration tests for hub fingerprint CLI output.
load '../helpers.bash'

setup() {
	bats_integration_setup
	source_lib platform hardware cli hub
}

@test "minimal fingerprint omits detailed GPU and display lists" {
	export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL=minimal
	run bash "$SCRIPT" --hub-fingerprint --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"fingerprint_level":"minimal"'* || "$output" == *'"fingerprint_level": "minimal"'* ]]
	[[ "$output" != *'"gpus"'* ]]
	[[ "$output" == *'"desktop"'* ]]
	[[ "$output" == *'"refresh_tier"'* ]]
}

@test "detailed fingerprint includes GPU and display lists" {
	export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL=detailed
	run bash "$SCRIPT" --hub-fingerprint --json --fingerprint-level detailed
	[[ $status -eq 0 ]]
	[[ "$output" == *'"gpus"'* ]]
	[[ "$output" == *'"displays"'* ]]
}

@test "hub-fingerprint subcommand emits json" {
	run bash "$SCRIPT" --hub-fingerprint --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"fingerprint"'* ]]
	[[ "$output" == *'"fingerprint_hash"'* ]]
}

@test "help documents hub commands" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--hub-fingerprint"* ]]
	[[ "$output" == *"--hub-publish"* ]]
	[[ "$output" == *"--hub-delete"* ]]
	[[ "$output" == *"--hub-recommend"* ]]
	[[ "$output" == *"--hub-prefs"* ]]
}

@test "hub-delete fails without configured url" {
	local tmp
	tmp="$(mktemp -d)"
	run env HOME="$tmp" XDG_CONFIG_HOME="$tmp" LAUNCHLAYER_CONFIG_DIR="$tmp" \
		"$SCRIPT" --hub-delete j972pwtdzcysmq5nqnxqgcqf2d88jtvg --yes 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"Hub URL is not configured"* ]]
	rm -rf "$tmp"
}

@test "hub-publish fails without configured url" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/games" "$tmp/launch.d/presets"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/42424242.env"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	run env \
		HOME="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		"$SCRIPT" --hub-publish 42424242 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"Hub URL is not configured"* ]]
	rm -rf "$tmp"
}

@test "hub-recommend fails without configured url" {
	local tmp
	tmp="$(mktemp -d)"
	run env HOME="$tmp" XDG_CONFIG_HOME="$tmp" LAUNCHLAYER_CONFIG_DIR="$tmp" \
		"$SCRIPT" --hub-recommend 42424242 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"Hub URL is not configured"* ]]
	rm -rf "$tmp"
}
