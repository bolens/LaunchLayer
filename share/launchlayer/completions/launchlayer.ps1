# PowerShell completion for launchlayer
# Install: managed block in $PROFILE via launchlayer --completions enable --shell pwsh

$script:LaunchlayerPresets = @('standard', 'competitive', 'lightweight', 'native')

function Get-LaunchlayerAppIds {
    param([string]$ScriptPath)
    try {
        & $ScriptPath --list-games --json 2>$null |
            ForEach-Object {
                if ($_ -match '"appid":"([0-9]+)"') {
                    $Matches[1]
                }
            }
    } catch {
        @()
    }
}

function Get-LaunchlayerCompletions {
    param(
        [string]$ScriptPath,
        [string[]]$Tokens
    )

    $subcmds = @(
        '--pause-vram-hogs', '--resume-vram-hogs', '--cleanup-stale-launch',
        '--status', '--show-cpu-topology', '--detect-environment', '--detect-defaults',
        '--write-local-config', '--doctor', '--setup', '--install-systemd', '--sysctl',
        '--completions', '--list-games', '--init-appid', '--init-unconfigured',
        '--prune-uninstalled', '--export-config', '--backup-config', '--import-config',
        '--prune-backups', '--run-scheduled-backup', '--backup-timer', '--backup-prefs',
        '--tui-prefs', '--show-config', '--edit-appid', '--paths', '--validate-config',
        '--scan-anticheat', '--scan-detections', '--cache-report', '--launch-stats',
        '--dry-run', '--help', '-h', '--version', '-V', '--tui'
    )

    if ($Tokens.Count -le 1) {
        return $subcmds
    }

    $subcmd = $Tokens[1]
    switch ($subcmd) {
        { $_ -in @('--status', '--show-config', '--edit-appid', '--launch-stats', '--paths') } {
            return (Get-LaunchlayerAppIds -ScriptPath $ScriptPath) + @('--json')
        }
        '--init-appid' {
            if ($Tokens.Count -eq 2) {
                return (Get-LaunchlayerAppIds -ScriptPath $ScriptPath) + @('--force')
            }
            if ($Tokens.Count -eq 3) {
                return $script:LaunchlayerPresets + @('--force')
            }
            return $script:LaunchlayerPresets + @('--force')
        }
        '--validate-config' {
            return @('all', 'default', 'presets') + @(Get-LaunchlayerAppIds -ScriptPath $ScriptPath)
        }
        '--init-unconfigured' {
            return @('--preset', '--dry-run', '--eac-only') + $script:LaunchlayerPresets
        }
        '--prune-uninstalled' {
            return @('--dry-run', '--yes', '--json')
        }
        '--export-config' {
            return @('--output', '--include-local', '--no-profiles', '--include-tui', '--json')
        }
        '--backup-config' {
            return @('--output', '--exclude-local', '--no-profiles', '--include-tui', '--json')
        }
        '--import-config' {
            return @('--dry-run', '--yes', '--merge', '--replace', '--exclude-local', '--no-profiles', '--include-tui', '--json')
        }
        '--prune-backups' {
            return @('--dir', '--keep', '--dry-run', '--json')
        }
        '--run-scheduled-backup' {
            return @('--dir', '--keep', '--json')
        }
        '--backup-timer' {
            return @('install', 'enable', 'disable', 'status', 'reinstall', '--dir', '--keep', '--schedule', '--no-enable')
        }
        '--backup-prefs' {
            return @('show', 'reset', 'set', 'set-schedule', '--json', '--reinstall-timer')
        }
        '--tui-prefs' {
            return @('show', 'reset', 'set', '--json')
        }
        '--list-games' {
            return @('--configured', '--json', '--grep')
        }
        '--cache-report' {
            return @('--min-gb', '--grep', '--json', '--shader-only', '--compat-only')
        }
        '--completions' {
            return @('status', 'enable', 'disable', 'print', '--shell', '--json',
                'bash', 'zsh', 'fish', 'nu', 'pwsh', 'osh', 'all')
        }
        { $_ -in @('--doctor', '--detect-defaults') } {
            return @('--json')
        }
        '--write-local-config' {
            return @('--force', '--dry-run')
        }
        '--setup' {
            return @('--completions', '--systemd', '--backup-timer', '--symlink', '--print-launch-option', '--write-local-config')
        }
        '--sysctl' {
            return @('status', 'install')
        }
        default {
            return @()
        }
    }
}

function Register-LaunchlayerCompleter {
    param([string]$CommandName)

    Register-ArgumentCompleter -CommandName $CommandName -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $line = $null
        $cursor = $null
        if (Get-Module -ListAvailable -Name PSReadLine) {
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor) | Out-Null
        }
        if (-not $line) {
            $line = "$commandName $wordToComplete"
        }
        $tokens = @($line.Trim() -split '\s+')
        $scriptPath = $tokens[0]
        if (-not $scriptPath) {
            $scriptPath = 'launchlayer'
        }
        $completions = Get-LaunchlayerCompletions -ScriptPath $scriptPath -Tokens $tokens
        $completions |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
    }
}

Register-LaunchlayerCompleter -CommandName 'launchlayer'

if ($env:LAUNCHLAYER_CONFIG_DIR) {
    Register-LaunchlayerCompleter -CommandName (Join-Path $env:LAUNCHLAYER_CONFIG_DIR 'launchlayer')
}
