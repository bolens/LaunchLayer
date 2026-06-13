# shellcheck shell=bash
# lib/prefs/backup.sh — Backup timer preferences and --backup-prefs helpers.
# _backup_prefs_set_defaults — Initialize backup preference globals (hardcoded fallback).
_backup_prefs_set_defaults() {
	BACKUP_PREFS_DIR="${BACKUP_PREFS_DIR:-$(default_systemd_backup_dir)}"
	BACKUP_PREFS_KEEP="${BACKUP_PREFS_KEEP:-7}"
	BACKUP_PREFS_TIMER_TYPE="${BACKUP_PREFS_TIMER_TYPE:-calendar}"
	BACKUP_PREFS_ON_CALENDAR="${BACKUP_PREFS_ON_CALENDAR:-*-*-* 03:15:00}"
	BACKUP_PREFS_ON_BOOT_SEC="${BACKUP_PREFS_ON_BOOT_SEC:-15min}"
	BACKUP_PREFS_ON_UNIT_ACTIVE_SEC="${BACKUP_PREFS_ON_UNIT_ACTIVE_SEC:-12h}"
	BACKUP_PREFS_RANDOMIZED_DELAY_SEC="${BACKUP_PREFS_RANDOMIZED_DELAY_SEC:-1800}"
	BACKUP_PREFS_INCLUDE_LOCAL="${BACKUP_PREFS_INCLUDE_LOCAL:-1}"
	BACKUP_PREFS_INCLUDE_PROFILES="${BACKUP_PREFS_INCLUDE_PROFILES:-1}"
	BACKUP_PREFS_INCLUDE_TUI="${BACKUP_PREFS_INCLUDE_TUI:-0}"
	BACKUP_PREFS_AUTO_PRUNE="${BACKUP_PREFS_AUTO_PRUNE:-1}"
}

