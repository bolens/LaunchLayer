# shellcheck shell=bash
# lib/inspect/validation.sh
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
					command_available "$wrapper" || {
						local hint=""
						hint="$(tool_install_hint "$wrapper" 2>/dev/null || true)"
						echo "$file:$line_num: wrapper not found: $wrapper${hint:+ — $hint}"
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

	if (( added > 0 )); then
		echo "Added $added AppID(s) to anticheat-appids.txt"
	fi
	return 0
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
			local dlss_cfg
			dlss_cfg="$(resolve_appid_env_path "$appid")"
			[[ -f "$dlss_cfg" ]] \
				&& grep -q 'dlss-swapper' "$dlss_cfg" 2>/dev/null && return 0
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
				local -A validated_appids=() v_appid
				validate_single_config_file "$LAUNCHD_DIR/default.env" || issues=$((issues + $?))
				for file in "$LAUNCHD_DIR"/presets/*.env; do
					[[ -f "$file" ]] || continue
					validate_single_config_file "$file" || issues=$((issues + $?))
				done
				for file in "$GAMES_DIR"/[0-9]*.env; do
					[[ -f "$file" ]] || continue
					v_appid="$(basename "$file" .env)"
					[[ -n "${validated_appids[$v_appid]+x}" ]] && continue
					validated_appids["$v_appid"]=1
					validate_single_config_file "$file" || issues=$((issues + $?))
				done
				;;
			default|presets|local)
				if [[ "$t" == default ]]; then
					validate_single_config_file "$LAUNCHD_DIR/default.env" || issues=$((issues + $?))
				elif [[ "$t" == local ]]; then
					[[ -f "$LAUNCHD_DIR/local.env" ]] \
						&& validate_single_config_file "$LAUNCHD_DIR/local.env" || issues=$((issues + $?)) \
						|| echo "No config: $LAUNCHD_DIR/local.env" >&2
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
				file="$(resolve_appid_env_path "$t")"
				if ! appid_env_exists "$t"; then
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
