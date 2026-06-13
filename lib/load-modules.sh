# shellcheck shell=bash
# lib/load-modules.sh — Shared source order for modular lib/ trees.
#
# Requires LIB_DIR (and CONFIG_DIR for modules that read config paths).
# Call after lib/common.sh and lib/keys.sh.

[[ -n "${LAUNCHLAYER_LOAD_MODULES_LOADED:-}" ]] && return 0
LAUNCHLAYER_LOAD_MODULES_LOADED=1

# launchlayer_source_platform — Portable helpers, OS/desktop detection, profiles.
launchlayer_source_platform() {
	# shellcheck source=platform/paths.sh
	source "$LIB_DIR/platform/paths.sh"
	# shellcheck source=platform/os.sh
	source "$LIB_DIR/platform/os.sh"
	# shellcheck source=platform/steam-detect.sh
	source "$LIB_DIR/platform/steam-detect.sh"
	# shellcheck source=platform/gpu.sh
	source "$LIB_DIR/platform/gpu.sh"
	# shellcheck source=platform/desktop.sh
	source "$LIB_DIR/platform/desktop.sh"
	# shellcheck source=platform/profiles.sh
	source "$LIB_DIR/platform/profiles.sh"
}

# launchlayer_source_hardware — CPU topology and display auto-detection.
launchlayer_source_hardware() {
	# shellcheck source=hardware/cpu.sh
	source "$LIB_DIR/hardware/cpu.sh"
	# shellcheck source=hardware/compositors.sh
	source "$LIB_DIR/hardware/compositors.sh"
	# shellcheck source=hardware/display.sh
	source "$LIB_DIR/hardware/display.sh"
}

# launchlayer_source_inspect — Config inspection, validation, backup bundles.
launchlayer_source_inspect() {
	# shellcheck source=inspect/show.sh
	source "$LIB_DIR/inspect/show.sh"
	# shellcheck source=inspect/maintenance.sh
	source "$LIB_DIR/inspect/maintenance.sh"
	# shellcheck source=inspect/reports.sh
	source "$LIB_DIR/inspect/reports.sh"
	# shellcheck source=inspect/validation.sh
	source "$LIB_DIR/inspect/validation.sh"
	# shellcheck source=inspect/backup.sh
	source "$LIB_DIR/inspect/backup.sh"
}

# launchlayer_source_prefs — User preference paths and .conf helpers.
launchlayer_source_prefs() {
	# shellcheck source=prefs/paths.sh
	source "$LIB_DIR/prefs/paths.sh"
	# shellcheck source=prefs/backup.sh
	source "$LIB_DIR/prefs/backup.sh"
	# shellcheck source=prefs/tui.sh
	source "$LIB_DIR/prefs/tui.sh"
}

# launchlayer_source_completions — Shell completion install/remove.
launchlayer_source_completions() {
	# shellcheck source=completions/core.sh
	source "$LIB_DIR/completions/core.sh"
	# shellcheck source=completions/shells.sh
	source "$LIB_DIR/completions/shells.sh"
	# shellcheck source=completions/helpers.sh
	source "$LIB_DIR/completions/helpers.sh"
	# shellcheck source=completions/cli.sh
	source "$LIB_DIR/completions/cli.sh"
}

# launchlayer_source_setup — Doctor, onboarding, systemd, sysctl.
launchlayer_source_setup() {
	# shellcheck source=setup/sysctl.sh
	source "$LIB_DIR/setup/sysctl.sh"
	# shellcheck source=setup/systemd.sh
	source "$LIB_DIR/setup/systemd.sh"
	# shellcheck source=setup/doctor.sh
	source "$LIB_DIR/setup/doctor.sh"
	# shellcheck source=setup/onboard.sh
	source "$LIB_DIR/setup/onboard.sh"
}

# launchlayer_source_commands — CLI subcommands and dispatch.
launchlayer_source_commands() {
	# shellcheck source=commands/status.sh
	source "$LIB_DIR/commands/status.sh"
	# shellcheck source=commands/environment.sh
	source "$LIB_DIR/commands/environment.sh"
	# shellcheck source=commands/games.sh
	source "$LIB_DIR/commands/games.sh"
	# shellcheck source=commands/dispatch.sh
	source "$LIB_DIR/commands/dispatch.sh"
}

# launchlayer_source_tui — Interactive terminal UI.
launchlayer_source_tui() {
	# shellcheck source=tui/config.sh
	source "$LIB_DIR/tui/config.sh"
	# shellcheck source=tui/primitives.sh
	source "$LIB_DIR/tui/primitives.sh"
	# shellcheck source=tui/menus-game.sh
	source "$LIB_DIR/tui/menus-game.sh"
	# shellcheck source=tui/menus-config.sh
	source "$LIB_DIR/tui/menus-config.sh"
	# shellcheck source=tui/menus-system.sh
	source "$LIB_DIR/tui/menus-system.sh"
	# shellcheck source=tui/main.sh
	source "$LIB_DIR/tui/main.sh"
}

# launchlayer_load_pre_main — Modules needed before LAUNCHLAYER_MAIN_SCRIPT is set.
launchlayer_load_pre_main() {
	launchlayer_source_platform
	# shellcheck source=tools.sh
	source "$LIB_DIR/tools.sh"
}

# launchlayer_load_post_main — Remaining modules (after LAUNCHLAYER_MAIN_SCRIPT).
launchlayer_load_post_main() {
	# shellcheck source=vdf.sh
	source "$LIB_DIR/vdf.sh"
	# shellcheck source=config.sh
	source "$LIB_DIR/config.sh"
	# shellcheck source=steam.sh
	source "$LIB_DIR/steam.sh"
	launchlayer_source_hardware
	# shellcheck source=detected-defaults.sh
	source "$LIB_DIR/detected-defaults.sh"
	# shellcheck source=gpu.sh
	source "$LIB_DIR/gpu.sh"
	# shellcheck source=preflight.sh
	source "$LIB_DIR/preflight.sh"
	# shellcheck source=runtime.sh
	source "$LIB_DIR/runtime.sh"
	# shellcheck source=vram.sh
	source "$LIB_DIR/vram.sh"
	launchlayer_source_inspect
	# shellcheck source=cli.sh
	source "$LIB_DIR/cli.sh"
	launchlayer_source_prefs
	launchlayer_source_completions
	launchlayer_source_setup
	launchlayer_source_commands
	launchlayer_source_tui
	# shellcheck source=launch.sh
	source "$LIB_DIR/launch.sh"
}
