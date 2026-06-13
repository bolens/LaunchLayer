#!/usr/bin/env bash
# Integration tests for shell completion installation.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

teardown() {
	bats_integration_teardown
}

@test "completions status runs" {
	run "$SCRIPT" --completions status
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer completions"* ]]
	[[ "$output" == *"bash:"* ]]
}

@test "completions enable and disable in temp home" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	mkdir -p "$tmp_home/.config"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions enable --shell bash
	[[ $status -eq 0 ]]
	[[ "$output" == *"bash"* || "$output" == *"enabled"* || -f "$tmp_home/.config/launchlayer/completions.bash" ]]
	[[ -f "$tmp_home/.config/launchlayer/completions.bash" ]]
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions disable --shell bash
	[[ $status -eq 0 ]]
	[[ ! -f "$tmp_home/.config/launchlayer/completions.bash" ]]
	rm -rf "$tmp_home"
}

@test "completions print bash" {
	run "$SCRIPT" --completions print --shell bash
	[[ $status -eq 0 ]]
	[[ "$output" == *"LAUNCHLAYER_CONFIG_DIR"* ]]
	[[ "$output" == *"_launchlayer_settings"* ]]
}

@test "completions print fish" {
	run "$SCRIPT" --completions print --shell fish
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer"* ]]
}

@test "completions print nu" {
	run "$SCRIPT" --completions print --shell nu
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu-complete launchlayer"* ]]
}

@test "completions print pwsh" {
	run "$SCRIPT" --completions print --shell pwsh
	[[ $status -eq 0 ]]
	[[ "$output" == *"Register-LaunchlayerCompleter"* ]]
}

@test "completions print osh uses bash script" {
	run "$SCRIPT" --completions print --shell osh
	[[ $status -eq 0 ]]
	[[ "$output" == *"_launchlayer_settings"* ]]
}

@test "completions enable nu and disable in temp home" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	mkdir -p "$tmp_home/.config"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions enable --shell nu
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu:"* ]]
	[[ "$output" == *"enabled"* ]]
	[[ -L "$tmp_home/.config/nushell/completions/launchlayer.nu" ]]
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions disable --shell nu
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu:"* ]]
	[[ "$output" == *"disabled"* ]]
	[[ ! -L "$tmp_home/.config/nushell/completions/launchlayer.nu" ]]
	rm -rf "$tmp_home"
}

@test "completions enable pwsh and disable in temp home" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	mkdir -p "$tmp_home/.config/powershell"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions enable --shell pwsh
	[[ $status -eq 0 ]]
	[[ "$output" == *"pwsh:"* ]]
	[[ "$output" == *"enabled"* ]]
	[[ -f "$tmp_home/.config/launchlayer/completions.pwsh" ]]
	grep -q 'launchlayer completions' "$tmp_home/.config/powershell/Microsoft.PowerShell_profile.ps1"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$SCRIPT" --completions disable --shell pwsh
	[[ $status -eq 0 ]]
	[[ "$output" == *"pwsh:"* ]]
	[[ "$output" == *"disabled"* ]]
	[[ ! -f "$tmp_home/.config/launchlayer/completions.pwsh" ]]
	rm -rf "$tmp_home"
}

@test "completions status includes nu and pwsh" {
	run "$SCRIPT" --completions status
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu:"* ]]
	[[ "$output" == *"pwsh:"* ]]
	[[ "$output" == *"osh:"* ]]
}

@test "completions_shell_is_enabled tracks nu install" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" bash -c '
		export XDG_CONFIG_HOME="'"$tmp_home"'/.config"
		mkdir -p "$XDG_CONFIG_HOME"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib completions
		completions_shell_is_enabled nu && echo enabled || echo disabled
		"'"$SCRIPT"'" --completions enable --shell nu >/dev/null
		source_lib completions
		completions_shell_is_enabled nu && echo enabled-after || echo disabled-after
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *disabled* ]]
	[[ "$output" == *enabled-after* ]]
	rm -rf "$tmp_home"
}

@test "completions_shell_status_brief reports enabled and disabled" {
	local tmp_home brief
	tmp_home="$(mktemp -d)"
	run env HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" bash -c '
		export XDG_CONFIG_HOME="'"$tmp_home"'/.config"
		mkdir -p "$XDG_CONFIG_HOME/powershell"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib completions
		completions_shell_status_brief pwsh
		"'"$SCRIPT"'" --completions enable --shell pwsh >/dev/null
		source_lib completions
		completions_shell_status_brief pwsh
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *disabled* ]]
	[[ "$output" == *enabled* ]]
	rm -rf "$tmp_home"
}

@test "doctor reports nu and pwsh completion status" {
	run "$SCRIPT" --doctor
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu:"* ]]
	[[ "$output" == *"pwsh:"* ]]
	[[ "$output" == *"osh:"* ]]
}
