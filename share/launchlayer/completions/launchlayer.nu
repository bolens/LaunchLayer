# nushell completion for launchlayer
# Install: symlink to ~/.config/nushell/completions/launchlayer.nu
#          or: launchlayer --completions enable --shell nu

def launchlayer-appids [script: string] {
    try {
        (^$script --list-games --json
            | lines
            | each {|line|
                if ($line | str contains '"appid"') {
                    $line | str replace -r '.*"appid":"([0-9]+)".*' '$1'
                }
            }
            | where {|id| ($id | is-not-empty) }
        )
    } catch {
        []
    }
}

def launchlayer-suggestions [values: list<string>, descriptions?: list<string>] {
    $values
    | enumerate
    | each {|item|
        let desc = (if ($descriptions | is-not-empty) {
            $descriptions | get $item.index | default ""
        } else {
            ""
        })
        if ($desc | is-empty) {
            { value: $item.item }
        } else {
            { value: $item.item, description: $desc }
        }
    }
}

def "nu-complete launchlayer" [spans: list<string>] {
    let script = ($spans | first)
    let presets = [standard competitive lightweight native]
    let subcmds = [
        { value: "--pause-vram-hogs", description: "Pause VRAM-heavy systemd units" }
        { value: "--resume-vram-hogs", description: "Resume paused VRAM-heavy units" }
        { value: "--cleanup-stale-launch", description: "Clean up after a stale launch session" }
        { value: "--status", description: "Show runtime and cache state" }
        { value: "--show-cpu-topology", description: "Show X3D CPU topology hints" }
        { value: "--detect-environment", description: "Show auto-detected platform state" }
        { value: "--detect-defaults", description: "Show recommended machine-local env settings" }
        { value: "--write-local-config", description: "Write launch.d/local.env from detection" }
        { value: "--doctor", description: "Full health check" }
        { value: "--tui", description: "Interactive game/config browser" }
        { value: "--setup", description: "Onboarding helper" }
        { value: "--install-systemd", description: "Install user maintenance timer" }
        { value: "--sysctl", description: "vm.max_map_count helper" }
        { value: "--completions", description: "Manage shell tab completions" }
        { value: "--list-games", description: "List installed Steam games" }
        { value: "--init-appid", description: "Scaffold games/<AppID>.env" }
        { value: "--bulk-set-include", description: "Set INCLUDE preset on many games" }
        { value: "--init-unconfigured", description: "Scaffold configs for unconfigured games" }
        { value: "--prune-uninstalled", description: "Remove configs for uninstalled games" }
        { value: "--export-config", description: "Pack launch.d configs into a tarball" }
        { value: "--backup-config", description: "Timestamped config backup" }
        { value: "--import-config", description: "Restore configs from tarball" }
        { value: "--prune-backups", description: "Remove oldest backup archives" }
        { value: "--run-scheduled-backup", description: "Backup then prune old archives" }
        { value: "--backup-timer", description: "Install/manage backup timer" }
        { value: "--backup-prefs", description: "Manage backup preferences" }
        { value: "--tui-prefs", description: "Manage TUI preferences" }
        { value: "--hub-fingerprint", description: "Machine fingerprint for hub matching" }
        { value: "--hub-publish", description: "Publish per-game config to community hub" }
        { value: "--hub-update", description: "Update shared hub configs for this machine" }
        { value: "--hub-delete", description: "Delete a shared hub config by id" }
        { value: "--hub-recommend", description: "Recommend configs from similar machines" }
        { value: "--hub-search", description: "List machines similar to this one" }
        { value: "--hub-apply", description: "Apply a shared hub config by id" }
        { value: "--hub-history", description: "List publication history of a shared config" }
        { value: "--hub-prefs", description: "Manage hub preferences" }
        { value: "--paths", description: "Shader cache, compatdata, install paths" }
        { value: "--show-config", description: "Show resolved config for an AppID" }
        { value: "--edit-appid", description: "Open per-game config in $EDITOR" }
        { value: "--validate-config", description: "Lint .env config files" }
        { value: "--suggest-config", description: "Suggest optimizations using ProtonDB comments" }
        { value: "--scan-anticheat", description: "Scan for EAC/BattlEye titles" }
        { value: "--scan-detections", description: "Audit detection heuristics" }
        { value: "--cache-report", description: "Report shader/compatdata cache sizes" }
        { value: "--launch-stats", description: "Summarize launch.log" }
        { value: "--dry-run", description: "Print env and launch chain without running" }
        { value: "--help", description: "Show help" }
        { value: "-h", description: "Show help" }
        { value: "--version", description: "Show version" }
        { value: "-V", description: "Show version" }
    ]

    if ($spans | length) <= 1 {
        return $subcmds
    }

    let subcmd = ($spans | get 1)
    match $subcmd {
        "--status" | "--show-config" | "--edit-appid" | "--launch-stats" | "--paths" => {
            launchlayer-appids $script | each {|id| { value: $id } }
        }
        "--init-appid" => {
            if ($spans | length) == 2 {
                launchlayer-appids $script | each {|id| { value: $id } }
            } else {
                ($presets ++ ["--force"]) | each {|v| { value: $v } }
            }
        }
        "--bulk-set-include" => {
            if ($spans | length) == 2 {
                $presets | each {|v| { value: $v } }
            } else {
                (["--all-configured" "--all-installed" "--grep" "--dry-run" "--json"] ++ $presets ++ (launchlayer-appids $script))
                | each {|v| { value: $v } }
            }
        }
        "--validate-config" => {
            (["all" "default" "presets"] ++ (launchlayer-appids $script))
            | each {|v| { value: $v } }
        }
        "--init-unconfigured" => {
            (["--preset" "--dry-run" "--eac-only"] ++ $presets)
            | each {|v| { value: $v } }
        }
        "--prune-uninstalled" => {
            launchlayer-suggestions ["--dry-run" "--yes" "--json"]
        }
        "--export-config" => {
            launchlayer-suggestions ["--output" "--include-local" "--no-profiles" "--include-tui" "--json"]
        }
        "--backup-config" => {
            launchlayer-suggestions ["--output" "--exclude-local" "--no-profiles" "--include-tui" "--json"]
        }
        "--import-config" => {
            launchlayer-suggestions ["--dry-run" "--yes" "--merge" "--replace" "--exclude-local" "--no-profiles" "--include-tui" "--json"]
        }
        "--prune-backups" | "--run-scheduled-backup" => {
            if $subcmd == "--run-scheduled-backup" {
                launchlayer-suggestions ["--dir" "--keep" "--json"]
            } else {
                launchlayer-suggestions ["--dir" "--keep" "--dry-run" "--json"]
            }
        }
        "--backup-timer" => {
            launchlayer-suggestions ["install" "enable" "disable" "status" "reinstall" "--dir" "--keep" "--schedule" "--no-enable"]
        }
        "--backup-prefs" => {
            launchlayer-suggestions ["show" "reset" "set" "set-schedule" "--json" "--reinstall-timer"]
        }
        "--tui-prefs" => {
            launchlayer-suggestions ["show" "reset" "set" "--json"]
        }
        "--hub-fingerprint" => {
            launchlayer-suggestions ["--json" "--fingerprint-level" "minimal" "standard" "detailed"]
        }
        "--hub-publish" => {
            if ($spans | length) == 2 {
                (launchlayer-appids $script ++ ["--all-configured"]) | each {|v| { value: $v } }
            } else {
                launchlayer-suggestions ["--note" "--config-id" "--all-configured" "--json"]
            }
        }
        "--hub-update" => {
            if ($spans | length) == 2 {
                (launchlayer-appids $script ++ ["--all-configured"]) | each {|v| { value: $v } }
            } else {
                launchlayer-suggestions ["--note" "--all-configured" "--include-new" "--json"]
            }
        }
        "--hub-recommend" => {
            if ($spans | length) == 2 {
                launchlayer-appids $script | each {|id| { value: $id } }
            } else {
                launchlayer-suggestions ["--limit" "--json"]
            }
        }
        "--hub-search" => {
            launchlayer-suggestions ["--limit" "--json"]
        }
        "--hub-apply" => {
            launchlayer-suggestions ["--dry-run" "--json" "--history"]
        }
        "--hub-history" => {
            launchlayer-suggestions ["--json"]
        }
        "--suggest-config" => {
            if ($spans | length) == 2 {
                launchlayer-appids $script | each {|id| { value: $id } }
            } else {
                launchlayer-suggestions ["--apply"]
            }
        }
        "--hub-delete" => {
            launchlayer-suggestions ["--yes" "--json"]
        }
        "--hub-prefs" => {
            launchlayer-suggestions ["show" "reset" "set" "--json" "hub_url" "publish_token" "machine_label" "fingerprint_level" "minimal" "standard" "detailed"]
        }
        "--list-games" => {
            launchlayer-suggestions ["--configured" "--json" "--grep"]
        }
        "--cache-report" => {
            launchlayer-suggestions ["--min-gb" "--grep" "--json" "--shader-only" "--compat-only"]
        }
        "--completions" => {
            launchlayer-suggestions ["status" "enable" "disable" "print" "--shell" "--json" "bash" "zsh" "fish" "nu" "pwsh" "osh" "all"]
        }
        "--doctor" | "--detect-defaults" => {
            launchlayer-suggestions ["--json"]
        }
        "--write-local-config" => {
            launchlayer-suggestions ["--force" "--dry-run"]
        }
        "--setup" => {
            launchlayer-suggestions ["--completions" "--systemd" "--backup-timer" "--symlink" "--print-launch-option" "--write-local-config"]
        }
        "--sysctl" => {
            launchlayer-suggestions ["status" "install"]
        }
        _ => []
    }
}

export extern launchlayer [
    ...rest: string@"nu-complete launchlayer"
]
