# shellcheck shell=bash
# lib/tui/hub/browse.sh — Hub search, recommend, and apply

[[ -n "${LAUNCHLAYER_TUI_HUB_BROWSE_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HUB_BROWSE_LOADED=1

# tui_hub_search_machines — List machines similar to this one.
tui_hub_search_machines() {
	local limit=10 action
	tui_hub_require_ready || return 0
	tui_hub_load_context
	action="$(tui_menu "Similar machines limit" \
		"Top 5" \
		"Top 10" \
		"Top 20" \
		"Back")" || return 0
	case "$action" in
		"Top 5") limit=5 ;;
		"Top 10") limit=10 ;;
		"Top 20") limit=20 ;;
		*) return 0 ;;
	esac
	tui_run_paged hub_search_machines --limit "$limit" "$(tui_json_flag)" || true
}

# tui_hub_parse_recommendation_lines — Build picker rows from recommend JSON.
tui_hub_parse_recommendation_lines() {
	local response=$1
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$response" | jq -r "$(hub_jq_recommend_picker_filter)" 2>/dev/null
		return 0
	fi
	HUB_JSON_RESPONSE=$response python3 -c '
import json, os
from datetime import datetime, timezone

def fmt(ms):
    if not isinstance(ms, (int, float)) or ms <= 0:
        return "unknown"
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d")

data = json.loads(os.environ["HUB_JSON_RESPONSE"])
for row in data.get("results") or []:
    cid = row.get("config_id", "")
    sim = row.get("similarity", 0)
    label = row.get("machine_label") or row.get("gpu_vendor") or "unknown"
    note = row.get("note") or "-"
    updated = fmt(row.get("published_at"))
    print(f"{cid}\t{sim}% match · {label} · updated {updated} · {note}")
' 2>/dev/null
}

# tui_hub_pick_recommendation — Pick one config_id from recommend response.
tui_hub_pick_recommendation() {
	local response=$1
	local -a rows=() row config_id
	mapfile -t rows < <(tui_hub_parse_recommendation_lines "$response")
	((${#rows[@]})) || {
		tui_show_text "No community configs from similar machines." "Recommendations"
		return 1
	}
	row="$(tui_menu "Pick a shared config" "${rows[@]}")" || return 1
	config_id="${row%%$'\t'*}"
	[[ -n "$config_id" ]] || return 1
	printf '%s\n' "$config_id"
}

# tui_hub_recommend_for_appid — Fetch and optionally apply recommendations for one game.
tui_hub_recommend_for_appid() {
	local appid=$1 limit=${2:-10} config_id response name
	tui_hub_require_ready || return 0
	tui_hub_require_json_parser || return 0
	tui_hub_load_context

	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	response="$(tui_spinner_capture "Fetching recommendations…" hub_recommend_configs "$appid" --limit "$limit" --json)" || {
		tui_show_text "$response" "Recommendations"
		return 1
	}

	if tui_json_enabled; then
		tui_run_paged printf '%s\n' "$response" || true
		return 0
	fi

	config_id="$(tui_hub_pick_recommendation "$response")" || return 0

	action="$(tui_menu "Config $config_id" \
		"Preview apply (dry-run)" \
		"Apply to $name" \
		"View history" \
		"Apply historical version" \
		"Back")" || return 0

	case "$action" in
		"Preview apply (dry-run)")
			tui_run_paged hub_apply_config "$config_id" --dry-run || true
			;;
		"Apply to"*)
			tui_confirm "Apply hub config $config_id to $name?" || return 0
			tui_run_capture "Applying shared config…" hub_apply_config "$config_id" || true
			;;
		"View history")
			tui_run_paged hub_history_config "$config_id" || true
			;;
		"Apply historical version")
			tui_hub_apply_historical "$config_id" "$name" || true
			;;
		*) ;;
	esac
}

# tui_hub_apply_historical — Pick a history id for config_id and apply it.
tui_hub_apply_historical() {
	local config_id=$1 name=$2
	local response history_id choice line
	local -a labels=() ids=()

	command_required_or_fail curl "Hub history" || return 1
	hub_require_url || return 1
	response="$(hub_curl_json GET "/api/config/${config_id}/history")" || return 1

	if command -v jq >/dev/null 2>&1; then
		mapfile -t ids < <(printf '%s' "$response" | jq -r '.[].history_id // empty' 2>/dev/null)
		mapfile -t labels < <(printf '%s' "$response" | jq -r '.[] | "\(.history_id)  \((.published_at // 0) / 1000 | strftime("%Y-%m-%d %H:%M"))  \(.note // "-")"' 2>/dev/null)
	else
		while IFS=$'\t' read -r history_id line; do
			[[ -n "$history_id" ]] || continue
			ids+=("$history_id")
			labels+=("$line")
		done < <(HUB_JSON_RESPONSE=$response python3 -c '
import json, os
from datetime import datetime, timezone
data = json.loads(os.environ["HUB_JSON_RESPONSE"])
for row in data:
    hid = row.get("history_id", "")
    if not hid:
        continue
    pub = row.get("published_at", 0)
    dt = datetime.fromtimestamp(pub / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")
    note = row.get("note") or "-"
    print(f"{hid}\t{hid}  {dt}  {note}")
')
	fi

	((${#ids[@]})) || {
		echo "No history entries found for config ${config_id}."
		return 0
	}

	choice="$(tui_menu "Historical version for $config_id" "${labels[@]}" "Back")" || return 0
	[[ "$choice" == "Back" || -z "$choice" ]] && return 0
	history_id="${choice%% *}"
	[[ -n "$history_id" ]] || return 0

	tui_confirm "Apply historical config $history_id to $name?" || return 0
	tui_run_capture "Applying historical config…" hub_apply_config "$history_id" --history || true
}

# tui_hub_recommend_menu — Pick a game then browse recommendations.
tui_hub_recommend_menu() {
	local appid limit action
	tui_hub_require_ready || return 0
	appid="$(tui_pick_game_appid)" || return 0
	action="$(tui_menu "Recommendation limit" \
		"Top 5" \
		"Top 10" \
		"Top 20" \
		"Back")" || return 0
	case "$action" in
		"Top 5") limit=5 ;;
		"Top 10") limit=10 ;;
		"Top 20") limit=20 ;;
		*) return 0 ;;
	esac
	tui_hub_recommend_for_appid "$appid" "$limit"
}
