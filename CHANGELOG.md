# Changelog

All notable changes to LaunchLayer are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

[Docs index](docs/README.md) · [README](README.md) · [CLI](docs/cli.md) · [TUI](docs/tui.md) · [Architecture](docs/architecture.md) · [Third-party](docs/third-party.md) · [Release](docs/release_runbook.md) · [Changelog](CHANGELOG.md)

## [Unreleased]

### Added

- First-class `DLSS_SWAPPER` (`1` → `dlss-swapper`, `dll` → `dlss-swapper-dll`) — CachyOS wrapper in the launch chain (TUI toggle, doctor/optional-tools, detection hints)
- CachyOS gaming wiki alignment: `SHADER_CACHE_BOOST`, Proton-CachyOS/GE/EM `PROTON_*_UPGRADE` knobs, and `PROTON_NVIDIA_LIBS*`
- Arch Gaming wiki alignment: `LD_BIND_NOW`, `VKBASALT` → `ENABLE_VKBASALT`, `LATENCYFLEX` → `LFX`, `DISABLE_VBLANK`
- Bazzite docs alignment: `DISABLE_STEAM_DECK` → `SteamDeck=0`, `FRAME_RATE=N` → `DXVK_FRAME_RATE`/`VKD3D_FRAME_RATE`
- Shared inject/fetch framework (`lib/runtime/inject.sh`) with XDG cache + NOTICE files — no third-party binaries in the source tree ([docs/third-party.md](docs/third-party.md) · [docs/architecture.md](docs/architecture.md))
- Gamescope nest fix (`GAMESCOPE_NESTED_FIX`): `env -u LD_PRELOAD` around nested desktop Gamescope; skip Gamescope inside gamescope-session ([docs/third-party.md § Nested Gamescope](docs/third-party.md#nested-gamescope-scopebuddy-parity) · [docs/cli.md](docs/cli.md#gamescope-nest--extras))
- Gamescope extras: `GAMESCOPE_EXTRA_ARGS`, `GAMESCOPE_PREFER_OUTPUT`, `GAMESCOPE_FRAME_LIMIT`, `GAMESCOPE_FILTER`, focused/unfocused FPS; auto-VRR when `GAMESCOPE_ADAPTIVE_SYNC` is empty/`auto` ([docs/cli.md](docs/cli.md#gamescope-nest--extras) · [docs/tui.md](docs/tui.md#advanced-config))
- vkBasalt `VKBASALT_CONFIG_FILE` / `VKBASALT_LOG_LEVEL`; lsfg-vk (`LSFG_VK`, purchase gate for Lossless Scaling) ([docs/third-party.md](docs/third-party.md))
- Chain/env tools: `OBS_VKCAPTURE`, `DISCORD_IPC`, `REPLAY_CAPTURE`, `BLOCK_INTERNET`, `CONTY` ([docs/cli.md](docs/cli.md#capture--network--conty))
- Wine extras: `WINETRICKS_VERBS`, `WINECFG_BEFORE`, `REGISTRY_FILES`, `WINE_FSR`, Special K / ReShade / Depth3D / FWS / ValvePlug / SKIF / OpenVR-FSR / Geo11 / SBS-VR / Flat2VR / specialty runtimes ([docs/cli.md § Wine inject](docs/cli.md#wine-inject-local-mutate--hub-stripped) · [docs/tui.md](docs/tui.md#advanced-config))
- Opt-in `PLAYTIME_LOG` and `CRASH_GUESS` (default timeout 0 — no STL wait-menu)
- Hub strips new mutate/remote-exec inject keys on publish/apply ([docs/architecture.md](docs/architecture.md) · [docs/cli.md § Community hub](docs/cli.md#community-hub))
- Docs index + shared nav across README / docs / CHANGELOG ([docs/README.md](docs/README.md))
- Shared `share/launchlayer/hub-untrusted-keys.txt` synced to Convex `HUB_UNTRUSTED_ENV_KEYS` (includes `CONTY`, `SPECIALTY_RUNTIME`, inject/Wine/VR mutate keys)
- Special K fetch extracts archives into a usable `SPECIAL_K_SOURCE`; launch-exit restore for tracked injects (`.ll-bak`)
- FWS vcrun2010 + non-stomping co-launch; winetricks prefix fallback; `SKIF_LAUNCH`; `DEPTH3D_FETCH_URL`; CRASH_GUESS default 5s timeout when enabled
- Assist-only labeling for Geo11 / Flat2VR / SBS-VR / Depth3D path markers; lsfg-vk layer stacking notes

### Changed

- Prefer `DLSS_SWAPPER=1` over `LAUNCH_WRAPPERS=dlss-swapper`; validation flags combining both; detection tips also accept `PROTON_DLSS_UPGRADE=1`
- Detected defaults enable `SHADER_CACHE_BOOST=1` off Steam Deck / WSL
- TUI quick toggles cover all boolean launch flags; Advanced config groups every remaining string/numeric key (full config-key parity)
- TUI: `DLSS_SWAPPER` cycles `0→1→dll→0` (◐ glyph for dll); `FWS` Advanced-only alias of `FLAWLESS_WIDESCREEN`; assist-only toggle labels; enum pickers for specialty runtime / replay / Gamescope filter / VRR; compact game preview (hot keys + overrides)
- Dry-run “Environment (selected)” includes Arch/Bazzite exports (`LD_BIND_NOW`, `ENABLE_VKBASALT`, `LFX`, `SteamDeck`, Mesa present mode, …)
- Config lint rejects non-integer `FRAME_RATE`; same-file `sd0` + `DISABLE_STEAM_DECK=1` flagged like other wrapper overlaps
- Flag `sd0` in `LAUNCH_WRAPPERS` when `DISABLE_STEAM_DECK=1` (use one path)

## [0.10.0] - 2026-07-14

### Added

- Community hub config history (`--hub-history`, apply historical revisions)
- ProtonDB-based `--suggest-config` rankings
- Release runbook (`docs/release_runbook.md`) with `make bump-version` / `make check-version`

### Security

- Fail-closed hub publish/delete unless `HUB_PUBLISH_TOKEN` is set (or `HUB_ALLOW_OPEN_PUBLISH=1` for local/dev)
- Reject/strip remote-exec keys (`PRE_LAUNCH_CMD`, wrappers, `OVERRIDE_PROTON`, VRAM-hog controls) on hub publish/apply
- Harden `INCLUDE=` path containment and tar import member checks
- Rate-limit privileged hub write routes; stop keying rate limits on client fingerprint alone
- Tighten hub prefs token hygiene (`chmod 600`, never echo token values)

### Changed

- CI path filters cover docs/changelog; shell bats and hub lint/test run as matrices

## [0.9.0] - 2026-06-12

### Added

- Modular `lib/` layout, TUI, backups, profiles, and broad platform detection
- LaunchLayer Hub client + Convex backend for sharing per-game configs

[Unreleased]: https://github.com/bolens/LaunchLayer/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/bolens/LaunchLayer/releases/tag/v0.10.0
[0.9.0]: https://github.com/bolens/LaunchLayer/tree/2f8d8bc0dda93bf55184f24eb784d903387368b2
