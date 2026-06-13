# shellcheck shell=bash
# shellcheck source=common.sh
# lib/cli.sh — CLI presentation: help, version, usage hints, unknown-subcommand suggestions.

[[ -n "${LAUNCHLAYER_CLI_LOADED:-}" ]] && return 0
LAUNCHLAYER_CLI_LOADED=1

# Bump when user-visible CLI behavior or subcommands change materially.
LAUNCHLAYER_VERSION=0.9.0

# All utility subcommands (for completion parity and typo suggestions).
LAUNCHLAYER_SUBCOMMANDS=(
	--help -h
	--version -V
	--doctor
	--setup
	--detect-environment
	--detect-defaults
	--write-local-config
	--completions
	--install-systemd
	--sysctl
	--status
	--show-cpu-topology
	--list-games
	--init-appid
	--bulk-set-include
	--init-unconfigured
	--prune-uninstalled
	--export-config
	--backup-config
	--import-config
	--prune-backups
	--run-scheduled-backup
	--backup-timer
	--backup-prefs
	--tui-prefs
	--tui-game-preview
	--show-config
	--edit-appid
	--paths
	--validate-config
	--scan-anticheat
	--scan-detections
	--hub-fingerprint
	--hub-publish
	--hub-update
	--hub-delete
	--hub-recommend
	--hub-apply
	--hub-search
	--hub-prefs
	--cache-report
	--launch-stats
	--dry-run
	--pause-vram-hogs
	--resume-vram-hogs
	--cleanup-stale-launch
	--tui
)

# cli_basename — Script filename for usage strings.
cli_basename() {
	basename "${LAUNCHLAYER_MAIN_SCRIPT:-launchlayer}"
}

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

# print_version — Version and install paths.
print_version() {
	local bn
	bn="$(cli_basename)"
	echo "LaunchLayer ${LAUNCHLAYER_VERSION}"
	echo "script=${LAUNCHLAYER_MAIN_SCRIPT:-unknown}"
	echo "config_dir=${CONFIG_DIR:-unknown}"
	echo "bash=${BASH_VERSION}"
}

# print_usage_brief — Short usage when invoked with no arguments.
print_usage_brief() {
	local bn
	bn="$(cli_basename)"
	cat <<EOF
$(cli_basename): Layered game launch orchestration and config toolkit.

Usage:
  ${bn} %command%                 Launch a game (Steam launch options)
  ${bn} --dry-run %command%       Print resolved config without running
  ${bn} --doctor                  Environment and config health check
  ${bn} --setup                   Onboarding (completions + launch option)
  ${bn} --list-games              Installed games with detection hints
  ${bn} --show-config APPID       Resolved layers and launch chain

  ${bn} --tui                       Interactive game/config browser (fzf optional)

With no arguments in a TTY, opens the TUI automatically when fzf is installed.

Run '${bn} --help' for the full command reference.
EOF
}

