# shellcheck shell=bash
# lib/tui/help.sh — TUI keyboard shortcut reference and help overlay.

[[ -n "${LAUNCHLAYER_TUI_HELP_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_HELP_LOADED=1

# tui_help_text — Keyboard shortcut reference by context.
tui_help_text() {
	local topic=${1:-menu}
	case "$topic" in
		game)
			cat <<'EOF'
Game picker
  Type              Fuzzy-filter installed games
  ↑ / ↓             Move selection
  Home / End        Jump to first / last game
  PgUp / PgDn       Page up / down the list
  Alt-S             Toggle relevance sort (default: recent-first order)
  Enter             Open selected game
  Ctrl-E            Edit per-game config in $EDITOR
  Ctrl-D            Dry-run launch chain (shown in preview)
  ?                 Show this help
  Esc               Cancel

Preview pane shows INCLUDE, toggles (* = override), and effective config.
* rows were played recently (from launch.log).

Columns: * (recent) · APPID · CFG · NAT · AC · ENGINE · NAME
  ● configured / native   ○ not   — no anticheat flag
  eac / battleye / listed shown as text when detected.
Long names truncate with … when the list pane is narrow.
EOF
			;;
		multi)
			cat <<'EOF'
Multi-select
  Tab               Toggle current item
  Shift-Tab         Toggle and move up
  ↑ / ↓             Move selection
  Alt-S             Toggle relevance sort
  Enter             Confirm selection
  ?                 Show this help
  Esc               Cancel
EOF
			;;
		confirm)
			cat <<'EOF'
Confirm
  Enter             Accept highlighted choice
  Esc               Cancel (same as No)
  ?                 Show this help
EOF
			;;
		main)
			cat <<'EOF'
Main menu
  Type              Filter hubs and actions
  ↑ / ↓             Move selection
  Enter             Open hub or run action
  ?                 Show this help
  Esc               Quit LaunchLayer TUI

Footer shows live filter, doctor, vm, backup, and hub status.
Right pane: status lines plus recent command output.
Status glyphs: ● ok/active · ○ off · ◑ idle/partial · ⚠ caution · ✕ error · — n/a
Optional rows: Doctor ⚠N, Resume last hub.
Ctrl-D opens doctor when issues are reported (footer hint appears then).
EOF
			;;
		actions)
			cat <<'EOF'
Game actions
  Type              Filter actions
  ↑ / ↓             Move selection
  Enter             Run highlighted action
  Ctrl-D            Dry-run launch chain (preview pane)
  ?                 Show this help
  Esc               Back to games menu

Preview pane shows the same summary as the game picker.
Grouped rows: View · Edit · Manage · Hub.
EOF
			;;
		toggles)
			cat <<'EOF'
Quick toggles
  Enter             Flip the highlighted setting (per-game override)
  ↑ / ↓             Move selection
  ?                 Show this help
  Esc               Back to game actions

Green/red ●/○ = per-game override in GAMES_DIR/<AppID>.env
Dim ○ = inherited layer. Override off uses red ○.
◐ = DLSS_SWAPPER=dll (cycle: 0 → 1 → dll → 0)
"assist" suffix = path/env helper only (Geo11, Flat2VR, SBS, Depth3D)

String / enum keys (FRAME_RATE, OVERRIDE_PROTON, VRR, specialty runtime, …)
live under Advanced config. Adaptive Sync is Advanced (not a boolean flip).
SKIF_LAUNCH=1 one-shots SKIF when SKIF_PATH is set. CRASH_GUESS=1 defaults
to a 5s retry prompt (set CRASH_GUESS_TIMEOUT to change).
FWS is an Advanced alias of FLAWLESS_WIDESCREEN — prefer the long name here.
EOF
			;;
		advanced)
			cat <<'EOF'
Advanced config
  Enter             Open a key group (Proton, Gamescope, …)
  Within a group    Edit KEY — enums use a picker; others prompt
                    empty keeps, "-" clears
  Esc               Back

Pickers: DLSS_SWAPPER, SPECIALTY_RUNTIME, REPLAY_TOOL,
GAMESCOPE_FILTER, GAMESCOPE_ADAPTIVE_SYNC (VRR empty|auto|0|1).

Every non-boolean launch.d key is reachable here (or via Open in $EDITOR).
EOF
			;;
		*)
			cat <<'EOF'
Navigation
  Type              Fuzzy-filter the list
  ↑ / ↓             Move selection
  Home / End        Jump to first / last item
  PgUp / PgDn       Page up / down the list
  Alt-S             Toggle relevance sort
  Enter             Confirm
  ?                 Show this help
  Esc               Go back / cancel

Breadcrumb headers use › between menu levels (Games › Title › Actions).
Quick toggles: green/red = per-game override, dim = inherited layer.
EOF
			;;
	esac
}

# tui_show_help_overlay — Read-only fzf panel for keyboard shortcuts.
tui_show_help_overlay() {
	local topic=${1:-menu}
	local -a fzf_args=()
	tui_require_tty || return 1
	fzf_args=(
		--header="$(tui_crumb_label "Keyboard shortcuts")"
		--header-first
		--footer="$(tui_fzf_footer_for help)"
		--height=70%
		--border
		--layout=reverse
		--bind esc:abort
		--pointer=""
		--phony
		--no-sort
	)
	if cli_uses_color; then
		fzf_args+=(--ansi)
	fi
	if tui_has_fzf; then
		fzf_args+=(--header-border --footer-border)
	fi
	fzf "${fzf_args[@]}" <<< "$(tui_help_text "$topic")" </dev/tty >/dev/tty 2>&1
}

# tui_fzf_help_bind — fzf --bind value for ? help overlay.
tui_fzf_help_bind() {
	local topic=${1:-menu} script_q
	script_q="$(printf '%q' "$LAUNCHLAYER_MAIN_SCRIPT")"
	printf '?:execute(%s --tui-help %s < /dev/tty >/dev/tty 2>&1)+clear-query' "$script_q" "$topic"
}
