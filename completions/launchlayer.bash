# bash completion for launchlayer
# Install: source this file from ~/.bashrc or place in /etc/bash_completion.d/

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
		--status --show-cpu-topology --detect-environment --doctor --setup
		--install-systemd --sysctl --completions --list-games --init-appid
		--init-unconfigured --show-config --edit-appid --paths --validate-config
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
			COMPREPLY=( $(compgen -W "status enable disable print --shell --json bash zsh fish all" -- "$cur") )
			;;
		--doctor)
			COMPREPLY=( $(compgen -W "--json" -- "$cur") )
			;;
		--setup)
			COMPREPLY=( $(compgen -W "--completions --systemd --symlink --print-launch-option" -- "$cur") )
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
