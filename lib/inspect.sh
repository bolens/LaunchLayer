# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=keys.sh
# shellcheck source=config.sh
# shellcheck source=steam.sh
# shellcheck source=hardware.sh
# shellcheck source=preflight.sh
# shellcheck source=runtime.sh
# lib/inspect.sh — Config inspection, validation, cache reports, and launch stats.

[[ -n "${LAUNCHLAYER_INSPECT_LOADED:-}" ]] && return 0
LAUNCHLAYER_INSPECT_LOADED=1

# show_paths — Print shader cache, compatdata, install, and config paths for a game.
show_paths() {
	local query=$1 json=${2:-0}
	local appid name game_dir proton_tool config_path

	[[ -n "$query" ]] || {
		echo "Usage: $0 --paths APPID|NAME [--json]" >&2
		return 1
	}

	appid="$(resolve_appid_query "$query")" || return $?
	name="$(get_game_name "$appid" 2>/dev/null || echo unknown)"
	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	config_path="$LAUNCHD_DIR/${appid}.env"

	collect_cache_size_entries "$appid"

	if [[ "$json" == "1" ]]; then
		printf '{'
		json_object_pair "appid" "$(json_string "$appid")"
		json_object_pair "name" "$(json_string "$name")" 1
		json_object_pair "config" "$(json_string "$config_path")" 1
		json_object_pair "install_dir" "$(json_string "$game_dir")" 1
		json_object_pair "proton_tool" "$(json_string "$proton_tool")" 1
		printf_cache_dirs_json_pair shader_cache_entries compatdata_entries
		printf '}\n'
		return 0
	fi

	echo "=== Paths for AppID $appid ($name) ==="
	echo "config=$config_path$([[ -f "$config_path" ]] && echo ' (exists)' || echo ' (missing)')"
	[[ -n "$game_dir" ]] && echo "install_dir=$game_dir" || echo "install_dir: (not found)"
	[[ -n "$proton_tool" ]] && echo "proton_tool=$proton_tool"
	echo
	print_cache_dirs_text "Shader cache" "Compatdata"
}

# show_config — Print resolved config and launch chain for an AppID or name fragment.
show_config() {
	local query=$1 json=${2:-0}
	local appid resolved chain_args=()
	[[ -n "$query" ]] || {
		echo "Usage: $0 --show-config APPID|NAME [--json]" >&2
		return 1
	}

	resolved="$(resolve_appid_query "$query")" || return $?
	appid="$resolved"

	prepare_launch_context "$appid"
	local name="${steam_game_name:-unknown}" proton_tool="" compat_path=""

	if [[ "$json" == "1" ]]; then
		show_config_json "$appid" "$name"
		return 0
	fi

	echo "=== Config for AppID $appid ($name) ==="
	echo "Layers:"
	local layer
	for layer in "${config_layers[@]}"; do
		echo "  → $(config_file_relative "$layer")"
	done
	echo
	echo "Detection: native=$is_native anticheat=$is_anticheat type=${anticheat_type:-none} engine=$game_engine_hint"
	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	compat_path="$(get_compatdata_path_for_appid "$appid" 2>/dev/null || true)"
	if [[ -n "$compat_path" ]]; then
		echo "Proton prefix: $compat_path${proton_tool:+ (tool: $proton_tool)}"
	fi
	if detect_dlss_present "$appid"; then
		echo "Note: DLSS libraries detected — consider LAUNCH_WRAPPERS=dlss-swapper"
	fi
	echo
	print_effective_config_summary
	echo
	echo "Launch chain:"
	chain_args=("${launch[@]}" "<steam %command%>" "${game_extra_argv[@]}")
	printf '  %q' "${chain_args[@]}"
	echo
}

# collect_effective_settings_json — Build JSON array of {key,value,source} objects.
collect_effective_settings_json() {
	local first=1
	_json_settings_item() {
		(( first )) || printf ','
		first=0
		printf '{"key":%s,"value":%s,"source":%s}' \
			"$(json_string "$1")" \
			"$(json_string "$2")" \
			"$(json_string "$(config_file_relative "$3")")"
	}
	printf '['
	for_each_effective_setting _json_settings_item
	printf ']'
}

