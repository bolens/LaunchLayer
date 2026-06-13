#!/usr/bin/env bash
setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../helpers.bash"
	SCRIPT="$(launchlayer_script)"
	export REPO_ROOT="$(launchlayer_root)"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
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
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME"
	run "$SCRIPT" --completions enable --shell bash
	[[ $status -eq 0 ]]
	[[ -f "$XDG_CONFIG_HOME/launchlayer/completions.bash" ]]
	run "$SCRIPT" --completions disable --shell bash
	[[ $status -eq 0 ]]
	[[ ! -f "$XDG_CONFIG_HOME/launchlayer/completions.bash" ]]
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
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME"
	run "$SCRIPT" --completions enable --shell nu
	[[ $status -eq 0 ]]
	[[ -L "$XDG_CONFIG_HOME/nushell/completions/launchlayer.nu" ]]
	run "$SCRIPT" --completions disable --shell nu
	[[ $status -eq 0 ]]
	[[ ! -L "$XDG_CONFIG_HOME/nushell/completions/launchlayer.nu" ]]
	rm -rf "$tmp_home"
}


@test "completions enable pwsh and disable in temp home" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME/powershell"
	run "$SCRIPT" --completions enable --shell pwsh
	[[ $status -eq 0 ]]
	[[ -f "$XDG_CONFIG_HOME/launchlayer/completions.pwsh" ]]
	grep -q 'launchlayer completions' "$XDG_CONFIG_HOME/powershell/Microsoft.PowerShell_profile.ps1"
	run "$SCRIPT" --completions disable --shell pwsh
	[[ $status -eq 0 ]]
	[[ ! -f "$XDG_CONFIG_HOME/launchlayer/completions.pwsh" ]]
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
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME"
	source_lib completions
	if completions_shell_is_enabled nu; then
		nu_was_enabled=1
	else
		nu_was_enabled=0
	fi
	[[ "$nu_was_enabled" -eq 0 ]]
	"$SCRIPT" --completions enable --shell nu >/dev/null
	source_lib completions
	completions_shell_is_enabled nu
	rm -rf "$tmp_home"
}


@test "completions_shell_status_brief reports enabled and disabled" {
	local tmp_home brief
	tmp_home="$(mktemp -d)"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME/powershell"
	source_lib completions
	brief="$(completions_shell_status_brief pwsh)"
	[[ "$brief" == disabled ]]
	"$SCRIPT" --completions enable --shell pwsh >/dev/null
	source_lib completions
	brief="$(completions_shell_status_brief pwsh)"
	[[ "$brief" == enabled ]]
	rm -rf "$tmp_home"
}


@test "doctor reports nu and pwsh completion status" {
	run "$SCRIPT" --doctor
	[[ $status -eq 0 ]]
	[[ "$output" == *"nu:"* ]]
	[[ "$output" == *"pwsh:"* ]]
	[[ "$output" == *"osh:"* ]]
}

