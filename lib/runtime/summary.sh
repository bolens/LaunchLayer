# shellcheck shell=bash
# lib/runtime/summary.sh — Launch hooks and effective-config reporting.

[[ -n "${LAUNCHLAYER_RUNTIME_SUMMARY_LOADED:-}" ]] && return 0
LAUNCHLAYER_RUNTIME_SUMMARY_LOADED=1

# run_pre_launch_cmd — Execute PRE_LAUNCH_CMD hook if set.
run_pre_launch_cmd() {
	[[ -n "${PRE_LAUNCH_CMD:-}" ]] || return 0
	debug "PRE_LAUNCH_CMD: $PRE_LAUNCH_CMD"
	eval "$PRE_LAUNCH_CMD"
}

# run_post_launch_cmd — Execute POST_LAUNCH_CMD hook if set.
run_post_launch_cmd() {
	[[ -n "${POST_LAUNCH_CMD:-}" ]] || return 0
	debug "POST_LAUNCH_CMD: $POST_LAUNCH_CMD"
	eval "$POST_LAUNCH_CMD"
}

# for_each_effective_setting — Invoke callback(key, value, source_file) for each summary key.
for_each_effective_setting() {
	local callback=$1 key val source
	[[ "$(type -t "$callback")" == function ]] || return 1
	for key in "${LAUNCHLAYER_SUMMARY_KEYS[@]}"; do
		val="${!key-}"
		[[ -n "$val" ]] || continue
		source="${config_key_sources[$key]:-default}"
		"$callback" "$key" "$val" "$source"
	done
}

# print_effective_config_summary — Show non-default tunables with config layer source.
print_effective_config_summary() {
	_summary_print_line() {
		printf '  %s=%s  (%s)\n' "$1" "$2" "$(config_file_relative "$3")"
	}
	echo "Effective settings:"
	for_each_effective_setting _summary_print_line
}

# print_config_layers — List loaded config files in order.
print_config_layers() {
	local layer
	[[ ${#config_layers[@]} -gt 0 ]] || return 0
	echo "Config layers:"
	for layer in "${config_layers[@]}"; do
		echo "  → $(config_file_relative "$layer")"
	done
	echo
}
