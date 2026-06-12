#!/usr/bin/env bash
# Bats tests for launchlayer

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../launchlayer"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
}

@test "help exits zero" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--show-config"* ]]
}

@test "validate-config all passes" {
	run "$SCRIPT" --validate-config all
	[[ $status -eq 0 ]]
	[[ "$output" == *"Validation passed"* ]]
}

@test "show-config for Overwatch" {
	[[ -f "$BATS_TEST_DIRNAME/../launch.d/2357570.env" ]] || skip "2357570.env missing"
	run "$SCRIPT" --show-config 2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"Launch chain"* ]]
}

@test "dry-run includes config layers" {
	run "$SCRIPT" --dry-run /bin/echo test AppId=2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config layers"* ]]
}

@test "list-games json output" {
	run "$SCRIPT" --list-games --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
}

@test "init-unconfigured dry-run does not create files" {
	local before after
	before="$(find "$BATS_TEST_DIRNAME/../launch.d" -maxdepth 1 -name '[0-9]*.env' 2>/dev/null | wc -l)"
	run "$SCRIPT" --init-unconfigured --eac-only --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"Init unconfigured (dry-run)"* ]]
	after="$(find "$BATS_TEST_DIRNAME/../launch.d" -maxdepth 1 -name '[0-9]*.env' 2>/dev/null | wc -l)"
	[[ "$before" -eq "$after" ]]
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
	run bash -c 'source "$1/lib/vdf.sh"; parse_libraryfolders_paths "$2"' _ "$BATS_TEST_DIRNAME/.." "$vdf"
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
	[[ "$output" == *"steam_root="* ]]
	[[ "$output" == *"gpu_vendor="* ]]
	[[ "$output" == *"systemd_user="* ]]
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

@test "show-config json for Overwatch" {
	[[ -f "$BATS_TEST_DIRNAME/../launch.d/2357570.env" ]] || skip "2357570.env missing"
	run "$SCRIPT" --show-config 2357570 --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "validate-config json runs" {
	run "$SCRIPT" --validate-config all --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"issue_count"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "status json runs" {
	run "$SCRIPT" --status --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "doctor includes config validation section" {
	run "$SCRIPT" --doctor
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config validation"* ]]
}

@test "setup print launch option" {
	run "$SCRIPT" --setup --print-launch-option
	[[ $status -eq 0 ]]
	[[ "$output" == *"%command%"* ]]
}

@test "completions status runs" {
	run "$SCRIPT" --completions status
	[[ $status -eq 0 ]]
	[[ "$output" == *"launchlayer completions"* ]]
	[[ "$output" == *"bash:"* ]]
}

@test "version exits zero" {
	run "$SCRIPT" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer"* ]]
	[[ "$output" == *"config_dir="* ]]
}

@test "no args prints brief usage" {
	run "$SCRIPT"
	[[ $status -eq 0 ]]
	[[ "$output" == *"--help"* ]]
	[[ "$output" == *"--doctor"* ]]
}

@test "unknown subcommand suggests similar flag" {
	run "$SCRIPT" --show-confg
	[[ $status -eq 1 ]]
	[[ "$output" == *"unknown subcommand"* ]]
	[[ "$output" == *"--show-config"* ]]
}

@test "help shows grouped sections" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"Onboarding & health"* ]]
	[[ "$output" == *"Games & config"* ]]
}

@test "completions enable and disable in temp home" {
	local tmp_home
	tmp_home="$(mktemp -d)"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	export XDG_CONFIG_HOME="$tmp_home/.config"
	mkdir -p "$XDG_CONFIG_HOME"
	run "$SCRIPT" --completions enable --shell bash
	[[ $status -eq 0 ]]
	[[ -f "$XDG_CONFIG_HOME/launchlayer/completions.bash" ]]
	run "$SCRIPT" --completions disable --shell bash
	[[ $status -eq 0 ]]
	[[ ! -f "$XDG_CONFIG_HOME/launchlayer/completions.bash" ]]
	rm -rf "$tmp_home"
}

@test "paths by name" {
	run "$SCRIPT" --paths overwatch
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"Shader cache"* ]]
}

@test "paths json is valid" {
	run "$SCRIPT" --paths 2357570 --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "completions print bash" {
	run "$SCRIPT" --completions print --shell bash
	[[ $status -eq 0 ]]
	[[ "$output" == *"LAUNCHLAYER_CONFIG_DIR"* ]]
	[[ "$output" == *"_launchlayer_settings"* ]]
}

@test "init-appid force overwrites in temp config dir" {
	local tmp_cfg
	tmp_cfg="$(mktemp -d)"
	mkdir -p "$tmp_cfg/launch.d/presets"
	cp "$BATS_TEST_DIRNAME/../launch.d/presets/"*.env "$tmp_cfg/launch.d/presets/"
	printf '%s\n' '# old' 'INCLUDE=presets/standard.env' > "$tmp_cfg/launch.d/2357570.env"
	LAUNCHLAYER_CONFIG_DIR="$tmp_cfg" run "$SCRIPT" --init-appid 2357570 lightweight --force
	[[ $status -eq 0 ]]
	[[ "$output" == *"Overwrote"* ]]
	grep -q 'presets/lightweight.env' "$tmp_cfg/launch.d/2357570.env"
	rm -rf "$tmp_cfg"
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
	run "$SCRIPT" --cache-report --min-gb 0 --grep "Overwatch"
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
}

@test "validate-config accepts game name" {
	[[ -f "$BATS_TEST_DIRNAME/../launch.d/2357570.env" ]] || skip "2357570.env missing"
	run "$SCRIPT" --validate-config overwatch
	[[ $status -eq 0 ]]
}

@test "setup symlink creates launchlayer" {
	local tmp_home bindir
	tmp_home="$(mktemp -d)"
	bindir="$tmp_home/.local/bin"
	mkdir -p "$bindir"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	run "$SCRIPT" --setup --symlink
	[[ $status -eq 0 ]]
	[[ -L "$bindir/launchlayer" ]]
	rm -rf "$tmp_home"
}

@test "launchlayer symlink resolves lib modules" {
	local tmp_home bindir
	tmp_home="$(mktemp -d)"
	bindir="$tmp_home/.local/bin"
	mkdir -p "$bindir"
	# shellcheck disable=SC2030
	export HOME="$tmp_home"
	"$SCRIPT" --setup --symlink >/dev/null
	run "$bindir/launchlayer" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer"* ]]
	[[ "$output" == *"script="* ]]
	rm -rf "$tmp_home"
}

@test "list-games uses heuristic native column" {
	run "$SCRIPT" --list-games --grep "Vampire Survivors"
	[[ $status -eq 0 ]]
	[[ "$output" == *"1794680"* ]]
	[[ "$output" == *"yes"* ]]
}

@test "tui requires interactive terminal" {
	run bash -c "$SCRIPT --tui </dev/null"
	[[ $status -ne 0 ]]
	[[ "$output" == *"interactive terminal"* ]]
}

@test "help documents tui" {
	run "$SCRIPT" --help
	[[ $status -eq 0 ]]
	[[ "$output" == *"--tui"* ]]
}

@test "version reports 0.8.0" {
	run "$SCRIPT" --version
	[[ $status -eq 0 ]]
	[[ "$output" == *"0.8.0"* ]]
}