# show_config_json — Machine-readable resolved config for an AppID.
show_config_json() {
	local appid=$1 name=$2
	local proton_tool="" compat_path="" layer
	local -a rel_layers=() chain_args=()

	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	compat_path="$(get_compatdata_path_for_appid "$appid" 2>/dev/null || true)"
	for layer in "${config_layers[@]}"; do
		rel_layers+=("$(config_file_relative "$layer")")
	done
	chain_args=("${launch[@]}" "<steam %command%>" "${game_extra_argv[@]}")

	printf '{'
	json_object_pair "appid" "$(json_string "$appid")"
	json_object_pair "name" "$(json_string "$name")" 1
	json_object_pair "layers" "$(json_array_strings rel_layers)" 1
	printf ',"detection":{"native":%s,"anticheat":%s,"type":%s,"engine":%s}' \
		"$(json_bool "$is_native")" \
		"$(json_bool "$is_anticheat")" \
		"$(json_string "${anticheat_type:-}")" \
		"$(json_string "$game_engine_hint")"
	printf ',"proton_prefix":%s,"proton_tool":%s,"dlss_present":%s' \
		"$(json_string "$compat_path")" \
		"$(json_string "$proton_tool")" \
		"$(json_bool "$(detect_dlss_present "$appid" && echo 1 || echo 0)")"
	printf ',"settings":'
	collect_effective_settings_json
	printf ',"launch_chain":%s}\n' "$(json_array_strings chain_args)"
}

# init_unconfigured — Scaffold launch.d/<AppID>.env for games without one.
init_unconfigured() {
	local preset=${1:-} dry_run=${2:-0} eac_only=${3:-0}
	local chosen created=0 skipped=0

	if [[ "$dry_run" == "1" ]]; then
		echo "=== Init unconfigured (dry-run) ==="
		[[ -n "$preset" ]] && echo "Forced preset: $preset"
		[[ "$eac_only" == "1" ]] && echo "Scope: anticheat titles only"
		printf '%-10s %-12s %s\n' APPID PRESET NAME
	fi

	_init_unconfigured_one() {
		local appid=$1 name=$2 _manifest=$3
		cli_scan_progress_tick
		if [[ -f "$LAUNCHD_DIR/${appid}.env" ]]; then
			((skipped++)) || true
			return 0
		fi
		if [[ "$eac_only" == "1" ]] && ! detect_anticheat_game "$appid"; then
			((skipped++)) || true
			return 0
		fi

		chosen="$preset"
		[[ -n "$chosen" ]] || chosen="$(suggest_preset_for_appid "$appid")"

		if [[ "$dry_run" == "1" ]]; then
			printf '%-10s %-12s %s\n' "$appid" "$chosen" "$name"
		else
			write_appid_env_scaffold "$appid" "$name" "$chosen"
			echo "Created $LAUNCHD_DIR/${appid}.env (preset: $chosen)"
		fi
		((created++)) || true
	}

	cli_scan_progress_begin "Scanning installed games"
	foreach_installed_game _init_unconfigured_one || true
	cli_scan_progress_end

	if [[ "$dry_run" == "1" ]]; then
		if (( created == 0 )); then
			echo "No new configs needed — every matching game already has launch.d/<AppID>.env"
		else
			echo "Would create $created config(s) under $LAUNCHD_DIR/"
		fi
	fi
	echo "Done: created=$created skipped=$skipped"
}

# edit_appid_config — Open or create launch.d/<AppID>.env in $EDITOR.
edit_appid_config() {
	local query=$1 appid editor
	[[ -n "$query" ]] || {
		echo "Usage: $0 --edit-appid APPID|NAME" >&2
		return 1
	}
	appid="$(resolve_appid_query "$query")" || return $?
	if [[ ! -f "$LAUNCHD_DIR/${appid}.env" ]]; then
		init_appid_config "$appid" "" 0 || return 1
	fi
	editor="${EDITOR:-${VISUAL:-nano}}"
	"$editor" "$LAUNCHD_DIR/${appid}.env"
}

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

