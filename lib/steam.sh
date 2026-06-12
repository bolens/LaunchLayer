# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=config.sh
# shellcheck source=vdf.sh
# lib/steam.sh — Steam library discovery and per-game metadata helpers.

[[ -n "${LAUNCHLAYER_STEAM_LOADED:-}" ]] && return 0
LAUNCHLAYER_STEAM_LOADED=1

# steam_add_library_root — Append a library root if not already present.
steam_add_library_root() {
	local lib=$1
	local -n _roots_ref=$2
	local r
	[[ -n "$lib" && -d "$lib" ]] || return 0
	for r in "${_roots_ref[@]}"; do
		[[ "$r" == "$lib" ]] && return 0
	done
	_roots_ref+=("$lib")
}

# collect_steam_library_roots — Print all Steam library root paths, one per line.
collect_steam_library_roots() {
	local vdf lib steam_real
	local -a roots=()

	steam_add_library_root "$STEAM_ROOT" roots
	if [[ -L "$HOME/.steam/root" ]]; then
		steam_real="$(realpath_portable "$HOME/.steam/root" 2>/dev/null || true)"
		steam_add_library_root "$steam_real" roots
	fi
	steam_add_library_root "$HOME/.steam/root" roots

	for vdf in \
		"$STEAM_ROOT/steamapps/libraryfolders.vdf" \
		"$HOME/.steam/root/steamapps/libraryfolders.vdf"; do
		[[ -f "$vdf" ]] || continue
		while IFS= read -r lib; do
			steam_add_library_root "$lib" roots
		done < <(parse_libraryfolders_paths "$vdf")
	done

	printf '%s\n' "${roots[@]}"
}

# find_app_manifest — Locate appmanifest_<appid>.acf across all library roots.
find_app_manifest() {
	local appid=$1
	local root manifest
	for root in $(collect_steam_library_roots); do
		manifest="$root/steamapps/appmanifest_${appid}.acf"
		if [[ -f "$manifest" ]]; then
			echo "$manifest"
			return 0
		fi
	done
	return 1
}

# manifest_field — Extract a quoted VDF field value from an app manifest.
manifest_field() {
	local manifest=$1
	local field=$2
	grep -m1 "\"$field\"" "$manifest" 2>/dev/null \
		| sed -n 's/^[[:space:]]*"[^"]*"[[:space:]]*"\([^"]*\)".*/\1/p' || true
}

# get_game_name — Return the human-readable name for a Steam AppID.
get_game_name() {
	local appid=$1
	local manifest
	manifest="$(find_app_manifest "$appid" 2>/dev/null || true)"
	[[ -n "$manifest" ]] || return 1
	manifest_field "$manifest" "name"
}

