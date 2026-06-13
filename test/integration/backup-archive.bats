#!/usr/bin/env bash
# Integration tests for config export, import, and backup archives.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

@test "export-config and import-config round-trip" {
	local tmp archive dest
	tmp="$(mktemp -d)"
	dest="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/games"
	cat > "$tmp/launch.d/default.env" <<'EOF'
GAMEMODE=1
EOF
	cat > "$tmp/launch.d/presets/standard.env" <<'EOF'
MANGOHUD=0
EOF
	cat > "$tmp/games/42424242.env" <<'EOF'
# Round Trip Game (Steam AppID 42424242)
INCLUDE=presets/standard.env
GAME_EXTRA_ARGS="-test"
EOF
	archive="$dest/roundtrip.tar.gz"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --export-config --output "$archive" --json
	[[ $status -eq 0 ]]
	[[ -f "$archive" ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["file_count"]>=3' "$output"

	rm -f "$tmp/games/42424242.env"
	[[ ! -f "$tmp/games/42424242.env" ]]

	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --import-config "$archive" --yes --json
	[[ $status -eq 0 ]]
	[[ -f "$tmp/games/42424242.env" ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["applied"]>=1' "$output"

	rm -rf "$tmp" "$dest"
}

@test "import-config merge skips existing files" {
	local tmp archive
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/games"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/11111111.env"
	cat > "$tmp/launch.d/presets/standard.env" <<'EOF'
MANGOHUD=0
EOF
	archive="$tmp/export.tar.gz"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --export-config --output "$archive"
	[[ $status -eq 0 ]]

	echo 'INCLUDE=presets/standard.env' > "$tmp/games/22222222.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --import-config "$archive" --yes --merge --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["skipped"]>=1' "$output"
	[[ -f "$tmp/games/22222222.env" ]]

	rm -rf "$tmp"
}

@test "backup-config writes timestamped archive" {
	local tmp outdir
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$tmp/launch.d/presets" "$outdir"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --backup-config --output "$outdir"
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer-backup"* ]]
	[[ $(find "$outdir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 1 ]]
	rm -rf "$tmp"
}

@test "import-config dry-run does not apply" {
	local tmp archive
	tmp="$(temp_config_dir)"
	archive="$tmp/export.tar.gz"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --export-config --output "$archive"
	[[ $status -eq 0 ]]
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/99999998.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --import-config "$archive" --dry-run --replace
	[[ $status -eq 0 ]]
	[[ -f "$tmp/games/99999998.env" ]]
	rm -rf "$tmp"
}
