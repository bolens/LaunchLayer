#!/usr/bin/env bash
# Unit tests for lib/hub/similarity.sh scoring.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib hub
}

@test "hub_json_get reads string fields" {
	local fp='{"gpu_vendor":"nvidia","desktop":"kde"}'
	run hub_json_get "$fp" gpu_vendor
	[[ $status -eq 0 ]]
	[[ "$output" == "nvidia" ]]
}

@test "hub_json_get_bool detects true values" {
	local fp='{"vrr":true,"wsl2":false}'
	run hub_json_get_bool "$fp" vrr
	[[ $status -eq 0 ]]

	run hub_json_get_bool "$fp" wsl2
	[[ $status -eq 1 ]]

	run bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hub
		fp='"'"'{"vrr":true,"wsl2":false}'"'"'
		hub_json_get_bool "$fp" vrr && echo vrr-true || echo vrr-false
		hub_json_get_bool "$fp" wsl2 && echo wsl2-true || echo wsl2-false
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'vrr-true\nwsl2-false' ]]
}

@test "hub_profile_overlap_score returns bounded integer" {
	local score
	score="$(hub_profile_overlap_score '{"profiles":["arch-linux"]}' '{"profiles":["fedora"]}')"
	[[ "$score" =~ ^[0-9]+$ ]]
	(( score <= 24 ))
}

@test "hub_platform_flag_score awards matching flags" {
	local flags='{"vrr":true,"wsl2":true,"flatpak_steam":true,"steam_deck":true,"immutable":true,"container":true}'
	local score
	score="$(hub_platform_flag_score "$flags" "$flags")"
	[[ "$score" == "12" ]]
}

@test "hub_similarity_score ranks identical fingerprints highest" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux","nvidia-desktop"],"display_tier":"ultrawide","refresh_tier":"hi144+","has_x3d":true,"x3d_cpus":"0-7","vram_tier":"12gb","monitor_layout":"triple+","primary_aspect":"21:9","audio":"pipewire","has_igpu":true,"vrr":true,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	local other='{"gpu_vendor":"amd","os_family":"fedora","session_type":"x11","desktop":"gnome","profiles":["fedora","amd-gpu"],"display_tier":"1080p","refresh_tier":"std60","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	local score_diff score_same

	score_same="$(hub_similarity_score "$fp" "$fp")"
	score_diff="$(hub_similarity_score "$fp" "$other")"
	[[ "$score_same" -ge 80 ]]
	[[ "$score_diff" -lt "$score_same" ]]
}

@test "hub_similarity_score gives partial credit for desktop and refresh tier" {
	local kde='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux"],"display_tier":"ultrawide","refresh_tier":"hi144+","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	local hypr='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"hyprland","profiles":["arch-linux"],"display_tier":"ultrawide","refresh_tier":"hi144+","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	local score_same score_diff

	score_same="$(hub_similarity_score "$kde" "$kde")"
	score_diff="$(hub_similarity_score "$kde" "$hypr")"
	[[ "$score_same" -gt "$score_diff" ]]
}
