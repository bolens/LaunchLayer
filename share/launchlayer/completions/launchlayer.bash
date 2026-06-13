# bash completion for launchlayer
# Install: source this file from ~/.bashrc or place in /etc/bash_completion.d/
# Also works with Oil shell (osh): launchlayer --completions enable --shell osh

_launchlayer_appids() {
	local script=$1
	"$script" --list-games --json 2>/dev/null \
		| sed -n 's/.*"appid":"\([0-9]*\)".*/\1/p'
}

_launchlayer_settings() {
	local cur prev words cword
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	words=("${COMP_WORDS[@]}")
	cword=$COMP_CWORD

	local script="${words[0]}"
	local subcmds="
		--pause-vram-hogs --resume-vram-hogs --cleanup-stale-launch
		--status --show-cpu-topology --detect-environment --detect-defaults --write-local-config
		--doctor --setup --install-systemd --sysctl --completions --list-games --init-appid
		--init-unconfigured --prune-uninstalled --export-config --backup-config --import-config
		--restore-backup --prune-backups --run-scheduled-backup --backup-timer --backup-prefs --tui-prefs
		--hub-fingerprint --hub-publish --hub-update --hub-delete --hub-recommend --hub-search --hub-apply --hub-prefs
		--bulk-set-include
		--show-config --edit-appid --paths --validate-config
		--scan-anticheat --scan-detections --cache-report --launch-stats --dry-run
		--help -h --version -V --tui
	"
	local presets="standard competitive lightweight native"

	if [[ $cword -eq 1 ]]; then
		COMPREPLY=( $(compgen -W "$subcmds" -- "$cur") )
		return 0
	fi

	case "${words[1]}" in
		--show-config|--edit-appid|--launch-stats)
			local appids
			appids="$(_launchlayer_appids "$script")"
			COMPREPLY=( $(compgen -W "$appids --json" -- "$cur") )
			;;
		--init-appid)
			local appids
			appids="$(_launchlayer_appids "$script")"
			if [[ $cword -eq 2 ]]; then
				COMPREPLY=( $(compgen -W "$appids --force" -- "$cur") )
			elif [[ $cword -eq 3 ]]; then
				COMPREPLY=( $(compgen -W "$presets --force" -- "$cur") )
			elif [[ $cword -ge 4 ]]; then
				COMPREPLY=( $(compgen -W "--force $presets" -- "$cur") )
			fi
			;;
		--bulk-set-include)
			local appids
			appids="$(_launchlayer_appids "$script")"
			if [[ $cword -eq 2 ]]; then
				COMPREPLY=( $(compgen -W "$presets" -- "$cur") )
			else
				COMPREPLY=( $(compgen -W "--all-configured --all-installed --grep --dry-run --json $presets $appids" -- "$cur") )
			fi
			;;
		--paths)
			local appids
			appids="$(_launchlayer_appids "$script")"
			COMPREPLY=( $(compgen -W "$appids --json" -- "$cur") )
			;;
		--status)
			local appids
			appids="$(_launchlayer_appids "$script")"
			COMPREPLY=( $(compgen -W "$appids --json" -- "$cur") )
			;;
		--init-unconfigured)
			COMPREPLY=( $(compgen -W "--preset --dry-run --eac-only $presets" -- "$cur") )
			;;
		--prune-uninstalled)
			COMPREPLY=( $(compgen -W "--dry-run --yes --json" -- "$cur") )
			;;
		--export-config)
			COMPREPLY=( $(compgen -W "--output --include-local --no-profiles --include-tui --json" -- "$cur") )
			;;
		--backup-config)
			COMPREPLY=( $(compgen -W "--output --exclude-local --no-profiles --include-tui --json" -- "$cur") )
			;;
		--import-config)
			COMPREPLY=( $(compgen -f -W "--dry-run --yes --merge --replace --exclude-local --no-profiles --include-tui --json" -- "$cur") )
			;;
		--restore-backup)
			local appids
			appids="$(_launchlayer_appids "$script")"
			COMPREPLY=( $(compgen -f -W "--dir --list --appid --dry-run --yes --merge --replace --exclude-local --no-profiles --include-tui --json $appids" -- "$cur") )
			;;
		--prune-backups)
			COMPREPLY=( $(compgen -W "--dir --keep --dry-run --json" -- "$cur") )
			;;
		--run-scheduled-backup)
			COMPREPLY=( $(compgen -W "--dir --keep --json" -- "$cur") )
			;;
		--backup-timer)
			COMPREPLY=( $(compgen -W "install enable disable status reinstall --dir --keep --schedule --no-enable" -- "$cur") )
			;;
		--backup-prefs)
			COMPREPLY=( $(compgen -W "show reset set set-schedule --json --reinstall-timer backup_dir keep auto_prune delay include_local include_profiles include_tui daily weekly interval custom" -- "$cur") )
			;;
		--tui-prefs)
			COMPREPLY=( $(compgen -W "show reset set --json game_filter cache_min_gb default_preset fzf_height fzf_preview" -- "$cur") )
			;;
		--hub-fingerprint)
			COMPREPLY=( $(compgen -W "--json --fingerprint-level minimal standard detailed" -- "$cur") )
			;;
		--hub-publish)
			local appids
			appids="$(_launchlayer_appids "$script")"
			if [[ $cword -eq 2 ]]; then
				COMPREPLY=( $(compgen -W "$appids --all-configured" -- "$cur") )
			else
				COMPREPLY=( $(compgen -W "--note --config-id --all-configured --json $appids" -- "$cur") )
			fi
			;;
		--hub-update)
			if [[ $cword -eq 2 ]]; then
				local appids
				appids="$(_launchlayer_appids "$script")"
				COMPREPLY=( $(compgen -W "$appids --all-configured" -- "$cur") )
			else
				COMPREPLY=( $(compgen -W "--note --all-configured --include-new --json" -- "$cur") )
			fi
			;;
		--hub-recommend)
			local appids
			appids="$(_launchlayer_appids "$script")"
			if [[ $cword -eq 2 ]]; then
				COMPREPLY=( $(compgen -W "$appids" -- "$cur") )
			else
				COMPREPLY=( $(compgen -W "--limit --json $appids" -- "$cur") )
			fi
			;;
		--hub-search)
			COMPREPLY=( $(compgen -W "--limit --json" -- "$cur") )
			;;
		--hub-apply)
			COMPREPLY=( $(compgen -W "--dry-run --json" -- "$cur") )
			;;
		--hub-delete)
			COMPREPLY=( $(compgen -W "--yes --json" -- "$cur") )
			;;
		--hub-prefs)
			COMPREPLY=( $(compgen -W "show reset set --json hub_url publish_token machine_label fingerprint_level minimal standard detailed" -- "$cur") )
			;;
		--list-games)
			COMPREPLY=( $(compgen -W "--configured --json --grep" -- "$cur") )
			;;
		--cache-report)
			COMPREPLY=( $(compgen -W "--min-gb --grep --json --shader-only --compat-only" -- "$cur") )
			;;
		--validate-config)
			local appids
			appids="$(_launchlayer_appids "$script")"
			COMPREPLY=( $(compgen -W "$appids all default presets --json" -- "$cur") )
			;;
		--completions)
			COMPREPLY=( $(compgen -W "status enable disable print --shell --json bash zsh fish nu pwsh osh all" -- "$cur") )
			;;
		--doctor)
			COMPREPLY=( $(compgen -W "--json" -- "$cur") )
			;;
		--detect-defaults)
			COMPREPLY=( $(compgen -W "--json" -- "$cur") )
			;;
		--write-local-config)
			COMPREPLY=( $(compgen -W "--force --dry-run" -- "$cur") )
			;;
		--setup)
			COMPREPLY=( $(compgen -W "--completions --systemd --backup-timer --symlink --print-launch-option --write-local-config" -- "$cur") )
			;;
		--sysctl)
			COMPREPLY=( $(compgen -W "status install" -- "$cur") )
			;;
	esac
}

complete -F _launchlayer_settings launchlayer
complete -F _launchlayer_settings ./launchlayer
if [[ -n "${LAUNCHLAYER_CONFIG_DIR:-}" ]]; then
	complete -F _launchlayer_settings "$LAUNCHLAYER_CONFIG_DIR/launchlayer"
fi
