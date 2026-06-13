# fish completion for launchlayer
# Install: copy or symlink to ~/.config/fish/completions/launchlayer.fish

function __launchlayer_script
    set -l tokens (commandline -opc)
    echo $tokens[1]
end

function __launchlayer_appids
    set -l script (__launchlayer_script)
    $script --list-games --json 2>/dev/null \
        | string replace -r '.*"appid":"([0-9]+)".*' '$1'
end

function __launchlayer_presets
    echo standard competitive lightweight native
end

function __launchlayer_no_subcommand
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 1
end

function __launchlayer_init_appid_preset
    set -l tokens (commandline -opc)
    contains -- --init-appid $tokens
    and test (count $tokens) -ge 3
end

function __launchlayer_register
    set -l cmd $argv[1]

    complete -c $cmd -f
    complete -c $cmd -n __launchlayer_no_subcommand -a '--pause-vram-hogs' -d 'Pause VRAM-heavy systemd units'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--resume-vram-hogs' -d 'Resume paused VRAM-heavy units'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--cleanup-stale-launch' -d 'Clean up after a stale launch session'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--status' -d 'Show runtime and cache state'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--show-cpu-topology' -d 'Show X3D CPU topology hints'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--detect-environment' -d 'Show auto-detected platform state'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--detect-defaults' -d 'Show recommended machine-local env settings'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--write-local-config' -d 'Write launch.d/local.env from detection'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--doctor' -d 'Full health check'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--tui' -d 'Interactive game/config browser'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--setup' -d 'Onboarding helper'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--install-systemd' -d 'Install user maintenance timer'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--sysctl' -d 'vm.max_map_count helper'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--completions' -d 'Manage shell tab completions'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--list-games' -d 'List installed Steam games'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--init-appid' -d 'Scaffold games/<AppID>.env'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--init-unconfigured' -d 'Scaffold configs for unconfigured games'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--prune-uninstalled' -d 'Remove configs for uninstalled games'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--export-config' -d 'Pack launch.d configs into a tarball'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--backup-config' -d 'Timestamped config backup'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--import-config' -d 'Restore configs from tarball'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--prune-backups' -d 'Remove oldest backup archives'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--run-scheduled-backup' -d 'Backup then prune old archives'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--backup-timer' -d 'Install/manage backup timer'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--backup-prefs' -d 'Manage backup preferences'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--tui-prefs' -d 'Manage TUI preferences'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--paths' -d 'Shader cache, compatdata, install paths'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--show-config' -d 'Show resolved config for an AppID'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--edit-appid' -d 'Open per-game config in EDITOR'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--validate-config' -d 'Lint .env config files'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--scan-anticheat' -d 'Scan for EAC/BattlEye titles'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--scan-detections' -d 'Audit detection heuristics'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--cache-report' -d 'Report shader/compatdata cache sizes'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--launch-stats' -d 'Summarize launch.log'
    complete -c $cmd -n __launchlayer_no_subcommand -a '--dry-run' -d 'Print env and launch chain without running'
    complete -c $cmd -n __launchlayer_no_subcommand -a --help -d 'Show help'
    complete -c $cmd -n __launchlayer_no_subcommand -a -h -d 'Show help'
    complete -c $cmd -n __launchlayer_no_subcommand -a --version -d 'Show version'
    complete -c $cmd -n __launchlayer_no_subcommand -a -V -d 'Show version'

    set -l appid_subcmds --status --show-config --edit-appid --launch-stats --paths
    for subcmd in $appid_subcmds
        complete -c $cmd \
            -n "__fish_seen_subcommand_from $subcmd; and not __fish_seen_subcommand_from --help -h" \
            -a '(__launchlayer_appids)'
    end

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-appid; and not __fish_seen_subcommand_from --help -h standard competitive lightweight native' \
        -a '(__launchlayer_appids)'

    complete -c $cmd \
        -n __launchlayer_init_appid_preset \
        -a '(__launchlayer_presets)'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --validate-config; and not __fish_seen_subcommand_from --help -h' \
        -a 'all default presets (__launchlayer_appids)'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-unconfigured' \
        -a '--preset' -d 'Preset to apply'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-unconfigured --preset' \
        -a '(__launchlayer_presets)'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-unconfigured' \
        -a '--dry-run' -d 'Print actions without writing files'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-unconfigured' \
        -a '--eac-only' -d 'Only anticheat titles'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-uninstalled' \
        -a '--dry-run' -d 'Print actions without deleting files'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-uninstalled' \
        -a '--yes' -d 'Delete orphan configs without prompting'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-uninstalled' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --export-config' \
        -a '--output' -d 'Output archive path'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --export-config' \
        -a '--include-local' -d 'Include launch.d/local.env'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --export-config' \
        -a '--no-profiles' -d 'Exclude launch.d/profiles'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --export-config' \
        -a '--include-tui' -d 'Include TUI preferences'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --export-config' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-config' \
        -a '--output' -d 'Output directory or archive path'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-config' \
        -a '--exclude-local' -d 'Exclude launch.d/local.env'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-config' \
        -a '--no-profiles' -d 'Exclude launch.d/profiles'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-config' \
        -a '--include-tui' -d 'Include TUI preferences'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-config' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--dry-run' -d 'Preview import without writing files'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--yes' -d 'Apply import'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--merge' -d 'Skip existing files'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--replace' -d 'Overwrite existing files'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--exclude-local' -d 'Skip launch.d/local.env'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--no-profiles' -d 'Skip launch.d/profiles'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--include-tui' -d 'Import TUI preferences'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --import-config' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-backups' \
        -a '--dir' -d 'Backup directory'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-backups' \
        -a '--keep' -d 'Keep newest N archives'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-backups' \
        -a '--dry-run' -d 'Preview without deleting'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --prune-backups' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-timer' \
        -a 'install enable disable status reinstall'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-timer' \
        -a '--dir' -d 'Backup directory'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-timer' \
        -a '--keep' -d 'Keep newest N archives'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-timer' \
        -a '--schedule' -d 'systemd OnCalendar expression'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-timer' \
        -a '--no-enable' -d 'Install without enabling timer'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-prefs' \
        -a 'show reset set set-schedule'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-prefs' \
        -a '--json' -d 'JSON output'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --backup-prefs' \
        -a '--reinstall-timer' -d 'Reinstall systemd timer after reset'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --tui-prefs' \
        -a 'show reset set'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --tui-prefs' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --list-games' \
        -a '--configured' -d 'Only configured games'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --list-games' \
        -a '--json' -d 'JSON output'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --list-games' \
        -a '--grep' -d 'Filter by game name'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --cache-report' \
        -a '--min-gb' -d 'Minimum size in GB'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --cache-report' \
        -a '--shader-only' -d 'Shader caches only'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --cache-report' \
        -a '--compat-only' -d 'Compatdata only'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --cache-report' \
        -a '--grep' -d 'Filter by game name'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --cache-report' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--symlink' -d 'Install ~/.local/bin/launchlayer symlink'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --scan-anticheat' \
        -a '--update-list' -d 'Update anticheat-appids.txt'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --init-appid' \
        -a '--force' -d 'Overwrite existing config'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --completions' \
        -a 'status enable disable print'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --completions' \
        -a '--shell' -d 'Shell to configure'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --completions --shell' \
        -a 'bash zsh fish nu pwsh osh all'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --completions' \
        -a '--json' -d 'JSON output (status only)'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --doctor' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--completions' -d 'Enable completions for login shell'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--systemd' -d 'Install user maintenance timer'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--backup-timer' -d 'Install user backup timer'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--print-launch-option' -d 'Print Steam launch options string'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --setup' \
        -a '--write-local-config' -d 'Write launch.d/local.env when missing'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --write-local-config' \
        -a '--force' -d 'Overwrite existing local.env'
    complete -c $cmd \
        -n '__fish_seen_subcommand_from --write-local-config' \
        -a '--dry-run' -d 'Print settings without writing'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --detect-defaults' \
        -a '--json' -d 'JSON output'

    complete -c $cmd \
        -n '__fish_seen_subcommand_from --sysctl' \
        -a 'status install'
end

function __launchlayer_config_dir
    if set -q LAUNCHLAYER_CONFIG_DIR
        echo $LAUNCHLAYER_CONFIG_DIR
        return
    end
    set -l src (status filename)
    if test -n "$src"
        echo (dirname (dirname $src))
    end
end

__launchlayer_register launchlayer
__launchlayer_register ./launchlayer
set -l _launchlayer_config_dir (__launchlayer_config_dir)
if test -n "$_launchlayer_config_dir"
    __launchlayer_register "$_launchlayer_config_dir/launchlayer"
end
