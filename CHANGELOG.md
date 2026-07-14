# Changelog

All notable changes to LaunchLayer are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
