# LaunchLayer architecture

LaunchLayer is a bash orchestration layer for Steam game launches. The repo separates **shipped config**, **user data**, and **runtime state**.

## Directory layout

```
launchlayer                 # entrypoint (sources lib via load-modules.sh)
lib/
  load-modules.sh           # module load order
  common.sh                 # paths: LAUNCHD_DIR, GAMES_DIR, launchlayer_share_dir()
  platform/                 # OS, GPU, Steam detection, profiles
  hardware/                 # CPU topology, compositors, display
  config.sh                 # layer loading, games path helpers
  inspect/                  # show, validate, backup, maintenance
  prefs/                    # backup.conf + tui.conf
  setup/                    # doctor, sysctl, systemd, onboard
  commands/                 # CLI subcommands + dispatch
  completions/              # shell completion installers
  tui/                      # interactive fzf menus
share/launchlayer/
  templates/                # backup.conf.example, tui.conf.example
  sysctl/                   # vm.max_map_count drop-ins
  systemd/                  # user unit templates
  completions/              # bash, zsh, fish, nu, pwsh scripts
launch.d/                   # shipped layers only (presets, profiles, lists)
examples/games/             # tracked example per-game configs
```

## Config layers (later overrides earlier)

1. `launch.d/local.env` — machine-local (from `--write-local-config`)
2. `launch.d/profiles/*.env` — distro/hardware profiles
3. `launch.d/default.env` — global defaults
4. `launch.d/presets/*.env` — via `INCLUDE=` or auto-selected preset
5. `games/<AppID>.env` — per-game overrides (`GAMES_DIR`)

## Path variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `LAUNCHLAYER_CONFIG_DIR` | repo root | Parent of `launch.d/` |
| `LAUNCHLAYER_GAMES_DIR` | `~/.local/share/launchlayer/games` | Per-game `.env` files |
| `XDG_CONFIG_HOME/launchlayer/` | user prefs | `backup.conf`, `tui.conf` |
| `XDG_STATE_HOME/launchlayer/` | runtime | launch logs, PID files |

## Module loading

`launchlayer` sources `load-modules.sh` and calls:

- `launchlayer_load_pre_main` — platform + tools (before main script path is set)
- `launchlayer_load_post_main` — hardware, config, inspect, prefs, setup, commands, completions, tui, launch

Each subtree uses a load guard (`LAUNCHLAYER_*_LOADED`) on its first file.

## Backup / export format

Exports include `manifest.json` plus:

- `launch.d/*` — shared layers and lists
- `games/*` — per-game configs from `GAMES_DIR`
- optional `tui.conf`

Import maps `games/*.env` into `GAMES_DIR`. Older archives that stored per-game files under `launch.d/` are imported into `GAMES_DIR` on restore.

## Tests

```bash
make test    # bats test/integration/*.bats test/lib-units.bats
make check   # shellcheck + bats
```
