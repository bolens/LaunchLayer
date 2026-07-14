#!/usr/bin/env bash
# Unit tests for lib/hub/prefs.sh and preference paths.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib prefs hub
}

@test "hub_prefs_path uses XDG config dir" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs
		hub_prefs_path
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp/launchlayer/hub.conf" ]]
	rm -rf "$tmp"
}

@test "load_hub_prefs reads custom hub_url from file" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/hub.conf" <<'EOF'
hub_url=https://example.convex.site
publish_token=secret
machine_label=test-box
fingerprint_level=standard
EOF
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub
		load_hub_prefs
		echo "url:$HUB_PREFS_URL label:$HUB_PREFS_MACHINE_LABEL level:$HUB_PREFS_FINGERPRINT_LEVEL"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "url:https://example.convex.site label:test-box level:standard" ]]
	rm -rf "$tmp"
}

@test "hub_url_configured is false without hub_url" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub
		hub_url_configured && echo configured || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == missing ]]
	rm -rf "$tmp"
}

@test "hub_require_url fails with setup hint" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub
		hub_require_url 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Hub URL is not configured"* ]]
	rm -rf "$tmp"
}

@test "show_hub_prefs json omits token value" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/hub.conf" <<'EOF'
hub_url=https://example.convex.site
publish_token=secret
machine_label=test-box
fingerprint_level=minimal
EOF
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub cli
		show_hub_prefs 1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"publish_token_set":true'* ]]
	[[ "$output" != *secret* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["hub_url"]=="https://example.convex.site"' "$output"
	rm -rf "$tmp"
}

@test "save_hub_prefs writes user config file" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export HUB_PREFS_URL=https://example.convex.site
		export HUB_PREFS_MACHINE_LABEL=test-box
		export HUB_PREFS_FINGERPRINT_LEVEL=standard
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub
		save_hub_prefs
		cat "$(hub_prefs_path)"
		stat -c %a "$(hub_prefs_path)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"hub_url=https://example.convex.site"* ]]
	[[ "$output" == *"fingerprint_level=standard"* ]]
	[[ "$output" == *"600"* ]]
	rm -rf "$tmp"
}

@test "handle_hub_prefs set redacts publish_token in output" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub cli
		handle_hub_prefs_subcommand set publish_token super-secret-token
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Set publish_token=(set)"* ]]
	[[ "$output" != *"super-secret-token"* ]]
	rm -rf "$tmp"
}

@test "reset_hub_prefs restores example template" {
	local tmp example
	tmp="$(mktemp -d)"
	example="$tmp/share/launchlayer/templates/hub.conf.example"
	mkdir -p "$(dirname "$example")" "$tmp/launchlayer"
	cat > "$example" <<'EOF'
hub_url=
publish_token=
machine_label=workstation
fingerprint_level=standard
EOF
	cat > "$tmp/launchlayer/hub.conf" <<'EOF'
hub_url=https://wrong.example
publish_token=bad
machine_label=wrong
fingerprint_level=detailed
EOF
	run env \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib prefs hub
			reset_hub_prefs
			cat "$(hub_prefs_path)"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"machine_label=workstation"* ]]
	[[ "$output" == *"fingerprint_level=standard"* ]]
	[[ "$output" != *"wrong.example"* ]]
	rm -rf "$tmp"
}

@test "handle_hub_prefs set updates fingerprint_level" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub cli
		handle_hub_prefs_subcommand set fingerprint_level detailed
		load_hub_prefs
		echo "level:$HUB_PREFS_FINGERPRINT_LEVEL"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"level:detailed"* ]]
	rm -rf "$tmp"
}

@test "handle_hub_prefs show reports path" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub cli
		handle_hub_prefs_subcommand show
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Hub preferences"* ]]
	rm -rf "$tmp"
}
