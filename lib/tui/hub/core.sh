# shellcheck shell=bash
# lib/tui/hub/core.sh — Hub shared context and guards

[[ -n "${LAUNCHLAYER_TUI_HUB_CORE_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HUB_CORE_LOADED=1

# tui_hub_load_context — Load config layers before hub fingerprint/API calls.
tui_hub_load_context() {
	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults
}

# tui_hub_status_brief — Short hub connection label for menus and banner.
tui_hub_status_brief() {
	load_hub_prefs
	if [[ -n "${HUB_PREFS_URL:-}" ]]; then
		tui_glyph_hub_brief "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}" 1
	else
		tui_glyph_hub_brief "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}" 0
	fi
}
# tui_hub_require_ready — curl + hub_url must be available.
tui_hub_require_ready() {
	local err
	command -v curl >/dev/null 2>&1 || {
		tui_show_text "Hub requires curl$(tool_warn_suffix curl)." "Hub"
		return 1
	}
	if ! err="$(hub_require_url 2>&1 >/dev/null)"; then
		tui_show_text "$err" "Hub"
		return 1
	fi
	load_hub_prefs
	return 0
}

# tui_hub_require_json_parser — jq or python3 for picking hub results.
tui_hub_require_json_parser() {
	command -v jq >/dev/null 2>&1 && return 0
	command -v python3 >/dev/null 2>&1 && return 0
	tui_show_text "Hub browsing requires jq or python3." "Hub"
	return 1
}
