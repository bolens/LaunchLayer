# shellcheck shell=bash
# lib/completions/helpers.sh

LAUNCHLAYER_COMPLETION_SHELLS=(bash zsh fish nu pwsh osh)

# completions_shell_is_enabled — True when a shell's completions are fully enabled.
completions_shell_is_enabled() {
	local shell=$1 status=""
	shell="$(normalize_completions_shell "$shell")"
	case "$shell" in
		bash) status="$(completions_bash_status)" ;;
		zsh) status="$(completions_zsh_status)" ;;
		fish) status="$(completions_fish_status)" ;;
		nu) status="$(completions_nu_status)" ;;
		pwsh) status="$(completions_pwsh_status)" ;;
		*) return 1 ;;
	esac
	[[ "$status" == *": enabled"* ]]
}

# completions_shell_status_brief — One of: enabled, partial, disabled.
completions_shell_status_brief() {
	local shell=$1 status=""
	shell="$(normalize_completions_shell "$shell")"
	case "$shell" in
		bash) status="$(completions_bash_status)" ;;
		zsh) status="$(completions_zsh_status)" ;;
		fish) status="$(completions_fish_status)" ;;
		nu) status="$(completions_nu_status)" ;;
		pwsh) status="$(completions_pwsh_status)" ;;
		*) echo unknown; return 1 ;;
	esac
	if [[ "$status" == *": enabled"* ]]; then
		echo enabled
	elif [[ "$status" == *"partially installed"* ]]; then
		echo partial
	else
		echo disabled
	fi
}

# normalize_completions_shell — Map login-shell aliases to supported completion targets.
normalize_completions_shell() {
	local shell=$1
	case "$shell" in
		osh) echo bash ;;
		powershell|pwsh) echo pwsh ;;
		nu|nushell) echo nu ;;
		*) echo "$shell" ;;
	esac
}
