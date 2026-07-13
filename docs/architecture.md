# LaunchLayer architecture

LaunchLayer is a bash orchestration layer for Steam game launches. The repo separates **shipped config**, **user data**, and **runtime state**.

## Directory layout

```
launchlayer                 # entrypoint (sources lib via load-modules.sh)
lib/
  load-modules.sh           # module load order
  common.sh                 # paths: LAUNCHD_DIR, GAMES_DIR, launchlayer_share_dir()
  platform/                 # OS, GPU, Steam detection, profiles
  steam/                    # library discovery, native/EAC/engine detection
  hardware/                 # CPU topology, compositors/, display
  config.sh                 # layer loading, games path helpers
  hub/                      # community hub client (fingerprint, HTTP, similarity)
  inspect/                  # show, validate, backup/, maintenance
  prefs/                    # backup.conf + tui.conf path helpers (hub.conf paths in lib/hub/)
  setup/                    # doctor, sysctl, systemd, onboard
  commands/                 # status, games, hub/, dispatch-*.sh
  completions/              # shell completion installers
  cli/                      # colors, json, help; cli.sh — version and flags
  tui/                      # primitives, games-cache/, menus-backup/, hub/, main loop
hub/                        # Convex backend for community config sharing (optional)
share/launchlayer/
  templates/                # backup.conf, tui.conf, hub.conf examples
  sysctl/                   # vm.max_map_count drop-ins
  systemd/                  # maintenance + backup user unit templates
  completions/              # bash, zsh, fish, nu, pwsh scripts
launch.d/                   # shipped layers only (presets, profiles, lists)
examples/games/             # tracked example per-game configs
docs/
  architecture.md           # this file
  cli.md                    # CLI command reference
  tui.md                    # TUI menus + screenshots (assets/tui-*.png)
  assets/                   # logo + TUI screenshots (regenerate: make tui-screenshots)
scripts/tui-screenshots/    # VHS capture scripts
```

## Config layers (later overrides earlier)

Matches `load_launch_config` in `lib/config.sh`:

| Order | File | Notes |
|------:|------|-------|
| 0 | `launch.d/profiles/*.env` | `LAUNCHLAYER_PROFILES` or auto-detected |
| 1 | `launch.d/default.env` | Global infrastructure defaults |
| 2 | `launch.d/local.env` | Machine-local (`--write-local-config`; gitignored; **force-overwrites** profile/default keys) |
| 3 | `launch.d/presets/*.env` | Per-game `INCLUDE=` **or** auto `standard`/`native` when no `GAMES_DIR/<AppID>.env` |
| 4 | `games/<AppID>.env` | Per-game overrides in `GAMES_DIR` |

If a per-game file exists, auto `standard`/`native` is **not** loaded—only that file (+ optional `INCLUDE=` chain).

After file layers, `apply_defaults` and `apply_detected_defaults` fill unset keys.

Per-game `INCLUDE=` loads the preset **under** that file’s keys (preset first, then per-game overrides).

## CLI and TUI parity

Utility subcommands are implemented once in `lib/commands/` and `lib/inspect/`, then wired through:

- **CLI** — `handle_subcommand` in `lib/commands/dispatch.sh` (`launchlayer --help` is the full reference; see [docs/cli.md](cli.md))
- **TUI** — menus under `lib/tui/` call the same functions (e.g. `show_doctor`, `hub_publish_config`, `bulk_set_include_preset`); see [docs/tui.md](tui.md)

User preferences follow the same pattern for all three config files:

| File | CLI | TUI |
|------|-----|-----|
| `tui.conf` | `--tui-prefs` | **Settings → Interface** |
| `backup.conf` | `--backup-prefs` | **Backup & restore → Settings** |
| `hub.conf` | `--hub-prefs` | **Community hub → Hub settings** |

Bulk preset changes: **`--bulk-set-include PRESET`** or **Games → Bulk change INCLUDE preset**.

## Path variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `LAUNCHLAYER_CONFIG_DIR` | repo root | Parent of `launch.d/` |
| `LAUNCHLAYER_GAMES_DIR` | `~/.local/share/launchlayer/games` | Per-game `.env` files |
| `XDG_CONFIG_HOME/launchlayer/` | user prefs | `backup.conf`, `tui.conf`, `hub.conf` |
| `XDG_STATE_HOME/launchlayer/` | runtime | launch logs, PID files, cache-check stamps |

## Module loading

`launchlayer` sources `load-modules.sh` and calls:

- `launchlayer_load_pre_main` — platform + tools (before main script path is set)
- `launchlayer_load_post_main` — remaining modules in dependency order

Subtree loaders (`launchlayer_source_steam`, `launchlayer_source_cli`, `launchlayer_source_compositors`, `launchlayer_source_backup`, `launchlayer_source_dispatch`, `launchlayer_source_tui_hub`, `launchlayer_source_tui_system`, etc.) source leaf modules directly—no thin orchestrator files.

Each leaf file uses a load guard (`LAUNCHLAYER_*_LOADED`) so tests can load individual subtrees via `source_lib` in `test/helpers.bash`.

## Launch pipeline

`run_game_launch` in `lib/launch.sh`:

1. Recover stale VRAM state
2. Resolve AppID → load config layers → defaults → detected defaults
3. Game flags, hardware defaults, `GAME_EXTRA_ARGS`
4. Preflight (skipped when `BENCHMARK=1`)
5. Tool warnings + anticheat guardrails
6. Pause VRAM hogs + exit trap (when enabled)
7. Runtime tuning (network, PipeWire, CPU perf, NVIDIA, Proton env, disk/HDR/malloc)
8. `build_launch_chain` → exec with pre/post hooks → log

