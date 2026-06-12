# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=platform.sh
# shellcheck source=completions.sh
# lib/setup.sh — Doctor, onboarding setup, systemd, and sysctl helpers.

[[ -n "${LAUNCHLAYER_SETUP_LOADED:-}" ]] && return 0
LAUNCHLAYER_SETUP_LOADED=1

# sysctl_required_value — Target vm.max_map_count for Proton stability.
sysctl_required_value() {
	echo "$LAUNCHLAYER_VM_MAX_MAP_COUNT_DEFAULT"
}

# sysctl_current_value — Read current vm.max_map_count or empty.
sysctl_current_value() {
	sysctl -n vm.max_map_count 2>/dev/null || true
}

# sysctl_status — Print vm.max_map_count state.
sysctl_status() {
	local current required installed
	current="$(sysctl_current_value)"
	required="$(sysctl_required_value)"
	installed=no
	[[ -f /etc/sysctl.d/elasticsearch.conf ]] && installed=yes
	echo "vm.max_map_count=${current:-unknown} (required >= $required)"
	echo "elasticsearch.conf installed: $installed"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		echo "action: run '$LAUNCHLAYER_MAIN_SCRIPT --sysctl install' as root"
	fi
}

# sysctl_install — Install elasticsearch.conf when run as root.
sysctl_install() {
	local src dest
	if [[ $EUID -ne 0 ]]; then
		echo "Run as root: sudo $LAUNCHLAYER_MAIN_SCRIPT --sysctl install" >&2
		return 1
	fi
	src="$CONFIG_DIR/elasticsearch.conf"
	dest="/etc/sysctl.d/elasticsearch.conf"
	[[ -f "$src" ]] || {
		echo "Missing $src" >&2
		return 1
	}
	if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
		echo "Already installed: $dest"
	else
		install -Dm644 "$src" "$dest"
		echo "Installed $dest"
	fi
	sysctl --system >/dev/null 2>&1 || sysctl -p "$dest" >/dev/null 2>&1 || true
	sysctl_status
}

# handle_sysctl_subcommand — Dispatch --sysctl status|install.
handle_sysctl_subcommand() {
	local action=${1:-status}
	case "$action" in
		status) sysctl_status ;;
		install) sysctl_install ;;
		*)
			echo "Usage: $0 --sysctl [status|install]" >&2
			return 1
			;;
	esac
}

# systemd_user_dir — User systemd unit directory.
systemd_user_dir() {
	echo "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
}

# install_systemd_user_units — Write maintenance timer/service with resolved script path.
install_systemd_user_units() {
	local unit_dir script service timer
	unit_dir="$(systemd_user_dir)"
	script="${LAUNCHLAYER_MAIN_SCRIPT:?}"
	mkdir -p "$unit_dir"
	service="$unit_dir/launchlayer-maintenance.service"
	timer="$unit_dir/launchlayer-maintenance.timer"

	cat > "$service" <<EOF
# Managed by launchlayer — safe to remove manually.
[Unit]
Description=Steam launch maintenance (stale cleanup + cache report)

[Service]
Type=oneshot
ExecStart=/bin/bash -c '${script} --cleanup-stale-launch 2>/dev/null || true; ${script} --cache-report --min-gb 10 2>/dev/null | logger -t launchlayer-maintenance || true'
EOF

	if [[ -f "$CONFIG_DIR/systemd/launchlayer-maintenance.timer" ]]; then
		install -Dm644 "$CONFIG_DIR/systemd/launchlayer-maintenance.timer" "$timer"
	else
		cat > "$timer" <<EOF
[Unit]
Description=Periodic launchlayer maintenance

[Timer]
OnBootSec=15min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF
	fi

	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user daemon-reload
		systemctl --user enable --now launchlayer-maintenance.timer 2>/dev/null \
			&& echo "Enabled launchlayer-maintenance.timer" \
			|| echo "Wrote units to $unit_dir (enable manually with systemctl --user enable --now launchlayer-maintenance.timer)"
	else
		echo "Wrote units to $unit_dir"
	fi
	echo "  service: $service"
	echo "  timer:   $timer"
}

