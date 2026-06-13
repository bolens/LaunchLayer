# shellcheck shell=bash
# lib/commands/hub.sh — LaunchLayer Hub: publish, recommend, and apply shared configs.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_LOADED=1

# hub_show_fingerprint — Print normalized machine fingerprint for similarity matching.
hub_show_fingerprint() {
	local json=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json) json=1; shift ;;
			--fingerprint-level)
				export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL=${2:-minimal}
				shift 2
				;;
			--fingerprint-level=*)
				export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL="${1#--fingerprint-level=}"
				shift
				;;
			*) shift ;;
		esac
	done

	load_hub_prefs
	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults

	local fp hash level
	level="$(hub_fingerprint_level)"
	fp="$(hub_fingerprint_from_detection)"
	hash="$(hub_fingerprint_hash "$fp")"

	if [[ "$json" == "1" ]]; then
		printf '{"fingerprint":'
		printf '%s' "$fp"
		printf ',"fingerprint_hash":%s,"fingerprint_level":%s}\n' \
			"$(json_string "$hash")" \
			"$(json_string "$level")"
		return 0
	fi

	cli_section "Machine fingerprint"
	env_report_row "Level" "$(cli_cyan "$level")"
	env_report_row "Hash" "$(cli_dim "$hash")"
	if command -v jq >/dev/null 2>&1; then
		printf '%s\n' "$fp" | jq . 2>/dev/null || printf '%s\n' "$fp"
	else
		printf '%s\n' "$fp"
	fi
}

# hub_sync_one_game — Upload one game config; sets HUB_SYNC_RESPONSE and HUB_SYNC_UPDATED.
hub_sync_one_game() {
	local fingerprint=$1 appid=$2 name=$3 content=$4 note=${5:-} config_id=${6:-}
	if [[ -z "$config_id" ]]; then
		config_id="$(hub_find_my_config_id "$appid" "$fingerprint" 2>/dev/null || true)"
	fi
	local payload
	payload="$(hub_publish_payload "$fingerprint" "$appid" "$name" "$content" "$note" "$config_id")"
	HUB_SYNC_RESPONSE="$(hub_curl_json POST /api/publish "$payload" 1)" || return 1
	HUB_SYNC_UPDATED="$(hub_parse_publish_updated "$HUB_SYNC_RESPONSE")"
	return 0
}

# hub_publish_result_message — Human message after publish/update.
hub_publish_result_message() {
	local name=$1 appid=$2 response=$3
	local updated cid
	updated="$(hub_parse_publish_updated "$response")"
	cid="$(hub_parse_publish_config_id "$response")"
	if [[ "$updated" == "1" ]]; then
		echo "Updated hub config for $name ($appid) — id=${cid:-unknown}"
	else
		echo "Published new hub config for $name ($appid) — id=${cid:-unknown}"
	fi
}

# hub_publish_config — Upload one or more game configs to the hub.
hub_publish_config() {
	local appid="" note="" all_configured=0 json=0 config_id="" arg
	local fingerprint payload response

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--note) note=${2:-}; shift 2 ;;
			--all-configured) all_configured=1; shift ;;
			--json) json=1; shift ;;
			--config-id) config_id=${2:-}; shift 2 ;;
			*)
				[[ -z "$appid" ]] && appid=$1
				shift
				;;
		esac
	done

	command_required_or_fail curl "Hub publish" || return 1
	hub_require_url || return 1
	load_hub_prefs
	hub_require_privileged_auth || return 1

	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults

	fingerprint="$(hub_fingerprint_from_detection)"

	if [[ "$all_configured" == "1" ]]; then
		local -a published=() updated=() created=()
		local line id name path content
		while IFS= read -r line; do
			[[ -n "$line" ]] || continue
			id="$(hub_json_get "$line" appid 2>/dev/null || true)"
			[[ "$id" =~ ^[0-9]+$ ]] || continue
			name="$(hub_json_get "$line" name 2>/dev/null || echo "AppID $id")"
			path="$(resolve_appid_env_path "$id" 2>/dev/null || true)"
			[[ -f "$path" ]] || continue
			content="$(cat "$path")"
			hub_sync_one_game "$fingerprint" "$id" "$name" "$content" "$note" || return 1
			published+=("$id")
			if [[ "$HUB_SYNC_UPDATED" == "1" ]]; then
				updated+=("$id")
			else
				created+=("$id")
			fi
		done < <(list_games 1 1 "")

		if [[ "$json" == "1" ]]; then
			printf '{"published":%s,"updated":%s,"created":%s}\n' \
				"$(json_array_strings published)" \
				"$(json_array_strings updated)" \
				"$(json_array_strings created)"
			return 0
		fi
		echo "Synced ${#published[@]} configured game(s) to LaunchLayer Hub (${#updated[@]} updated, ${#created[@]} new)."
		return 0
	fi

	[[ -n "$appid" ]] || {
		echo "Usage: launchlayer --hub-publish APPID|NAME [--note TEXT] [--config-id ID] [--all-configured] [--json]" >&2
		return 1
	}
	[[ "$appid" =~ ^[0-9]+$ ]] || appid="$(resolve_appid_arg "$appid")" || return $?

	local name path content
	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	path="$(resolve_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		echo "No config at $path — run --init-appid first" >&2
		return 1
	}
	content="$(cat "$path")"
	hub_sync_one_game "$fingerprint" "$appid" "$name" "$content" "$note" "$config_id" || return 1
	response="$HUB_SYNC_RESPONSE"

	if [[ "$json" == "1" ]]; then
		printf '%s\n' "$response"
		return 0
	fi
	hub_publish_result_message "$name" "$appid" "$response"
}

