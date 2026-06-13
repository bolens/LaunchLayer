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

# hub_validate_local_env_file — Lint one .env file before hub publish/apply.
hub_validate_local_env_file() {
	local file=$1 label=${2:-local config}
	local lint_out issues=0

	declare -f validate_single_config_file >/dev/null 2>&1 || return 0
	lint_out="$(validate_single_config_file "$file" 2>&1)" || issues=$?
	if (( issues > 0 )); then
		echo "$label failed validation:" >&2
		printf '%s\n' "$lint_out" >&2
		return 1
	fi
	return 0
}

# hub_validate_config_id — Reject malformed hub config ids before HTTP calls.
hub_validate_config_id() {
	local config_id=$1
	[[ "$config_id" =~ ^[a-z0-9]{10,64}$ ]] || {
		echo "Invalid hub config ID: $config_id" >&2
		return 1
	}
}
