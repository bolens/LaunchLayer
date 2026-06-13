# shellcheck shell=bash
# lib/commands/hub/apply.sh — --hub-apply.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_APPLY_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_APPLY_LOADED=1

# hub_apply_config — Download and merge a shared config by hub config id.
hub_apply_config() {
	local config_id="" dry_run=0 json=0 arg
	local response env_content path appid published_at

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run) dry_run=1; shift ;;
			--json) json=1; shift ;;
			*)
				[[ -z "$config_id" ]] && config_id=$1
				shift
				;;
		esac
	done

	[[ -n "$config_id" ]] || {
		echo "Usage: launchlayer --hub-apply CONFIG_ID [--dry-run] [--json]" >&2
		return 1
	}

	command_required_or_fail curl "Hub apply" || return 1
	hub_require_url || return 1

	response="$(hub_curl_json GET "/api/config/${config_id}")" || return 1

	if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
		echo "hub-apply requires jq or python3 to parse the hub response" >&2
		return 1
	fi

	appid="$(hub_json_get "$response" appid)"
	env_content="$(hub_json_get "$response" env_content)"
	published_at="$(hub_json_get "$response" published_at 2>/dev/null || true)"
	[[ -n "$appid" && -n "$env_content" ]] || {
		echo "Hub response missing appid or env_content" >&2
		return 1
	}

	path="$(resolve_appid_env_path "$appid")"
	if [[ "$dry_run" == "1" ]]; then
		if [[ "$json" == "1" ]]; then
			printf '{"appid":%s,"path":%s,"env_content":%s}\n' \
				"$(json_string "$appid")" \
				"$(json_string "$path")" \
				"$(json_string "$env_content")"
			return 0
		fi
		echo "Would write $path:"
		printf '%s\n' "$env_content"
		return 0
	fi

	mkdir -p "$(dirname "$path")"
	if [[ -f "$path" ]]; then
		cp "$path" "${path}.bak.$(date +%s)"
	fi
	printf '%s\n' "$env_content" > "$path"

	if [[ "$json" == "1" ]]; then
		printf '{"appid":%s,"path":%s,"applied":true}\n' \
			"$(json_string "$appid")" \
			"$(json_string "$path")"
		return 0
	fi
	echo "Applied hub config to $path (previous file backed up if it existed)."
	if [[ -n "$published_at" ]]; then
		echo "Hub config last updated: $(hub_format_published_at "$published_at")."
	fi
}
