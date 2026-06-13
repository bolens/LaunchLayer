#!/usr/bin/env bash
setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../helpers.bash"
	SCRIPT="$(launchlayer_script)"
	export REPO_ROOT="$(launchlayer_root)"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
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


@test "help mentions export and import" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--export-config"* ]]
	[[ "$output" == *"--import-config"* ]]
	[[ "$output" == *"--backup-config"* ]]
	[[ "$output" == *"--backup-timer"* ]]
	[[ "$output" == *"--backup-prefs"* ]]
	[[ "$output" == *"--tui-prefs"* ]]
	[[ "$output" == *"--prune-backups"* ]]
}


@test "prune-backups dry-run keeps newest archives" {
	local tmp backup_dir i
	tmp="$(mktemp -d)"
	backup_dir="$tmp/backups"
	mkdir -p "$backup_dir"
	for i in 1 2 3; do
		echo "backup$i" > "$backup_dir/launchlayer-backup-2026010${i}-12000${i}.tar.gz"
		sleep 0.01
	done
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --prune-backups --dir "$backup_dir" --keep 1 --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"would remove"* ]]
	[[ $(find "$backup_dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 3 ]]
	rm -rf "$tmp"
}


@test "prune-backups removes oldest archives" {
	local tmp backup_dir i
	tmp="$(mktemp -d)"
	backup_dir="$tmp/backups"
	mkdir -p "$backup_dir"
	for i in 1 2 3; do
		echo "backup$i" > "$backup_dir/launchlayer-backup-2026010${i}-12000${i}.tar.gz"
		sleep 0.01
	done
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --prune-backups --dir "$backup_dir" --keep 1
	[[ $status -eq 0 ]]
	[[ "$output" == *"removed=2"* ]]
	[[ $(find "$backup_dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 1 ]]
	rm -rf "$tmp"
}


@test "backup-timer install writes user units" {
	local tmp unit_dir
	tmp="$(mktemp -d)"
	unit_dir="$tmp/systemd/user"
	mkdir -p "$tmp/launch.d/presets"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer install --no-enable --dir "$tmp/backups" --keep 5
	[[ $status -eq 0 ]]
	[[ -f "$unit_dir/launchlayer-backup.service" ]]
	[[ -f "$unit_dir/launchlayer-backup.timer" ]]
	[[ -f "$tmp/launchlayer/backup.conf" ]]
	[[ "$output" == *"backup_dir: $tmp/backups"* ]]
	grep -q -- '--run-scheduled-backup' "$unit_dir/launchlayer-backup.service"
	grep -q 'OnCalendar=' "$unit_dir/launchlayer-backup.timer"
	rm -rf "$tmp"
}


@test "backup prefs persist custom schedule" {
	local tmp unit_dir
	tmp="$(mktemp -d)"
	unit_dir="$tmp/systemd/user"
	mkdir -p "$tmp/launch.d/presets"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer install --no-enable --schedule 'Mon..Fri *-*-* 04:00:00'
	[[ $status -eq 0 ]]
	grep -q 'OnCalendar=Mon..Fri \*-\*-\* 04:00:00' "$unit_dir/launchlayer-backup.timer"
	grep -q 'on_calendar=Mon..Fri \*-\*-\* 04:00:00' "$tmp/launchlayer/backup.conf"
	rm -rf "$tmp"
}


@test "backup prefs interval schedule writes OnUnitActiveSec" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/systemd/user" "$tmp/launchlayer"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	cat > "$tmp/launchlayer/backup.conf" <<'EOF'
backup_dir=/tmp/backups
keep=3
timer_type=interval
on_calendar=*-*-* 03:15:00
on_boot_sec=10min
on_unit_active_sec=6h
randomized_delay_sec=0
include_local=1
include_profiles=1
include_tui=0
EOF
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer install --no-enable
	[[ $status -eq 0 ]]
	grep -q 'OnUnitActiveSec=6h' "$tmp/systemd/user/launchlayer-backup.timer"
	grep -q 'OnBootSec=10min' "$tmp/systemd/user/launchlayer-backup.timer"
	rm -rf "$tmp"
}


@test "backup-timer status reports not installed" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" "$SCRIPT" --backup-timer status
	[[ $status -eq 0 ]]
	[[ "$output" == *"not installed"* ]]
	rm -rf "$tmp"
}


@test "backup-prefs reset restores repo defaults" {
	local tmp example
	tmp="$(mktemp -d)"
	example="$tmp/share/launchlayer/templates/backup.conf.example"
	mkdir -p "$(dirname "$example")"
	cat > "$example" <<'EOF'
backup_dir=$HOME/custom-backups
keep=3
timer_type=interval
on_calendar=*-*-* 04:00:00
on_boot_sec=5min
on_unit_active_sec=6h
randomized_delay_sec=0
include_local=0
include_profiles=1
include_tui=1
EOF
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/backup.conf" <<'EOF'
backup_dir=$HOME/wrong
keep=99
timer_type=calendar
on_calendar=*-*-* 01:00:00
on_boot_sec=1min
on_unit_active_sec=1h
randomized_delay_sec=999
include_local=1
include_profiles=0
include_tui=0
EOF
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-prefs reset
	[[ $status -eq 0 ]]
	[[ "$output" == *"Reset backup preferences"* ]]
	grep -q 'keep=3' "$tmp/launchlayer/backup.conf"
	grep -q 'timer_type=interval' "$tmp/launchlayer/backup.conf"
	rm -rf "$tmp"
}


@test "tui-prefs reset restores repo defaults" {
	local tmp example
	tmp="$(mktemp -d)"
	example="$tmp/share/launchlayer/templates/tui.conf.example"
	mkdir -p "$(dirname "$example")"
	cat > "$example" <<'EOF'
game_filter=configured
cache_min_gb=10
default_preset=competitive
fzf_height=50%
fzf_preview=down:40%:wrap
EOF
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/tui.conf" <<'EOF'
game_filter=all
cache_min_gb=1
default_preset=lightweight
fzf_height=20%
fzf_preview=left:30%:wrap
EOF
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		"$SCRIPT" --tui-prefs reset
	[[ $status -eq 0 ]]
	[[ "$output" == *"Reset TUI preferences"* ]]
	grep -q 'game_filter=configured' "$tmp/launchlayer/tui.conf"
	grep -q 'default_preset=competitive' "$tmp/launchlayer/tui.conf"
	rm -rf "$tmp"
}


@test "prune-backups keep=0 retains all archives" {
	local tmp backup_dir i
	tmp="$(mktemp -d)"
	backup_dir="$tmp/backups"
	mkdir -p "$backup_dir"
	for i in 1 2 3; do
		echo "backup$i" > "$backup_dir/launchlayer-backup-2026010${i}-12000${i}.tar.gz"
	done
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --prune-backups --dir "$backup_dir" --keep 0
	[[ $status -eq 0 ]]
	[[ "$output" == *"unlimited retention"* ]]
	[[ $(find "$backup_dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 3 ]]
	rm -rf "$tmp"
}


@test "run-scheduled-backup skips prune when auto_prune=0" {
	local tmp backup_dir
	tmp="$(mktemp -d)"
	backup_dir="$tmp/backups"
	mkdir -p "$tmp/launch.d/presets" "$backup_dir"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	echo "old" > "$backup_dir/launchlayer-backup-20260101-120001.tar.gz"
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/backup.conf" <<EOF
backup_dir=$backup_dir
keep=1
auto_prune=0
timer_type=calendar
on_calendar=*-*-* 03:15:00
on_boot_sec=15min
on_unit_active_sec=12h
randomized_delay_sec=1800
include_local=0
include_profiles=1
include_tui=0
EOF
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --run-scheduled-backup
	[[ $status -eq 0 ]]
	[[ "$output" == *"Skipping prune"* ]]
	[[ $(find "$backup_dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 2 ]]
	rm -rf "$tmp"
}


@test "run-scheduled-backup prunes using live backup.conf keep" {
	local tmp backup_dir i
	tmp="$(mktemp -d)"
	backup_dir="$tmp/backups"
	mkdir -p "$tmp/launch.d/presets" "$backup_dir"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	for i in 1 2; do
		echo "backup$i" > "$backup_dir/launchlayer-backup-2026010${i}-12000${i}.tar.gz"
	done
	mkdir -p "$tmp/launchlayer"
	cat > "$tmp/launchlayer/backup.conf" <<EOF
backup_dir=$backup_dir
keep=1
auto_prune=1
timer_type=calendar
on_calendar=*-*-* 03:15:00
on_boot_sec=15min
on_unit_active_sec=12h
randomized_delay_sec=1800
include_local=0
include_profiles=1
include_tui=0
EOF
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --run-scheduled-backup
	[[ $status -eq 0 ]]
	[[ "$output" == *"removed="* ]]
	[[ $(find "$backup_dir" -maxdepth 1 -name 'launchlayer-backup-*.tar.gz' | wc -l) -eq 1 ]]
	rm -rf "$tmp"
}


@test "backup-prefs show reports prune policy" {
	local tmp
	tmp="$(mktemp -d)"
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-prefs show
	[[ $status -eq 0 ]]
	[[ "$output" == *"auto_prune"* ]]
	[[ "$output" == *"prune_policy"* ]]
	rm -rf "$tmp"
}


@test "backup.conf.example contains all backup preference keys" {
	local example="$REPO_ROOT/share/launchlayer/templates/backup.conf.example"
	[[ -f "$example" ]]
	local key
	for key in backup_dir keep timer_type on_calendar on_boot_sec on_unit_active_sec \
		randomized_delay_sec include_local include_profiles include_tui auto_prune; do
		grep -q "^${key}=" "$example"
	done
}


@test "tui.conf.example contains all TUI preference keys" {
	local example="$REPO_ROOT/share/launchlayer/templates/tui.conf.example"
	[[ -f "$example" ]]
	local key
	for key in game_filter cache_min_gb default_preset last_menu json_output \
		resume_last_menu press_enter_lines fzf_height fzf_preview; do
		grep -q "^${key}=" "$example"
	done
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

