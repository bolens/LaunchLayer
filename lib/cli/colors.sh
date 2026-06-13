# shellcheck shell=bash
# lib/cli/colors.sh — ANSI styling for CLI and TUI output.

[[ -n "${LAUNCHLAYER_CLI_COLORS_LOADED:-}" ]] && return 0
LAUNCHLAYER_CLI_COLORS_LOADED=1

# cli_uses_color — True when stderr is a TTY and NO_COLOR is unset.
cli_uses_color() {
	[[ -t 2 && -z "${NO_COLOR:-}" ]]
}

# cli_bold / cli_dim — Optional ANSI styling for help output.
cli_bold() {
	if cli_uses_color; then
		printf '\033[1m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

cli_dim() {
	if cli_uses_color; then
		printf '\033[2m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

# cli_green / cli_yellow / cli_red / cli_cyan — Semantic ANSI colors for status output.
cli_green() {
	if cli_uses_color; then
		printf '\033[32m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

cli_yellow() {
	if cli_uses_color; then
		printf '\033[33m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

cli_red() {
	if cli_uses_color; then
		printf '\033[31m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

cli_cyan() {
	if cli_uses_color; then
		printf '\033[36m%s\033[0m' "$*"
	else
		printf '%s' "$*"
	fi
}

# cli_yesno — Colorized yes/no (and common variants).
cli_yesno() {
	case "${1,,}" in
		yes|true|1|ok|enabled|on|running)
			cli_green "$1"
			;;
		no|false|0|off|disabled|dead|missing|unknown|unset)
			cli_yellow "$1"
			;;
		needs_override|*)
			cli_red "$1"
			;;
	esac
}

# cli_section — Bold section heading with trailing blank line.
cli_section() {
	printf '\n'
	cli_bold "$1"
	printf '\n'
}
