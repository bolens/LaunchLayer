# Interactive TUI

```bash
./launchlayer --tui          # always opens the TUI (interactive terminal required)
launchlayer                  # same when symlinked; also opens TUI with no args when fzf + TTY
```

Requires an interactive terminal. With [fzf](https://github.com/junegunn/fzf) menus are fuzzy lists with a header, border, and reverse layout; without fzf, the same items appear as numbered prompts (`1) …`, `Choice:`).

[← README](../README.md) · [CLI reference](cli.md) · [Architecture](architecture.md)

Regenerate screenshots after UI changes: `make tui-screenshots` ([VHS](https://github.com/charmbracelet/vhs) + `fzf` required). Source: `scripts/tui-screenshots/`.

---

## Screenshots

### Main menu

Status banner, then the top-level hub (`LaunchLayer` version in the fzf header):

<p align="center">
  <img src="assets/tui-main-menu.png" alt="LaunchLayer main menu" width="720">
</p>

### Game picker

Fuzzy search with live config preview. **Ctrl-E** opens the editor; **Ctrl-D** dry-runs the launch chain.

<p align="center">
  <img src="assets/tui-game-picker.png" alt="LaunchLayer game picker with live preview" width="720">
</p>

### Quick toggles

Per-game boolean overrides. Green/red labels mark values set in `GAMES_DIR/<AppID>.env`; dim text marks inherited layers.

<p align="center">
  <img src="assets/tui-quick-toggles.png" alt="LaunchLayer per-game quick toggles" width="720">
</p>

---

## On launch

Status banner (two lines, then the main menu):

```
── filter: all │ doctor: 0 issue(s) │ vm.max_map_count: ok
── backup: off │ maintenance: off │ keep newest 7 after backup │ hub: not configured · fp:minimal
```

---

## Main menu

Header `LaunchLayer 0.9.0` (version from `LAUNCHLAYER_VERSION`). Optional prefix rows appear first when applicable:

```
LaunchLayer 0.9.0                          ← fzf --header
────────────────────────────────────────
Doctor: 2 issue(s)                         ← only when doctor finds issues
▶ Resume: Games                            ← when a previous hub was saved
Games  ← last visit                        ← suffix on the last main hub visited
Config library
Backup & restore
Community hub
System & tools
TUI settings
Quit
```

With **auto-resume** enabled (`TUI settings → Auto-resume last hub`), the saved hub opens immediately instead of showing this menu.

---

## Submenus

Exact labels from the TUI.

### Games › `(filter: all)`

- Browse & configure game
- Recent games
- Change game filter (`all` / `configured` / `unconfigured`)
- Bulk change INCLUDE preset
- Init unconfigured games
- Prune uninstalled configs

### Games › *Game* › Actions `(config ok | validation issues | inherits layers)`

- `[View]` Resolved config · Dry-run launch chain · Paths · Launch stats
- `[Edit]` Quick toggles · Advanced config · Clear override · Open in `$EDITOR` · Set preset (re-init)
- `[Manage]` Validate config · Delete per-game config
- `[Hub]` Community configs

### Game picker (fzf)

Header: `Select a game ([recent] at top, Ctrl-E: editor, Ctrl-D: dry-run, filter=…)`

- `[recent]` rows sort to the top
- Live preview via `--tui-game-preview`
- **Ctrl-E** → `--edit-appid`
- **Ctrl-D** → `--dry-run`

### Config library › Layers & validation

- Edit `launch.d/default.env` / `local.env` · Show detected defaults · Write local.env from detection
- Anticheat & detections · Edit machine profile · Edit gameplay preset
- Validate default + presets · Validate all game configs

### Backup & restore › `(prune policy │ maint: …)`

- Settings & preferences · Backup actions · Export & import · Prune archives · Backup timer

### Community hub › `(url · fp:minimal | not configured · fp:minimal)`

- Hub settings · Fingerprint level: *minimal* · Machine fingerprint · Similar machines
- Recommend configs (pick game) · Publish config · Update shared configs · Delete config by ID · Apply config by ID
- Publish/update flows support optional **config ID** and **include-new** (same as `--config-id` / `--include-new` on the CLI)

### System & tools › Diagnostics & setup

- Doctor · Detect environment · Runtime status · CPU topology · vm.max_map_count
- VRAM hogs & launch cleanup · Cache report (full / shader-only / compat-only / grep / min GB) · Setup / onboarding

### TUI settings › `saved to tui.conf`

- Game picker filter · JSON view output · Auto-resume last hub · Press-enter line threshold
- Cache report min GB · Default init preset · fzf height · fzf preview layout · Reset to defaults

---

## Highlights

- Breadcrumb headers use ` › ` (e.g. `Games › Overwatch 2 › Quick toggles`)
- Quick toggles show inherited vs per-game override coloring when the terminal supports it
- JSON view mode (`TUI settings`) makes view commands emit `--json` output, pretty-printed when `jq`/`python3` is available
- Long output only pauses at “Press Enter to continue…” when it spans `press_enter_lines` (default 8)

---

## Preferences

Files in `~/.config/launchlayer/`:

| File | Template |
|------|----------|
| `tui.conf` | `share/launchlayer/templates/tui.conf.example` |
| `backup.conf` | `share/launchlayer/templates/backup.conf.example` |
| `hub.conf` | `share/launchlayer/templates/hub.conf.example` |

Reset via `--tui-prefs reset`, `--backup-prefs reset`, `--hub-prefs reset`, or **TUI settings** / **Backup & restore → Settings & preferences** / **Community hub → Hub settings**.