# hub_update_config — Update existing shared config(s) for this machine fingerprint.
hub_update_config() {
	local config_id="" appid="" note="" all_configured=0 json=0 only_existing=1
	local fingerprint name path content hub_config response
	local -a updated=() skipped=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--note) note=${2:-}; shift 2 ;;
			--all-configured) all_configured=1; shift ;;
			--json) json=1; shift ;;
			--include-new) only_existing=0; shift ;;
			*)
				if [[ -z "$config_id" && -z "$appid" ]]; then
					if [[ "$1" =~ ^[0-9]+$ ]]; then
						appid=$1
					else
						config_id=$1
					fi
				fi
				shift
				;;
		esac
	done

	command_required_or_fail curl "Hub update" || return 1
	hub_require_url || return 1
	load_hub_prefs
	hub_require_privileged_auth || return 1

	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults

	fingerprint="$(hub_fingerprint_from_detection)"

	if [[ "$all_configured" == "1" ]]; then
		local line id existing_id
		while IFS= read -r line; do
			[[ -n "$line" ]] || continue
			id="$(hub_json_get "$line" appid 2>/dev/null || true)"
			[[ "$id" =~ ^[0-9]+$ ]] || continue
			name="$(hub_json_get "$line" name 2>/dev/null || echo "AppID $id")"
			path="$(resolve_appid_env_path "$id" 2>/dev/null || true)"
			[[ -f "$path" ]] || continue
			existing_id="$(hub_find_my_config_id "$id" "$fingerprint" 2>/dev/null || true)"
			if [[ -z "$existing_id" ]]; then
				if [[ "$only_existing" == "1" ]]; then
					skipped+=("$id")
					continue
				fi
				content="$(cat "$path")"
				hub_sync_one_game "$fingerprint" "$id" "$name" "$content" "$note" || return 1
				updated+=("$id")
				continue
			fi
			content="$(cat "$path")"
			hub_sync_one_game "$fingerprint" "$id" "$name" "$content" "$note" "$existing_id" || return 1
			updated+=("$id")
		done < <(list_games 1 1 "")

		if [[ "$json" == "1" ]]; then
			printf '{"updated":%s,"skipped":%s}\n' \
				"$(json_array_strings updated)" \
				"$(json_array_strings skipped)"
			return 0
		fi
		echo "Updated ${#updated[@]} shared hub config(s)."
		((${#skipped[@]})) && echo "Skipped ${#skipped[@]} game(s) with no existing hub config (use --include-new to publish them)."
		return 0
	fi

	if [[ -n "$appid" ]]; then
		[[ "$appid" =~ ^[0-9]+$ ]] || appid="$(resolve_appid_arg "$appid")" || return $?
		config_id="$(hub_find_my_config_id "$appid" "$fingerprint" 2>/dev/null || true)"
		[[ -n "$config_id" ]] || {
			echo "No shared hub config for $appid on this machine — use --hub-publish to create one." >&2
			return 1
		}
	elif [[ -z "$config_id" ]]; then
		echo "Usage: launchlayer --hub-update APPID|NAME|CONFIG_ID [--all-configured] [--note TEXT] [--include-new] [--json]" >&2
		return 1
	fi

	hub_config="$(hub_curl_json GET "/api/config/${config_id}")" || return 1
	appid="$(hub_json_get "$hub_config" appid)"
	[[ -n "$appid" ]] || {
		echo "Hub config $config_id is missing appid metadata." >&2
		return 1
	}

	name="$(get_game_name "$appid" 2>/dev/null || hub_json_get "$hub_config" game_name)"
	path="$(resolve_appid_env_path "$appid")"
	[[ -f "$path" ]] || {
		echo "No local config at $path — run --init-appid first" >&2
		return 1
	}
	content="$(cat "$path")"
	hub_sync_one_game "$fingerprint" "$appid" "$name" "$content" "$note" "$config_id" || return 1
	response="$HUB_SYNC_RESPONSE"

	if [[ "$json" == "1" ]]; then
		printf '%s\n' "$response"
		return 0
	fi
	hub_publish_result_message "$name" "$appid" "$response"
}

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

# hub_recommend_configs — Find community configs from similar machines.
hub_recommend_configs() {
	local appid="" limit=10 json=0 arg
	local fingerprint payload response

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--limit) limit=${2:-10}; shift 2 ;;
			--json) json=1; shift ;;
			*)
				[[ -z "$appid" ]] && appid=$1
				shift
				;;
		esac
	done

	[[ -n "$appid" ]] || {
		echo "Usage: launchlayer --hub-recommend APPID|NAME [--limit N] [--json]" >&2
		return 1
	}
	[[ "$appid" =~ ^[0-9]+$ ]] || appid="$(resolve_appid_arg "$appid")" || return $?

	command_required_or_fail curl "Hub recommend" || return 1
	hub_require_url || return 1
	load_hub_prefs

	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults

	fingerprint="$(hub_fingerprint_from_detection)"
	payload="$(hub_recommend_payload "$fingerprint" "$appid" "$limit")"
	response="$(hub_curl_json POST /api/recommend "$payload")" || return 1

	if [[ "$json" == "1" ]]; then
		if command -v jq >/dev/null 2>&1; then
			printf '%s\n' "$response" | jq . 2>/dev/null || printf '%s\n' "$response"
		else
			printf '%s\n' "$response"
		fi
		return 0
	fi

	local name
	name="$(get_game_name "$appid" 2>/dev/null || echo "AppID $appid")"
	cli_section "Hub recommendations for $name ($appid)"
	hub_format_recommend_response_cli "$response" || printf '%s\n' "$response"
}

