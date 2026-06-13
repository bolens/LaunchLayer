#!/usr/bin/env bash
# Integration tests for environment detection and local config.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

@test "detect-environment runs" {
	run "$SCRIPT" --detect-environment
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer environment"* ]]
	[[ "$output" == *"Gaming profile"* ]]
	[[ "$output" == *"GPU:"* ]]
	[[ "$output" == *"systemd user:"* ]]
}

@test "detect-environment json is valid" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "detect-environment json includes optional tools" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"optional_tools"'* ]]
	[[ "$output" == *'"package_manager"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "optional_tools" in d and isinstance(d["optional_tools"], list)' "$output"
}

@test "detect-environment lists optional tools section" {
	run "$SCRIPT" --detect-environment
	[[ $status -eq 0 ]]
	[[ "$output" == *"Optional tools"* ]]
}

@test "detect-environment json includes os fields" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"os_id"'* ]]
	[[ "$output" == *'"os_family"'* ]]
	[[ "$output" == *'"compositor"'* ]]
	[[ "$output" == *'"session_type"'* ]]
	[[ "$output" == *'"immutable"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert all(k in d for k in ("os_family","compositor","session_type","immutable"))' "$output"
}

@test "detect-defaults runs" {
	run "$SCRIPT" --detect-defaults
	[[ $status -eq 0 ]]
	[[ "$output" == *"Detected defaults"* ]]
}

@test "detect-defaults json is valid" {
	run "$SCRIPT" --detect-defaults --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "defaults" in d' "$output"
}

@test "write-local-config dry-run" {
	local tmp
	tmp="$(temp_config_dir)"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --write-local-config --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"Write local config (dry-run)"* ]]
	rm -rf "$tmp"
}

@test "help mentions detect-environment" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--detect-environment"* ]]
	[[ "$output" == *"--detect-defaults"* ]]
	[[ "$output" == *"--write-local-config"* ]]
}
