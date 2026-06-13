# shellcheck shell=bash
# lib/setup/onboard.sh

# print_steam_launch_option — Steam launch options string for this install.
print_steam_launch_option() {
	printf '"%s" %%command%%\n' "$LAUNCHLAYER_MAIN_SCRIPT"
}

# remove_legacy_cli_symlink — Drop pre-rename ~/.local/bin/steaml when we own it.
remove_legacy_cli_symlink() {
	local bindir old_link target
	bindir="${XDG_BIN_HOME:-${HOME}/.local/bin}"
	old_link="$bindir/steaml"
	[[ -L "$old_link" ]] || return 0
	target="$(realpath_portable "$old_link" 2>/dev/null || readlink "$old_link" 2>/dev/null || true)"
	if [[ -n "$target" && ( "$target" == "$LAUNCHLAYER_MAIN_SCRIPT" || "$target" == *steam-game-launch-settings* ) ]]; then
		rm -f "$old_link"
		echo "Removed legacy symlink: $old_link"
	fi
}

# install_cli_symlink — Install ~/.local/bin/launchlayer → main script.
install_cli_symlink() {
	local bindir link
	bindir="${XDG_BIN_HOME:-${HOME}/.local/bin}"
	link="$bindir/launchlayer"
	mkdir -p "$bindir"
	remove_legacy_cli_symlink
	if [[ -e "$link" && ! -L "$link" ]]; then
		echo "Refusing to replace existing file: $link" >&2
		return 1
	fi
	ln -sfn "$LAUNCHLAYER_MAIN_SCRIPT" "$link"
	echo "Linked $link -> $LAUNCHLAYER_MAIN_SCRIPT"
	echo "Ensure $bindir is on your PATH, then run: launchlayer --help"
}

# run_setup — Onboarding helper (non-destructive optional steps).
run_setup() {
	local do_completions=0 do_systemd=0 do_backup_timer=0 print_launch=0 do_symlink=0 do_local=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--completions) do_completions=1; shift ;;
			--systemd) do_systemd=1; shift ;;
			--symlink) do_symlink=1; shift ;;
			--print-launch-option) print_launch=1; shift ;;
			--write-local-config) do_local=1; shift ;;
			--backup-timer) do_backup_timer=1; shift ;;
			*)
				echo "Usage: $0 --setup [--completions] [--systemd] [--backup-timer] [--symlink] [--print-launch-option] [--write-local-config]" >&2
				return 1
				;;
		esac
	done
	(( do_completions || do_systemd || do_backup_timer || print_launch || do_symlink || do_local )) || {
		do_completions=1
		print_launch=1
	}

	echo "=== launchlayer setup ==="
	echo "config_dir=$CONFIG_DIR"
	echo
	if (( do_completions )); then
		completions_enable "$(detect_login_shell_name)"
	fi
	if (( do_symlink )); then
		install_cli_symlink
	fi
	if (( do_systemd )); then
		install_systemd_user_units
	fi
	if (( do_backup_timer )); then
		install_systemd_backup_units
	fi
	if (( do_local )); then
		if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
			echo "local.env already exists — skipping (use --write-local-config --force)"
		else
			write_local_config 0 0
		fi
	fi
	if (( print_launch )); then
		echo
		echo "Add to Steam Launch Options:"
		print_steam_launch_option
	fi
	echo
	if [[ ! -f "$LOCAL_CONFIG_FILE" ]]; then
		echo "Tip: run '$LAUNCHLAYER_MAIN_SCRIPT --write-local-config' to persist detected machine defaults."
	fi
	echo "Run '$LAUNCHLAYER_MAIN_SCRIPT --doctor' to verify."
}
