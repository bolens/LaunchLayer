# shellcheck shell=bash
# lib/setup/doctor.sh

# doctor_collect_json_issues — Print JSON array of structured doctor issues.
doctor_collect_json_issues() {
	local current=$1 required=$2 access=$3 config_issues=$4 validation_out=$5
	local -a objs=() line first=1
	if is_linux && [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
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

# doctor_issue_count — Return critical issue count without printing full doctor output.
doctor_issue_count() {
	local issues=0 config_issues=0 current required access
	local validation_out=""

	required="$(sysctl_required_value)"
	current="$(sysctl_current_value)"
	access="$(flatpak_script_access)"

	if is_linux && [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
		((issues++))
	fi
	if [[ "$access" == needs_override ]]; then
		((issues++))
	fi
	[[ -d "$LAUNCHD_DIR" ]] || ((issues++))

	validation_out="$(validate_config all 0 2>&1)" || config_issues=$?
	issues=$((issues + config_issues))
	printf '%s\n' "$issues"
}

# show_doctor — Full health check for a new or moved machine.
show_doctor() {
	local json=${1:-0} issues=0 config_issues=0 current required access
	local validation_out=""
	required="$(sysctl_required_value)"
	current="$(sysctl_current_value)"
	access="$(flatpak_script_access)"

	if is_linux && [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
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
		printf ',"package_manager":%s,"optional_tools":' "$(json_string "$(detect_package_manager)")"
		optional_tools_json_array
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
	print_detect_environment_body 2>/dev/null || true
	echo
	echo "-- Issues --"
	if is_linux && [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" -lt "$required" ]]; then
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
	completions_nu_status
	completions_pwsh_status
	echo "osh: uses bash completions (enable with --shell bash or --shell osh)"
	echo
	echo "-- Systemd --"
	systemd_user_status
	systemd_backup_status
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
