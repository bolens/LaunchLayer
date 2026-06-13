#!/usr/bin/env bash
# Unit tests for lib/inspect launch stats helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "launch_stats json with empty log" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam cli inspect
			launch_stats "" 1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"entries":[]'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$tmp"
}

@test "launch_stats parses sample log entries" {
	local tmp log
	tmp="$(temp_state_dir)"
	log="$tmp/state/launchlayer/launch.log"
	mkdir -p "$(dirname "$log")"
	cat > "$log" <<'EOF'
2026-01-01T12:00:00+0000 appid=42424242 name="Test Game" duration=120s exit=0
2026-01-02T12:00:00+0000 appid=42424242 name="Test Game" duration=60s exit=1
EOF
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam cli inspect
			launch_stats 42424242 1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"entries"'* ]]
	[[ "$output" == *'"appid":"42424242"'* ]]
	[[ "$output" == *'"launches":2'* ]]
	[[ "$output" == *'"failures":1'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); e=d["entries"][0]; assert e["appid"]=="42424242" and e["launches"]==2 and e["failures"]==1' "$output"
	rm -rf "$tmp"
}

@test "show_paths json includes install and cache paths" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Paths Game")"
	mkdir -p "$fake_steam/steamapps/shadercache/42424242"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform steam keys config preflight cli vdf inspect
		show_paths 42424242 1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	[[ "$output" == *'"shader_cache"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$fake_steam"
}