# _backup_prefs_expand_path — Expand leading ~ and \$HOME in a path.
_backup_prefs_expand_path() {
	local path=$1
	case "$path" in
		"~") printf '%s\n' "$HOME" ;;
		"~"/*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
		\$HOME/*) printf '%s/%s\n' "$HOME" "${path#\$HOME/}" ;;
		*) printf '%s\n' "$path" ;;
	esac
}

# _backup_prefs_parse_file — Parse backup.conf lines into BACKUP_PREFS_* globals.
_backup_prefs_parse_file() {
	local file=$1
	local line key val
	[[ -f "$file" ]] || return 1
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		key="${key#"${key%%[![:space:]]*}"}"
		val="${line#*=}"
		val="${val#"${val%%[![:space:]]*}"}"
		val="${val%"${val##*[![:space:]]}"}"
		case "$key" in
			backup_dir) BACKUP_PREFS_DIR="$(_backup_prefs_expand_path "$val")" ;;
			keep) BACKUP_PREFS_KEEP=$val ;;
			timer_type) BACKUP_PREFS_TIMER_TYPE=$val ;;
			on_calendar) BACKUP_PREFS_ON_CALENDAR=$val ;;
			on_boot_sec) BACKUP_PREFS_ON_BOOT_SEC=$val ;;
			on_unit_active_sec) BACKUP_PREFS_ON_UNIT_ACTIVE_SEC=$val ;;
			randomized_delay_sec) BACKUP_PREFS_RANDOMIZED_DELAY_SEC=$val ;;
			include_local) BACKUP_PREFS_INCLUDE_LOCAL=$val ;;
			include_profiles) BACKUP_PREFS_INCLUDE_PROFILES=$val ;;
			include_tui) BACKUP_PREFS_INCLUDE_TUI=$val ;;
			auto_prune|prune) BACKUP_PREFS_AUTO_PRUNE=$val ;;
		esac
	done < "$file"
	return 0
}

# load_backup_prefs — Load saved backup preferences (defaults when missing).
load_backup_prefs() {
	_backup_prefs_set_defaults
	_backup_prefs_parse_file "$(backup_prefs_path)" || \
		_backup_prefs_parse_file "$(backup_prefs_example_path)" || true
	return 0
}

# save_backup_prefs — Persist backup preferences to the user config dir.
save_backup_prefs() {
	local file dir example
	_backup_prefs_set_defaults
	file="$(backup_prefs_path)"
	dir="$(dirname "$file")"
	example="$(backup_prefs_example_path)"
	mkdir -p "$dir"
	{
		echo "# LaunchLayer backup preferences"
		[[ -f "$example" ]] && echo "# Defaults: $example"
		if [[ "$BACKUP_PREFS_DIR" == "$HOME"/* ]]; then
			echo "backup_dir=\$HOME/${BACKUP_PREFS_DIR#"$HOME/"}"
		else
			echo "backup_dir=${BACKUP_PREFS_DIR}"
		fi
		cat <<EOF
keep=${BACKUP_PREFS_KEEP}
timer_type=${BACKUP_PREFS_TIMER_TYPE}
on_calendar=${BACKUP_PREFS_ON_CALENDAR}
on_boot_sec=${BACKUP_PREFS_ON_BOOT_SEC}
on_unit_active_sec=${BACKUP_PREFS_ON_UNIT_ACTIVE_SEC}
randomized_delay_sec=${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}
include_local=${BACKUP_PREFS_INCLUDE_LOCAL}
include_profiles=${BACKUP_PREFS_INCLUDE_PROFILES}
include_tui=${BACKUP_PREFS_INCLUDE_TUI}
auto_prune=${BACKUP_PREFS_AUTO_PRUNE}
EOF
	} > "$file"
}

# reset_backup_prefs — Restore backup.conf from the repo example template.
reset_backup_prefs() {
	local example user_file
	example="$(backup_prefs_example_path)"
	user_file="$(backup_prefs_path)"
	if [[ ! -f "$example" ]]; then
		echo "Missing backup template: $example" >&2
		return 1
	fi
	mkdir -p "$(dirname "$user_file")"
	cp "$example" "$user_file"
	load_backup_prefs
	echo "Reset backup preferences to defaults ($user_file)"
}

# backup_prefs_schedule_summary — Human-readable schedule label for menus/status.
backup_prefs_schedule_summary() {
	load_backup_prefs
	case "$BACKUP_PREFS_TIMER_TYPE" in
		calendar) printf 'calendar %s' "$BACKUP_PREFS_ON_CALENDAR" ;;
		interval) printf 'every %s (boot %s)' "$BACKUP_PREFS_ON_UNIT_ACTIVE_SEC" "$BACKUP_PREFS_ON_BOOT_SEC" ;;
		*) printf '%s' "$BACKUP_PREFS_TIMER_TYPE" ;;
	esac
}

# backup_prefs_apply_env — Export LAUNCHLAYER_BACKUP_* from saved preferences.
backup_prefs_apply_env() {
	load_backup_prefs
	: "${LAUNCHLAYER_BACKUP_DIR:=${BACKUP_PREFS_DIR}}"
	: "${LAUNCHLAYER_BACKUP_KEEP:=${BACKUP_PREFS_KEEP}}"
	export LAUNCHLAYER_BACKUP_DIR LAUNCHLAYER_BACKUP_KEEP
}

# backup_prefs_set_schedule_daily — Configure daily calendar timer at HH:MM.
backup_prefs_set_schedule_daily() {
	local time=${1:-03:15}
	[[ "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]] || return 1
	BACKUP_PREFS_TIMER_TYPE=calendar
	BACKUP_PREFS_ON_CALENDAR="*-*-* ${time}:00"
}

# backup_prefs_set_schedule_weekly — Configure weekly calendar timer.
backup_prefs_set_schedule_weekly() {
	local weekday=${1:-Sun} time=${2:-03:15}
	[[ "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]] || return 1
	BACKUP_PREFS_TIMER_TYPE=calendar
	BACKUP_PREFS_ON_CALENDAR="${weekday} *-*-* ${time}:00"
}

# backup_prefs_set_schedule_interval — Configure interval timer (e.g. 12h).
backup_prefs_set_schedule_interval() {
	local interval=${1:-12h} boot=${2:-15min}
	BACKUP_PREFS_TIMER_TYPE=interval
	BACKUP_PREFS_ON_UNIT_ACTIVE_SEC=$interval
	BACKUP_PREFS_ON_BOOT_SEC=$boot
}

# backup_prefs_set_schedule_custom — Configure raw systemd OnCalendar expression.
backup_prefs_set_schedule_custom() {
	local calendar=$1
	[[ -n "$calendar" ]] || return 1
	BACKUP_PREFS_TIMER_TYPE=calendar
	BACKUP_PREFS_ON_CALENDAR=$calendar
}

# backup_prune_summary — Human-readable pruning policy for menus/status.
backup_prune_summary() {
	load_backup_prefs
	if [[ "${BACKUP_PREFS_AUTO_PRUNE}" != "1" ]]; then
		printf 'disabled (auto_prune=0)'
	elif [[ "${BACKUP_PREFS_KEEP}" == "0" ]]; then
		printf 'unlimited retention (keep=0)'
	else
		printf 'keep newest %s after backup' "${BACKUP_PREFS_KEEP}"
	fi
}

# backup_prefs_set_key — Set a single backup preference by key name.
backup_prefs_set_key() {
	local key=$1 val=$2
	load_backup_prefs
	case "$key" in
		backup_dir|dir) BACKUP_PREFS_DIR="$(_backup_prefs_expand_path "$val")" ;;
		keep)
			[[ "$val" =~ ^[0-9]+$ ]] || {
				echo "keep must be a non-negative integer (0=unlimited retention)" >&2
				return 1
			}
			BACKUP_PREFS_KEEP=$val
			;;
		randomized_delay_sec|delay) BACKUP_PREFS_RANDOMIZED_DELAY_SEC=$val ;;
		include_local)
			[[ "$val" == "0" || "$val" == "1" ]] || return 1
			BACKUP_PREFS_INCLUDE_LOCAL=$val
			;;
		include_profiles)
			[[ "$val" == "0" || "$val" == "1" ]] || return 1
			BACKUP_PREFS_INCLUDE_PROFILES=$val
			;;
		include_tui)
			[[ "$val" == "0" || "$val" == "1" ]] || return 1
			BACKUP_PREFS_INCLUDE_TUI=$val
			;;
		auto_prune|prune)
			[[ "$val" == "0" || "$val" == "1" ]] || {
				echo "auto_prune must be 0 or 1" >&2
				return 1
			}
			BACKUP_PREFS_AUTO_PRUNE=$val
			;;
		*) echo "Unknown backup preference key: $key" >&2; return 1 ;;
	esac
}

# show_backup_prefs — Print current backup preferences.
show_backup_prefs() {
	local json=${1:-0}
	load_backup_prefs
	if [[ "$json" == "1" ]]; then
		printf '{"path":%s,"example":%s,"backup_dir":%s,"keep":%s,"auto_prune":%s,"prune_policy":%s,"timer_type":%s,"on_calendar":%s,"on_boot_sec":%s,"on_unit_active_sec":%s,"randomized_delay_sec":%s,"include_local":%s,"include_profiles":%s,"include_tui":%s,"schedule":%s}\n' \
			"$(json_string "$(backup_prefs_path)")" \
			"$(json_string "$(backup_prefs_example_path)")" \
			"$(json_string "$BACKUP_PREFS_DIR")" \
			"$BACKUP_PREFS_KEEP" \
			"$(json_bool "$([[ "$BACKUP_PREFS_AUTO_PRUNE" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_string "$(backup_prune_summary)")" \
			"$(json_string "$BACKUP_PREFS_TIMER_TYPE")" \
			"$(json_string "$BACKUP_PREFS_ON_CALENDAR")" \
			"$(json_string "$BACKUP_PREFS_ON_BOOT_SEC")" \
			"$(json_string "$BACKUP_PREFS_ON_UNIT_ACTIVE_SEC")" \
			"$BACKUP_PREFS_RANDOMIZED_DELAY_SEC" \
			"$(json_bool "$([[ "$BACKUP_PREFS_INCLUDE_LOCAL" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$BACKUP_PREFS_INCLUDE_PROFILES" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_bool "$([[ "$BACKUP_PREFS_INCLUDE_TUI" == "1" ]] && echo 1 || echo 0)")" \
			"$(json_string "$(backup_prefs_schedule_summary)")"
		return 0
	fi
	echo "=== Backup preferences ==="
	echo "path=$(backup_prefs_path)"
	echo "example=$(backup_prefs_example_path)"
	echo "backup_dir=${BACKUP_PREFS_DIR}"
	echo "keep=${BACKUP_PREFS_KEEP} (0=unlimited retention)"
	echo "auto_prune=${BACKUP_PREFS_AUTO_PRUNE}"
	echo "prune_policy=$(backup_prune_summary)"
	echo "schedule=$(backup_prefs_schedule_summary)"
	echo "randomized_delay_sec=${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}"
	echo "include_local=${BACKUP_PREFS_INCLUDE_LOCAL}"
	echo "include_profiles=${BACKUP_PREFS_INCLUDE_PROFILES}"
	echo "include_tui=${BACKUP_PREFS_INCLUDE_TUI}"
}
