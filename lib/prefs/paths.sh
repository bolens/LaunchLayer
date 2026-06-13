# shellcheck shell=bash
# lib/prefs/paths.sh — User and repo preference file paths.

[[ -n "${LAUNCHLAYER_PREFS_LOADED:-}" ]] && return 0
LAUNCHLAYER_PREFS_LOADED=1
# launchlayer_user_config_dir — XDG directory for user preference files.
launchlayer_user_config_dir() {
	printf '%s/launchlayer' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# launchlayer_repo_config_dir — Shipped example preference files in the repo.
launchlayer_repo_config_dir() {
	printf '%s/templates' "$(launchlayer_share_dir)"
}

# backup_prefs_path — User backup timer/preferences file.
backup_prefs_path() {
	printf '%s/backup.conf' "$(launchlayer_user_config_dir)"
}

# backup_prefs_example_path — Repo default backup.conf template.
backup_prefs_example_path() {
	printf '%s/backup.conf.example' "$(launchlayer_repo_config_dir)"
}

# tui_config_path — User TUI settings file.
tui_config_path() {
	printf '%s/tui.conf' "$(launchlayer_user_config_dir)"
}

# tui_config_example_path — Repo default tui.conf template.
tui_config_example_path() {
	printf '%s/tui.conf.example' "$(launchlayer_repo_config_dir)"
}

# default_systemd_backup_dir — Default backup directory when no prefs exist.
default_systemd_backup_dir() {
	printf '%s/launchlayer-backups' "${HOME}"
}
