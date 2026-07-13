# shellcheck shell=bash
# lib/runtime/chain.sh — Wrapper chain assembly for Steam launch.

[[ -n "${LAUNCHLAYER_RUNTIME_CHAIN_LOADED:-}" ]] && return 0
LAUNCHLAYER_RUNTIME_CHAIN_LOADED=1

# append_launch_wrappers_from — Append installed binaries from a wrapper list to launch[].
append_launch_wrappers_from() {
	local wrappers=$1 wrapper
	for wrapper in $wrappers; do
		if launch_wrapper_available "$wrapper"; then
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
		launch+=(taskset -c "${CPU_AFFINITY_RANGE:-${X3D_CPUS:-$(default_online_cpus)}}")
	elif [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]]; then
		debug "taskset unavailable — continuing without CPU affinity wrapper"
	fi
	if [[ "${GAME_PERFORMANCE:-1}" == "1" ]] && launch_wrapper_available game-performance; then
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
		[[ "${GAMESCOPE_HDR:-0}" == "1" ]] && launch+=(--hdr-enabled)
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

	# --mangoapp already integrates MangoHUD; exporting MANGOHUD=1 would inject a
	# second overlay via the Vulkan/OpenGL layer path.
	if [[ "$use_mangoapp" == "1" ]]; then
		unset MANGOHUD
		debug "MANGOHUD unset — gamescope --mangoapp handles the overlay"
	fi

	debug "launch chain: ${launch[*]}"
}

# launch_wrapper_config_conflict_errors — Flag LAUNCH_WRAPPERS* overlapping built-in features.
launch_wrapper_config_conflict_errors() {
	local wrapper
	local -a errors=()

	for wrapper in ${LAUNCH_WRAPPERS_BEFORE:-} ${LAUNCH_WRAPPERS:-}; do
		case "$wrapper" in
			gamemoderun)
				[[ "${GAMEMODE:-0}" == "1" ]] \
					&& errors+=("LAUNCH_WRAPPERS includes gamemoderun while GAMEMODE=1")
				;;
			gamescope)
				[[ "${GAMESCOPE:-0}" == "1" ]] \
					&& errors+=("LAUNCH_WRAPPERS includes gamescope while GAMESCOPE=1")
				;;
			mangohud)
				[[ "${MANGOHUD:-0}" == "1" ]] \
					&& errors+=("LAUNCH_WRAPPERS includes mangohud while MANGOHUD=1")
				;;
			game-performance)
				[[ "${GAME_PERFORMANCE:-1}" == "1" ]] \
					&& errors+=("LAUNCH_WRAPPERS includes game-performance while GAME_PERFORMANCE=1")
				;;
		esac
	done

	if ((${#errors[@]})); then
		printf '%s\n' "${errors[@]}"
	fi
}

# warn_launch_chain_issues — Warn on config/chain wrapper conflicts; return 1 when any exist.
warn_launch_chain_issues() {
	local line had_issue=0

	while IFS= read -r line; do
		[[ -n "$line" ]] || continue
		warn "launch chain: $line"
		had_issue=1
	done < <(launch_wrapper_config_conflict_errors)

	while IFS= read -r line; do
		[[ -n "$line" ]] || continue
		warn "launch chain: $line"
		had_issue=1
	done < <(launch_chain_duplicate_wrapper_errors)

	(( !had_issue ))
}

# launch_chain_uses_mangohud — True when the resolved chain enables MangoHUD.
launch_chain_uses_mangohud() {
	local item
	for item in "${launch[@]}"; do
		[[ "$item" == mangohud || "$item" == --mangoapp ]] && return 0
	done
	return 1
}

# launch_chain_count_token — Count exact token matches in launch[].
launch_chain_count_token() {
	local token=$1 item count=0
	for item in "${launch[@]}"; do
		[[ "$item" == "$token" ]] && ((count++))
	done
	printf '%s' "$count"
}

# launch_chain_duplicate_wrapper_errors — One line per duplicate/conflict; empty when ok.
launch_chain_duplicate_wrapper_errors() {
	local wrapper item count=0
	local -a errors=()
	local has_mangohud=0 has_mangoapp=0

	for wrapper in gamemoderun game-performance gamescope mangohud; do
		count="$(launch_chain_count_token "$wrapper")"
		if (( count > 1 )); then
			errors+=("duplicate $wrapper in launch chain (count=$count)")
		fi
	done

	for item in "${launch[@]}"; do
		[[ "$item" == mangohud ]] && has_mangohud=1
		[[ "$item" == --mangoapp ]] && has_mangoapp=1
	done
	if (( has_mangohud && has_mangoapp )); then
		errors+=("mangohud wrapper and gamescope --mangoapp both present")
	fi

	if ((${#errors[@]})); then
		printf '%s\n' "${errors[@]}"
	fi
}

# launch_chain_has_duplicate_wrappers — True when launch_chain_duplicate_wrapper_errors is non-empty.
launch_chain_has_duplicate_wrappers() {
	[[ -n "$(launch_chain_duplicate_wrapper_errors)" ]]
}
