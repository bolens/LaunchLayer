# shellcheck shell=bash
# lib/commands/hub/history.sh — --hub-history.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_HISTORY_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_HISTORY_LOADED=1

# hub_history_config — List community config history.
hub_history_config() {
	local config_id="" json=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json) json=1; shift ;;
			*)
				[[ -z "$config_id" ]] && config_id=$1
				shift
				;;
		esac
	done

	[[ -n "$config_id" ]] || {
		echo "Usage: launchlayer --hub-history CONFIG_ID [--json]" >&2
		return 1
	}
	hub_validate_config_id "$config_id" || return 1

	command_required_or_fail curl "Hub history" || return 1
	hub_require_url || return 1

	local response
	response="$(hub_curl_json GET "/api/config/${config_id}/history")" || return 1

	if [[ "$json" == "1" ]]; then
		if command -v jq >/dev/null 2>&1; then
			printf '%s\n' "$response" | jq . 2>/dev/null || printf '%s\n' "$response"
		else
			printf '%s\n' "$response"
		fi
		return 0
	fi

	if command -v jq >/dev/null 2>&1; then
		local count
		count="$(printf '%s' "$response" | jq '. | length' 2>/dev/null || echo 0)"
		if (( count == 0 )); then
			echo "No history entries found for config ${config_id}."
			return 0
		fi
		cli_section "History for config ${config_id}"
		printf '%s' "$response" | jq -r '.[] | "\(.published_at / 1000 | strftime("%Y-%m-%d %H:%M:%S"))  preset=\(.preset // "-")  launchlayer=\(.launchlayer_version // "-")  note=\(.note // "-")  id=\(.history_id)"' 2>/dev/null
	else
		HUB_JSON_RESPONSE=$response python3 -c '
import json, os
from datetime import datetime, timezone

data = json.loads(os.environ["HUB_JSON_RESPONSE"])
if not data:
    print("No history entries found.")
else:
    for row in data:
        pub = row.get("published_at", 0)
        dt = datetime.fromtimestamp(pub / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        preset = row.get("preset") or "-"
        version = row.get("launchlayer_version") or "-"
        note = row.get("note") or "-"
        hid = row.get("history_id", "")
        print(f"{dt}  preset={preset}  launchlayer={version}  note={note}  id={hid}")
' 2>/dev/null
	fi
}
