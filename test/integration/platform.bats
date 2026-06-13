#!/usr/bin/env bash
setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../helpers.bash"
	SCRIPT="$(launchlayer_script)"
	export REPO_ROOT="$(launchlayer_root)"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
}

@test "list-games json output" {
	local fake_steam
	fake_steam="$(fake_steam_root 1794680 "Vampire Survivors")"
	run env STEAM_ROOT="$fake_steam" "$SCRIPT" --list-games --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	rm -rf "$fake_steam"
}


@test "parse_libraryfolders_paths emits one path per line" {
	local vdf tmp
	tmp="$(mktemp -d)"
	vdf="$tmp/libraryfolders.vdf"
	cat > "$vdf" <<'EOF'
"libraryfolders"
{
	"0"
	{
		"path"		"/steam/main"
	}
	"1"
	{
		"path"		"/mnt/games/SteamLibrary"
	}
}
EOF
	run bash -c 'source "$1/lib/vdf.sh"; parse_libraryfolders_paths "$2"' _ "$REPO_ROOT" "$vdf"
	[[ $status -eq 0 ]]
	[[ "$output" == $'/steam/main\n/mnt/games/SteamLibrary' ]]
	rm -rf "$tmp"
}


@test "cache-report runs" {
	run "$SCRIPT" --cache-report --min-gb 999
	[[ $status -eq 0 ]]
	[[ "$output" == *"Cache report"* ]]
}


@test "scan-anticheat runs" {
	run "$SCRIPT" --scan-anticheat
	[[ $status -eq 0 ]]
	[[ "$output" == *"Anticheat scan"* ]]
}


@test "scan-detections runs" {
	run "$SCRIPT" --scan-detections
	[[ $status -eq 0 ]]
	[[ "$output" == *"Detection audit"* ]]
}


@test "detect-environment runs" {
	run "$SCRIPT" --detect-environment
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer environment"* ]]
	[[ "$output" == *"Gaming profile"* ]]
	[[ "$output" == *"GPU:"* ]]
	[[ "$output" == *"systemd user:"* ]]
}


@test "help mentions detect-environment" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--detect-environment"* ]]
}


@test "doctor runs" {
	run "$SCRIPT" --doctor
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer doctor"* ]]
}


@test "doctor json runs" {
	run "$SCRIPT" --doctor --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"issue_count"'* ]]
	[[ "$output" == *'"config_validation_issues"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}


@test "detect-environment json is valid" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}


@test "detect-environment json includes optional tools" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"optional_tools"'* ]]
	[[ "$output" == *'"package_manager"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "optional_tools" in d and isinstance(d["optional_tools"], list)' "$output"
}


@test "detect-environment lists optional tools section" {
	run "$SCRIPT" --detect-environment
	[[ $status -eq 0 ]]
	[[ "$output" == *"Optional tools"* ]]
}


@test "doctor json includes optional tools" {
	run "$SCRIPT" --doctor --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"optional_tools"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "optional_tools" in d' "$output"
}


@test "warn_enabled_missing_tools reports gamescope" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		optional_tool_installed() { [[ "$1" != gamescope ]]; }
		detect_package_manager() { echo pacman; }
		GAMESCOPE=1
		warn_enabled_missing_tools 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMESCOPE=1 but gamescope is not installed"* ]]
	[[ "$output" == *"pacman"* ]]
}


@test "build_launch_chain skips missing wrappers safely" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		source "'"$REPO_ROOT/lib/runtime.sh"'"
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		GAMEMODE=1 GAMESCOPE=1 MANGOHUD=1
		launch=()
		build_launch_chain
		(( ${#launch[@]} == 0 ))
	'
	[[ $status -eq 0 ]]
}


@test "tool install hint for gamemoderun" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		detect_package_manager() { echo pacman; }
		optional_tool_installed() { return 1; }
		tool_install_hint gamemoderun
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"pacman"* ]]
	[[ "$output" == *"gamemode"* ]]
}


@test "doctor includes config validation section" {
	run "$SCRIPT" --doctor
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config validation"* ]]
}


@test "no args prints brief usage" {
	run "$SCRIPT"
	[[ $status -eq 0 ]]
	[[ "$output" == *"--help"* ]]
	[[ "$output" == *"--doctor"* ]]
}


@test "paths by name" {
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" "$SCRIPT" --paths overwatch
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"Shader cache"* ]]
	rm -rf "$fake_steam"
}


