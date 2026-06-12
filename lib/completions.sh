# shellcheck shell=bash
# shellcheck source=common.sh
# lib/completions.sh — Enable/disable shell completions without destructive profile edits.

[[ -n "${LAUNCHLAYER_COMPLETIONS_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMPLETIONS_LOADED=1

COMPLETIONS_MARKER_BEGIN='# >>> launchlayer completions >>>'
COMPLETIONS_MARKER_END='# <<< launchlayer completions <<<'

# completions_state_dir — Persistent install metadata under XDG config.
completions_state_dir() {
	echo "${XDG_CONFIG_HOME:-$HOME/.config}/launchlayer"
}

# completions_manifest_file — Records install method per shell.
completions_manifest_file() {
	echo "$(completions_state_dir)/completions.env"
}

# update_manifest_key — Set or replace one key in the completions manifest.
update_manifest_key() {
	local key=$1 value=$2 manifest tmp
	manifest="$(completions_manifest_file)"
	mkdir -p "$(completions_state_dir)"
	tmp="${manifest}.tmp"
	if [[ -f "$manifest" ]]; then
		grep -v "^${key}=" "$manifest" > "$tmp" || true
	else
		: > "$tmp"
	fi
	printf '%s=%q\n' "$key" "$value" >> "$tmp"
	mv "$tmp" "$manifest"
}

# remove_manifest_key — Remove one key from the completions manifest.
remove_manifest_key() {
	local key=$1 manifest
	manifest="$(completions_manifest_file)"
	[[ -f "$manifest" ]] || return 0
	grep -v "^${key}=" "$manifest" > "${manifest}.tmp" || true
	mv "${manifest}.tmp" "$manifest"
}

# write_completions_manifest — Record CONFIG_DIR and per-shell install method.
write_completions_manifest() {
	update_manifest_key LAUNCHLAYER_CONFIG_DIR "$CONFIG_DIR"
	update_manifest_key "$1" "$2"
}

# read_completions_manifest — Print value for a manifest key.
read_completions_manifest() {
	local key=$1 manifest="${2:-$(completions_manifest_file)}"
	[[ -f "$manifest" ]] || return 1
	grep -m1 "^${key}=" "$manifest" 2>/dev/null | cut -d= -f2- | tr -d "'\""
}

# profile_has_completions_block — True when a marked block exists in profile.
profile_has_completions_block() {
	local profile=$1
	[[ -f "$profile" ]] || return 1
	grep -qF "$COMPLETIONS_MARKER_BEGIN" "$profile"
}

# profile_remove_completions_block — Remove only our marked block from a profile.
profile_remove_completions_block() {
	local profile=$1
	[[ -f "$profile" ]] || return 0
	profile_has_completions_block "$profile" || return 0
	awk -v begin="$COMPLETIONS_MARKER_BEGIN" -v end="$COMPLETIONS_MARKER_END" '
		$0 == begin { skip=1; next }
		$0 == end { skip=0; next }
		!skip { print }
	' "$profile" > "${profile}.launchlayer.tmp"
	mv "${profile}.launchlayer.tmp" "$profile"
}

# profile_append_completions_block — Append a single-source line inside marked block.
profile_append_completions_block() {
	local profile=$1 drop_in=$2
	mkdir -p "$(dirname "$profile")"
	[[ -f "$profile" ]] || touch "$profile"
	if profile_has_completions_block "$profile"; then
		return 0
	fi
	cat >> "$profile" <<EOF

$COMPLETIONS_MARKER_BEGIN
[[ -f "$drop_in" ]] && source "$drop_in"
$COMPLETIONS_MARKER_END
EOF
}

# symlink_points_to — True when path is a symlink to expected target.
symlink_points_to() {
	local link=$1 expected=$2 actual=""
	[[ -L "$link" ]] || return 1
	actual="$(realpath_portable "$link" 2>/dev/null || readlink "$link" 2>/dev/null || true)"
	expected="$(realpath_portable "$expected" 2>/dev/null || echo "$expected")"
	[[ "$actual" == "$expected" ]]
}

# safe_install_symlink — Create or refresh a symlink we manage.
safe_install_symlink() {
	local target=$1 link=$2
	mkdir -p "$(dirname "$link")"
	if [[ -L "$link" ]]; then
		if symlink_points_to "$link" "$target"; then
			return 0
		fi
		if [[ -e "$link" || -L "$link" ]]; then
			echo "Refusing to replace unrelated symlink: $link" >&2
			return 1
		fi
	fi
	if [[ -e "$link" && ! -L "$link" ]]; then
		echo "Refusing to replace existing file: $link" >&2
		return 1
	fi
	ln -sfn "$target" "$link"
}

# safe_remove_symlink — Remove symlink only when it points at our target.
safe_remove_symlink() {
	local link=$1 expected=$2
	[[ -L "$link" ]] || return 0
	if symlink_points_to "$link" "$expected"; then
		rm -f "$link"
	fi
}

# zsh_profile_path — Respect ZDOTDIR for non-destructive zsh profile edits.
zsh_profile_path() {
	echo "${ZDOTDIR:-$HOME}/.zshrc"
}

# write_completions_dropin — Write a managed drop-in that sources repo completions.
write_completions_dropin() {
	local shell_name=$1 dest=$2 source_file=$3 script_dir
	mkdir -p "$(completions_state_dir)"
	script_dir="$(dirname "${LAUNCHLAYER_MAIN_SCRIPT:-$CONFIG_DIR/launchlayer}")"
	cat > "$dest" <<EOF
# Managed by launchlayer — safe to remove via --completions disable.
export LAUNCHLAYER_CONFIG_DIR='$CONFIG_DIR'
export LAUNCHLAYER_SCRIPT_DIR='$script_dir'
source '$source_file'
EOF
	echo "Wrote $dest ($shell_name)"
}

# bash_completion_dir — User-writable bash-completion completions directory.
bash_completion_dir() {
	echo "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
}

# completions_enable_bash — Enable bash completions (symlink preferred, profile fallback).
completions_enable_bash() {
	local drop_in link_dir link target
	drop_in="$(completions_state_dir)/completions.bash"
	target="$CONFIG_DIR/completions/launchlayer.bash"
	write_completions_dropin bash "$drop_in" "$target"

	link_dir="$(bash_completion_dir)"
	mkdir -p "$link_dir"
	link="$link_dir/launchlayer"
	if safe_install_symlink "$target" "$link"; then
		write_completions_manifest BASH_METHOD "bash-completion:$link"
		echo "bash: enabled via bash-completion ($link)"
		return 0
	fi

	profile_append_completions_block "$HOME/.bashrc" "$drop_in"
	write_completions_manifest BASH_METHOD "profile:$HOME/.bashrc"
	echo "bash: enabled via managed block in ~/.bashrc"
}

# completions_disable_bash — Disable bash completions; only remove what we installed.
completions_disable_bash() {
	local method="" drop_in link path
	method="$(read_completions_manifest BASH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.bash"

	case "$method" in
		bash-completion:*)
			link="${method#bash-completion:}"
			safe_remove_symlink "$link" "$CONFIG_DIR/completions/launchlayer.bash"
			;;
		profile:*)
			path="${method#profile:}"
			profile_remove_completions_block "$path"
			;;
	esac

	if [[ -z "$method" ]]; then
		link_dir="$(bash_completion_dir 2>/dev/null || true)"
		if [[ -n "$link_dir" ]]; then
			safe_remove_symlink "$link_dir/launchlayer" \
				"$CONFIG_DIR/completions/launchlayer.bash"
		fi
		profile_remove_completions_block "$HOME/.bashrc"
	fi

	rm -f "$drop_in"
	remove_manifest_key BASH_METHOD
	echo "bash: disabled"
}

