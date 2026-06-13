#!/usr/bin/env bash
# Integration tests for scheduled backups and backup preferences.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

teardown() {
	bats_integration_teardown
}

@test "help mentions export and import" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--export-config"* ]]
	[[ "$output" == *"--import-config"* ]]
	[[ "$output" == *"--restore-backup"* ]]
	[[ "$output" == *"--backup-config"* ]]
	[[ "$output" == *"--backup-timer"* ]]
	[[ "$output" == *"--backup-prefs"* ]]
	[[ "$output" == *"--tui-prefs"* ]]
	[[ "$output" == *"--prune-backups"* ]]
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
	run grep OnCalendar= "$unit_dir/launchlayer-backup.timer"
	[[ "$output" == *"Mon..Fri"* ]]
	run grep on_calendar= "$tmp/launchlayer/backup.conf"
	[[ "$output" == *"Mon..Fri"* ]]
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
	run grep OnUnitActiveSec= "$tmp/systemd/user/launchlayer-backup.timer"
	[[ "$output" == *"OnUnitActiveSec=6h"* ]]
	run grep OnBootSec= "$tmp/systemd/user/launchlayer-backup.timer"
	[[ "$output" == *"OnBootSec=10min"* ]]
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

@test "backup-timer uninstall removes user units" {
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
		"$SCRIPT" --backup-timer install --no-enable
	[[ $status -eq 0 ]]
	[[ -f "$unit_dir/launchlayer-backup.service" ]]
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer uninstall
	[[ $status -eq 0 ]]
	[[ ! -f "$unit_dir/launchlayer-backup.service" ]]
	[[ ! -f "$unit_dir/launchlayer-backup.timer" ]]
	[[ "$output" == *"Removed launchlayer-backup"* ]]
	rm -rf "$tmp"
}

@test "backup-timer enable-service toggles oneshot unit" {
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
		"$SCRIPT" --backup-timer install --no-enable
	[[ $status -eq 0 ]]
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer enable-service
	[[ $status -eq 0 ]]
	[[ "$output" == *"Enabled launchlayer-backup.service"* ]]
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --backup-timer disable-service
	[[ $status -eq 0 ]]
	[[ "$output" == *"Disabled launchlayer-backup.service"* ]]
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