# systemd_user_status — Report whether maintenance timer is installed.
systemd_user_status() {
	local unit_dir service timer
	unit_dir="$(systemd_user_dir)"
	service="$unit_dir/launchlayer-maintenance.service"
	timer="$unit_dir/launchlayer-maintenance.timer"
	if [[ -f "$service" && -f "$timer" ]]; then
		if command -v systemctl >/dev/null 2>&1 \
			&& systemctl --user is-enabled launchlayer-maintenance.timer >/dev/null 2>&1; then
			echo "systemd: enabled (launchlayer-maintenance.timer)"
		else
			echo "systemd: installed but timer not enabled ($timer)"
		fi
		grep -qF "$LAUNCHLAYER_MAIN_SCRIPT" "$service" 2>/dev/null \
			&& echo "systemd: script path current" \
			|| echo "systemd: script path stale — re-run --install-systemd"
	else
		echo "systemd: not installed (run --install-systemd)"
	fi
}

# print_steam_launch_option — Steam launch options string for this install.
print_steam_launch_option() {
	printf '"%s" %%command%%\n' "$LAUNCHLAYER_MAIN_SCRIPT"
}

# remove_legacy_cli_symlink — Drop pre-rename ~/.local/bin/steaml when we own it.
remove_legacy_cli_symlink() {
	local bindir old_link target
	bindir="${XDG_BIN_HOME:-${HOME}/.local/bin}"
	old_link="$bindir/steaml"
	[[ -L "$old_link" ]] || return 0
	target="$(realpath_portable "$old_link" 2>/dev/null || readlink "$old_link" 2>/dev/null || true)"
	if [[ -n "$target" && ( "$target" == "$LAUNCHLAYER_MAIN_SCRIPT" || "$target" == *steam-game-launch-settings* ) ]]; then
		rm -f "$old_link"
		echo "Removed legacy symlink: $old_link"
	fi
}

# install_cli_symlink — Install ~/.local/bin/launchlayer → main script.
install_cli_symlink() {
	local bindir link
	bindir="${XDG_BIN_HOME:-${HOME}/.local/bin}"
	link="$bindir/launchlayer"
	mkdir -p "$bindir"
	remove_legacy_cli_symlink
	if [[ -e "$link" && ! -L "$link" ]]; then
		echo "Refusing to replace existing file: $link" >&2
		return 1
	fi
	ln -sfn "$LAUNCHLAYER_MAIN_SCRIPT" "$link"
	echo "Linked $link -> $LAUNCHLAYER_MAIN_SCRIPT"
	echo "Ensure $bindir is on your PATH, then run: launchlayer --help"
}

# doctor_collect_json_issues — Print JSON array of structured doctor issues.
doctor_collect_json_issues() {
	local current=$1 required=$2 access=$3 config_issues=$4 validation_out=$5
	local -a objs=() line first=1
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		objs+=("$(printf '{"code":"vm_max_map_count","severity":"error","message":%s}' \
			"$(json_string "vm.max_map_count=$current (< $required)")")")
	fi
	if [[ "$access" == needs_override ]]; then
		objs+=("$(printf '{"code":"flatpak_script_access","severity":"error","message":%s}' \
			"$(json_string "Flatpak Steam may not reach script path — $(flatpak_override_hint)")")")
	fi
	[[ -d "$LAUNCHD_DIR" ]] || objs+=("$(printf '{"code":"missing_launch_d","severity":"error","message":%s}' \
		"$(json_string "missing $LAUNCHD_DIR")")")
	if (( config_issues > 0 )); then
		while IFS= read -r line; do
			[[ -n "$line" ]] || continue
			[[ "$line" == Validation* ]] && continue
			objs+=("$(printf '{"code":"config_validation","severity":"error","message":%s}' \
				"$(json_string "$line")")")
		done <<< "$validation_out"
	fi
	printf '['
	for line in "${objs[@]}"; do
		(( first )) || printf ','
		first=0
		printf '%s' "$line"
	done
	printf ']'
}