# completions_bash_status — Print bash completion install state.
completions_bash_status() {
	local method="" drop_in link
	method="$(read_completions_manifest BASH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.bash"
	if [[ "$method" == bash-completion:* ]]; then
		link="${method#bash-completion:}"
		if [[ -L "$link" ]] && symlink_points_to "$link" "$CONFIG_DIR/completions/launchlayer.bash"; then
			echo "bash: enabled (bash-completion → $link)"
			return 0
		fi
	elif [[ "$method" == profile:* ]]; then
		if profile_has_completions_block "${method#profile:}"; then
			echo "bash: enabled (profile block → ${method#profile:})"
			return 0
		fi
	fi

	if [[ -f "$drop_in" ]]; then
		echo "bash: partially installed (drop-in present, reload shell or re-run enable)"
		return 0
	fi
	echo "bash: disabled"
}

# completions_enable_zsh — Enable zsh completions via profile drop-in.
completions_enable_zsh() {
	local drop_in target zshrc
	drop_in="$(completions_state_dir)/completions.zsh"
	target="$CONFIG_DIR/completions/_launchlayer"
	zshrc="$(zsh_profile_path)"
	write_completions_dropin zsh "$drop_in" "$target"
	profile_append_completions_block "$zshrc" "$drop_in"
	write_completions_manifest ZSH_METHOD "profile:$zshrc"
	echo "zsh: enabled via managed block in $zshrc"
}

# completions_disable_zsh — Disable zsh completions.
completions_disable_zsh() {
	local method="" drop_in path
	method="$(read_completions_manifest ZSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.zsh"
	path="${method#profile:}"
	[[ -n "$path" && "$method" == profile:* ]] || path="$(zsh_profile_path)"
	profile_remove_completions_block "$path"
	rm -f "$drop_in"
	remove_manifest_key ZSH_METHOD
	echo "zsh: disabled"
}

# completions_zsh_status — Print zsh completion install state.
completions_zsh_status() {
	local method="" drop_in
	method="$(read_completions_manifest ZSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.zsh"
	if [[ "$method" == profile:* ]] && profile_has_completions_block "${method#profile:}"; then
		echo "zsh: enabled (profile block → ${method#profile:})"
	elif [[ -f "$drop_in" ]]; then
		echo "zsh: partially installed (drop-in present, reload shell or re-run enable)"
	else
		echo "zsh: disabled"
	fi
}

