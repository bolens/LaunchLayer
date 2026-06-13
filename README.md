# LaunchLayer

**Layered launch orchestration for Steam games.**

LaunchLayer sits in Steam’s **Launch Options** ahead of `%command%`. It loads machine and per-game settings, runs preflight checks, and assembles a wrapper chain—GameMode, CPU affinity, MangoHUD, Gamescope, and more—before your game starts.

Built for a tuned Linux gaming workstation (7900X3D, RTX 3080 Ti, Wayland / Plasma 6), but auto-detection and profiles make it work across distros, Steam Deck, Flatpak Steam, BSD, and WSL2.

---

## Contents

- [Quick start](#quick-start)
- [What it does](#what-it-does)
- [How a launch works](#how-a-launch-works)
- [Configuration](#configuration)
- [CLI reference](#cli-reference)
- [Interactive TUI](#interactive-tui)
- [System tuning](#system-tuning)
- [Project layout](#project-layout)
- [Optional dependencies](#optional-dependencies)
- [Testing](#testing)
- [License](#license)

---

## Quick start

**1. Clone to a stable path**

```bash
git clone https://github.com/bolens/LaunchLayer.git /mnt/games/config
cd /mnt/games/config
```

**2. Run onboarding**

```bash
./launchlayer --setup --completions --symlink --print-launch-option --write-local-config
```

This installs shell completions, adds a `~/.local/bin/launchlayer` shortcut, prints your Steam launch string, and writes `launch.d/local.env` with detected machine defaults. Add `--systemd` to install the maintenance timer.

**3. Set Steam launch options**

In Steam → game → **Properties → Launch Options** (or globally under **Settings → Compatibility**):

```
"/path/to/config/launchlayer" %command%
```

`%command%` is required—without it Steam never runs the game binary.

**4. Scaffold a per-game config**

```bash
./launchlayer --init-appid 2357570 competitive    # by AppID
./launchlayer --init-appid "Overwatch" competitive  # by name
```

Or browse interactively: `./launchlayer --tui`

**5. Sanity check**

```bash
./launchlayer --doctor
```

If Proton titles misbehave, fix `vm.max_map_count` once—see [System tuning](#system-tuning).

---

## What it does

| Area | Behavior |
|------|----------|
| **Layered config** | Plain `KEY=VALUE` files stack from machine profiles → defaults → presets → per-game overrides |
| **Auto-detection** | Distro, GPU, compositor, display resolution/VRR, X3D V-Cache CPU mask, native vs Proton |
| **Preflight** | Checks `vm.max_map_count`, shader cache size, VRAM, disk space, concurrent launches |
| **Runtime tuning** | Network (`ethtool`), PipeWire latency, NVIDIA power mode, Proton/DXVK/VKD3D env |
| **VRAM management** | Pause configured systemd units (Sunshine, etc.) during play; resume on exit |
| **Launch chain** | Wrappers → GameMode → CPU affinity → `game-performance` → Gamescope → MangoHUD → game |
| **CLI + TUI** | Manage configs, inspect launch chains, backup/restore, doctor checks |

Use `--dry-run %command%` to print the resolved config and chain without starting the game.

---

## How a launch works

When Steam invokes the script, `run_game_launch` in `lib/launch.sh` runs this pipeline:

1. **Recover stale state** — Resume VRAM-heavy services left paused after a crash
2. **Resolve AppID** — From `SteamAppId`, `STEAM_APPID`, or launch argv
3. **Load layered config** — Profiles → defaults → local → preset → per-game file
4. **Detect game flags** — Native vs Proton, EAC/BattlEye, engine hints
5. **Auto hardware defaults** — X3D CPU mask, display resolution/refresh for Gamescope
6. **Preflight checks** — Skipped when `BENCHMARK=1` (sysctl, caches, VRAM, disk, launch guard)
7. **Runtime tuning** — Network, PipeWire, GPU power, Proton/DXVK env
8. **VRAM hogs** — Optionally stop configured systemd user units with refcount + exit trap
9. **Build launch chain** — Assemble wrappers and performance tools
10. **Exec** — Run `%command%` plus `GAME_EXTRA_ARGS`; log to `~/.local/state/launchlayer/launch.log`

For module-level detail, see [docs/architecture.md](docs/architecture.md).

---

## Configuration

Settings are plain `KEY=VALUE` files. **Later layers override earlier ones.**

### Layer order

| Order | File | Purpose |
|------:|------|---------|
| 0 | `launch.d/profiles/*.env` | Machine profiles (auto-detected or via `LAUNCHLAYER_PROFILES`) |
| 1 | `launch.d/default.env` | Global infrastructure defaults |
| 2 | `launch.d/local.env` | Machine-local overrides (gitignored; from `--write-local-config`) |
| 3 | `launch.d/presets/*.env` | Gameplay profile via `INCLUDE=` or auto-selection |
| 4 | `games/<AppID>.env` | Per-game overrides in `GAMES_DIR` (wins over everything) |

After files load, **runtime detection** fills any still-unset keys: PipeWire latency, network tuning, NVIDIA checks, VRAM hog filtering, disk thresholds, and platform guardrails (Steam Deck, WSL2, containers).

Per-game configs live in `GAMES_DIR` (default `~/.local/share/launchlayer/games`). Example: [examples/games/2357570.env](examples/games/2357570.env) (Overwatch 2).

### Auto preset selection

When no per-game `.env` exists:

- **Native Linux build** → `presets/native.env`
- **Everything else** → `presets/standard.env`

### Presets

| Preset | Use case |
|--------|----------|
| `standard` | Default Proton titles — GameMode on |
| `competitive` | Online / latency-sensitive — MangoHUD, Gamescope, VRR, VRAM hogs, network tune |
| `lightweight` | 2D / indie — minimal overhead |
| `native` | Native Linux — skips Proton env and cache checks |

Init with: `./launchlayer --init-appid APPID competitive`

### Machine profiles

Profiles in `launch.d/profiles/` layer automatically based on detection, or set explicitly:

```bash
LAUNCHLAYER_PROFILES=steam-deck,flatpak-steam   # comma-separated
# legacy: LAUNCHLAYER_PROFILE=steam-deck
```

| Category | Profiles |
|----------|----------|
| **Distros** | `arch-linux`, `debian`, `fedora`, `suse`, `nixos`, `alpine`, `void`, `gentoo`, `solus`, `clearlinux`, `immutable-linux` |
| **Environment** | `steam-deck`, `flatpak-steam`, `wsl2`, `bsd`, `macos`, `non-systemd` |
| **GPU** | `amd-gpu`, `intel-gpu`, `nvidia-desktop` (auto-layered) |

### Common config keys

Per-game files typically start with `INCLUDE=presets/competitive.env`, then override individual keys:

```bash
# Layering
INCLUDE=presets/competitive.env

# Wrappers and game args
LAUNCH_WRAPPERS="dlss-swapper"
LAUNCH_WRAPPERS_BEFORE=""
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

### Display detection

Cross-compositor probing covers KDE/Plasma, GNOME/COSMIC, Hyprland, Sway, wlroots compositors, and X11 stacks (via xrandr). Compositor IPC probes are gated so inactive tools (e.g. `hyprctl` on KDE) do not false-match. Wayland sessions auto-set `GAMESCOPE_EXPOSE_WAYLAND=0`.

Inspect detection: `./launchlayer --detect-environment`

---

## CLI reference

Run from a terminal—no `%command%` needed. Most game commands accept **AppID or name fragment** (case-insensitive).

Global flags (place before subcommands):

| Flag / variable | Effect |
|-----------------|--------|
| `--quiet`, `-q` | Suppress non-fatal warnings |
| `--verbose`, `-v` | Extra debug output (`DEBUG=1`) |
| `--json` | Machine-readable output (where supported) |
| `LAUNCHLAYER_CONFIG_DIR` | Override config root |
| `LAUNCHLAYER_GAMES_DIR` | Per-game `.env` directory |
| `LAUNCHLAYER_PROFILES` | Comma-separated machine profiles |
| `NO_COLOR=1` | Disable ANSI colors |

### Setup and health

| Command | Description |
|---------|-------------|
| `--help`, `-h` | Grouped command reference |
| `--version`, `-V` | Version and install paths |
| `--doctor [--json]` | Full health check; exits non-zero when issues remain |
| `--setup [--completions] [--systemd] [--symlink] [--print-launch-option] [--write-local-config]` | Non-destructive onboarding |
| `--detect-environment [--json]` | Auto-detected platform, GPU, display, tools |
| `--detect-defaults [--json]` | Recommended machine-local settings |
| `--write-local-config [--force] [--dry-run]` | Persist defaults to `launch.d/local.env` |
| `--completions [status\|enable\|disable\|print] [--shell S]` | Shell tab completions |
| `--install-systemd` | Install user maintenance timer |
| `--sysctl [status\|install]` | `vm.max_map_count` helper (install needs root) |

### Games and config

| Command | Description |
|---------|-------------|
| `--list-games [--configured] [--json] [--grep NAME]` | Installed games with native/EAC hints |
| `--init-appid APPID\|NAME [preset] [--force]` | Create per-game config |
| `--init-unconfigured [--preset P] [--eac-only] [--dry-run]` | Bulk-scaffold missing configs |
| `--prune-uninstalled [--dry-run] [--yes]` | Remove configs for uninstalled games |
| `--show-config APPID\|NAME [--json]` | Resolved layers, settings, launch chain |
| `--edit-appid APPID\|NAME` | Open/create per-game config in `$EDITOR` |
| `--paths APPID\|NAME [--json]` | Shader cache, compatdata, install paths |
| `--validate-config [APPID\|NAME\|all] [--json]` | Lint `.env` files |
| `--scan-anticheat [--update-list]` | Find EAC/BattlEye vs known list |
| `--scan-detections` | Audit heuristic vs list mismatches |

### Runtime and diagnostics

| Command | Description |
|---------|-------------|
| `--status [AppID\|NAME] [--json]` | Runtime state, cache sizes |
| `--show-cpu-topology` | CPU summary + X3D V-Cache CCD range |
| `--cache-report [--min-gb N] [--grep NAME] [--json]` | Large cache directories |
| `--launch-stats [AppID\|NAME] [--json]` | Summarize `launch.log` |
| `--dry-run %command%` | Print env + chain without running |
| `--pause-vram-hogs` / `--resume-vram-hogs` | Manual VRAM service control |
| `--cleanup-stale-launch [pid]` | Recover after crash or force-quit |

### Shell completion

Supported shells: **bash**, **zsh**, **fish**, **nushell**, **PowerShell**, and **Oil** (reuses bash).

```bash
./launchlayer --completions enable              # login shell
./launchlayer --completions enable --shell all
./launchlayer --completions print --shell bash  # for Nix/packaging
```

---

## Interactive TUI

```bash
./launchlayer --tui
launchlayer          # same when installed via --setup --symlink
```

Requires an interactive terminal. With [fzf](https://github.com/junegunn/fzf) you get fuzzy game search and a live config preview; without it, numbered menus still work.

**Menus:** Games · Config library · Backup & restore · System & tools · TUI settings

**Highlights:**

- Status banner on launch (doctor issues, sysctl, timers, active filter)
- Per-game quick toggles with inherited vs override coloring
- **Ctrl-E** opens `$EDITOR`, **Ctrl-D** shows dry-run in game picker
- Breadcrumb headers (`Games › Overwatch 2 › Quick toggles`)
- JSON view mode for scripting (`--json` output, pretty-printed when `jq`/`python3` available)

**Preferences** in `~/.config/launchlayer/`:

| File | Template |
|------|----------|
| `tui.conf` | `share/launchlayer/templates/tui.conf.example` |
| `backup.conf` | `share/launchlayer/templates/backup.conf.example` |

Reset via `--tui-prefs reset`, `--backup-prefs reset`, or the settings menus.

---

## System tuning

### vm.max_map_count (Proton)

Elasticsearch’s package sysctl can reset `vm.max_map_count` to `262144`, which breaks some Proton games:

```bash
./launchlayer --sysctl install
# or manually:
sudo cp share/launchlayer/sysctl/elasticsearch.conf /etc/sysctl.d/
sudo sysctl --system
sysctl -n vm.max_map_count   # expect 2147483642
```

Remove `/etc/sysctl.d/99-proton-vm.conf` if present—it is superseded by `elasticsearch.conf`.

Set `VM_MAX_MAP_COUNT_FIX=1` in config to raise the value at launch when passwordless `sudo` is available.

### Workstation setup (optional)

```bash
sudo ./scripts/setup-workstation-tuning.sh
```

Installs **irqbalance**, enables **btrfs autodefrag** when applicable, and installs the **X3D IRQ affinity** helper when found.

### systemd maintenance timer

```bash
./launchlayer --install-systemd
```

Writes user units under `~/.config/systemd/user/` with the resolved script path.

---

## Project layout

```
launchlayer              # Entry point
launch.d/                # Shipped config layers (profiles, presets, lists)
lib/                     # Core modules (config, launch, hardware, tui, …)
share/launchlayer/       # Templates, sysctl, systemd units, completions
examples/games/          # Example per-game configs
scripts/                 # One-time workstation setup
test/                    # bats integration + unit tests
docs/architecture.md     # Module load order and path variables
```

### Runtime state

Under `$XDG_STATE_HOME/launchlayer` (default `~/.local/state/launchlayer/`):

| File | Purpose |
|------|---------|
| `launch.log` | Structured launch history |
| `paused-vram-units` | systemd units stopped for VRAM |
| `vram-hog-refcount` | Nested launch refcount |
| `active-launch.pid` | Current game PID |
| `x3d-cpus` | Cached V-Cache CPU mask |

---

## Optional dependencies

The script degrades gracefully when tools are missing. Run `--doctor` or `--detect-environment` for distro-aware install hints.

| Tool | Used for |
|------|----------|
| `fzf` | Interactive TUI |
| `gamemoderun` | GameMode CPU governor |
| `game-performance` | CPU perf profile wrapper |
| `gamescope` | Compositor upscaling, VRR |
| `mangohud` | Overlay |
| `taskset` | Pin to X3D V-Cache CCD |
| `nvidia-smi`, `nvidia-settings` | VRAM/power checks |
| `ethtool` | `NETWORK_TUNE` |
| `pw-metadata` | `PIPEWIRE_LOW_LATENCY` |
| systemd user session | `VRAM_HOGS` unit pause/resume |

### Anticheat and native detection

- **`launch.d/anticheat-appids.txt`** — Known EAC/BattlEye AppIDs; guardrails warn on risky settings (`DEBUG=1`, `DXVK_ASYNC`)
- **`launch.d/native-appids.txt`** — Known native Linux builds; skips Proton env unless `FORCE_PROTON=1`
- Heuristics in `lib/steam.sh` also inspect install manifests; `--scan-anticheat` and `--scan-detections` help keep lists accurate

---

## Testing

```bash
make test    # bats integration + unit tests
make check   # shellcheck + bats
```

Or directly:

```bash
bats test/
```

---

## License

[CC BY-NC-SA 4.0](LICENSE) — non-commercial use with attribution; derivatives must use the same license.

You may use, modify, and share this project for personal or non-commercial purposes if you credit **bolens**, link to [github.com/bolens/LaunchLayer](https://github.com/bolens/LaunchLayer), and release any derivatives under the same terms. Commercial use requires separate permission.
