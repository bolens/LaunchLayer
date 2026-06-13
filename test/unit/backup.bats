#!/usr/bin/env bash
# Unit tests for lib/inspect/backup/common.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "config_bundle_sha256 hashes file contents" {
	local tmp file
	tmp="$(mktemp -d)"
	file="$tmp/sample.env"
	echo 'GAMEMODE=1' > "$file"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		config_bundle_sha256 "'"$file"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^[0-9a-f]{64}$ ]]
	rm -rf "$tmp"
}

@test "config_file_abs_from_rel maps games and launch.d paths" {
	local tmp games
	tmp="$(temp_config_dir)"
	games="$tmp/games-custom"
	mkdir -p "$games"
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$games" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		printf "%s\n" "$(config_file_abs_from_rel launch.d/default.env)" "$(config_file_abs_from_rel games/12345.env)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"$tmp/launch.d/default.env"* ]]
	[[ "$output" == *"$games/12345.env"* ]]
	rm -rf "$tmp"
}

@test "collect_managed_config_files lists default presets and games" {
	local tmp games
	tmp="$(temp_config_dir)"
	games="$tmp/games-custom"
	mkdir -p "$games"
	echo 'GAMEMODE=1' > "$games/42424242.env"
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$games" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		files=()
		collect_managed_config_files 0 0 files
		printf "%s\n" "${files[@]}"
	' 
	[[ $status -eq 0 ]]
	[[ "$output" == *"launch.d/default.env"* ]]
	[[ "$output" == *"presets/standard.env"* ]]
	[[ "$output" == *"games/42424242.env"* ]]
	rm -rf "$tmp"
}

@test "_find_config_bundle_root locates nested bundle directory" {
	local tmp root
	tmp="$(mktemp -d)"
	root="$tmp/nested-bundle"
	mkdir -p "$root/launch.d"
	echo '{}' > "$root/manifest.json"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		_find_config_bundle_root "'"$tmp"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$root" ]]
	rm -rf "$tmp"
}

@test "list_backup_archives returns newest first" {
	local tmp outdir first second
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	touch -d '2020-01-01 00:00:00' "$outdir/launchlayer-backup-20200101-000000.tar.gz"
	touch -d '2024-06-01 00:00:00' "$outdir/launchlayer-backup-20240601-000000.tar.gz"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		list_backup_archives "'"$outdir"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"20240601"* ]]
	[[ "$output" == *"20200101"* ]]
	mapfile -t out <<< "$output"
	[[ "${out[0]}" == *"20240601"* ]]
	[[ "${out[1]}" == *"20200101"* ]]
	rm -rf "$tmp"
}

@test "latest_backup_archive picks newest archive" {
	local tmp outdir
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	touch -d '2020-01-01 00:00:00' "$outdir/launchlayer-backup-20200101-000000.tar.gz"
	touch -d '2024-06-01 00:00:00' "$outdir/launchlayer-export-20240601-000000.tar.gz"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		latest_backup_archive "'"$outdir"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"20240601"* ]]
	rm -rf "$tmp"
}

@test "list_backup_archives fails when directory is empty" {
	local tmp outdir
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		list_backup_archives "'"$outdir"'"
	'
	[[ $status -eq 1 ]]
	rm -rf "$tmp"
}

@test "resolve_restore_archive returns explicit archive file" {
	local tmp archive
	tmp="$(mktemp -d)"
	archive="$tmp/launchlayer-backup-20240601-000000.tar.gz"
	touch "$archive"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		resolve_restore_archive "'"$archive"'" "'"$tmp"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$archive" ]]
	rm -rf "$tmp"
}

@test "resolve_restore_archive treats directory argument as backup dir" {
	local tmp outdir old new
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	old="$outdir/launchlayer-backup-20200101-000000.tar.gz"
	new="$outdir/launchlayer-backup-20240601-000000.tar.gz"
	touch -d '2020-01-01 00:00:00' "$old"
	touch -d '2024-06-01 00:00:00' "$new"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		resolve_restore_archive "'"$outdir"'" ""
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$new" ]]
	rm -rf "$tmp"
}

@test "resolve_restore_archive fails when no archives exist" {
	local tmp outdir
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		resolve_restore_archive "" "'"$outdir"'" 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"No launchlayer backup archives"* ]]
	rm -rf "$tmp"
}

@test "list_backups reports empty directory in json" {
	local tmp outdir
	tmp="$(mktemp -d)"
	outdir="$tmp/backups"
	mkdir -p "$outdir"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		list_backups "'"$outdir"'" 1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"count":0'* ]]
	[[ "$output" == *'"archives":[]'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["count"]==0 and d["archives"]==[]' "$output"
	rm -rf "$tmp"
}

@test "_filter_import_files_by_appid keeps only matching game config" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		files=(games/11111111.env launch.d/default.env games/42424242.env)
		_filter_import_files_by_appid 42424242 files
		printf "%s\n" "${files[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "games/42424242.env" ]]
}

@test "_filter_import_files_by_appid fails when game missing from archive" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		files=(games/11111111.env launch.d/default.env)
		_filter_import_files_by_appid 42424242 files
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Archive does not contain games/42424242.env"* ]]
}

@test "resolve_restore_filter_appid accepts numeric AppID" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		resolve_restore_filter_appid 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "42424242" ]]
}
