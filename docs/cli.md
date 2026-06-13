# CLI reference

Run from a terminal — no `%command%` needed. Most game commands accept **AppID or name fragment** (case-insensitive).

`./launchlayer --help` is the live source of truth; this page mirrors the grouped reference.

[← README](../README.md) · [TUI reference](tui.md) · [Architecture](architecture.md)

---

## Global flags

Place before subcommands:

| Flag / variable | Effect |
|-----------------|--------|
| `--quiet`, `-q` | Suppress non-fatal warnings |
| `--verbose`, `-v` | Extra debug output (`DEBUG=1`) |
| `--json` | Machine-readable output (where supported) |
| `LAUNCHLAYER_QUIET=1` | Same as `--quiet` (including during game launch) |
| `LAUNCHLAYER_CONFIG_DIR` | Override config root (parent of `launch.d/`) |
| `LAUNCHLAYER_GAMES_DIR` | Per-game `.env` directory (default: `~/.local/share/launchlayer/games`) |
| `LAUNCHLAYER_PROFILES` | Comma-separated machine profiles (or auto-detect) |
| `NO_COLOR=1` | Disable ANSI colors |

---

## Setup and health

| Command | Description |
|---------|-------------|
| `--help`, `-h` | Grouped command reference |
| `--version`, `-V` | Version and install paths |
| `--doctor [--json]` | Environment + config health check (includes `--validate-config all`); exits non-zero when issues remain |
| `--setup [--completions] [--systemd] [--backup-timer] [--symlink] [--print-launch-option] [--write-local-config]` | Non-destructive onboarding |
| `--detect-environment [--json]` | Auto-detected platform, GPU, display, tools |
| `--detect-defaults [--json]` | Recommended machine-local settings |
| `--write-local-config [--force] [--dry-run]` | Persist defaults to `launch.d/local.env` |
| `--completions [status\|enable\|disable\|print] [--shell S]` | Shell tab completions |
| `--install-systemd` | Install user **maintenance** timer (`launchlayer-maintenance.timer`) |
| `--backup-timer [install\|enable\|disable\|status\|reinstall] [--dir PATH] [--keep N] [--schedule ON_CALENDAR] [--no-enable]` | Install/manage **backup** timer (`launchlayer-backup.timer`) |
| `--backup-prefs [show\|reset\|set\|set-schedule] [--json] [--reinstall-timer]` | Edit `backup.conf` retention, schedule, and includes |
| `--sysctl [status\|install]` | `vm.max_map_count` helper (install needs root) |

---

## Games and config

| Command | Description |
|---------|-------------|
| `--list-games [--configured] [--json] [--grep NAME]` | Installed games with native/EAC hints |
| `--init-appid APPID\|NAME [preset] [--force]` | Create per-game config |
| `--bulk-set-include PRESET [--all-configured\|--all-installed] [--grep NAME] [APPID\|NAME...] [--dry-run] [--json]` | Set `INCLUDE=presets/PRESET.env` on many games (TUI: **Games → Bulk change INCLUDE preset**) |
| `--init-unconfigured [--preset P] [--eac-only] [--dry-run]` | Bulk-scaffold missing configs |
| `--prune-uninstalled [--dry-run] [--yes]` | Remove configs for uninstalled games |
| `--show-config APPID\|NAME [--json]` | Resolved layers, settings, launch chain |
| `--edit-appid APPID\|NAME` | Open/create per-game config in `$EDITOR` |
| `--paths APPID\|NAME [--json]` | Shader cache, compatdata, install paths |
| `--validate-config [APPID\|NAME\|all] [--json]` | Lint `.env` files |
| `--scan-anticheat [--update-list]` | Find EAC/BattlEye vs known list |
| `--scan-detections` | Audit heuristic vs list mismatches |

---

## Runtime and diagnostics

| Command | Description |
|---------|-------------|
| `--status [AppID\|NAME] [--json]` | Runtime state, cache sizes |
| `--show-cpu-topology` | CPU summary + X3D V-Cache CCD range |
| `--cache-report [--min-gb N] [--grep NAME] [--json] [--shader-only\|--compat-only]` | Large cache directories |
| `--launch-stats [AppID\|NAME] [--json]` | Summarize `launch.log` |
| `--dry-run %command%` | Print env + chain without running |
| `--pause-vram-hogs` / `--resume-vram-hogs` | Manual VRAM service control |
| `--cleanup-stale-launch [pid]` | Recover after crash or force-quit |

---

## Backup and restore

| Command | Description |
|---------|-------------|
| `--export-config [--output PATH] [--include-local] [--no-profiles] [--include-tui] [--json]` | Export config bundle (timestamped `.tar.gz` by default) |
| `--backup-config [--output DIR\|PATH] [--exclude-local] [--no-profiles] [--include-tui] [--json]` | Backup alias with backup-dir defaults |
| `--import-config ARCHIVE [--yes] [--merge\|--replace] [--exclude-local] [--no-profiles] [--include-tui] [--json]` | Restore bundle (dry-run by default; pass `--yes` to apply) |
| `--restore-backup [ARCHIVE\|DIR] [--dir PATH] [--list] [--appid APPID\|NAME] [--yes] [--merge\|--replace] …` | Restore from latest or chosen backup archive (replace by default) |
| `--prune-backups [--dir PATH] [--keep N] [--dry-run] [--json]` | Remove old backup archives |
| `--run-scheduled-backup [--dir PATH] [--keep N] [--json]` | Run backup + prune (used by `launchlayer-backup.timer`) |
| `--tui-prefs [show\|reset\|set] [--json]` | Edit `tui.conf` (fzf height, JSON mode, default preset, …) |

---

## Community hub

Optional — local launches do not need the hub. Requires `curl` for publish/delete/apply; `jq` or `python3` for apply.

| Command | Description |
|---------|-------------|
| `--hub-fingerprint [--json] [--fingerprint-level minimal\|standard\|detailed]` | Machine descriptor for matching (`minimal` default; override via `hub.conf` or env) |
| `--hub-publish APPID\|NAME [--note TEXT] [--config-id ID] [--all-configured] [--json]` | Upload per-game config(s) |
| `--hub-update APPID\|NAME\|CONFIG_ID [--all-configured] [--note TEXT] [--include-new] [--json]` | Update existing shared config(s) for this machine |
| `--hub-delete CONFIG_ID [--yes] [--json]` | Delete a shared config (publish token when enforced) |
| `--hub-recommend APPID\|NAME [--limit N] [--json]` | Configs from similar machines |
| `--hub-search [--limit N] [--json]` | Machines most like yours |
| `--hub-apply CONFIG_ID [--dry-run] [--json]` | Download and write a shared config |
| `--hub-prefs [show\|reset\|set] [--json]` | Edit `hub.conf` without the TUI |

TUI equivalents: **Community hub** (main menu) and **[Hub] Community configs** (per-game actions). Bulk preset changes: **`--bulk-set-include`** or **Games → Bulk change INCLUDE preset**.

---

## Shell completion

Supported shells: **bash**, **zsh**, **fish**, **nushell** (`nu`), **PowerShell** (`pwsh`), and **Oil** (`osh`, reuses bash completions).

```bash
./launchlayer --completions enable              # login shell
./launchlayer --completions enable --shell all
./launchlayer --completions print --shell bash  # for Nix/packaging
./launchlayer --completions enable --shell osh    # Oil shell
./launchlayer --completions enable --shell nu     # ~/.config/nushell/completions/
./launchlayer --completions enable --shell pwsh   # $PROFILE drop-in
```

Disable with `--completions disable`. Unknown flags suggest close matches (“Did you mean …?”).
