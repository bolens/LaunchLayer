#!/usr/bin/env bash
# Unit tests for lib/vdf.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "vdf_unescape_path converts backslashes to slashes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/vdf.sh"
		vdf_unescape_path "C:\\\\Steam\\\\steamapps"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == 'C:\Steam\steamapps' || "$output" == *"Steam"* ]]
}

@test "parse_libraryfolders_paths emits one path per line" {
	local vdf tmp
	tmp="$(mktemp -d)"
	vdf="$tmp/libraryfolders.vdf"
	cat > "$vdf" <<'EOF'
"libraryfolders"
{
	"0"
	{
		"path"		"/steam/main"
	}
	"1"
	{
		"path"		"/mnt/games/SteamLibrary"
	}
}
EOF
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source "'"$CONFIG_DIR"'/lib/vdf.sh"
		parse_libraryfolders_paths "'"$vdf"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'/steam/main\n/mnt/games/SteamLibrary' ]]
	rm -rf "$tmp"
}

@test "parse_libraryfolders_paths returns empty for missing file" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source "'"$CONFIG_DIR"'/lib/vdf.sh"
		parse_libraryfolders_paths /tmp/no-such-libraryfolders-$$.vdf
	'
	[[ $status -eq 0 ]]
	[[ -z "$output" ]]
}