Dry-run (`--dry-run`) loads the same config path and applies env-only tuners (HDR, malloc, Proton override) so the printed chain matches a live launch; host-mutating steps (network/disk sysfs) are skipped.

Wrapper order (`lib/runtime/chain.sh`): `LAUNCH_WRAPPERS_BEFORE` → `gamemoderun` → `taskset` → `game-performance` → `LAUNCH_WRAPPERS` → `gamescope` (optional `--mangoapp`) → `mangohud`.

## Backup / export format

Exports include `manifest.json` plus:

- `launch.d/*` — shared layers and lists
- `games/*` — per-game configs from `GAMES_DIR`
- optional `tui.conf`

Import maps `games/*.env` into `GAMES_DIR`. Older archives that stored per-game files under `launch.d/` are imported into `GAMES_DIR` on restore.

## LaunchLayer Hub

Community config sharing lives in two parts:

1. **CLI client** (`lib/hub/`) — machine fingerprinting, weighted similarity scoring, and HTTP calls to the hub API.
2. **Hub service** (`hub/`) — Convex backend with HTTP routes for publish, recommend, similar-machines, and config download.

Configure the client in `~/.config/launchlayer/hub.conf` (template: `share/launchlayer/templates/hub.conf.example`):

```
hub_url=https://your-deployment.convex.site
machine_label=My gaming PC
publish_token=
```

CLI commands:

| Command | Purpose |
|---------|---------|
| `--hub-fingerprint [--json] [--fingerprint-level minimal\|standard\|detailed]` | Normalized machine descriptor for matching |
| `--hub-publish APPID\|NAME [--note TEXT] [--config-id ID] [--all-configured]` | Upload or update per-game config(s) |
| `--hub-update APPID\|NAME\|CONFIG_ID [--all-configured] [--include-new]` | Update existing shared config(s) for this machine |
| `--hub-delete CONFIG_ID [--yes]` | Delete a shared config (requires publish token) |
| `--hub-recommend APPID\|NAME [--limit N]` | Configs from similar machines |
| `--hub-search [--limit N]` | Machines most like yours |
| `--hub-apply CONFIG_ID [--history] [--dry-run]` | Download and write a shared config (or historical version) |
| `--hub-history CONFIG_ID` | List publication history for a shared config |
| `--hub-prefs [show\|reset\|set]` | Edit `hub.conf` (url, token, label, fingerprint level) |

ProtonDB suggestions (client-side, no hub required):

| `--suggest-config APPID\|NAME [--apply]` | Rank ProtonDB reports for this machine and optionally write allowlisted knobs |

The interactive TUI exposes the same flows under **Community hub** (main menu) and **[Hub] Community configs** (per-game actions).

Deploy the hub backend from `hub/`:

```bash
corepack enable
cd hub
pnpm install
pnpm dev          # development (convex dev)
pnpm run convex:deploy # production only (or: npx convex deploy)
```

Point `hub_url` at the Convex HTTP actions URL.

**Publish authentication** (optional): when `HUB_PUBLISH_TOKEN` is set on the Convex deployment, privileged routes (`POST /api/publish`, `POST /api/delete`) require `Authorization: Bearer <token>`. The client sends the same value from `publish_token` in `hub.conf` and probes `GET /api/auth` before privileged commands when auth is enforced. When the env var is unset or empty, publishes/deletes are open (typical for local dev).

```bash
# Generate a token
openssl rand -hex 32

# Set on Convex (dev or prod deployment)
cd hub && npx convex env set HUB_PUBLISH_TOKEN '<your-token>'

# Match in ~/.config/launchlayer/hub.conf
publish_token=<your-token>
```

Recommend, similar-machines, and config download stay public (no token required).

| Route | Auth |
|-------|------|
| `GET /api/auth` | Public — returns `{ publish_auth_required: bool }` |
| `POST /api/publish` | Privileged when `HUB_PUBLISH_TOKEN` set; upserts by machine fingerprint + appid; optional `config_id` updates that record when fingerprint matches |
| `POST /api/my-config` | Public; returns `{ config_id, published_at, downloads }` or `null` for this machine + appid |
| `POST /api/delete` | Privileged when `HUB_PUBLISH_TOKEN` set |
| `POST /api/recommend` | Public |
| `POST /api/similar-machines` | Public |
| `GET /api/config/:id` | Public |

Similarity scoring weights GPU vendor, OS/session, desktop compositor, display and refresh tiers, VRAM tier, monitor layout, X3D flags, profile overlap, and platform flags (Deck, Flatpak, WSL2, container, etc.) on a 0–100 scale — same algorithm in bash (`lib/hub/similarity.sh`) and TypeScript (`hub/convex/lib/similarity.ts`).

Recommendations are ranked by **similarity (desc)**, then **`published_at` (desc)** so newer configs win ties on the same hardware match, then **downloads (desc)**. `published_at` is refreshed on every republish of the same machine+game config. CLI and TUI list lines include `updated YYYY-MM-DD`; `GET /api/config/:id` also returns `published_at` and `downloads`.

**Fingerprint depth** (`fingerprint_level` in `hub.conf`, default `minimal`):

| Level | Shared data |
|-------|-------------|
| `minimal` | GPU vendor, OS, session, profiles, display/refresh tiers, desktop, platform flags |
| `standard` | minimal + audio, VRAM tier, monitor layout, aspect, exact display, X3D CPU mask |
| `detailed` | standard + full GPU list, all monitors, output names, OS id |

Override once: `LAUNCHLAYER_HUB_FINGERPRINT_LEVEL=detailed` or `--hub-fingerprint --fingerprint-level detailed`.

## Tests

```bash
make test           # bats test/integration/*.bats test/unit/*.bats + hub TS tests
make check          # shellcheck + check-hub-git + bats
make check-hub-git  # scripts/check-staged-hub-secrets.sh
```
