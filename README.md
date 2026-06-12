# LaunchLayer

Layered launch orchestration for games. LaunchLayer sits in Steam’s **Launch Options** ahead of `%command%`, applies per-game and machine-wide tuning, runs preflight checks, and assembles a wrapper chain (GameMode, CPU affinity, MangoHUD, Gamescope, and so on) before the game starts.

Originally tuned for **7900X3D + RTX 3080 Ti** on **Wayland / Plasma 6**, but machine profiles and auto-detection make it usable on Steam Deck, Flatpak Steam, and AMD-only setups.

## Quick start

1. Clone or copy this repo to a stable path (e.g. `/mnt/games/config`).
2. Run onboarding (optional but recommended):

   ```bash
   ./launchlayer --setup --completions --symlink --print-launch-option
   ```

   This enables shell tab completion, installs a `~/.local/bin/launchlayer` shortcut, and prints the Steam launch option string. Add `--systemd` to install the maintenance timer.

3. In Steam → game → **Properties → Launch Options**, set:

   ```
   "/path/to/config/launchlayer" %command%
   ```

   `%command%` is required. Without it Steam never runs the game binary.

   Global launch options work too: Steam → **Settings → Compatibility → Set Launch Options**.

4. Scaffold a per-game config (AppID or game name):

   ```bash
   ./launchlayer --init-appid 2357570 competitive
   ./launchlayer --init-appid "Overwatch" competitive
   ```

   Or use the interactive browser: `./launchlayer --tui` (or `launchlayer` when `fzf` is installed).