# resolve_appid_query — Resolve numeric AppID or case-insensitive name fragment.
# Prints AppID on stdout; returns 1 if not found, 2 if ambiguous.
resolve_appid_query() {
	local query=$1
	local -a matches=() match

	if [[ "$query" =~ ^[0-9]+$ ]]; then
		get_game_name "$query" >/dev/null 2>&1 || {
			echo "AppID $query not found in installed Steam libraries." >&2
			return 1
		}
		echo "$query"
		return 0
	fi

	_resolve_appid_name_match() {
		local appid=$1 name=$2 _manifest=$3
		game_name_matches_grep "$name" "$query" || return 0
		matches+=("$appid")
	}
	foreach_installed_game _resolve_appid_name_match

	if ((${#matches[@]} == 0)); then
		echo "No installed game matching: $query" >&2
		return 1
	fi
	if ((${#matches[@]} > 1)); then
		echo "Multiple games match '$query':" >&2
		for match in "${matches[@]}"; do
			printf '  %s (%s)\n' "$match" "$(get_game_name "$match" 2>/dev/null || echo unknown)" >&2
		done
		echo "Use the numeric AppID." >&2
		return 2
	fi
	echo "${matches[0]}"
}

# get_installdir — Return the installdir field from an app manifest.
get_installdir() {
	local appid=$1
	local manifest
	manifest="$(find_app_manifest "$appid" 2>/dev/null || true)"
	[[ -n "$manifest" ]] || return 1
	manifest_field "$manifest" "installdir"
}

# find_game_dir — Resolve installdir to an absolute common/ path.
find_game_dir() {
	local installdir=$1
	local root
	for root in $(collect_steam_library_roots); do
		if [[ -d "$root/steamapps/common/$installdir" ]]; then
			echo "$root/steamapps/common/$installdir"
			return 0
		fi
	done
	return 1
}

# get_game_dir_for_appid — Resolve install directory for an AppID.
get_game_dir_for_appid() {
	local appid=$1 installdir
	installdir="$(get_installdir "$appid" 2>/dev/null || true)"
	[[ -n "$installdir" ]] || return 1
	find_game_dir "$installdir"
}

# find_all_app_manifests — Print one app manifest path per unique AppID.
find_all_app_manifests() {
	local root manifest appid
	declare -A seen_appids=()
	for root in $(collect_steam_library_roots); do
		[[ -d "$root/steamapps" ]] || continue
		while IFS= read -r manifest; do
			[[ -n "$manifest" ]] || continue
			appid="$(manifest_field "$manifest" appid)"
			[[ -n "$appid" ]] || continue
			[[ -n "${seen_appids[$appid]+x}" ]] && continue
			seen_appids[$appid]=1
			echo "$manifest"
		done < <(find "$root/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -print 2>/dev/null || true)
	done
}

# is_skippable_steam_package — True for Steam runtimes, SDKs, and Proton tool entries.
is_skippable_steam_package() {
	local name=$1
	[[ "$name" == *Runtime* || "$name" == *Redistribut* || "$name" == *SDK* || "$name" == Proton* ]]
}

# game_name_matches_grep — True when name matches a case-insensitive grep pattern (or pattern empty).
game_name_matches_grep() {
	local name=$1 pattern=$2
	[[ -z "$pattern" || "${name,,}" == *"${pattern,,}"* ]]
}

# foreach_installed_game — Invoke callback(appid, name, manifest) for each installed game.
foreach_installed_game() {
	local callback=$1 manifest appid name
	[[ "$(type -t "$callback")" == function ]] || return 1
	for manifest in $(find_all_app_manifests | sort -u); do
		appid="$(manifest_field "$manifest" appid)"
		name="$(manifest_field "$manifest" name)"
		[[ -n "$appid" && -n "$name" ]] || continue
		is_skippable_steam_package "$name" && continue
		"$callback" "$appid" "$name" "$manifest"
	done
}

# game_dir_has_native_launcher — True when a Steam/Linux launcher script is present.
game_dir_has_native_launcher() {
	local game_dir=$1
	[[ -f "$game_dir/launcher.sh" || -f "$game_dir/start.sh" || -f "$game_dir/run.sh" ]]
}

# detect_native_game — Heuristic: should this title run without Proton?
#
# Priority:
#   FORCE_PROTON=1  → always false
#   FORCE_NATIVE=1  → always true
#   native-appids.txt membership
#   launcher.sh / start.sh / run.sh (before .exe check)
#   ELF executable without root-level .exe
detect_native_game() {
	local appid=${1:-$steam_app_id}
	local use_heuristic=${2:-1}
	local installdir game_dir

	[[ "${FORCE_PROTON:-0}" == "1" ]] && return 1
	[[ "${FORCE_NATIVE:-0}" == "1" ]] && return 0
	[[ -n "$appid" ]] || return 1

	appid_in_list_file "$appid" "$LAUNCHD_DIR/native-appids.txt" && return 0
	[[ "$use_heuristic" == "0" ]] && return 1

	installdir="$(get_installdir "$appid" 2>/dev/null || true)"
	[[ -n "$installdir" ]] || return 1
	game_dir="$(find_game_dir "$installdir" 2>/dev/null || true)"
	[[ -n "$game_dir" ]] || return 1

	if game_dir_has_native_launcher "$game_dir"; then
		return 0
	fi

	# Root-level Windows executables suggest Proton (ignore nested tool/redist exes).
	if find "$game_dir" -maxdepth 1 -iname '*.exe' -print -quit 2>/dev/null | grep -q .; then
		return 1
	fi

	if find "$game_dir" -maxdepth 2 -type f -perm /111 -print0 2>/dev/null \
		| xargs -0 file 2>/dev/null | grep -q 'ELF.*executable'; then
		return 0
	fi
	return 1
}

# detect_anticheat_in_list — True when AppID is listed in anticheat-appids.txt.
detect_anticheat_in_list() {
	local appid=${1:-$steam_app_id}
	[[ -n "$appid" ]] || return 1
	appid_in_list_file "$appid" "$LAUNCHD_DIR/anticheat-appids.txt"
}

# _detect_anticheat_markers — Return battleye, eac, or empty from install dir markers.
_detect_anticheat_markers() {
	local game_dir=$1
	[[ -n "$game_dir" && -d "$game_dir" ]] || return 0

	if find "$game_dir" -maxdepth 4 \( \
		-type d -iname 'BattlEye' -o -iname 'BEService.exe' \
		\) -print -quit 2>/dev/null | grep -q .; then
		echo battleye
		return 0
	fi
	if find "$game_dir" -maxdepth 3 \( \
		-type d -iname 'EasyAntiCheat' -o -type d -iname 'easyanticheat' \
		\) -print -quit 2>/dev/null | grep -q .; then
		echo eac
		return 0
	fi
	if find "$game_dir" -maxdepth 4 \( \
		-iname 'EasyAntiCheat_EOS.exe' -o -iname 'EasyAntiCheat_Setup.exe' \
		\) -print -quit 2>/dev/null | grep -q .; then
		echo eac
		return 0
	fi
}

# detect_anticheat_filesystem — True when EAC/BattlEye markers exist in the install dir.
detect_anticheat_filesystem() {
	local appid=${1:-$steam_app_id}
	local game_dir markers
	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	markers="$(_detect_anticheat_markers "$game_dir")"
	[[ -n "$markers" ]]
}

# detect_anticheat_game — True when listed or install dir contains anticheat markers.
detect_anticheat_game() {
	local appid=${1:-$steam_app_id}
	detect_anticheat_in_list "$appid" && return 0
	detect_anticheat_filesystem "$appid"
}

# detect_anticheat_type — Return eac, battleye, listed, or empty string.
detect_anticheat_type() {
	local appid=${1:-$steam_app_id}
	local game_dir="" fs_type="" in_list=0

	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	fs_type="$(_detect_anticheat_markers "$game_dir")"

	detect_anticheat_in_list "$appid" && in_list=1
	if [[ -n "$fs_type" ]]; then
		echo "$fs_type"
		return 0
	fi
	(( in_list )) && echo listed
	return 0
}

# detect_engine_hint — Return unity, unreal, unity-il2cpp, or unknown.
detect_engine_hint() {
	local appid=${1:-$steam_app_id}
	local game_dir
	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	[[ -n "$game_dir" && -d "$game_dir" ]] || {
		echo unknown
		return 0
	}

	if [[ -d "$game_dir/Engine/Binaries" ]]; then
		echo unreal
		return 0
	fi
	if [[ -f "$game_dir/UnityPlayer.so" ]] \
		|| find "$game_dir" -maxdepth 2 -name 'UnityPlayer.so' -print -quit 2>/dev/null | grep -q .; then
		echo unity
		return 0
	fi
	if [[ -f "$game_dir/GameAssembly.dll" ]]; then
		echo unity-il2cpp
		return 0
	fi
	echo unknown
}

# detect_dlss_present — True when DLSS/NVNGX libraries are in the install dir.
detect_dlss_present() {
	local appid=${1:-$steam_app_id}
	local game_dir
	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	[[ -n "$game_dir" && -d "$game_dir" ]] || return 1
	find "$game_dir" -maxdepth 3 \( \
		-iname 'nvngx.dll' -o -iname 'nvngx_dlss.dll' -o -iname 'sl.dlss.dll' \
		\) -print -quit 2>/dev/null | grep -q .
}

# get_compatdata_path_for_appid — Print first compatdata prefix path for an AppID.
get_compatdata_path_for_appid() {
	local appid=$1
	collect_compatdata_dirs "$appid"
	# shellcheck disable=SC2154  # set by collect_compatdata_dirs in preflight.sh
	[[ ${#compatdata_dirs[@]} -gt 0 ]] && echo "${compatdata_dirs[0]}"
}

# get_proton_tool_for_appid — Read Proton/compatibility tool name from prefix config_info.
get_proton_tool_for_appid() {
	local appid=$1 dir
	dir="$(get_compatdata_path_for_appid "$appid" 2>/dev/null || true)"
	[[ -n "$dir" && -f "$dir/config_info" ]] || return 1
	head -1 "$dir/config_info" 2>/dev/null | tr -d '[:space:]'
}

# suggest_preset_for_appid — Auto-select standard, competitive, or native preset.
suggest_preset_for_appid() {
	local appid=$1
	if detect_native_game "$appid"; then
		echo native
	elif detect_anticheat_game "$appid"; then
		echo competitive
	else
		echo standard
	fi
}

# resolve_game_flags — Populate is_native, is_anticheat, engine, and name globals.
# shellcheck disable=SC2034  # globals defined in common.sh, consumed by other modules
resolve_game_flags() {
	is_native=0
	is_anticheat=0
	anticheat_type=""
	game_engine_hint="unknown"

	detect_native_game "$steam_app_id" && is_native=1
	detect_anticheat_game "$steam_app_id" && is_anticheat=1
	anticheat_type="$(detect_anticheat_type "$steam_app_id")"
	game_engine_hint="$(detect_engine_hint "$steam_app_id")"
	steam_game_name="$(get_game_name "$steam_app_id" 2>/dev/null || true)"
}
