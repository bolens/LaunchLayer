# shellcheck shell=bash
# lib/hub/similarity.sh — Weighted machine fingerprint similarity scoring.

[[ -n "${LAUNCHLAYER_HUB_SIMILARITY_LOADED:-}" ]] && return 0
LAUNCHLAYER_HUB_SIMILARITY_LOADED=1

# hub_json_get — Read a string field from a JSON object (requires jq or python3).
hub_json_get() {
	local json=$1 key=$2
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
		return 0
	fi
	if command -v python3 >/dev/null 2>&1; then
		HUB_JSON_GET_KEY=$key python3 -c '
import json, os, sys
d = json.load(sys.stdin)
v = d.get(os.environ["HUB_JSON_GET_KEY"])
if v is None:
    sys.exit(0)
if isinstance(v, bool):
    print("true" if v else "false")
elif isinstance(v, list):
    print(",".join(str(x) for x in v))
else:
    print(v)
' <<< "$json" 2>/dev/null
		return 0
	fi
	return 1
}

# hub_json_get_bool — Return 0 when a JSON boolean field is true.
hub_json_get_bool() {
	local json=$1 key=$2 val
	val="$(hub_json_get "$json" "$key" 2>/dev/null || true)"
	case "$val" in
		true|1|yes) return 0 ;;
		*) return 1 ;;
	esac
}

# hub_profile_overlap_score — Points for shared profile tags (max 24).
hub_profile_overlap_score() {
	local left=$1 right=$2
	local -a la=() ra=() match=0
	local item

	IFS=',' read -r -a la <<< "$(hub_json_get "$left" profiles 2>/dev/null | tr -d '[]"' | tr ' ' ',')"
	IFS=',' read -r -a ra <<< "$(hub_json_get "$right" profiles 2>/dev/null | tr -d '[]"' | tr ' ' ',')"

	for item in "${la[@]}"; do
		[[ -n "$item" ]] || continue
		local other
		for other in "${ra[@]}"; do
			[[ "$item" == "$other" ]] && (( match++ )) && break
		done
	done
	(( match > 6 )) && match=6
	echo $(( match * 4 ))
}

# hub_platform_flag_score — Shared platform constraint flags (2 pts each, max 12).
hub_platform_flag_score() {
	local left=$1 right=$2
	local score=0

	hub_json_get_bool "$left" vrr && hub_json_get_bool "$right" vrr && (( score += 2 ))
	hub_json_get_bool "$left" wsl2 && hub_json_get_bool "$right" wsl2 && (( score += 2 ))
	hub_json_get_bool "$left" flatpak_steam && hub_json_get_bool "$right" flatpak_steam && (( score += 2 ))
	hub_json_get_bool "$left" steam_deck && hub_json_get_bool "$right" steam_deck && (( score += 2 ))
	hub_json_get_bool "$left" immutable && hub_json_get_bool "$right" immutable && (( score += 2 ))
	hub_json_get_bool "$left" container && hub_json_get_bool "$right" container && (( score += 2 ))

	echo "$score"
}

# hub_similarity_score — Weighted 0–100 score between two fingerprint JSON blobs.
hub_similarity_score() {
	local left=$1 right=$2
	local score=0 lv rv overlap

	lv="$(hub_json_get "$left" gpu_vendor 2>/dev/null || true)"
	rv="$(hub_json_get "$right" gpu_vendor 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 18 ))

	lv="$(hub_json_get "$left" display_tier 2>/dev/null || true)"
	rv="$(hub_json_get "$right" display_tier 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 10 ))

	lv="$(hub_json_get "$left" refresh_tier 2>/dev/null || true)"
	rv="$(hub_json_get "$right" refresh_tier 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 5 ))

	lv="$(hub_json_get "$left" os_family 2>/dev/null || true)"
	rv="$(hub_json_get "$right" os_family 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 7 ))

	lv="$(hub_json_get "$left" session_type 2>/dev/null || true)"
	rv="$(hub_json_get "$right" session_type 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 7 ))

	lv="$(hub_json_get "$left" desktop 2>/dev/null || true)"
	rv="$(hub_json_get "$right" desktop 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" != unknown && "$lv" == "$rv" ]] && (( score += 8 ))

	hub_json_get_bool "$left" has_x3d && hub_json_get_bool "$right" has_x3d && (( score += 5 ))

	lv="$(hub_json_get "$left" x3d_cpus 2>/dev/null || true)"
	rv="$(hub_json_get "$right" x3d_cpus 2>/dev/null || true)"
	[[ -n "$lv" && -n "$rv" && "$lv" == "$rv" && "$lv" != none ]] && (( score += 3 ))

	lv="$(hub_json_get "$left" vram_tier 2>/dev/null || true)"
	rv="$(hub_json_get "$right" vram_tier 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" != unknown && "$lv" == "$rv" ]] && (( score += 5 ))

	lv="$(hub_json_get "$left" monitor_layout 2>/dev/null || true)"
	rv="$(hub_json_get "$right" monitor_layout 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" == "$rv" ]] && (( score += 3 ))

	lv="$(hub_json_get "$left" primary_aspect 2>/dev/null || true)"
	rv="$(hub_json_get "$right" primary_aspect 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" != unknown && "$lv" == "$rv" ]] && (( score += 3 ))

	lv="$(hub_json_get "$left" audio 2>/dev/null || true)"
	rv="$(hub_json_get "$right" audio 2>/dev/null || true)"
	[[ -n "$lv" && "$lv" != unknown && "$lv" == "$rv" ]] && (( score += 4 ))

	if hub_json_get_bool "$left" has_igpu; then
		hub_json_get_bool "$right" has_igpu && (( score += 2 ))
	elif ! hub_json_get_bool "$left" has_igpu && ! hub_json_get_bool "$right" has_igpu; then
		(( score += 2 ))
	fi

	overlap="$(hub_profile_overlap_score "$left" "$right")"
	(( score += overlap ))

	overlap="$(hub_platform_flag_score "$left" "$right")"
	(( score += overlap ))

	(( score > 100 )) && score=100
	echo "$score"
}