# print_help — Grouped command reference.
print_help() {
	local bn
	bn="$(cli_basename)"

	cat <<EOF
$(cli_bold "LaunchLayer") $(cli_dim "${LAUNCHLAYER_VERSION}")
Layered launch profiles, preflight checks, and wrapper chains for games.

$(cli_bold "Steam launch options")
  "${LAUNCHLAYER_MAIN_SCRIPT:-$bn}" %command%
  %command% is required; without it Steam never runs the game binary.

$(cli_bold "Onboarding & health")
  --doctor [--json]                 Full environment + config health check
  --setup [--completions] [--systemd] [--backup-timer] [--symlink] [--print-launch-option]
          [--write-local-config]
  --detect-environment [--json]   Auto-detected platform, GPU, display, tools
  --detect-defaults [--json]      Recommended machine-local env settings
  --write-local-config [--force] [--dry-run]
                                    Write launch.d/local.env from detection
  --completions [status|enable|disable|print] [--shell bash|zsh|fish|nu|pwsh|osh|all] [--json]
  --install-systemd                 Install user maintenance timer
  --backup-timer [install|enable|disable|status|reinstall] [--dir PATH] [--keep N] [--schedule ON_CALENDAR]
                                    Install/manage backup timer (prefs: ~/.config/launchlayer/backup.conf)
  --backup-prefs [show|reset|set|set-schedule] [args...] [--json] [--reinstall-timer]
                                    Manage backup preferences (keep, auto_prune, schedule, includes)
  --sysctl [status|install]         vm.max_map_count helper (install needs root)

$(cli_bold "Games & config")
  --list-games [--configured] [--json] [--grep NAME]
  --init-appid APPID|NAME [preset] [--force]  Create games/<AppID>.env
  --bulk-set-include PRESET [--all-configured|--all-installed] [--grep NAME] [APPID|NAME...] [--dry-run] [--json]
                                    Set INCLUDE=presets/PRESET.env on many games
  --paths APPID|NAME [--json]         Shader cache, compatdata, install paths
  --init-unconfigured [--preset P] [--eac-only] [--dry-run]
  --prune-uninstalled [--dry-run] [--yes] [--json]
                                    Remove per-game .env for uninstalled games
  --export-config [--output PATH] [--include-local] [--no-profiles] [--include-tui] [--json]
                                    Pack launch.d + games configs into a tarball
  --backup-config [--output DIR|PATH] [--exclude-local] [--no-profiles] [--include-tui] [--json]
                                    Timestamped export (default: ~/launchlayer-backup-*.tar.gz)
  --import-config ARCHIVE [--dry-run] [--yes] [--merge|--replace] [--exclude-local]
                          [--no-profiles] [--include-tui] [--json]
                                    Restore configs from export/backup tarball
  --prune-backups [--dir PATH] [--keep N] [--dry-run] [--json]
                                    Remove oldest launchlayer-backup-*.tar.gz archives (keep=0: unlimited)
  --run-scheduled-backup [--dir PATH] [--keep N] [--json]
                                    Backup configs then prune per backup.conf (auto_prune, keep)
  --show-config APPID|NAME [--json]   Resolved config layers + launch chain
  --edit-appid APPID|NAME             Open/create per-game config in \$EDITOR
  --validate-config [APPID|all] [--json]  Lint .env files
  --scan-anticheat [--update-list]  Find EAC/BattlEye vs anticheat-appids.txt
  --scan-detections                 Audit heuristic vs list mismatches

$(cli_bold "Community hub") $(cli_dim "(requires hub.conf — see share/launchlayer/templates/hub.conf.example)")
  --hub-fingerprint [--json] [--fingerprint-level minimal|standard|detailed]
                                    Machine fingerprint for similarity matching
  --hub-publish APPID|NAME [--note TEXT] [--config-id ID] [--all-configured] [--json]
                                    Upload or update per-game config(s) on LaunchLayer Hub
  --hub-update APPID|NAME|CONFIG_ID [--all-configured] [--note TEXT] [--include-new] [--json]
                                    Update existing shared config(s) for this machine
  --hub-delete CONFIG_ID [--yes] [--json]
                                    Delete a shared config (requires publish token)
  --hub-recommend APPID|NAME [--limit N] [--json]
                                    Configs from machines similar to yours
  --hub-search [--limit N] [--json] List machines most similar to this one
  --hub-apply CONFIG_ID [--dry-run] [--json]
                                    Download and apply a shared hub config
  --hub-prefs [show|reset|set] [args...] [--json]
                                    Manage hub preferences (template: share/launchlayer/templates/hub.conf.example)
                                    User file: ~/.config/launchlayer/hub.conf

$(cli_bold "Runtime & diagnostics")
  --status [AppID|NAME] [--json]    Runtime state, shader/compatdata sizes
  --show-cpu-topology               V-Cache CCD hints for X3D_CPUS
  --cache-report [--min-gb N] [--grep NAME] [--json] [--shader-only|--compat-only]
  --launch-stats [APPID|NAME] [--json]  Summarize launch.log
  --dry-run %command%               Print env + chain without running
  --pause-vram-hogs / --resume-vram-hogs / --cleanup-stale-launch [pid]

$(cli_bold "Interactive")
  --tui                             Browse games, toggle settings, edit configs (fzf recommended)
  --tui-prefs [show|reset|set] [args...] [--json]
                                    Manage TUI preferences (template: share/launchlayer/templates/tui.conf.example)
                                    User file: ~/.config/launchlayer/tui.conf

$(cli_bold "General")
  --help, -h                        Show this help
  --version, -V                     Show version and paths

$(cli_bold "Config layers") $(cli_dim "(later overrides earlier)")
  launch.d/profiles/<profile>.env   LAUNCHLAYER_PROFILES or auto-detected
  launch.d/default.env              Global infrastructure defaults
  launch.d/local.env                Machine-local overrides (--write-local-config; gitignored; force-overwrites)
  launch.d/presets/*.env            Via INCLUDE= or auto standard/native (skipped when per-game file exists)
  games/<AppID>.env                 Per-game overrides (LAUNCHLAYER_GAMES_DIR)

$(cli_bold "Environment")
  LAUNCHLAYER_CONFIG_DIR           Override config root (launch.d parent)
  LAUNCHLAYER_GAMES_DIR            Per-game .env directory (default: ~/.local/share/launchlayer/games)
  LAUNCHLAYER_PROFILES           Comma-separated machine profiles
  NO_COLOR=1                        Disable ANSI colors in help output
  LAUNCHLAYER_QUIET=1              Same as --quiet (also suppresses launch warnings)

Global flags (before subcommands): --quiet|-q  --verbose|-v

Presets: standard, competitive, lightweight, native
EOF
}

# cli_parse_global_flags — Strip leading --quiet/-q and --verbose/-v from argv.
# Sets LAUNCH_QUIET / LAUNCH_VERBOSE / DEBUG; prints remaining args one per line.
cli_parse_global_flags() {
	local arg
	LAUNCH_QUIET=${LAUNCH_QUIET:-0}
	LAUNCH_VERBOSE=${LAUNCH_VERBOSE:-0}
	[[ "${LAUNCHLAYER_QUIET:-${STEAM_LAUNCH_QUIET:-0}}" == "1" ]] && LAUNCH_QUIET=1
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--quiet|-q) LAUNCH_QUIET=1; shift ;;
			--verbose|-v) LAUNCH_VERBOSE=1; DEBUG=1; shift ;;
			*) break ;;
		esac
	done
	while [[ $# -gt 0 ]]; do
		printf '%s\n' "$1"
		shift
	done
}

# cli_scan_progress_enabled — True when stderr is a TTY and scans may show progress.
cli_scan_progress_enabled() {
	[[ -t 2 && "${LAUNCH_QUIET:-0}" != "1" && "${CLI_JSON_OUTPUT:-0}" != "1" ]]
}

# cli_scan_progress_begin — Optional progress label before manifest iteration.
cli_scan_progress_begin() {
	local label=${1:-Scanning Steam library}
	CLI_SCAN_LABEL=$label
	CLI_SCAN_COUNT=0
	cli_scan_progress_enabled || return 0
	printf '%s…\n' "$CLI_SCAN_LABEL" >&2
}

# cli_scan_progress_tick — Increment scan counter and refresh progress line.
cli_scan_progress_tick() {
	((CLI_SCAN_COUNT++)) || true
	cli_scan_progress_enabled || return 0
	printf '\r%s (%d games scanned)' "$CLI_SCAN_LABEL" "$CLI_SCAN_COUNT" >&2
}

# cli_scan_progress_end — Finish progress line after manifest iteration.
cli_scan_progress_end() {
	cli_scan_progress_enabled || return 0
	printf '\r%s (%d games scanned)\n' "$CLI_SCAN_LABEL" "${CLI_SCAN_COUNT:-0}" >&2
}

# json_string — Escape and quote a value for JSON output.
json_string() {
	local s=${1-}
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	s="${s//$'\n'/\\n}"
	s="${s//$'\r'/\\r}"
	s="${s//$'\t'/\\t}"
	printf '"%s"' "$s"
}

# json_bool — Emit JSON true/false from common shell truthiness.
json_bool() {
	case "${1:-0}" in
		1|yes|true|on) printf 'true' ;;
		*) printf 'false' ;;
	esac
}

# json_number_or_string — Numeric JSON value or quoted string when not numeric.
json_number_or_string() {
	local v=${1-}
	if [[ "$v" =~ ^-?[0-9]+$ ]]; then
		printf '%s' "$v"
	else
		json_string "$v"
	fi
}

# json_array_strings — JSON array from a bash array of strings.
json_array_strings() {
	local -n _items=$1
	local first=1 item
	printf '['
	for item in "${_items[@]}"; do
		(( first )) || printf ','
		first=0
		json_string "$item"
	done
	printf ']'
}

# json_object_pair — Print one "key":value object field (comma prefix optional).
json_object_pair() {
	local key=$1 value=$2 prefix_comma=${3:-0}
	(( prefix_comma )) && printf ','
	printf '%s:' "$(json_string "$key")"
	printf '%s' "$value"
}

# printf_cache_path_bytes_json — Print [{"path":...,"bytes":...,"gb":...},...] from path|bytes entries.
printf_cache_path_bytes_json() {
	local -n _entries=$1
	local first=1 entry path bytes
	printf '['
	for entry in "${_entries[@]}"; do
		path="${entry%%|*}"
		bytes="${entry##*|}"
		(( first )) || printf ','
		first=0
		printf '{"path":%s,"bytes":%s,"gb":%s}' \
			"$(json_string "$path")" "$bytes" "$(json_string "$(bytes_to_gb "${bytes:-0}")")"
	done
	printf ']'
}

# printf_cache_dirs_json_pair — Print ,"shader_cache":[...],"compatdata":[...].
printf_cache_dirs_json_pair() {
	local -n _shader=$1 _compat=$2
	printf ',"shader_cache":'
	printf_cache_path_bytes_json _shader
	printf ',"compatdata":'
	printf_cache_path_bytes_json _compat
}

# cli_edit_distance — Levenshtein distance between two strings (bash-only).
cli_edit_distance() {
	local a=$1 b=$2
	local -i i j la=${#a} lb=${#b}
	local -i cost=0
	local -a prev curr

	if (( la == 0 )); then echo "$lb"; return; fi
	if (( lb == 0 )); then echo "$la"; return; fi

	prev=()
	for ((i = 0; i <= lb; i++)); do prev[i]=$i; done

	for ((i = 1; i <= la; i++)); do
		curr[0]=$i
		for ((j = 1; j <= lb; j++)); do
			if [[ ${a:i-1:1} == "${b:j-1:1}" ]]; then
				cost=${prev[j-1]}
			else
				cost=$(( prev[j-1] + 1 ))
				(( curr[j-1] + 1 < cost )) && cost=$(( curr[j-1] + 1 ))
				(( prev[j] + 1 < cost )) && cost=$(( prev[j] + 1 ))
			fi
			curr[j]=$cost
		done
		prev=("${curr[@]}")
	done
	echo "${prev[lb]}"
}

# cli_suggest_subcommand — Print closest subcommand matches for a typo.
cli_suggest_subcommand() {
	local input=$1
	local cmd dist best_dist=99
	local -a suggestions=()

	[[ "$input" == --* ]] || return 1

	for cmd in "${LAUNCHLAYER_SUBCOMMANDS[@]}"; do
		dist="$(cli_edit_distance "$input" "$cmd")"
		if (( dist <= 3 && dist < best_dist )); then
			suggestions=("$cmd")
			best_dist=$dist
		elif (( dist == best_dist && dist <= 3 )); then
			suggestions+=("$cmd")
		fi
	done

	((${#suggestions[@]})) || return 1
	printf '%s\n' "${suggestions[@]}"
}

# cli_is_known_subcommand — True when verb is a registered utility flag.
cli_is_known_subcommand() {
	local verb=$1 cmd
	for cmd in "${LAUNCHLAYER_SUBCOMMANDS[@]}"; do
		[[ "$cmd" == "$verb" ]] && return 0
	done
	return 1
}

# cli_unknown_subcommand — Error message for unrecognized utility flags.
cli_unknown_subcommand() {
	local verb=$1
	local -a suggestions=()
	local suggestion

	echo "launchlayer: unknown subcommand: $verb" >&2
	mapfile -t suggestions < <(cli_suggest_subcommand "$verb" || true)
	if ((${#suggestions[@]})); then
		if ((${#suggestions[@]} == 1)); then
			echo "Did you mean '${suggestions[0]}'?" >&2
		else
			echo "Did you mean one of:" >&2
			for suggestion in "${suggestions[@]}"; do
				echo "  $suggestion" >&2
			done
		fi
	fi
	echo "Run '$(cli_basename) --help' for usage." >&2
}
