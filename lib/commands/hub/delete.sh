# shellcheck shell=bash
# lib/commands/hub/delete.sh — --hub-delete.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_DELETE_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_DELETE_LOADED=1

# hub_delete_config — Remove a shared config from the hub (requires publish token when enforced).
hub_delete_config() {
	local config_id="" json=0 yes=0 arg
	local payload response deleted_machine

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json) json=1; shift ;;
			--yes) yes=1; shift ;;
			*)
				[[ -z "$config_id" ]] && config_id=$1
				shift
				;;
		esac
	done

	[[ -n "$config_id" ]] || {
		echo "Usage: launchlayer --hub-delete CONFIG_ID [--yes] [--json]" >&2
		return 1
	}

	command_required_or_fail curl "Hub delete" || return 1
	hub_require_url || return 1
	load_hub_prefs

	if [[ "$yes" != "1" && -t 0 ]]; then
		read -r -p "Delete hub config ${config_id}? [y/N] " arg </dev/tty || true
		case "$arg" in
			y|Y|yes|Yes) ;;
			*) echo "Cancelled."; return 1 ;;
		esac
	fi

	payload="$(hub_delete_payload "$config_id")"
	response="$(hub_curl_json POST /api/delete "$payload" 1)" || return 1

	if [[ "$json" == "1" ]]; then
		printf '%s\n' "$response"
		return 0
	fi

	echo "Deleted hub config ${config_id}."
	if command -v jq >/dev/null 2>&1; then
		deleted_machine="$(printf '%s' "$response" | jq -r '.deleted_machine' 2>/dev/null || true)"
		[[ "$deleted_machine" == "true" ]] && echo "Removed orphaned machine record."
	fi
}
