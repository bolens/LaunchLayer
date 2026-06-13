#!/usr/bin/env bash
# Unit tests for lib/completions/helpers.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib completions
}

@test "normalize_completions_shell maps aliases" {
	[[ "$(normalize_completions_shell osh)" == bash ]]
	[[ "$(normalize_completions_shell pwsh)" == pwsh ]]
	[[ "$(normalize_completions_shell powershell)" == pwsh ]]
	[[ "$(normalize_completions_shell nu)" == nu ]]
	[[ "$(normalize_completions_shell nushell)" == nu ]]
	[[ "$(normalize_completions_shell fish)" == fish ]]
}

@test "normalize_completions_shell returns unknown shells unchanged" {
	[[ "$(normalize_completions_shell bash)" == bash ]]
	[[ "$(normalize_completions_shell zsh)" == zsh ]]
}

@test "completions_shell_status_brief reports disabled for unknown shell" {
	run completions_shell_status_brief not-a-shell
	[[ $status -eq 1 ]]
	[[ "$output" == unknown ]]
}
