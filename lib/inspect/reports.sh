# shellcheck shell=bash
# lib/inspect/reports.sh
# cache_report — Library-wide shader/compatdata size audit.
cache_report() {
	local min_gb=${1:-5} mode=${2:-both} grep_pattern=${3:-} json=${4:-0}
	local total_shader=0 total_compat=0 count=0
	local -a games_json=()
	local first=1 entry

	[[ "$min_gb" =~ ^[0-9]+$ ]] || min_gb=5
	CLI_JSON_OUTPUT=$json

	if [[ "$json" != "1" ]]; then
		echo "=== Cache report (min ${min_gb}GB, mode=$mode${grep_pattern:+, grep=$grep_pattern}) ==="
		printf '%-10s %-6s %-6s %-6s %s\n' APPID SHADER COMPAT TOTAL NAME
	fi

	_cache_report_one() {
		local appid=$1 name=$2 _manifest=$3
		local shader_gb=0 compat_gb=0 total_gb

		cli_scan_progress_tick
		[[ -n "$grep_pattern" ]] && ! game_name_matches_grep "$name" "$grep_pattern" && return 0

		if [[ "$mode" == "both" || "$mode" == "shader" ]]; then
			shader_gb="$(sum_cache_dirs_gb "$appid" shader)"
		fi
		if [[ "$mode" == "both" || "$mode" == "compat" ]]; then
			compat_gb="$(sum_cache_dirs_gb "$appid" compat)"
		fi

		total_gb=$((shader_gb + compat_gb))
		(( total_gb >= min_gb )) || return 0
		(( count++ )) || true
		(( total_shader += shader_gb )) || true
		(( total_compat += compat_gb )) || true
		if [[ "$json" == "1" ]]; then
			games_json+=("$(printf '{"appid":%s,"name":%s,"shader_gb":%s,"compat_gb":%s,"total_gb":%s}' \
				"$(json_string "$appid")" "$(json_string "$name")" "$shader_gb" "$compat_gb" "$total_gb")")
		else
			printf '%-10s %-6s %-6s %-6s %s\n' "$appid" "${shader_gb}GB" "${compat_gb}GB" "${total_gb}GB" "$name"
		fi
	}

	cli_scan_progress_begin "Scanning cache sizes"
	foreach_installed_game _cache_report_one
	cli_scan_progress_end

	if [[ "$json" == "1" ]]; then
		printf '{"min_gb":%s,"mode":%s,"grep":%s,"summary":{"count":%s,"shader_total_gb":%s,"compat_total_gb":%s},"games":[' \
			"$min_gb" "$(json_string "$mode")" "$(json_string "$grep_pattern")" \
			"$count" "$total_shader" "$total_compat"
		first=1
		for entry in "${games_json[@]}"; do
			(( first )) || printf ','
			first=0
			printf '%s' "$entry"
		done
		printf ']}\n'
		return 0
	fi

	echo
	echo "Games over threshold: $count (shader total: ${total_shader}GB, compat total: ${total_compat}GB)"
}

# launch_stats — Summarize launch.log play time and exit codes.
launch_stats() {
	local filter_query=${1:-} json=${2:-0}
	local filter_appid=""

	if [[ -n "$filter_query" ]]; then
		if [[ "$filter_query" =~ ^[0-9]+$ ]]; then
			filter_appid="$filter_query"
		else
			filter_appid="$(resolve_appid_query "$filter_query")" || return $?
		fi
	fi

	[[ -f "$LAUNCH_LOG_FILE" ]] || {
		if [[ "$json" == "1" ]]; then
			printf '{"entries":[],"filter":%s}\n' "$(json_string "$filter_appid")"
			return 0
		fi
		echo "No launch log at $LAUNCH_LOG_FILE"
		return 0
	}

	[[ "$json" != "1" ]] && echo "=== Launch stats${filter_appid:+ for AppID $filter_appid} ==="
	awk -v filter="$filter_appid" -v fmt="$([[ "$json" == "1" ]] && echo json || echo text)" '
		function json_quote(s,    t) {
			t = s
			gsub(/\\/, "\\\\", t)
			gsub(/"/, "\\\"", t)
			return "\"" t "\""
		}
		function parse_launch_line(    i) {
			appid=""; name=""; duration=0; exitval=0; ts=$1
			for (i = 2; i <= NF; i++) {
				if ($i ~ /^appid=/) { sub(/^appid=/, "", $i); appid = $i }
				else if ($i ~ /^name=/) { name = $i; sub(/^name=/, "", name); gsub(/^"/, "", name); gsub(/"$/, "", name) }
				else if ($i ~ /^duration=/) { sub(/^duration=/, "", $i); sub(/s$/, "", $i); duration = $i + 0 }
				else if ($i ~ /^exit=/) { sub(/^exit=/, "", $i); exitval = $i + 0 }
			}
		}
		{
			parse_launch_line()
			if (filter != "" && appid != filter) next
			if (appid == "") next
			launches[appid]++
			time[appid] += duration
			if (exitval != 0) fails[appid]++
			last[appid] = ts
			names[appid] = name
		}
		END {
			if (fmt == "json") {
				printf "{\"filter\":%s,\"entries\":[", json_quote(filter)
				n = asorti(launches, sorted, "@val_num_desc")
				for (i = 1; i <= n; i++) {
					id = sorted[i]
					if (i > 1) printf ","
					printf "{\"appid\":\"%s\",\"name\":%s,\"launches\":%d,\"time_s\":%d,\"failures\":%d,\"last\":%s}",
						id, json_quote(names[id]), launches[id], time[id], fails[id]+0, json_quote(last[id])
				}
				printf "]}\n"
				exit
			}
			printf "%-10s %-6s %-8s %-6s %-19s %s\n", "APPID", "LAUNCH", "TIME", "FAIL", "LAST", "NAME"
			n = asorti(launches, sorted, "@val_num_desc")
			for (i = 1; i <= n; i++) {
				id = sorted[i]
				printf "%-10s %-6s %-8s %-6s %-19s %s\n", id, launches[id], time[id] "s", fails[id]+0, last[id], names[id]
			}
			if (n == 0) print "(no matching entries)"
		}
		' "$LAUNCH_LOG_FILE"
}
