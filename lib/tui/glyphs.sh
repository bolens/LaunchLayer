# shellcheck shell=bash
# lib/tui/glyphs.sh — Compact status glyphs for TUI rows, footers, and menus.
#
# Palette (semantic, not alarmist):
#   ●  active / yes / enabled / ok
#   ○  inactive / no / off (dim; red only when explicitly “bad”)
#   ◑  partial / installed-but-idle
#   ⚠  caution (doctor issues, low vm, partial completions)
#   ✕  error / validation failure
#   —  neutral / n/a

[[ -n "${LAUNCHLAYER_TUI_GLYPHS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_GLYPHS_LOADED=1

if [[ -z "${LAUNCHLAYER_CLI_COLORS_LOADED:-}" ]]; then
	# shellcheck source=../cli/colors.sh
	source "${LIB_DIR:?}/cli/colors.sh"
fi

TUI_GLYPH_OK=$'●'
TUI_GLYPH_OFF=$'○'
TUI_GLYPH_WARN=$'⚠'
TUI_GLYPH_MID=$'◑'
TUI_GLYPH_BAD=$'✕'
TUI_GLYPH_NA=$'—'
TUI_GAME_BOOL_COL_WIDTH=2

# Legacy aliases (tests, no-color fallbacks).
TUI_GLYPH_NO=$TUI_GLYPH_BAD

# tui_glyph_paint — Apply semantic color to a glyph character.
tui_glyph_paint() {
	local glyph=$1 role=${2:-muted}
	case "$role" in
		ok) cli_green "$glyph" ;;
		off) cli_dim "$glyph" ;;
		warn) cli_yellow "$glyph" ;;
		bad) cli_red "$glyph" ;;
		mid) cli_cyan "$glyph" ;;
		muted) cli_dim "$glyph" ;;
		*) printf '%s' "$glyph" ;;
	esac
}

tui_glyph_ok() {
	tui_glyph_paint "$TUI_GLYPH_OK" ok
}

tui_glyph_off() {
	tui_glyph_paint "$TUI_GLYPH_OFF" off
}

tui_glyph_warn() {
	tui_glyph_paint "$TUI_GLYPH_WARN" warn
}

tui_glyph_mid() {
	tui_glyph_paint "$TUI_GLYPH_MID" mid
}

tui_glyph_bad() {
	tui_glyph_paint "$TUI_GLYPH_BAD" bad
}

tui_glyph_na() {
	tui_glyph_paint "$TUI_GLYPH_NA" muted
}

# tui_glyph_no — Alias for error glyph (validation, hard failures).
tui_glyph_no() {
	tui_glyph_bad
}

# tui_glyph_yesno — yes/no as ● / ○ (no is dim, not red).
tui_glyph_yesno() {
	case "${1,,}" in
		yes|true|1|on|ok|enabled|running)
			tui_glyph_ok
			;;
		no|false|0|off|disabled|dead|missing)
			tui_glyph_off
			;;
		low)
			tui_glyph_warn
			;;
		*)
			[[ "$1" == "-" ]] && tui_glyph_na && return 0
			printf '%s' "$1"
			;;
	esac
}

# tui_glyph_timer — ● enabled · ◑ installed · ○ off.
tui_glyph_timer() {
	case "${1,,}" in
		enabled|yes|on)
			tui_glyph_ok
			;;
		installed)
			tui_glyph_mid
			;;
		off|no|disabled|not_installed)
			tui_glyph_off
			;;
		*)
			printf '%s' "$1"
			;;
	esac
}

# tui_glyph_vm — ● ok · ⚠ low.
tui_glyph_vm() {
	case "${1,,}" in
		ok) tui_glyph_ok ;;
		low) tui_glyph_warn ;;
		*) printf '%s' "$1" ;;
	esac
}

# tui_glyph_doctor — ● clean · ⚠N issues.
tui_glyph_doctor() {
	local issues=${1:-0}
	if [[ "$issues" =~ ^[0-9]+$ ]] && (( issues == 0 )); then
		tui_glyph_ok
		return 0
	fi
	if cli_uses_color; then
		printf '%s%s' "$(tui_glyph_warn)" "$(cli_yellow "$issues")"
	else
		printf '%s%s' "$TUI_GLYPH_WARN" "$issues"
	fi
}

# tui_glyph_bool_onoff — ● on · ○ off (override off = red ○).
tui_glyph_bool_onoff() {
	local val=$1 dim=${2:-0}
	if tui_bool_on "$val"; then
		if [[ "$dim" == 1 ]]; then
			tui_glyph_paint "$TUI_GLYPH_OK" off
		else
			tui_glyph_ok
		fi
	else
		if [[ "$dim" == 1 ]]; then
			tui_glyph_off
		else
			tui_glyph_paint "$TUI_GLYPH_OFF" bad
		fi
	fi
}

# tui_glyph_pref — ● on · ○ off for 0/1 prefs.
tui_glyph_pref() {
	[[ "${1:-0}" == "1" ]] && tui_glyph_ok || tui_glyph_off
}

# tui_glyph_hub_brief — Hub connection line for banners/footers.
tui_glyph_hub_brief() {
	local fp=${1:-minimal} connected=${2:-0}
	if [[ "$connected" == "1" ]]; then
		printf '%s url · fp:%s' "$(tui_glyph_ok)" "$fp"
	else
		printf '%s fp:%s' "$(tui_glyph_off)" "$fp"
	fi
}

# tui_glyph_ac_type — Anticheat column: — when unset, else keep label.
tui_glyph_ac_type() {
	local ac=${1:-}
	[[ -z "$ac" || "$ac" == "-" ]] && {
		tui_glyph_na
		return 0
	}
	printf '%s' "$ac"
}
