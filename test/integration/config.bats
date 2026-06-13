#!/usr/bin/env bash
setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../helpers.bash"
	SCRIPT="$(launchlayer_script)"
	export REPO_ROOT="$(launchlayer_root)"
	export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
}

@test "validate-config all passes" {
	run "$SCRIPT" --validate-config all
	[[ $status -eq 0 ]]
	[[ "$output" == *"Validation passed"* ]]
}


@test "show-config for Overwatch" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --show-config 2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"Launch chain"* ]]
	rm -rf "$fake_steam"
}


@test "dry-run includes config layers" {
	run "$SCRIPT" --dry-run /bin/echo test AppId=2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config layers"* ]]
}


@test "init-unconfigured dry-run does not create files" {
	local tmp before after
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/games"
	before="$(find "$tmp/games" -maxdepth 1 -name '[0-9]*.env' 2>/dev/null | wc -l)"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --init-unconfigured --eac-only --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"Init unconfigured (dry-run)"* ]]
	after="$(find "$tmp/games" -maxdepth 1 -name '[0-9]*.env' 2>/dev/null | wc -l)"
	[[ "$before" -eq "$after" ]]
	rm -rf "$tmp"
}


@test "prune-uninstalled dry-run finds orphan configs" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d" "$tmp/games"
	cat > "$tmp/games/99999999.env" <<'EOF'
# Test Orphan Game (Steam AppID 99999999)
INCLUDE=presets/standard.env
EOF
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --prune-uninstalled --dry-run
	[[ $status -eq 0 ]]
	[[ "$output" == *"Prune uninstalled (dry-run)"* ]]
	[[ "$output" == *"99999999"* ]]
	[[ "$output" == *"Test Orphan Game"* ]]
	[[ -f "$tmp/games/99999999.env" ]]
	rm -rf "$tmp"
}


@test "prune-uninstalled yes removes orphan configs" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d" "$tmp/games"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/99999999.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --prune-uninstalled --yes
	[[ $status -eq 0 ]]
	[[ "$output" == *"removed=1"* ]]
	[[ ! -f "$tmp/games/99999999.env" ]]
	rm -rf "$tmp"
}


@test "prune-uninstalled json output" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d" "$tmp/games"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/99999999.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --prune-uninstalled --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["orphans"][0]["appid"]=="99999999"' "$output"
	rm -rf "$tmp"
}


@test "show-config json for Overwatch" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --show-config 2357570 --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$fake_steam"
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


@test "setup print launch option" {
	run "$SCRIPT" --setup --print-launch-option
	[[ $status -eq 0 ]]
	[[ "$output" == *"%command%"* ]]
}


@test "init-appid force overwrites in temp config dir" {
	local tmp_cfg fake_steam
	tmp_cfg="$(mktemp -d)"
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	mkdir -p "$tmp_cfg/games" "$tmp_cfg/launch.d/presets"
	cp "$REPO_ROOT/launch.d/presets/"*.env "$tmp_cfg/launch.d/presets/"
	printf '%s\n' '# old' 'INCLUDE=presets/standard.env' > "$tmp_cfg/games/2357570.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp_cfg" LAUNCHLAYER_GAMES_DIR="$tmp_cfg/games" STEAM_ROOT="$fake_steam" "$SCRIPT" --init-appid 2357570 lightweight --force
	[[ $status -eq 0 ]]
	[[ "$output" == *"Overwrote"* ]]
	grep -q 'presets/lightweight.env' "$tmp_cfg/games/2357570.env"
	rm -rf "$tmp_cfg" "$fake_steam"
}


@test "validate-config accepts game name" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	run env LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --validate-config overwatch
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


@test "tui requires interactive terminal" {
	run bash -c "$SCRIPT --tui </dev/null"
	[[ $status -ne 0 ]]
	[[ "$output" == *"interactive terminal"* ]]
}


@test "tui-prefs show reports defaults" {
	local tmp
	tmp="$(mktemp -d)"
	run env \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		"$SCRIPT" --tui-prefs show
	[[ $status -eq 0 ]]
	[[ "$output" == *"game_filter"* ]]
	[[ "$output" == *"default_preset"* ]]
	rm -rf "$tmp"
}


@test "dry-run verbose includes debug layers" {
	run "$SCRIPT" --verbose --dry-run /bin/echo test AppId=2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config layers"* ]]
}

