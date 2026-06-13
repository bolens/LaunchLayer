# shellcheck shell=bash
# lib/runtime/chain.sh — Wrapper chain assembly for Steam launch.

[[ -n "${LAUNCHLAYER_RUNTIME_CHAIN_LOADED:-}" ]] && return 0
LAUNCHLAYER_RUNTIME_CHAIN_LOADED=1

# append_launch_wrappers_from — Append installed binaries from a wrapper list to launch[].
append_launch_wrappers_from() {
	local wrappers=$1 wrapper
	for wrapper in $wrappers; do
		if command_available "$wrapper"; then
			launch+=("$wrapper")
		else
			debug "launch wrapper skipped (not installed): $wrapper"
		fi
	done
}

# append_launch_wrappers — Prepend LAUNCH_WRAPPERS_BEFORE binaries to the chain.
append_launch_wrappers() {
	append_launch_wrappers_from "${LAUNCH_WRAPPERS_BEFORE}"
}

# append_launch_wrappers_after_performance — Append LAUNCH_WRAPPERS after game-performance.
append_launch_wrappers_after_performance() {
	append_launch_wrappers_from "${LAUNCH_WRAPPERS}"
}

# parse_game_extra_args — Split GAME_EXTRA_ARGS into game_extra_argv[].
parse_game_extra_args() {
	game_extra_argv=()
	[[ -n "${GAME_EXTRA_ARGS:-}" ]] || return 0
	local arg
	read -r -a game_extra_argv <<< "$GAME_EXTRA_ARGS"
	for arg in "${game_extra_argv[@]}"; do
		debug "extra arg: $arg"
	done
}

# build_launch_chain — Assemble the wrapper prefix executed before Steam's %command%.
#
# Typical chain:
#   [wrappers_before] → gamemoderun → taskset → game-performance
#   → [wrappers] → [gamescope --mangoapp] → [mangohud]
build_launch_chain() {
	local use_mangoapp=0

	launch=( )
	append_launch_wrappers

	if [[ "${GAMEMODE:-1}" == "1" ]] && optional_tool_installed gamemoderun; then
		launch+=(gamemoderun)
	elif [[ "${GAMEMODE:-1}" == "1" ]]; then
		debug "gamemoderun unavailable — continuing without GameMode wrapper"
	fi

	if [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]] && optional_tool_installed taskset; then
		launch+=(taskset -c "${X3D_CPUS:-$(default_online_cpus)}")
	elif [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]]; then
		debug "taskset unavailable — continuing without CPU affinity wrapper"
	fi
	if [[ "${GAME_PERFORMANCE:-1}" == "1" ]] && command_available game-performance; then
		launch+=(game-performance)
	fi
	append_launch_wrappers_after_performance

	if [[ "${GAMESCOPE:-0}" == "1" && "$is_native" == "1" && "${FORCE_PROTON:-0}" != "1" ]]; then
		warn "GAMESCOPE=1 on native game — set FORCE_PROTON=1 if intentional"
	fi

	if [[ "${GAMESCOPE:-0}" == "1" ]] && optional_tool_installed gamescope; then
		launch+=(gamescope)
		launch+=(-W "${GAMESCOPE_W}" -H "${GAMESCOPE_H}" -r "${GAMESCOPE_R:-120}")
		launch+=(-f --force-grab-cursor)
		[[ "${GAMESCOPE_ADAPTIVE_SYNC:-0}" == "1" ]] && launch+=(--adaptive-sync)
		[[ "${GAMESCOPE_EXPOSE_WAYLAND:-0}" == "1" ]] && launch+=(--expose-wayland)
		[[ "${GAMESCOPE_FSR:-0}" == "1" ]] && launch+=(--fsr-sharpness "${GAMESCOPE_FSR_SHARPNESS:-5}")
		# --mangoapp integrates MangoHUD inside gamescope (avoids double-wrapping).
		if [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" ]]; then
			launch+=(--mangoapp)
			use_mangoapp=1
		fi
		launch+=(--)
	elif [[ "${GAMESCOPE:-0}" == "1" ]]; then
		debug "gamescope unavailable — continuing without Gamescope wrapper"
	fi

	if [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" && "$use_mangoapp" != "1" ]] \
		&& optional_tool_installed mangohud; then
		launch+=(mangohud)
	elif [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" && "$use_mangoapp" != "1" ]]; then
		debug "mangohud unavailable — continuing without MangoHUD wrapper"
	fi

	debug "launch chain: ${launch[*]}"
}