# validate_single_config_file — Lint one .env file; print issues to stdout.
validate_single_config_file() {
	local file=$1
	local line_num=0 line key value preset_path issues=0

	[[ -f "$file" ]] || return 0

	while IFS= read -r line || [[ -n "$line" ]]; do
		((line_num++)) || true
		local raw="$line"
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ -z "$line" ]] && continue

		if [[ "$line" =~ ^INCLUDE=(.+)$ ]]; then
			preset_path="${BASH_REMATCH[1]}"
			preset_path="${preset_path#"${preset_path%%[![:space:]]*}"}"
			preset_path="${preset_path%"${preset_path##*[![:space:]]}"}"
			preset_path="${preset_path#\"}"; preset_path="${preset_path%\"}"
			if [[ ! -f "$LAUNCHD_DIR/$preset_path" ]]; then
				echo "$file:$line_num: INCLUDE target missing: $preset_path"
				((issues++)) || true
			fi
			continue
		fi

		[[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || {
			echo "$file:$line_num: invalid line: $raw"
			((issues++)) || true
			continue
		}
		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		if ! known_config_key "$key"; then
			echo "$file:$line_num: unknown key: $key"
			((issues++)) || true
		fi
		case "$key" in
			LAUNCH_WRAPPERS|LAUNCH_WRAPPERS_BEFORE)
				local wrapper
				for wrapper in $value; do
					command -v "$wrapper" >/dev/null 2>&1 || {
						echo "$file:$line_num: wrapper not found: $wrapper"
						((issues++)) || true
					}
				done
				;;
			GAMESCOPE)
				[[ "$value" == "1" ]] && [[ "${FORCE_PROTON:-0}" != "1" ]] && {
					local appid_from_file
					appid_from_file="$(basename "$file" .env)"
					if [[ "$appid_from_file" =~ ^[0-9]+$ ]] && detect_native_game "$appid_from_file" 0; then
						echo "$file:$line_num: GAMESCOPE=1 on native game without FORCE_PROTON=1"
						((issues++)) || true
					fi
				}
				;;
			FORCE_NATIVE|FORCE_PROTON) ;;
	esac
	done < "$file"

	if grep -qE '^[[:space:]]*FORCE_NATIVE=1' "$file" 2>/dev/null \
		&& grep -qE '^[[:space:]]*FORCE_PROTON=1' "$file" 2>/dev/null; then
		echo "$file: conflicting FORCE_NATIVE=1 and FORCE_PROTON=1"
		((issues++)) || true
	fi

	return "$issues"
}

# scan_anticheat — Compare filesystem anticheat markers against anticheat-appids.txt.
scan_anticheat() {
	local update_list=${1:-0}
	local fs list ac_type added=0

	echo "=== Anticheat scan ==="
	printf '%-10s %-4s %-4s %-8s %s\n' APPID FS LIST TYPE NAME

	_scan_anticheat_one() {
		local appid=$1 name=$2 _manifest=$3
		fs=no; list=no
		detect_anticheat_filesystem "$appid" && fs=yes
		detect_anticheat_in_list "$appid" && list=yes
		ac_type="$(detect_anticheat_type "$appid")"
		[[ -z "$ac_type" ]] && ac_type="-"

		[[ "$fs" == yes || "$list" == yes ]] || return 0
		printf '%-10s %-4s %-4s %-8s %s\n' "$appid" "$fs" "$list" "$ac_type" "$name"

		if [[ "$fs" == yes && "$list" == no ]]; then
			echo "  → missing from anticheat-appids.txt: $appid ($name)"
			if [[ "$update_list" == "1" ]] && ! grep -qx "$appid" "$LAUNCHD_DIR/anticheat-appids.txt" 2>/dev/null; then
				echo "$appid" >> "$LAUNCHD_DIR/anticheat-appids.txt"
				echo "    added $appid to anticheat-appids.txt"
				((added++)) || true
			fi
		fi
		if [[ "$fs" == no && "$list" == yes ]]; then
			echo "  → list-only (no install-dir markers): $appid ($name)"
		fi
	}

	foreach_installed_game _scan_anticheat_one

	(( added > 0 )) && echo "Added $added AppID(s) to anticheat-appids.txt"
}