# show_doctor — Full health check for a new or moved machine.
show_doctor() {
	local json=${1:-0} issues=0 config_issues=0 current required access
	local validation_out=""
	required="$(sysctl_required_value)"
	current="$(sysctl_current_value)"
	access="$(flatpak_script_access)"

	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		((issues++))
	fi
	if [[ "$access" == needs_override ]]; then
		((issues++))
	fi
	[[ -d "$LAUNCHD_DIR" ]] || ((issues++))

	validation_out="$(validate_config all 0 2>&1)" || config_issues=$?
	issues=$((issues + config_issues))

	if [[ "$json" == "1" ]]; then
		printf '{"config_dir":%s,"script":%s,"steam_root":%s,"profiles":%s,"gpu_vendor":%s,"desktop":%s,"audio":%s,"wsl2":%s,"flatpak_steam":%s,"flatpak_script_access":%s,"systemd_user":%s,"vm_max_map_count":%s,"vm_max_map_count_required":%s,"config_validation_issues":%s,"issue_count":%s,"issues":' \
			"$(json_string "$CONFIG_DIR")" \
			"$(json_string "$LAUNCHLAYER_MAIN_SCRIPT")" \
			"$(json_string "$STEAM_ROOT")" \
			"$(json_string "$(detect_default_profiles 2>/dev/null || true)")" \
			"$(json_string "$(detect_gpu_vendor)")" \
			"$(json_string "$(detect_desktop_session)")" \
			"$(json_string "$(detect_audio_server)")" \
			"$(json_bool "$(is_wsl2 && echo 1 || echo 0)")" \
			"$(json_bool "$(is_flatpak_steam && echo 1 || echo 0)")" \
			"$(json_string "$access")" \
			"$(json_bool "$(has_systemd_user && echo 1 || echo 0)")" \
			"$(json_number_or_string "${current:-unknown}")" \
			"$required" \
			"$config_issues" \
			"$issues"
		doctor_collect_json_issues "$current" "$required" "$access" "$config_issues" "$validation_out"
		printf '}\n'
		(( issues == 0 )) || return 1
		return 0
	fi

	echo "=== launchlayer doctor ==="
	echo "config_dir=$CONFIG_DIR"
	echo "script=$LAUNCHLAYER_MAIN_SCRIPT"
	echo "steam_root=$STEAM_ROOT"
	echo "profiles=$(detect_default_profiles 2>/dev/null || echo none)"
	echo "gpu_vendor=$(detect_gpu_vendor) desktop=$(detect_desktop_session) audio=$(detect_audio_server)"
	echo "wsl2=$(is_wsl2 && echo yes || echo no) container=$(is_container && echo yes || echo no)"
	echo "flatpak_steam=$(is_flatpak_steam && echo yes || echo no) script_access=$access"
	[[ "$access" == needs_override ]] && echo "  hint: $(flatpak_override_hint)"
	echo
	echo "-- Environment --"
	show_detect_environment 2>/dev/null | tail -n +2 || true
	echo
	echo "-- Issues --"
	if [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		echo "issue: vm.max_map_count=$current (< $required)"
	fi
	if [[ "$access" == needs_override ]]; then
		echo "issue: Flatpak Steam may not reach script path — $(flatpak_override_hint)"
	fi
	[[ -d "$LAUNCHD_DIR" ]] || echo "issue: missing $LAUNCHD_DIR"
	(( issues == 0 )) && echo "(none)"
	echo
	echo "-- Config validation --"
	echo "$validation_out"
	echo
	echo "-- Completions --"
	completions_bash_status
	completions_zsh_status
	completions_fish_status
	echo
	echo "-- Systemd --"
	systemd_user_status
	echo
	sysctl_status
	echo
	if (( issues == 0 )); then
		echo "Doctor: no critical issues found."
	else
		echo "Doctor: $issues issue(s) reported."
	fi
	echo
	echo "Steam launch option:"
	print_steam_launch_option
	(( issues == 0 )) || return 1
}

# run_setup — Onboarding helper (non-destructive optional steps).
run_setup() {
	local do_completions=0 do_systemd=0 print_launch=0 do_symlink=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--completions) do_completions=1; shift ;;
			--systemd) do_systemd=1; shift ;;
			--symlink) do_symlink=1; shift ;;
			--print-launch-option) print_launch=1; shift ;;
			*)
				echo "Usage: $0 --setup [--completions] [--systemd] [--symlink] [--print-launch-option]" >&2
				return 1
				;;
		esac
	done
	(( do_completions || do_systemd || print_launch || do_symlink )) || {
		do_completions=1
		print_launch=1
	}

	echo "=== launchlayer setup ==="
	echo "config_dir=$CONFIG_DIR"
	echo
	if (( do_completions )); then
		completions_enable "$(detect_login_shell_name)"
	fi
	if (( do_symlink )); then
		install_cli_symlink
	fi
	if (( do_systemd )); then
		install_systemd_user_units
	fi
	if (( print_launch )); then
		echo
		echo "Add to Steam Launch Options:"
		print_steam_launch_option
	fi
	echo
	echo "Run '$LAUNCHLAYER_MAIN_SCRIPT --doctor' to verify."
}
