# shellcheck shell=bash
# lib/steam/library.sh — Steam library roots, manifests, and installed-game iteration.

[[ -n "${LAUNCHLAYER_STEAM_LIBRARY_LOADED:-}" ]] && return 0
LAUNCHLAYER_STEAM_LIBRARY_LOADED=1

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
