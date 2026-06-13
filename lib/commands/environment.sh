# shellcheck shell=bash
# lib/commands/environment.sh
# tool_available — Print yes/no for an optional dependency.
tool_available() {
	optional_tool_installed "$1" && echo yes || echo no
}

# env_report_row — One aligned label/value line for environment reports.
env_report_row() {
	local label=$1
	shift
	printf '  '
	cli_dim "$label"
	printf ': %s\n' "$*"
}

# env_report_tools_row — Tool availability with checkmarks for installed tools.
env_report_tools_row() {
	local -a tools=("$@")
	local tool line="" part
	local -a lines=()
	local count=0

	for tool in "${tools[@]}"; do
		if optional_tool_installed "$tool"; then
			part="$(printf '%s %s' "$(cli_green ✓)" "$tool")"
		else
			part="$(printf '%s %s' "$(cli_dim ·)" "$(cli_dim "$tool")")"
		fi
		if [[ -z "$line" ]]; then
			line="$part"
		else
			line+="  $part"
		fi
		(( count++ ))
		if (( count % 4 == 0 )); then
			lines+=("$line")
			line=""
		fi
	done
	[[ -n "$line" ]] && lines+=("$line")
	for line in "${lines[@]}"; do
		printf '  %s\n' "$line"
	done
}

# optional_tools_json_array — JSON array of optional tool status objects.
optional_tools_json_array() {
	local tool first=1 installed hint
	printf '['
	for tool in "${LAUNCHLAYER_OPTIONAL_TOOLS[@]}"; do
		optional_tool_relevant "$tool" || continue
		(( first )) || printf ','
		first=0
		if optional_tool_installed "$tool"; then
			installed=true
			hint=""
		else
			installed=false
			hint="$(tool_install_hint "$tool" 2>/dev/null || true)"
		fi
		printf '{"name":%s,"installed":%s,"install_hint":%s}' \
			"$(json_string "$tool")" \
			"$installed" \
			"$(json_string "$hint")"
	done
	printf ']'
}

# print_detect_environment_report — Formatted hardware/platform summary (no title).
print_detect_environment_report() {
	local w h r profiles free_vram access
	local desktop gpu audio vrr active_output primary_output display_line desktop_line
	local vram_line deck wsl container flatpak systemd_user immutable session_type

	profiles="$(detect_default_profiles 2>/dev/null || true)"
	[[ -n "$profiles" ]] || profiles="${LAUNCHLAYER_PROFILES:-${LAUNCHLAYER_PROFILE:-none}}"
	read -r w h < <(detect_display_resolution) || true
	r="$(detect_display_refresh)"
	free_vram="$(gpu_vram_free_mb 2>/dev/null || echo unknown)"
	access="$(flatpak_script_access)"
	desktop="$(detect_desktop_session)"
	gpu="$(detect_gpu_vendor)"
	audio="$(detect_audio_server)"
	active_output="$(detect_active_output 2>/dev/null || true)"
	primary_output="$(detect_kwin_primary_output 2>/dev/null || true)"
	[[ -n "$primary_output" ]] || primary_output="$active_output"
	deck="$(is_steam_deck && echo yes || echo no)"
	wsl="$(is_wsl2 && echo yes || echo no)"
	container="$(is_container && echo yes || echo no)"
	flatpak="$(is_flatpak_steam && echo yes || echo no)"
	systemd_user="$(has_systemd_user && echo yes || echo no)"
	immutable="$(is_immutable_os && echo yes || echo no)"
	session_type="$(detect_session_type)"

	if detect_vrr_enabled; then
		vrr="$(cli_green "enabled")"
	else
		vrr="$(cli_dim off)"
	fi

	if [[ "$free_vram" =~ ^[0-9]+$ ]]; then
		vram_line="${free_vram} MB free"
	else
		vram_line="$(cli_yellow unknown)"
	fi

	desktop_line="$desktop"
	case "$session_type" in
		wayland) desktop_line+=" · $(cli_cyan Wayland)" ;;
		x11) desktop_line+=" · X11" ;;
		*) desktop_line+=" · $(cli_dim "$session_type")" ;;
	esac

	display_line="$(cli_bold "${w}×${h} @ ${r} Hz")"
	[[ -n "$primary_output" ]] && display_line+=" · $(cli_dim "primary: ${primary_output}")"
	[[ -n "$active_output" && "$active_output" != "$primary_output" ]] \
		&& display_line+=" · $(cli_dim "focused: ${active_output}")"
	display_line+=" · VRR ${vrr}"

	cli_section "Gaming profile"
	env_report_row "Profiles" "$(cli_cyan "$profiles")"
	env_report_row "OS" "$(cli_bold "$(detect_os_pretty_name)") $(cli_dim "($(detect_os_family) · $(detect_uname_kernel))")"
	[[ "$immutable" == yes ]] && env_report_row "Immutable" "$(cli_yesno yes)"
	env_report_row "Desktop" "$desktop_line"
	env_report_row "GPUs" "$(detect_gpu_summary 2>/dev/null || cli_bold "$gpu")"
	env_report_row "Primary GPU" "$(printf '%s · %s' "$(cli_bold "$gpu")" "$vram_line")"
	env_report_row "Display" "$display_line"
	env_report_row "Audio" "$audio"
	env_report_row "CPU affinity" "$(cli_bold "$(detect_x3d_cpus)") $(cli_dim "(X3D V-Cache CCD)")"
	env_report_row "Network NIC" "$(detect_default_nic 2>/dev/null || echo unknown)"

	cli_section "Platform"
	env_report_row "Steam Deck" "$(cli_yesno "$deck")"
	env_report_row "WSL2 / Container" "$(cli_yesno "$wsl") / $(cli_yesno "$container")"
	env_report_row "Flatpak Steam" "$(cli_yesno "$flatpak")"
	if [[ "$flatpak" == yes ]]; then
		env_report_row "Script access" "$(cli_yesno "$access")"
		[[ "$access" == needs_override ]] && env_report_row "Flatpak hint" "$(cli_yellow "$(flatpak_override_hint)")"
	fi
	env_report_row "systemd user" "$(cli_yesno "$systemd_user")"

	cli_section "Optional tools"
	env_report_tools_row "${LAUNCHLAYER_OPTIONAL_TOOLS[@]}"
	if collect_missing_optional_tools | grep -q .; then
		cli_section "Install hints"
		while IFS= read -r tool; do
			[[ -n "$tool" ]] || continue
			hint="$(tool_install_hint "$tool")"
			[[ -n "$hint" ]] || continue
			printf '  %s: %s\n' "$tool" "$(cli_yellow "$hint")"
		done < <(collect_missing_optional_tools)
	fi

	cli_section "Paths"
	env_report_row "Config" "$(cli_dim "$CONFIG_DIR")"
	env_report_row "Script" "$(cli_dim "$LAUNCHLAYER_MAIN_SCRIPT")"
	env_report_row "Steam" "$(cli_dim "$STEAM_ROOT")"
}