@test "paths json is valid" {
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" "$SCRIPT" --paths 2357570 --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$fake_steam"
}


@test "doctor json includes issues array" {
	run "$SCRIPT" --doctor --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"issues"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert isinstance(d["issues"], list)' "$output"
}


@test "cache-report json runs" {
	run "$SCRIPT" --cache-report --min-gb 999 --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}


@test "cache-report grep filters" {
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" "$SCRIPT" --cache-report --min-gb 0 --grep "Overwatch"
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	rm -rf "$fake_steam"
}


@test "list-games uses heuristic native column" {
	local fake_steam
	fake_steam="$(fake_steam_root 1794680 "Vampire Survivors")"
	run env STEAM_ROOT="$fake_steam" "$SCRIPT" --list-games --grep "Vampire Survivors"
	[[ $status -eq 0 ]]
	[[ "$output" == *"1794680"* ]]
	[[ "$output" == *"yes"* ]]
	rm -rf "$fake_steam"
}


@test "detect-defaults runs" {
	run "$SCRIPT" --detect-defaults
	[[ $status -eq 0 ]]
	[[ "$output" == *"Detected defaults"* ]]
}


@test "detect-defaults json is valid" {
	run "$SCRIPT" --detect-defaults --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "defaults" in d' "$output"
}


@test "write-local-config dry-run" {
	local tmp
	tmp="$(temp_config_dir)"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" "$SCRIPT" --write-local-config --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"Write local config (dry-run)"* ]]
	rm -rf "$tmp"
}


@test "help mentions detect-defaults" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--detect-defaults"* ]]
	[[ "$output" == *"--write-local-config"* ]]
}


@test "detect_desktop_session recognizes additional compositors" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_CURRENT_DESKTOP=niri XDG_SESSION_DESKTOP= detect_desktop_session
	'
	[[ $status -eq 0 ]]
	[[ "$output" == niri ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_CURRENT_DESKTOP=COSMIC XDG_SESSION_DESKTOP=KDE detect_desktop_session
	'
	[[ $status -eq 0 ]]
	[[ "$output" == cosmic ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP=XFCE detect_desktop_session
	'
	[[ $status -eq 0 ]]
	[[ "$output" == xfce ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_CURRENT_DESKTOP=Budgie XDG_SESSION_DESKTOP= detect_desktop_session
	'
	[[ $status -eq 0 ]]
	[[ "$output" == budgie ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP=i3 detect_desktop_session
	'
	[[ $status -eq 0 ]]
	[[ "$output" == i3 ]]
}


@test "compositor_session_active does not match without socket" {
	local root="$REPO_ROOT"
	local fake_bin
	fake_bin="$(mktemp -d)"
	cat > "$fake_bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 1
exit 0
EOF
	chmod +x "$fake_bin/hyprctl"
	run env CONFIG_DIR="$root" PATH="$fake_bin:$PATH" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		unset HYPRLAND_INSTANCE_SIGNATURE
		XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1
		compositor_session_active hyprland && echo active || echo inactive
	'
	[[ $status -eq 0 ]]
	[[ "$output" == inactive ]]
	rm -rf "$fake_bin"
}


@test "is_immutable_os detects bazzite id" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		read_os_release_field() {
			case "$1" in
				ID) echo bazzite ;;
				VARIANT_ID|IMAGE_ID) echo "" ;;
			esac
		}
		is_immutable_os && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]
}


@test "detect_xrandr_display_mode parses xrandr output" {
	local root="$REPO_ROOT"
	local fake_bin
	fake_bin="$(mktemp -d)"
	cat > "$fake_bin/xrandr" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Screen 0: minimum 320 x 200, current 1920 x 1080, maximum 16384 x 16384
DP-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 527mm x 296mm
   1920x1080     60.00*+  144.00
OUT
EOF
	chmod +x "$fake_bin/xrandr"
	run env CONFIG_DIR="$root" PATH="$fake_bin:$PATH" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform hardware
		detect_xrandr_display_mode
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "1920 1080 60 DP-1" ]]
	rm -rf "$fake_bin"
}


@test "is_wayland_session detects Wayland env" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		XDG_SESSION_TYPE=wayland is_wayland_session && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		unset XDG_SESSION_TYPE WAYLAND_DISPLAY
		is_wayland_session && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == no ]]
}


