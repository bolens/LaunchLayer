# shellcheck shell=bash
# lib/commands/hub/context.sh — Shared config loading for hub CLI commands.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_CONTEXT_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_CONTEXT_LOADED=1

# hub_load_launch_context — Load profile + default/local layers before fingerprinting.
hub_load_launch_context() {
	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults
}
