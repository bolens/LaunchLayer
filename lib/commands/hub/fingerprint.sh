# shellcheck shell=bash
# lib/commands/hub/fingerprint.sh — --hub-fingerprint output.

[[ -n "${LAUNCHLAYER_COMMANDS_HUB_FINGERPRINT_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_HUB_FINGERPRINT_LOADED=1

# hub_show_fingerprint — Print normalized machine fingerprint for similarity matching.
hub_show_fingerprint() {
	local json=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json) json=1; shift ;;
			--fingerprint-level)
				export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL=${2:-minimal}
				shift 2
				;;
			--fingerprint-level=*)
				export LAUNCHLAYER_HUB_FINGERPRINT_LEVEL="${1#--fingerprint-level=}"
				shift
				;;
			*) shift ;;
		esac
	done

	load_hub_prefs
	hub_load_launch_context

	local fp hash level
	level="$(hub_fingerprint_level)"
	fp="$(hub_fingerprint_from_detection)"
	hash="$(hub_fingerprint_hash "$fp")"

	if [[ "$json" == "1" ]]; then
		printf '{"fingerprint":'
		printf '%s' "$fp"
		printf ',"fingerprint_hash":%s,"fingerprint_level":%s}\n' \
			"$(json_string "$hash")" \
			"$(json_string "$level")"
		return 0
	fi

	cli_section "Machine fingerprint"
	env_report_row "Level" "$(cli_cyan "$level")"
	env_report_row "Hash" "$(cli_dim "$hash")"
	if command -v jq >/dev/null 2>&1; then
		printf '%s\n' "$fp" | jq . 2>/dev/null || printf '%s\n' "$fp"
	else
		printf '%s\n' "$fp"
	fi
}
