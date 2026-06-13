#!/usr/bin/env bash
# Unit tests for lib/commands/environment.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "tool_available reports yes when optional tool is installed" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands environment tools
		optional_tool_installed() { [[ "$1" == gamescope ]]; }
		printf "gamescope:%s\n" "$(tool_available gamescope)"
		printf "missing:%s\n" "$(tool_available not-a-tool)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"gamescope:yes"* ]]
	[[ "$output" == *"missing:no"* ]]
}

@test "optional_tools_json_array emits parseable tool status objects" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli environment tools
		optional_tool_relevant() { [[ "$1" == gamescope || "$1" == mangohud ]]; }
		optional_tool_installed() { [[ "$1" == mangohud ]]; }
		tool_install_hint() { echo "install-$1"; }
		LAUNCHLAYER_OPTIONAL_TOOLS=(gamescope mangohud)
		optional_tools_json_array
	'
	[[ $status -eq 0 ]]
	python3 -c '
import json, sys
raw = sys.argv[1].strip()
start = raw.find("[")
data = json.loads(raw[start:])
by_name = {row["name"]: row for row in data}
assert by_name["mangohud"]["installed"] is True
assert by_name["gamescope"]["installed"] is False
assert "install-gamescope" in by_name["gamescope"]["install_hint"]
' "$output"
}

@test "env_report_tools_row marks installed and missing tools" {
	run env NO_COLOR=1 bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands environment tools cli
		optional_tool_installed() { [[ "$1" == jq ]]; }
		env_report_tools_row jq gamescope
	' 2>&1
	[[ $status -eq 0 ]]
	[[ "$output" == *"jq"* ]]
	[[ "$output" == *"gamescope"* ]]
}
