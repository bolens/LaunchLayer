# shellcheck shell=bash
# lib/completions/cli.sh
# completions_show_status — Print completion state for all shells.
completions_show_status() {
	local json=${1:-0}
	if [[ "$json" == "1" ]]; then
		completions_status_json
		return 0
	fi
	echo "=== launchlayer completions ==="
	echo "config_dir=$CONFIG_DIR"
	echo "state_dir=$(completions_state_dir)"
	echo "login_shell=$(detect_login_shell_name)"
	echo
	completions_bash_status
	completions_zsh_status
	completions_fish_status
	completions_nu_status
	completions_pwsh_status
	echo "osh: uses bash completions (enable with --shell bash or --shell osh)"
	echo
	echo "Enable:  $LAUNCHLAYER_MAIN_SCRIPT --completions enable [--shell bash|zsh|fish|nu|pwsh|osh|all]"
	echo "         (enable/disable default to login shell: $(detect_login_shell_name))"
	echo "Print:   $LAUNCHLAYER_MAIN_SCRIPT --completions print --shell bash|zsh|fish|nu|pwsh|osh"
	echo "Disable: $LAUNCHLAYER_MAIN_SCRIPT --completions disable [--shell bash|zsh|fish|nu|pwsh|osh|all]"
}

# completions_source_file — Path to the bundled completion script for a shell.
completions_source_file() {
	local shell=$1
	shell="$(normalize_completions_shell "$shell")"
	case "$shell" in
		bash) echo "$(launchlayer_share_dir)/completions/launchlayer.bash" ;;
		zsh) echo "$(launchlayer_share_dir)/completions/_launchlayer" ;;
		fish) echo "$(launchlayer_share_dir)/completions/launchlayer.fish" ;;
		nu) echo "$(launchlayer_share_dir)/completions/launchlayer.nu" ;;
		pwsh) echo "$(launchlayer_share_dir)/completions/launchlayer.ps1" ;;
		*) return 1 ;;
	esac
}

# completions_print — Write completion script to stdout (for Nix/packaging).
completions_print() {
	local shell=$1 file script_dir
	file="$(completions_source_file "$shell")" || {
		echo "Unknown shell: $shell (use bash, zsh, fish, nu, pwsh, or osh)" >&2
		return 1
	}
	[[ -f "$file" ]] || {
		echo "Completion file not found: $file" >&2
		return 1
	}
	script_dir="$(dirname "${LAUNCHLAYER_MAIN_SCRIPT:-$CONFIG_DIR/launchlayer}")"
	cat <<EOF
# launchlayer shell completions ($shell)
# Printed by: ${LAUNCHLAYER_MAIN_SCRIPT:-launchlayer} --completions print --shell $shell
export LAUNCHLAYER_CONFIG_DIR='$CONFIG_DIR'
export LAUNCHLAYER_SCRIPT_DIR='$script_dir'

EOF
	cat "$file"
}

# remove_legacy_completions_install — Drop pre-rename completion symlinks we managed.
remove_legacy_completions_install() {
	local link_dir link fish_link
	link_dir="$(bash_completion_dir 2>/dev/null || true)"
	if [[ -n "$link_dir" ]]; then
		link="$link_dir/steam-game-launch-settings"
		if [[ -L "$link" ]]; then
			rm -f "$link"
			echo "Removed legacy bash completion symlink: $link"
		fi
	fi
	fish_link="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/steam-game-launch-settings.fish"
	if [[ -L "$fish_link" ]]; then
		rm -f "$fish_link"
		echo "Removed legacy fish completion symlink: $fish_link"
	fi
}

# completions_enable — Enable completions for selected shells.
completions_enable() {
	local shell=${1:-$(detect_login_shell_name)}
	shell="$(normalize_completions_shell "$shell")"
	remove_legacy_completions_install
	case "$shell" in
		bash) completions_enable_bash ;;
		zsh) completions_enable_zsh ;;
		fish) completions_enable_fish ;;
		nu) completions_enable_nu ;;
		pwsh) completions_enable_pwsh ;;
		all)
			completions_enable_bash
			completions_enable_zsh
			completions_enable_fish
			completions_enable_nu
			completions_enable_pwsh
			;;
		*)
			echo "Unknown shell: $shell (use bash, zsh, fish, nu, pwsh, osh, or all)" >&2
			return 1
			;;
	esac
}

# completions_disable — Disable completions for selected shells.
completions_disable() {
	local shell=${1:-$(detect_login_shell_name)}
	shell="$(normalize_completions_shell "$shell")"
	case "$shell" in
		bash) completions_disable_bash ;;
		zsh) completions_disable_zsh ;;
		fish) completions_disable_fish ;;
		nu) completions_disable_nu ;;
		pwsh) completions_disable_pwsh ;;
		all)
			completions_disable_bash
			completions_disable_zsh
			completions_disable_fish
			completions_disable_nu
			completions_disable_pwsh
			;;
		*)
			echo "Unknown shell: $shell (use bash, zsh, fish, nu, pwsh, osh, or all)" >&2
			return 1
			;;
	esac
}

# handle_completions_subcommand — Dispatch --completions status|enable|disable|print.
handle_completions_subcommand() {
	local action=status shell="" json=0
	case "${1:-status}" in
		status|enable|disable|print)
			action=$1
			shift
			;;
	esac
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--shell)
				shell=${2:-}
				shift 2
				;;
			--json)
				json=1
				shift
				;;
			*)
				echo "Usage: $0 --completions [status|enable|disable|print] [--shell bash|zsh|fish|nu|pwsh|osh|all] [--json]" >&2
				return 1
				;;
		esac
	done
	case "$action" in
		print)
			[[ -n "$shell" ]] || {
				echo "Usage: $0 --completions print --shell bash|zsh|fish|nu|pwsh|osh" >&2
				return 1
			}
			[[ "$shell" != all ]] || {
				echo "Usage: $0 --completions print --shell bash|zsh|fish|nu|pwsh|osh" >&2
				return 1
			}
			completions_print "$shell"
			;;
		status|enable|disable)
			[[ -n "$shell" ]] || {
				if [[ "$action" == status ]]; then
					shell=all
				else
					shell="$(normalize_completions_shell "$(detect_login_shell_name)")"
				fi
			}
			case "$action" in
				status) completions_show_status "$json" ;;
				enable) completions_enable "$shell" ;;
				disable) completions_disable "$shell" ;;
			esac
			;;
		*)
			echo "Usage: $0 --completions [status|enable|disable|print] [--shell bash|zsh|fish|nu|pwsh|osh|all] [--json]" >&2
			return 1
			;;
	esac
}