@test "parse_json_focused_monitor extracts hyprland monitor" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform hardware
		printf "%s\n" "[{\"name\":\"DP-1\",\"width\":3440,\"height\":1440,\"refreshRate\":144.0,\"focused\":true}]" \
			| parse_json_focused_monitor
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "3440 1440 144 DP-1" ]]
}


@test "detect_river_display_mode parses riverctl text" {
	local root="$REPO_ROOT"
	local fake_bin
	fake_bin="$(mktemp -d)"
	cat > "$fake_bin/riverctl" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Monitor: DP-2
	Status: connected
	Mode: 2560x1440@165.00Hz
	Focused: yes
OUT
EOF
	chmod +x "$fake_bin/riverctl"
	run env CONFIG_DIR="$root" PATH="$fake_bin:$PATH" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform hardware
		detect_river_display_mode
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "2560 1440 165 DP-2" ]]
	rm -rf "$fake_bin"
}


@test "detect_os_family maps distro IDs" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		read_os_release_field() {
			case "$1" in
				ID) echo ubuntu ;;
				ID_LIKE) echo debian ;;
				PRETTY_NAME) echo "Ubuntu 24.04" ;;
			esac
		}
		detect_os_family
	'
	[[ $status -eq 0 ]]
	[[ "$output" == debian ]]

	run env CONFIG_DIR="$root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		read_os_release_field() {
			case "$1" in
				ID) echo fedora ;;
				ID_LIKE) echo "" ;;
			esac
		}
		detect_os_profile
	'
	[[ $status -eq 0 ]]
	[[ "$output" == fedora ]]
}


@test "detect_default_profiles includes distro profile" {
	local root="$REPO_ROOT"
	run env CONFIG_DIR="$root" LAUNCHLAYER_PROFILES= bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		detect_default_profiles
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"nvidia-desktop"* || "$output" == *"amd-gpu"* || "$output" == *"intel-gpu"* || "$output" == *"arch-linux"* || "$output" == *"debian"* ]]
}


@test "detect-environment json includes os fields" {
	run "$SCRIPT" --detect-environment --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"os_id"'* ]]
	[[ "$output" == *'"os_family"'* ]]
	[[ "$output" == *'"compositor"'* ]]
	[[ "$output" == *'"session_type"'* ]]
	[[ "$output" == *'"immutable"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert all(k in d for k in ("os_family","compositor","session_type","immutable"))' "$output"
}


@test "show-cpu-topology runs" {
	run "$SCRIPT" --show-cpu-topology
	[[ $status -eq 0 ]]
	[[ "$output" == *"CPU topology"* || "$output" == *"lscpu"* || "$output" == *"X3D"* ]]
}


@test "sysctl status runs" {
	run "$SCRIPT" --sysctl status
	[[ $status -eq 0 ]]
	[[ "$output" == *"vm.max_map_count"* ]]
}


@test "launch-stats json with no filter" {
	run "$SCRIPT" --launch-stats --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "entries" in d' "$output"
}


@test "status text runs" {
	run "$SCRIPT" --status
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer status"* ]]
}


@test "install-systemd writes user units in temp home" {
	local tmp unit_dir
	tmp="$(mktemp -d)"
	unit_dir="$tmp/.config/systemd/user"
	run env HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" "$SCRIPT" --install-systemd
	[[ $status -eq 0 ]]
	[[ -f "$unit_dir/launchlayer-maintenance.service" ]]
	[[ -f "$unit_dir/launchlayer-maintenance.timer" ]]
	grep -q launchlayer "$unit_dir/launchlayer-maintenance.service"
	rm -rf "$tmp"
}


@test "tui-game-preview for Overwatch" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --tui-game-preview 2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	rm -rf "$fake_steam"
}


@test "list-games configured only" {
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --list-games --configured --grep "Overwatch"
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	rm -rf "$fake_steam"
}


@test "cache-report shader-only mode" {
	run "$SCRIPT" --cache-report --min-gb 999 --shader-only
	[[ $status -eq 0 ]]
	[[ "$output" == *"Cache report"* ]]
	[[ "$output" != *"compat total"* || "$output" == *"shader"* ]]
}


@test "help mentions launch-stats and sysctl" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--launch-stats"* ]]
	[[ "$output" == *"--sysctl"* ]]
	[[ "$output" == *"--show-cpu-topology"* ]]
}
