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

@test "show_config notes DLSS when libraries are present" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "DLSS Show" DlssShow)"
	mkdir -p "$fake_steam/steamapps/common/DlssShow/bin"
	touch "$fake_steam/steamapps/common/DlssShow/bin/nvngx_dlss.dll"
	tmp="$(temp_config_dir)"
	run env \
		HOME="$tmp" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_PROFILES= \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config hardware runtime detected-defaults gpu preflight cli inspect launch
			optional_tool_installed() { return 1; }
			command_available() { return 1; }
			default_online_cpus() { echo 0-3; }
			show_config 42424242 0
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"DLSS libraries detected"* ]]
	[[ "$output" == *"DLSS_SWAPPER=1"* ]]
	[[ "$output" == *"PROTON_DLSS_UPGRADE=1"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "show_config notes Proton-CachyOS when available with DLSS" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "DLSS Cachy" DlssCachy)"
	mkdir -p "$fake_steam/steamapps/common/DlssCachy/bin"
	touch "$fake_steam/steamapps/common/DlssCachy/bin/nvngx_dlss.dll"
	tmp="$(temp_config_dir)"
	run env \
		HOME="$tmp" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_PROFILES= \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config hardware runtime detected-defaults gpu preflight cli inspect launch
			optional_tool_installed() { return 1; }
			command_available() { return 1; }
			default_online_cpus() { echo 0-3; }
			prefer_proton_cachyos() { echo proton-cachyos-slr; }
			show_config 42424242 0
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Proton-CachyOS available (proton-cachyos-slr)"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "show_config json reports dlss_present and DLSS_SWAPPER in chain" {
	local fake_steam tmp json_line
	fake_steam="$(fake_steam_root 42424242 "DLSS Json" DlssJson)"
	mkdir -p "$fake_steam/steamapps/common/DlssJson/bin"
	touch "$fake_steam/steamapps/common/DlssJson/bin/nvngx.dll"
	tmp="$(temp_config_dir)"
	printf '%s\n' 'DLSS_SWAPPER=1' > "$tmp/games/42424242.env"
	run env \
		HOME="$tmp" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_PROFILES= \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config hardware runtime detected-defaults gpu preflight cli inspect launch
			optional_tool_installed() { return 1; }
			command_available() { [[ "$1" == dlss-swapper ]]; }
			default_online_cpus() { echo 0-3; }
			prefer_proton_cachyos() { return 1; }
			show_config 42424242 1
		'
	[[ $status -eq 0 ]]
	json_line="$(printf '%s\n' "$output" | grep '^{' | tail -1)"
	[[ -n "$json_line" ]]
	python3 -c '
import json,sys
d=json.loads(sys.argv[1])
assert d["dlss_present"] is True, d
assert "dlss-swapper" in d["launch_chain"], d["launch_chain"]
settings={s["key"]: s["value"] for s in d["settings"]}
assert settings.get("DLSS_SWAPPER") == "1", settings
' "$json_line"
	rm -rf "$fake_steam" "$tmp"
}
