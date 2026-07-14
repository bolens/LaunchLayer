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

# doctor_print_gaming_tips — Non-critical CachyOS / Arch / upscaler / sched tips.
doctor_print_gaming_tips() {
	local cachyos_tool="" vendor
	vendor="$(detect_gpu_vendor 2>/dev/null || true)"

	echo "-- Gaming tips --"
	if [[ "${GAMEMODE:-1}" == "1" ]] && ananicy_cpp_active; then
		echo "tip: GameMode and ananicy-cpp both adjust process niceness — stop ananicy-cpp before using GameMode: systemctl stop ananicy-cpp"
		echo "  wiki: https://wiki.cachyos.org/configuration/gaming/#do-not-combine-gamemode-and-ananicy-cpp"
	fi

	if cachyos_tool="$(prefer_proton_cachyos 2>/dev/null)"; then
		echo "tip: Proton-CachyOS available ($cachyos_tool) — set OVERRIDE_PROTON=$cachyos_tool for PROTON_DLSS_UPGRADE / PROTON_FSR4_UPGRADE / PROTON_XESS_UPGRADE"
	fi

	if [[ "$vendor" == nvidia ]]; then
		if optional_tool_installed dlss-swapper; then
			echo "tip: DLSS via launch wrapper: DLSS_SWAPPER=1 (NGX updater) or DLSS_SWAPPER=dll (presets only after manual DLL replace)"
		fi
		if optional_tool_installed dlss-updater; then
			echo "tip: dlss-updater is installed (GUI only — no CLI). Use it offline to replace game DLLs; at launch prefer DLSS_SWAPPER or PROTON_DLSS_UPGRADE"
		elif [[ "$(detect_os_id 2>/dev/null || true)" == cachyos ]]; then
			echo "tip: optional GUI DLL updater: pacman -S dlss-updater (no launch CLI; pair with DLSS_SWAPPER for presets)"
		fi
	fi

	if [[ "${SHADER_CACHE_BOOST:-0}" != "1" ]]; then
		echo "tip: SHADER_CACHE_BOOST=1 raises Mesa/NVIDIA shader cache size limits (reduces recompile stutters)"
	fi

	if [[ "$vendor" == amd ]]; then
		echo "tip: AMD/RADV — optional per-game RADV_PERFTEST=… (e.g. sam,nggc) for some titles; start unset and test carefully"
		echo "  wiki: https://wiki.archlinux.org/title/Gaming#Improving_performance"
	fi

	if sched_ext_supported 2>/dev/null; then
		if sched_ext_loaded 2>/dev/null; then
			echo "tip: sched_ext active ($(sched_ext_ops_name 2>/dev/null || echo unknown)) — complements GameMode; avoid stacking with conflicting CPUfreq daemons"
		else
			echo "tip: kernel supports sched_ext — optional gaming schedulers: scx_lavd / scx_bpfland (Arch: pacman -S scx-scheds)"
			echo "  wiki: https://wiki.archlinux.org/title/sched_ext"
		fi
	fi

	if [[ "${LD_BIND_NOW:-0}" != "1" || "${DISABLE_VBLANK:-0}" != "1" \
		|| "${VKBASALT:-0}" != "1" || "${LATENCYFLEX:-0}" != "1" ]]; then
		echo "tip: Arch Gaming latency knobs: LD_BIND_NOW=1, DISABLE_VBLANK=1, VKBASALT=1 (vkBasalt), LATENCYFLEX=1 (LFX)"
		echo "  wiki: https://wiki.archlinux.org/title/Gaming"
	fi

	local os_id=""
	os_id="$(detect_os_id 2>/dev/null || true)"
	if [[ "$os_id" == bazzite ]] || is_immutable_os 2>/dev/null; then
		if [[ "${DISABLE_STEAM_DECK:-0}" != "1" ]]; then
			echo "tip: DISABLE_STEAM_DECK=1 exports SteamDeck=0 (Bazzite sd0) — unlocks full graphics menus on titles that force Deck limits"
			echo "  docs: https://docs.bazzite.gg/Gaming/launch-options-env-variables/"
		fi
		if [[ "$os_id" == bazzite ]] && [[ "$(detect_gpu_vendor 2>/dev/null || true)" == nvidia ]]; then
			echo "tip: Bazzite ships dlss-swapper — prefer DLSS_SWAPPER=1 over pasting the wrapper into Steam launch options"
		fi
		if [[ -z "${FRAME_RATE:-}" || "${FRAME_RATE}" == "0" ]]; then
			echo "tip: FRAME_RATE=N sets DXVK_FRAME_RATE/VKD3D_FRAME_RATE (lowest-latency API caps; restart to change)"
			echo "  docs: https://docs.bazzite.gg/Gaming/launch-options-env-variables/#frame-rate-limiting-issues-and-inconsistency"
		fi
	fi
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
		printf ',"ananicy_cpp_active":%s,"proton_cachyos":%s,"package_manager":%s,"optional_tools":' \
			"$(json_bool "$(ananicy_cpp_active && echo 1 || echo 0)")" \
			"$(json_string "$(prefer_proton_cachyos 2>/dev/null || true)")" \
			"$(json_string "$(detect_package_manager)")"
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
	doctor_print_gaming_tips
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
