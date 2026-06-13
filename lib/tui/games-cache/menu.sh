# shellcheck shell=bash
# lib/tui/games-cache/menu.sh — Games hub menu labels, header, and footer.

[[ -n "${LAUNCHLAYER_TUI_GAMES_CACHE_MENU_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_GAMES_CACHE_MENU_LOADED=1
# tui_games_menu_item_needs_list — True when a hub menu row needs the game list.
tui_games_menu_item_needs_list() {
	local label=$1 plain item
	plain="$(printf '%s' "$label" | tui_strip_ansi)"
	for item in "${TUI_GAMES_MENU_NEED_LIST[@]}"; do
		[[ "$plain" == "$item" || "$plain" == "$item  · loading…" ]] && return 0
	done
	return 1
}

# tui_games_menu_item_loading_p — True when row is shown in the loading (disabled) state.
tui_games_menu_item_loading_p() {
	local label=$1 plain
	plain="$(printf '%s' "$label" | tui_strip_ansi)"
	[[ "$plain" == *" · loading…" ]]
}

# tui_games_menu_item_label — Hub menu label; dim + suffix only before first cache is available.
tui_games_menu_item_label() {
	local label=$1
	if tui_games_cache_has_lines || ! tui_games_menu_item_needs_list "$label"; then
		printf '%s' "$label"
	elif cli_uses_color; then
		printf '%s' "$(cli_dim "${label}  · loading…")"
	else
		printf '%s' "${label}  · loading…"
	fi
}

# tui_games_menu_normalize_selection — Strip loading decoration from a picked row.
tui_games_menu_normalize_selection() {
	local label=$1
	label="$(printf '%s' "$label" | tui_strip_ansi)"
	label="${label%  · loading…}"
	printf '%s' "$label"
}

# tui_games_menu_print_items — Hub menu rows for fzf reload (stdout).
tui_games_menu_print_items() {
	local item
	if tui_games_cache_loading; then
		if cli_uses_color; then
			printf '%s\n' "$(cli_dim '── loading installed games… ──')"
		else
			printf '%s\n' '── loading installed games… ──'
		fi
	fi
	for item in \
		"Browse & configure game" \
		"Recent games" \
		"Bulk change INCLUDE preset" \
		"Init unconfigured games" \
		"Prune uninstalled configs" \
		"Back"; do
		tui_games_menu_item_label "$item"
		printf '\n'
	done
}

# tui_games_menu_reload — fzf reload source: refresh hub rows from cache state.
tui_games_menu_reload() {
	tui_games_cache_start
	tui_games_menu_print_items
}

# tui_games_menu_resize_reload — Replace list once when cache becomes ready (refresh-list marker).
tui_games_menu_resize_reload() {
	tui_games_cache_paths
	[[ -f "${TUI_GAMES_CACHE_DIR}/refresh-list" ]] || return 1
	rm -f "${TUI_GAMES_CACHE_DIR}/refresh-list"
	tui_games_menu_print_items
}

# tui_games_menu_header — fzf header: title + inline spinner while scan runs.
tui_games_menu_header() {
	local base=${TUI_GAMES_FZF_HEADER_BASE:-Games}
	local frame st
	if tui_games_cache_refreshing; then
		frame="$(tui_games_cache_spinner_frame)"
		if cli_uses_color; then
			printf '%s %s %s' "$base" "$(cli_cyan "$frame")" "$(cli_dim 'Refreshing game list…')"
		else
			printf '%s %s Refreshing game list…' "$base" "$frame"
		fi
		return 0
	fi
	if tui_games_cache_loading; then
		frame="$(tui_games_cache_spinner_frame)"
		if cli_uses_color; then
			printf '%s %s %s' "$base" "$(cli_cyan "$frame")" "$(cli_dim 'Loading installed games…')"
		else
			printf '%s %s Loading installed games…' "$base" "$frame"
		fi
		return 0
	fi
	st="$(tui_games_cache_status)"
	if [[ "$st" == error ]] && ! tui_games_cache_has_lines; then
		if cli_uses_color; then
			printf '%s %s' "$base" "$(cli_dim '(game list unavailable)')"
		else
			printf '%s (game list unavailable)' "$base"
		fi
		return 0
	fi
	printf '%s' "$base"
}

# tui_games_menu_footer — fzf footer: hints + spinner or live game count.
tui_games_menu_footer() {
	local hint frame count st
	hint="$(tui_fzf_footer_for menu)"
	if tui_games_cache_busy; then
		count="$(tui_games_cache_count)"
		frame="$(tui_games_cache_spinner_frame)"
		if tui_games_cache_refreshing; then
			if cli_uses_color; then
				printf '%s │ filter:%s · %s %s · %s cached' \
					"$hint" "${TUI_GAME_FILTER:-all}" \
					"$(cli_cyan "$frame")" "$(cli_dim 'refreshing…')" "${count:-0}"
			else
				printf '%s │ filter:%s · %s refreshing… · %s cached' \
					"$hint" "${TUI_GAME_FILTER:-all}" "$frame" "${count:-0}"
			fi
		else
			if cli_uses_color; then
				printf '%s │ filter:%s · %s %s' \
					"$hint" "${TUI_GAME_FILTER:-all}" \
					"$(cli_cyan "$frame")" "$(cli_dim 'loading games…')"
			else
				printf '%s │ filter:%s · %s loading games…' "$hint" "${TUI_GAME_FILTER:-all}" "$frame"
			fi
		fi
		return 0
	fi
	st="$(tui_games_cache_status)"
	if [[ "$st" == error ]] && ! tui_games_cache_has_lines; then
		if cli_uses_color; then
			printf '%s │ filter:%s · %s' \
				"$hint" "${TUI_GAME_FILTER:-all}" "$(cli_dim 'load failed · see loader.log')"
		else
			printf '%s │ filter:%s · load failed · see loader.log' "$hint" "${TUI_GAME_FILTER:-all}"
		fi
		return 0
	fi
	count="$(tui_games_cache_count)"
	printf '%s │ filter:%s · %s games' "$hint" "${TUI_GAME_FILTER:-all}" "${count:-0}"
}