5. Fix `vm.max_map_count` once if Proton titles misbehave (see [System tuning](#system-tuning)).

6. Sanity check: `./launchlayer --doctor`

## How a launch works

When Steam invokes the script with the game command, `run_game_launch` in `lib/launch.sh` runs this pipeline:

1. **Recover stale state** — Resume VRAM-heavy services left paused after a crash (`lib/vram.sh`).
2. **Resolve AppID** — From `SteamAppId`, `STEAM_APPID`, or launch argv (`lib/config.sh`).
3. **Load layered config** — Profile → `default.env` → preset or per-game file (`lib/config.sh`).
4. **Detect game flags** — Native vs Proton, EAC/BattlEye, engine hints (`lib/steam.sh`).
5. **Auto hardware defaults** — X3D V-Cache CPU mask, display resolution/refresh for Gamescope (`lib/hardware.sh`).
6. **Preflight checks** — Skipped when `BENCHMARK=1` (`lib/preflight.sh`):
   - `vm.max_map_count`
   - Shader cache / compatdata size (optional trim)
   - Free VRAM, GPU power mode, disk space
   - Concurrent launch guard
7. **Runtime tuning** — Network (`ethtool`), PipeWire latency, NVIDIA power mode, Proton/DXVK/VKD3D env (`lib/runtime.sh`, `lib/gpu.sh`).
8. **VRAM hogs** — Optionally stop configured systemd user units (Sunshine, HyprWhspr, etc.) with refcount + exit trap.
9. **Build launch chain** — Wrappers → `gamemoderun` → `taskset` → `game-performance` → custom wrappers → `gamescope` → `mangohud`.
10. **Exec** — Run `%command%` plus `GAME_EXTRA_ARGS`; log outcome to `~/.local/state/launchlayer/launch.log`.

Use `--dry-run %command%` to print the resolved config and chain without starting the game.

## Configuration layers

Settings are plain `KEY=VALUE` files under `launch.d/`. Later layers override earlier ones.

| Order | File | Purpose |
|------:|------|---------|
| 0 | `launch.d/profiles/*.env` | Machine profiles (`LAUNCHLAYER_PROFILES` or auto-detected, layered) |
| 1 | `launch.d/default.env` | Global infrastructure (cache limits, VRAM hog units, sysctl hints) |
| 2 | `launch.d/presets/*.env` | Gameplay profile via `INCLUDE=` or auto-selection |
| 3 | `launch.d/<AppID>.env` | Per-game overrides (wins over everything) |

**Auto preset** (when no `launch.d/<AppID>.env` exists):

- Native Linux build → `presets/native.env`
- Otherwise → `presets/standard.env`

**Profiles** (`launch.d/profiles/`):

| Profile | When |
|---------|------|
| `wsl2.env` | Windows Subsystem for Linux |
| `steam-deck.env` | Steam Deck / SteamOS |
| `flatpak-steam.env` | Flatpak Steam install |
| `amd-gpu.env` | AMD GPU primary |
| `intel-gpu.env` | Intel GPU primary |
| `nvidia-desktop.env` | NVIDIA GPU (auto-layered; no forced overrides) |

Set explicitly: `LAUNCHLAYER_PROFILES=steam-deck,flatpak-steam` or legacy `LAUNCHLAYER_PROFILE=steam-deck`.

**Presets** (`launch.d/presets/`):

| Preset | Use case |
|--------|----------|
| `standard.env` | Default Proton titles — GameMode on |
| `competitive.env` | Online / latency-sensitive — MangoHUD, Gamescope, VRR, VRAM hogs, network tune |
| `lightweight.env` | 2D / indie — minimal overhead |
| `native.env` | Native Linux — skips Proton env and cache checks |

Reference per-game file: `launch.d/2357570.env` (Overwatch 2).

### Common config keys

```bash
# Layering
INCLUDE=presets/competitive.env

# Wrappers and game args
LAUNCH_WRAPPERS="dlss-swapper"          # after game-performance
LAUNCH_WRAPPERS_BEFORE=""               # before gamemoderun
GAME_EXTRA_ARGS="-skipintro -nolog"
UNSET_VARS="DXVK_ASYNC VKD3D_CONFIG"

# Hooks
PRE_LAUNCH_CMD=""
POST_LAUNCH_CMD=""

# Flags
FORCE_NATIVE=1    FORCE_PROTON=1
BENCHMARK=1       DEBUG=1

# Features (0/1 unless noted)
GAMEMODE  MANGOHUD  MANGOHUD_CONFIG  MANGOHUD_LOG
GAMESCOPE  GAMESCOPE_W  GAMESCOPE_H  GAMESCOPE_R
GAMESCOPE_ADAPTIVE_SYNC  GAMESCOPE_FSR  GAMESCOPE_FSR_SHARPNESS
VRAM_HOGS  LAUNCH_WATCHDOG  NETWORK_TUNE  PIPEWIRE_LOW_LATENCY
GPU_POWER_CHECK  NVIDIA_POWER_MODE  GAME_PERFORMANCE
DISABLE_CPU_AFFINITY  CONCURRENT_LAUNCH_GUARD

# Preflight thresholds
SHADER_CACHE_CHECK  SHADER_CACHE_MAX_GB  SHADER_CACHE_TRIM
COMPATDATA_CHECK  COMPATDATA_MAX_GB  COMPATDATA_TRIM
VRAM_PREFLIGHT_MIN_MB  DISK_PREFLIGHT_MIN_GB  GPU_VRAM_PROCESS_MIN_MB
VM_MAX_MAP_COUNT_MIN  VM_MAX_MAP_COUNT_FIX

# Proton / GPU (passed through when set)
PROTON_*  DXVK_*  VKD3D_*  __GL_*  __VK_*
```

Per-game files use `INCLUDE=` to pull in a preset, then override individual keys.

## CLI utilities

Run from a terminal (no `%command%` needed). Check version and paths with `--version`.

### Interactive TUI

```bash
./launchlayer --tui
launchlayer                    # same, when installed via --setup --symlink
./launchlayer   # opens TUI when fzf is installed and stdout is a TTY
```

Requires an interactive terminal. With [fzf](https://github.com/junegunn/fzf) installed you get fuzzy game search and a live `--show-config` preview pane. Without fzf, numbered menus still work.

**Saved preferences** (`~/.config/launchlayer/tui.conf`): game picker filter (all / configured / unconfigured), cache report threshold, default init preset, fzf layout.

| Menu | Actions |
|------|---------|
| **Main** | Browse games, quick toggles, init unconfigured, edit `default.env` / profiles, doctor, environment, status, setup, cache report, validate all, TUI settings |
| **Per game** | Show config, dry-run chain, **quick toggles** (GameMode, MangoHUD, Gamescope, VRAM hogs, …), **advanced config** (INCLUDE preset, game args, wrappers, Gamescope W/H/R, shader cache, MangoHUD, UNSET_VARS), paths, launch stats, `$EDITOR`, re-init preset, validate, delete config |

Quick toggles flip boolean keys in `launch.d/<AppID>.env` (shows inherited vs override). Advanced config prompts for string values without leaving the TUI.

### Onboarding and health

| Command | Description |
|---------|-------------|
| `--help`, `-h` | Grouped command reference |
| `--version`, `-V` | Version and install paths |
| `--doctor [--json]` | Environment + config health check; runs `--validate-config all`; **exits non-zero** when issues remain |
| `--setup [--completions] [--systemd] [--symlink] [--print-launch-option]` | Non-destructive onboarding |
| `--detect-environment [--json]` | Auto-detected platform, GPU, display, optional tools |
| `--completions [status\|enable\|disable\|print] [--shell S] [--json]` | Shell tab completions (`print` writes script to stdout) |
| `--install-systemd` | Install user maintenance timer with resolved script path |
| `--sysctl [status\|install]` | `vm.max_map_count` helper (install needs root) |

### Games and config

Most game commands accept **AppID or name fragment** (case-insensitive). Ambiguous names exit with a list of matches.

| Command | Description |
|---------|-------------|
| `--list-games [--configured] [--json] [--grep NAME]` | Installed games with native/EAC hints; scan progress on stderr when TTY |
| `--init-appid APPID\|NAME [preset] [--force]` | Create `launch.d/<AppID>.env` |
| `--init-unconfigured [--preset P] [--eac-only] [--dry-run]` | Bulk-scaffold missing configs |
| `--show-config APPID\|NAME [--json]` | Resolved layers, settings, launch chain |
| `--edit-appid APPID\|NAME` | Open/create per-game config in `$EDITOR` |
| `--paths APPID\|NAME [--json]` | Shader cache, compatdata, install, and config paths |
| `--validate-config [APPID\|NAME\|all] [--json]` | Lint `.env` files |
| `--scan-anticheat [--update-list]` | Find EAC/BattlEye vs `anticheat-appids.txt` |
| `--scan-detections` | Audit heuristic vs list mismatches |

Presets: `standard`, `competitive`, `lightweight`, `native`.

### Runtime and diagnostics

| Command | Description |
|---------|-------------|
| `--status [AppID\|NAME] [--json]` | Runtime state, shader/compatdata sizes |
| `--show-cpu-topology` | CPU summary + detected X3D V-Cache CCD range |
| `--cache-report [--min-gb N] [--grep NAME] [--json] [--shader-only\|--compat-only]` | Large cache directories |
| `--launch-stats [AppID\|NAME] [--json]` | Summarize `launch.log` |
| `--dry-run %command%` | Print env + chain without running |
| `--pause-vram-hogs` / `--resume-vram-hogs` | Manual VRAM service control |
| `--cleanup-stale-launch [pid]` | Recover after crash or force-quit |

### Global flags and environment

Place before any subcommand:

| Flag / variable | Effect |
|-----------------|--------|
| `--quiet`, `-q` | Suppress non-fatal warnings (including during game launch) |
| `--verbose`, `-v` | Extra debug output (`DEBUG=1`) |
| `LAUNCHLAYER_QUIET=1` | Same as `--quiet` |
| `LAUNCHLAYER_CONFIG_DIR` | Override config root (parent of `launch.d/`) |
| `LAUNCHLAYER_PROFILES` | Comma-separated machine profiles (or auto-detect) |
| `NO_COLOR=1` | Disable ANSI colors in help output |

### JSON output

Add `--json` where supported for scripting: `--show-config`, `--status`, `--validate-config`, `--list-games`, `--detect-environment`, `--doctor`, `--cache-report`, `--launch-stats`, `--completions status`.

### Shell completion

```bash
./launchlayer --completions enable          # login shell
./launchlayer --completions enable --shell all
./launchlayer --completions print --shell bash   # Nix/packaging
```

Disable with `--completions disable`. Unknown flags suggest close matches (“Did you mean …?”).

## Directory layout

```
launchlayer   # Entry point
setup-workstation-tuning.sh       # One-time root setup (irqbalance, btrfs, X3D IRQ)
lib/
  common.sh      paths, state, logging
  platform.sh    Steam root, GPU vendor, desktop detection
  config.sh      layered .env loading
  vdf.sh         libraryfolders.vdf parsing
  steam.sh       library discovery, native/EAC detection
  hardware.sh    X3D CPU + display auto-detection
  gpu.sh         NVIDIA VRAM/power helpers
  preflight.sh   sysctl, caches, VRAM/disk checks
  runtime.sh     env tuning, launch chain assembly
  vram.sh        VRAM hog pause/resume, watchdog
  inspect.sh     show-config, validation, cache reports
  cli.sh         help, version, usage hints
  commands.sh    CLI subcommands
  completions.sh shell completion install/remove
  setup.sh       doctor, setup, systemd, sysctl helpers
  tui.sh         interactive terminal UI (--tui)
  launch.sh      main orchestration
launch.d/
  default.env
  profiles/      machine profiles
  presets/       standard, competitive, lightweight, native
  <AppID>.env    per-game overrides
  native-appids.txt
  anticheat-appids.txt
systemd/         maintenance timer, X3D IRQ affinity unit
completions/     bash, zsh, and fish completion scripts
test/            bats tests
elasticsearch.conf   sysctl drop-in for vm.max_map_count
99-proton-vm.conf    deprecated; see elasticsearch.conf
```

## Runtime state

Persistent data under `$XDG_STATE_HOME/launchlayer` (default `~/.local/state/launchlayer/`):

| File | Purpose |
|------|---------|
| `launch.log` | Structured launch history |
| `paused-vram-units` | systemd units stopped for VRAM |
| `vram-hog-refcount` | Nested launch refcount |
| `active-launch.pid` | Current game PID |
| `launch-watchdog.pid` | Cleanup subprocess |
| `x3d-cpus` | Cached V-Cache CPU mask |
| `shader-cache-check-<AppID>.stamp` | Rate-limit cache checks |

## System tuning

### vm.max_map_count (Proton)

Elasticsearch’s package sysctl can reset `vm.max_map_count` to `262144`, which breaks some Proton games. Install the override:

```bash
sudo cp elasticsearch.conf /etc/sysctl.d/
sudo sysctl --system
sysctl -n vm.max_map_count   # expect 2147483642
```

Remove `/etc/sysctl.d/99-proton-vm.conf` if present — it is superseded by `elasticsearch.conf`.

Set `VM_MAX_MAP_COUNT_FIX=1` in config to raise the value at launch when passwordless `sudo` is available.

### Workstation setup (optional)

```bash
sudo ./setup-workstation-tuning.sh
```

Installs/enables **irqbalance**, enables **btrfs autodefrag** on `/` and `/home` when applicable, and installs the **X3D IRQ affinity** helper + `irq-affinity-x3d.service` when the helper binary is found.

### systemd maintenance timer

Enable `systemd/launchlayer-maintenance.timer` via:

```bash
./launchlayer --install-systemd
```

This writes user units under `~/.config/systemd/user/` with the resolved script path.

## Optional dependencies

The script degrades gracefully when tools are missing (warnings only):

| Tool | Used for |
|------|----------|
| `fzf` | Interactive `--tui` (fuzzy search + config preview) |
| `gamemoderun` | GameMode CPU governor |
| `game-performance` | CPU perf profile wrapper |
| `gamescope` | Compositor upscaling, VRR, `--mangoapp` |
| `mangohud` | Overlay (or via gamescope) |
| `taskset` | Pin to X3D V-Cache CCD |
| `nvidia-smi`, `nvidia-settings` | VRAM/power checks |
| `ethtool` | `NETWORK_TUNE` |
| `pw-metadata` | `PIPEWIRE_LOW_LATENCY` |
| systemd user session | `VRAM_HOGS` unit pause/resume |

## Anticheat and native detection

- **`launch.d/anticheat-appids.txt`** — Known EAC/BattlEye AppIDs; used for preset hints and guardrails (e.g. warn on `DEBUG=1`, `DXVK_ASYNC`).
- **`launch.d/native-appids.txt`** — Known native Linux builds; skips Proton env unless `FORCE_PROTON=1`.
- Heuristics in `lib/steam.sh` also inspect install manifests; `--scan-anticheat` and `--scan-detections` help keep lists accurate.

## Testing

```bash
bats test/
```

## License

No license file is included in this repository; treat as personal/homelab configuration unless you add one.