# scan_detections — Report heuristic vs list mismatches and tuning hints.
scan_detections() {
	echo "=== Detection audit ==="

	_scan_detections_one() {
		local appid=$1 name=$2 _manifest=$3
		local native_heur native_list ac_fs ac_list

		native_heur=no; native_list=no; ac_fs=no; ac_list=no
		detect_native_game "$appid" 1 && native_heur=yes
		appid_in_list_file "$appid" "$LAUNCHD_DIR/native-appids.txt" && native_list=yes
		detect_anticheat_filesystem "$appid" && ac_fs=yes
		detect_anticheat_in_list "$appid" && ac_list=yes

		if [[ "$native_heur" == yes && "$native_list" == no ]]; then
			echo "native heuristic only: $appid ($name) — consider native-appids.txt"
		fi
		if [[ "$native_heur" == no && "$native_list" == yes ]]; then
			echo "native list only: $appid ($name) — verify FORCE_NATIVE or list entry"
		fi
		if [[ "$ac_fs" == yes && "$ac_list" == no ]]; then
			echo "anticheat fs only: $appid ($name) — run --scan-anticheat --update-list"
		fi
		if detect_dlss_present "$appid"; then
			[[ -f "$LAUNCHD_DIR/${appid}.env" ]] \
				&& grep -q 'dlss-swapper' "$LAUNCHD_DIR/${appid}.env" 2>/dev/null && return 0
			echo "dlss present: $appid ($name) — consider LAUNCH_WRAPPERS=dlss-swapper"
		fi
	}

	foreach_installed_game _scan_detections_one
}

# validate_config — Lint one AppID config, all per-game configs, or default + presets.
validate_config() {
	local target=${1:-all} json=${2:-0} issues=0 file
	local -a issue_lines=()
	local line

	_run_validation() {
		local t=${1:-all}
		case "$t" in
			all)
				validate_single_config_file "$LAUNCHD_DIR/default.env" || issues=$((issues + $?))
				for file in "$LAUNCHD_DIR"/presets/*.env; do
					[[ -f "$file" ]] || continue
					validate_single_config_file "$file" || issues=$((issues + $?))
				done
				for file in "$LAUNCHD_DIR"/[0-9]*.env; do
					[[ -f "$file" ]] || continue
					validate_single_config_file "$file" || issues=$((issues + $?))
				done
				;;
			default|presets)
				if [[ "$t" == default ]]; then
					validate_single_config_file "$LAUNCHD_DIR/default.env" || issues=$((issues + $?))
				else
					for file in "$LAUNCHD_DIR"/presets/*.env; do
						[[ -f "$file" ]] || continue
						validate_single_config_file "$file" || issues=$((issues + $?))
					done
				fi
				;;
			*)
				if [[ "$t" != all && "$t" != default && "$t" != presets && ! "$t" =~ ^[0-9]+$ ]]; then
					t="$(resolve_appid_query "$t")" || return $?
				fi
				[[ "$t" =~ ^[0-9]+$ ]] || {
					echo "Usage: $0 --validate-config [APPID|NAME|all|default|presets] [--json]" >&2
					return 1
				}
				file="$LAUNCHD_DIR/${t}.env"
				if [[ ! -f "$file" ]]; then
					echo "No config: $file" >&2
					return 1
				fi
				validate_single_config_file "$file" || issues=$((issues + $?))
				;;
		esac
	}

		if [[ "$json" == "1" ]]; then
		issues=0
		while IFS= read -r line; do
			[[ -n "$line" ]] && issue_lines+=("$line")
		done < <(_run_validation "$target")
		printf '{"target":%s,"issue_count":%s,"issues":' \
			"$(json_string "$target")" "$issues"
		json_array_strings issue_lines
		printf '}\n'
		(( issues == 0 )) || return "$issues"
		return 0
	fi

	_run_validation "$target"

	if (( issues == 0 )); then
		echo "Validation passed (0 issues)"
	else
		echo "Validation failed ($issues issue(s))"
	fi
	return "$issues"
}