# print_detect_environment_body — Report plus detected defaults (no title).
print_detect_environment_body() {
	print_detect_environment_report
	cli_section "Detected defaults"
	show_detected_defaults 0 1
}

# show_detect_environment — Print auto-detected platform and hardware state.
show_detect_environment() {
	local json=0
	while [[ "${1:-}" == --* ]]; do
		case "$1" in
			--json) json=1; shift ;;
			*) shift ;;
		esac
	done

	if [[ "$json" == "1" ]]; then
		local w h r profiles free_vram access active_output
		profiles="$(detect_default_profiles 2>/dev/null || true)"
		[[ -n "$profiles" ]] || profiles="${LAUNCHLAYER_PROFILES:-${LAUNCHLAYER_PROFILE:-none}}"
		read -r w h < <(detect_display_resolution) || true
		r="$(detect_display_refresh)"
		free_vram="$(gpu_vram_free_mb 2>/dev/null || echo unknown)"
		access="$(flatpak_script_access)"
		active_output="$(detect_active_output 2>/dev/null || true)"

		printf '{"config_dir":%s,"script":%s,"steam_root":%s,"profiles":%s,"os_id":%s,"os_family":%s,"os_pretty":%s,"kernel":%s,"desktop":%s,"compositor":%s,"session_type":%s,"display_backend":%s,"active_output":%s,"immutable":%s,"gpu_vendor":%s,"gpus":' \
			"$(json_string "$CONFIG_DIR")" \
			"$(json_string "$LAUNCHLAYER_MAIN_SCRIPT")" \
			"$(json_string "$STEAM_ROOT")" \
			"$(json_string "$profiles")" \
			"$(json_string "$(detect_os_id)")" \
			"$(json_string "$(detect_os_family)")" \
			"$(json_string "$(detect_os_pretty_name)")" \
			"$(json_string "$(detect_uname_kernel)")" \
			"$(json_string "$(detect_desktop_session)")" \
			"$(json_string "$(detect_desktop_session)")" \
			"$(json_string "$(detect_session_type)")" \
			"$(json_string "$(detect_session_type)")" \
			"$(json_string "${active_output:-}")" \
			"$(json_bool "$(is_immutable_os && echo 1 || echo 0)")" \
			"$(json_string "$(detect_gpu_vendor)")"
		detect_gpus_json 2>/dev/null || printf '[]'
		printf ',"audio":%s,"wsl2":%s,"container":%s,"flatpak_steam":%s,"flatpak_script_access":%s,"systemd_user":%s,"x3d_cpus":%s,"default_nic":%s,"display":%s,"vrr":%s,"gpu_vram_free_mb":%s,"package_manager":%s,"optional_tools":' \
			"$(json_string "$(detect_audio_server)")" \
			"$(json_bool "$(is_wsl2 && echo 1 || echo 0)")" \
			"$(json_bool "$(is_container && echo 1 || echo 0)")" \
			"$(json_bool "$(is_flatpak_steam && echo 1 || echo 0)")" \
			"$(json_string "$access")" \
			"$(json_bool "$(has_systemd_user && echo 1 || echo 0)")" \
			"$(json_string "$(detect_x3d_cpus)")" \
			"$(json_string "$(detect_default_nic 2>/dev/null || echo unknown)")" \
			"$(json_string "${w}x${h}@${r}Hz")" \
			"$(json_bool "$(detect_vrr_enabled && echo 1 || echo 0)")" \
			"$(json_number_or_string "$free_vram")" \
			"$(json_string "$(detect_package_manager)")"
		optional_tools_json_array
		printf '}\n'
		return 0
	fi

	printf '%s %s\n' "$(cli_bold "LaunchLayer environment")" "$(cli_dim "v${LAUNCHLAYER_VERSION}")"
	print_detect_environment_body
}
