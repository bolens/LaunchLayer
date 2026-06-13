# shellcheck shell=bash
# lib/completions/core.sh

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
# zsh_profile_path — Respect ZDOTDIR for non-destructive zsh profile edits.
zsh_profile_path() {
	echo "${ZDOTDIR:-$HOME}/.zshrc"
}

# pwsh_profile_path — PowerShell profile path (Linux/macOS default layout).
pwsh_profile_path() {
	echo "${XDG_CONFIG_HOME:-$HOME/.config}/powershell/Microsoft.PowerShell_profile.ps1"
}

# nu_completions_dir — Nushell auto-loaded completions directory.
nu_completions_dir() {
	echo "${XDG_CONFIG_HOME:-$HOME/.config}/nushell/completions"
}