# hub_apply_config — Download and merge a shared config by hub config id.
hub_apply_config() {
	local config_id="" dry_run=0 json=0 arg
	local response env_content path appid

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

# hub_search_machines — List machines most similar to the current fingerprint.
hub_search_machines() {
	local limit=10 json=0 arg
	local fingerprint payload response

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--limit) limit=${2:-10}; shift 2 ;;
			--json) json=1; shift ;;
			*) shift ;;
		esac
	done

	command_required_or_fail curl "Hub search" || return 1
	hub_require_url || return 1
	load_hub_prefs

	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0
	[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
	apply_defaults

	fingerprint="$(hub_fingerprint_from_detection)"
	payload="$(printf '{"fingerprint":%s,"limit":%s}' "$fingerprint" "$limit")"
	response="$(hub_curl_json POST /api/similar-machines "$payload")" || return 1

	if [[ "$json" == "1" ]]; then
		if command -v jq >/dev/null 2>&1; then
			printf '%s\n' "$response" | jq . 2>/dev/null || printf '%s\n' "$response"
		else
			printf '%s\n' "$response"
		fi
		return 0
	fi

	cli_section "Similar machines"
	if command -v jq >/dev/null 2>&1; then
		printf '%s\n' "$response" | jq -r '.results[]? | "\(.similarity)%  \(.machine_label // .gpu_vendor)  \(.display // "")  \(.profiles | join(", "))"' 2>/dev/null \
			|| printf '%s\n' "$response"
	else
		printf '%s\n' "$response"
	fi
}
