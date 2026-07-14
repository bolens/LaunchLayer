# Changelog

All notable changes to LaunchLayer are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- First-class `DLSS_SWAPPER` (`1` → `dlss-swapper`, `dll` → `dlss-swapper-dll`) — CachyOS [latest DLSS preset](https://wiki.cachyos.org/configuration/gaming/#forcing-the-latest-dlss-preset) wrapper in the launch chain (TUI toggle, doctor/optional-tools, detection hints)
- CachyOS gaming wiki alignment: `SHADER_CACHE_BOOST`, Proton-CachyOS/GE/EM `PROTON_*_UPGRADE` knobs (`PROTON_DLSS_UPGRADE`, `PROTON_FSR4_UPGRADE` / RDNA3 auto-path, `PROTON_XESS_UPGRADE`), and `PROTON_NVIDIA_LIBS*`
- Doctor gaming tips: GameMode vs `ananicy-cpp`, Proton-CachyOS discovery, `dlss-updater` GUI detection (no launch CLI)
- Prefer `/usr/share/steam/compatibilitytools.d` when resolving Proton tools (e.g. `proton-cachyos-slr`)

### Changed

- Prefer `DLSS_SWAPPER=1` over `LAUNCH_WRAPPERS=dlss-swapper`; validation flags combining both; detection tips also accept `PROTON_DLSS_UPGRADE=1`
- Detected defaults enable `SHADER_CACHE_BOOST=1` off Steam Deck / WSL
- Quick toggles expose upscaler and shader-boost flags

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
