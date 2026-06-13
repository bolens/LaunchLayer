# shellcheck shell=bash
# lib/tui/hub/settings.sh — Hub settings and fingerprint privacy

[[ -n "${LAUNCHLAYER_TUI_HUB_SETTINGS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HUB_SETTINGS_LOADED=1

# tui_hub_fingerprint_level_help — Explain fingerprint tiers before choosing.
tui_hub_fingerprint_level_help() {
	tui_show_text "$(cat <<'EOF'
Fingerprint levels control how much machine data is sent for hub
publish, recommend, and similar-machine matching.

  minimal  — GPU vendor, OS, session, profiles, display/refresh tiers,
             desktop compositor, X3D flag, platform flags (VRR, WSL, …)

  standard — minimal + audio stack, VRAM tier, monitor layout, aspect,
             exact primary resolution, X3D CPU mask, iGPU presence

  detailed — standard + every GPU (model/VRAM/PCI), all monitors,
             output connector names, OS id

Saved to hub.conf as fingerprint_level=. Default is minimal.
EOF
)" "Fingerprint levels"
}

# tui_hub_fingerprint_level_menu — Pick and persist fingerprint_level in hub.conf.
tui_hub_fingerprint_level_menu() {
	local val level current
	load_hub_prefs
	current="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"

	val="$(tui_menu "Fingerprint privacy (current: ${current})" \
		"minimal — GPU/OS/tiers/desktop only" \
		"standard — + audio, VRAM tier, monitors, exact display" \
		"detailed — + full GPU/monitor lists and output names" \
		"What does each level share?" \
		"Back")" || return 0

	case "$val" in
		"minimal "*) level=minimal ;;
		"standard "*) level=standard ;;
		"detailed "*) level=detailed ;;
		"What does each level share?"*)
			tui_hub_fingerprint_level_help
			tui_hub_fingerprint_level_menu
			return 0
			;;
		*) return 0 ;;
	esac

	[[ "$level" == "$current" ]] && return 0

	HUB_PREFS_FINGERPRINT_LEVEL=$level
	save_hub_prefs
	tui_show_text "$(printf 'Fingerprint level set to %s (%s).\nSaved to %s' \
		"$level" "$(hub_fingerprint_level_desc "$level")" "$(hub_prefs_path)")" \
		"Fingerprint level"
}

# tui_hub_token_glyph — ● when publish token is set, ○ otherwise.
tui_hub_token_glyph() {
	if [[ -n "${1:-}" ]]; then
		tui_glyph_ok
	else
		tui_glyph_off
	fi
}

# tui_hub_settings_items — Compact hub.conf menu rows.
tui_hub_settings_items() {
	local arr_name=$1
	# shellcheck disable=SC2178 # nameref to caller's array
	local -n out_arr=$arr_name
	local url_label=${2:-} label_label=${3:-} level_label=${4:-}
	load_hub_prefs
	url_label="${url_label:-$(tui_prefs_truncate "${HUB_PREFS_URL:-(not set)}" 44)}"
	label_label="${label_label:-$(tui_prefs_truncate "${HUB_PREFS_MACHINE_LABEL:-(not set)}" 44)}"
	level_label="${level_label:-${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}}"
	out_arr=(
		"[Hub] ${url_label}"
		"[Auth] token $(tui_hub_token_glyph "${HUB_PREFS_PUBLISH_TOKEN:-}")"
		"[You] ${label_label}"
		"[Privacy] ${level_label}"
		"" "[·] Open hub.conf in \$EDITOR"
	)
	tui_prefs_footer "$arr_name" save
}

# tui_hub_settings_menu — Edit hub.conf.
tui_hub_settings_menu() {
	local action val url_label label_label level_label
	local -a items=()

	load_hub_prefs
	url_label="$(tui_prefs_truncate "${HUB_PREFS_URL:-(not set)}" 44)"
	label_label="$(tui_prefs_truncate "${HUB_PREFS_MACHINE_LABEL:-(not set)}" 44)"
	level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"

	while true; do
		tui_hub_settings_items items "$url_label" "$label_label" "$level_label"
		action="$(tui_menu_anchored "hub.conf" "" "${items[@]}")" || return 0

		case "$action" in
			"[Hub]"*)
				read -r -p "Hub base URL [${HUB_PREFS_URL}]: " val </dev/tty || continue
				[[ -n "$val" ]] && HUB_PREFS_URL="$val"
				url_label="$(tui_prefs_truncate "${HUB_PREFS_URL:-(not set)}" 44)"
				;;
			"[Auth]"*)
				read -r -p "Publish token (empty to clear) [hidden]: " val </dev/tty || continue
				HUB_PREFS_PUBLISH_TOKEN="$val"
				;;
			"[You]"*)
				read -r -p "Machine label [${HUB_PREFS_MACHINE_LABEL}]: " val </dev/tty || continue
				HUB_PREFS_MACHINE_LABEL="$val"
				label_label="$(tui_prefs_truncate "${HUB_PREFS_MACHINE_LABEL:-(not set)}" 44)"
				;;
			"[Privacy]"*)
				tui_hub_fingerprint_level_menu
				load_hub_prefs
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"[·] Show all")
				tui_run_paged show_hub_prefs 0 || true
				;;
			"[·] Open hub.conf in \$EDITOR")
				if [[ ! -f "$(hub_prefs_path)" ]]; then
					save_hub_prefs
					tui_panel_note "Created $(hub_prefs_path)" "Hub settings"
				fi
				tui_open_in_editor "$(hub_prefs_path)"
				load_hub_prefs
				url_label="$(tui_prefs_truncate "${HUB_PREFS_URL:-(not set)}" 44)"
				label_label="$(tui_prefs_truncate "${HUB_PREFS_MACHINE_LABEL:-(not set)}" 44)"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"[·] Reset defaults")
				tui_confirm "Reset hub settings to repo example?" || continue
				reset_hub_prefs || continue
				load_hub_prefs
				url_label="$(tui_prefs_truncate "${HUB_PREFS_URL:-(not set)}" 44)"
				label_label="$(tui_prefs_truncate "${HUB_PREFS_MACHINE_LABEL:-(not set)}" 44)"
				level_label="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
				;;
			"[·] Save")
				save_hub_prefs
				tui_show_text "Saved hub settings to $(hub_prefs_path)" "Hub settings"
				return 0
				;;
			*) return 0 ;;
		esac
	done
}

# tui_hub_show_fingerprint — View machine fingerprint.
tui_hub_show_fingerprint() {
	tui_hub_load_context
	tui_run_paged hub_show_fingerprint "$(tui_json_flag)" || true
}