# completions_status_json — JSON status for all shells.
completions_status_json() {
	local bash_s zsh_s fish_s
	bash_s="$(completions_bash_status | sed 's/^bash: //')"
	zsh_s="$(completions_zsh_status | sed 's/^zsh: //')"
	fish_s="$(completions_fish_status | sed 's/^fish: //')"
	printf '{"config_dir":%s,"bash":%s,"zsh":%s,"fish":%s}\n' \
		"$(json_string "$CONFIG_DIR")" \
		"$(json_string "$bash_s")" \
		"$(json_string "$zsh_s")" \
		"$(json_string "$fish_s")"
}

# completions_enable_fish — Enable fish completions via completions dir symlink.
completions_enable_fish() {
	local fish_dir link target
	fish_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
	target="$CONFIG_DIR/completions/launchlayer.fish"
	link="$fish_dir/launchlayer.fish"
	safe_install_symlink "$target" "$link"
	write_completions_manifest FISH_METHOD "symlink:$link"
	echo "fish: enabled via symlink ($link)"
}

# completions_disable_fish — Disable fish completions.
completions_disable_fish() {
	local method="" link
	method="$(read_completions_manifest FISH_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/launchlayer.fish"
	safe_remove_symlink "$link" "$CONFIG_DIR/completions/launchlayer.fish"
	remove_manifest_key FISH_METHOD
	echo "fish: disabled"
}

# completions_fish_status — Print fish completion install state.
completions_fish_status() {
	local method="" link
	method="$(read_completions_manifest FISH_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/launchlayer.fish"
	if [[ -L "$link" ]] && symlink_points_to "$link" "$CONFIG_DIR/completions/launchlayer.fish"; then
		echo "fish: enabled (symlink → $link)"
	else
		echo "fish: disabled"
	fi
}

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
	echo
	echo "Enable:  $LAUNCHLAYER_MAIN_SCRIPT --completions enable [--shell bash|zsh|fish|all]"
	echo "         (enable/disable default to login shell: $(detect_login_shell_name))"
	echo "Print:   $LAUNCHLAYER_MAIN_SCRIPT --completions print --shell bash|zsh|fish"
	echo "Disable: $LAUNCHLAYER_MAIN_SCRIPT --completions disable [--shell bash|zsh|fish|all]"
}

# completions_source_file — Path to the bundled completion script for a shell.
completions_source_file() {
	local shell=$1
	case "$shell" in
		bash) echo "$CONFIG_DIR/completions/launchlayer.bash" ;;
		zsh) echo "$CONFIG_DIR/completions/_launchlayer" ;;
		fish) echo "$CONFIG_DIR/completions/launchlayer.fish" ;;
		*) return 1 ;;
	esac
}

# completions_print — Write completion script to stdout (for Nix/packaging).
completions_print() {
	local shell=$1 file script_dir
	file="$(completions_source_file "$shell")" || {
		echo "Unknown shell: $shell (use bash, zsh, or fish)" >&2
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
	remove_legacy_completions_install
	case "$shell" in
		bash) completions_enable_bash ;;
		zsh) completions_enable_zsh ;;
		fish) completions_enable_fish ;;
		all)
			completions_enable_bash
			completions_enable_zsh
			completions_enable_fish
			;;
		*)
			echo "Unknown shell: $shell (use bash, zsh, fish, or all)" >&2
			return 1
			;;
	esac
}

# completions_disable — Disable completions for selected shells.
completions_disable() {
	local shell=${1:-$(detect_login_shell_name)}
	case "$shell" in
		bash) completions_disable_bash ;;
		zsh) completions_disable_zsh ;;
		fish) completions_disable_fish ;;
		all)
			completions_disable_bash
			completions_disable_zsh
			completions_disable_fish
			;;
		*)
			echo "Unknown shell: $shell (use bash, zsh, fish, or all)" >&2
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
				echo "Usage: $0 --completions [status|enable|disable|print] [--shell bash|zsh|fish|all] [--json]" >&2
				return 1
				;;
		esac
	done
	case "$action" in
		print)
			[[ -n "$shell" ]] || {
				echo "Usage: $0 --completions print --shell bash|zsh|fish" >&2
				return 1
			}
			[[ "$shell" != all ]] || {
				echo "Usage: $0 --completions print --shell bash|zsh|fish" >&2
				return 1
			}
			completions_print "$shell"
			;;
		status|enable|disable)
			[[ -n "$shell" ]] || {
				if [[ "$action" == status ]]; then
					shell=all
				else
					shell="$(detect_login_shell_name)"
				fi
			}
			case "$action" in
				status) completions_show_status "$json" ;;
				enable) completions_enable "$shell" ;;
				disable) completions_disable "$shell" ;;
			esac
			;;
		*)
			echo "Usage: $0 --completions [status|enable|disable|print] [--shell bash|zsh|fish|all] [--json]" >&2
			return 1
			;;
	esac
}
