# shellcheck shell=bash
# lib/hub/prefs.sh — Hub URL and publish token preferences.

[[ -n "${LAUNCHLAYER_HUB_PREFS_LOADED:-}" ]] && return 0
LAUNCHLAYER_HUB_PREFS_LOADED=1

# hub_config_path — XDG path for hub.conf.
hub_config_path() {
	hub_prefs_path
}

# _hub_prefs_set_defaults — Default hub preference globals.
_hub_prefs_set_defaults() {
	HUB_PREFS_URL="${HUB_PREFS_URL:-}"
	HUB_PREFS_PUBLISH_TOKEN="${HUB_PREFS_PUBLISH_TOKEN:-}"
	HUB_PREFS_MACHINE_LABEL="${HUB_PREFS_MACHINE_LABEL:-}"
	HUB_PREFS_FINGERPRINT_LEVEL="${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"
}

# _hub_prefs_parse_file — Parse hub.conf into HUB_PREFS_* globals.
_hub_prefs_parse_file() {
	local file=$1 line key val
	[[ -f "$file" ]] || return 1
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		key="${key#"${key%%[![:space:]]*}"}"
		val="${line#*=}"
		val="${val#"${val%%[![:space:]]*}"}"
		val="${val%"${val##*[![:space:]]}"}"
		case "$key" in
			hub_url) HUB_PREFS_URL="$val" ;;
			publish_token) HUB_PREFS_PUBLISH_TOKEN="$val" ;;
			machine_label) HUB_PREFS_MACHINE_LABEL="$val" ;;
			fingerprint_level)
				case "$val" in
					minimal|standard|detailed) HUB_PREFS_FINGERPRINT_LEVEL="$val" ;;
				esac
				;;
		esac
	done < "$file"
	return 0
}

# load_hub_prefs — Load hub preferences (defaults when missing).
load_hub_prefs() {
	_hub_prefs_set_defaults
	_hub_prefs_parse_file "$(hub_prefs_path)" || \
		_hub_prefs_parse_file "$(hub_prefs_example_path)" || true
	if [[ -n "${LAUNCHLAYER_HUB_URL:-}" ]]; then
		HUB_PREFS_URL="$LAUNCHLAYER_HUB_URL"
	fi
	if [[ -n "${LAUNCHLAYER_HUB_TOKEN:-}" ]]; then
		HUB_PREFS_PUBLISH_TOKEN="$LAUNCHLAYER_HUB_TOKEN"
	fi
	if [[ -n "${LAUNCHLAYER_HUB_FINGERPRINT_LEVEL:-}" ]]; then
		case "${LAUNCHLAYER_HUB_FINGERPRINT_LEVEL}" in
			minimal|standard|detailed) HUB_PREFS_FINGERPRINT_LEVEL="$LAUNCHLAYER_HUB_FINGERPRINT_LEVEL" ;;
		esac
	fi
	return 0
}

# save_hub_prefs — Persist hub preferences to the user config dir.
save_hub_prefs() {
	local file dir example
	_hub_prefs_set_defaults
	file="$(hub_prefs_path)"
	dir="$(dirname "$file")"
	example="$(hub_prefs_example_path)"
	mkdir -p "$dir"
	{
		echo "# LaunchLayer Hub preferences"
		[[ -f "$example" ]] && echo "# Defaults: $example"
		cat <<EOF
hub_url=${HUB_PREFS_URL}
publish_token=${HUB_PREFS_PUBLISH_TOKEN}
machine_label=${HUB_PREFS_MACHINE_LABEL}
fingerprint_level=${HUB_PREFS_FINGERPRINT_LEVEL}
EOF
	} > "$file"
}

# reset_hub_prefs — Restore hub.conf from the repo example template.
reset_hub_prefs() {
	local example user_file
	example="$(hub_prefs_example_path)"
	user_file="$(hub_prefs_path)"
	if [[ ! -f "$example" ]]; then
		echo "Missing hub template: $example" >&2
		return 1
	fi
	mkdir -p "$(dirname "$user_file")"
	cp "$example" "$user_file"
	load_hub_prefs
	echo "Reset hub preferences to defaults ($user_file)"
}

# hub_fingerprint_level_desc — One-line description for TUI/CLI display.
hub_fingerprint_level_desc() {
	case "${1:-minimal}" in
		standard) printf '%s\n' 'audio, VRAM tier, monitors, exact display' ;;
		detailed) printf '%s\n' 'full GPU/monitor lists and connector names' ;;
		*) printf '%s\n' 'GPU, OS, tiers, desktop only (default)' ;;
	esac
}

# show_hub_prefs — Print current hub preferences.
show_hub_prefs() {
	local json=${1:-0}
	load_hub_prefs
	if [[ "$json" == "1" ]]; then
		printf '{"path":%s,"example":%s,"hub_url":%s,"machine_label":%s,"fingerprint_level":%s,"publish_token_set":%s}\n' \
			"$(json_string "$(hub_prefs_path)")" \
			"$(json_string "$(hub_prefs_example_path)")" \
			"$(json_string "${HUB_PREFS_URL:-}")" \
			"$(json_string "${HUB_PREFS_MACHINE_LABEL:-}")" \
			"$(json_string "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}")" \
			"$(json_bool "$([[ -n "${HUB_PREFS_PUBLISH_TOKEN:-}" ]] && echo 1 || echo 0)")"
		return 0
	fi
	echo "=== Hub preferences ==="
	echo "path=$(hub_prefs_path)"
	echo "example=$(hub_prefs_example_path)"
	echo "hub_url=${HUB_PREFS_URL:-(not set)}"
	echo "machine_label=${HUB_PREFS_MACHINE_LABEL:-(not set)}"
	echo "fingerprint_level=${HUB_PREFS_FINGERPRINT_LEVEL:-minimal} ($(hub_fingerprint_level_desc "${HUB_PREFS_FINGERPRINT_LEVEL:-minimal}"))"
	if [[ -n "${HUB_PREFS_PUBLISH_TOKEN:-}" ]]; then
		echo "publish_token=(set)"
	else
		echo "publish_token=(not set)"
	fi
}

# hub_url_configured — True when a hub base URL is set.
hub_url_configured() {
	load_hub_prefs
	[[ -n "${HUB_PREFS_URL:-}" ]]
}

# hub_require_url — Fail with setup hint when hub URL is unset.
hub_require_url() {
	load_hub_prefs
	[[ -n "${HUB_PREFS_URL:-}" ]] || {
		echo "LaunchLayer Hub URL is not configured." >&2
		echo "Set hub_url in $(hub_config_path) (see share/launchlayer/templates/hub.conf.example)" >&2
		return 1
	}
}

# hub_prefs_set_key — Set a single hub preference by key name.
hub_prefs_set_key() {
	local key=$1 val=$2
	load_hub_prefs
	case "$key" in
		hub_url|url) HUB_PREFS_URL="$val" ;;
		publish_token|token) HUB_PREFS_PUBLISH_TOKEN="$val" ;;
		machine_label|label) HUB_PREFS_MACHINE_LABEL="$val" ;;
		fingerprint_level|fingerprint)
			case "$val" in
				minimal|standard|detailed) HUB_PREFS_FINGERPRINT_LEVEL="$val" ;;
				*)
					echo "fingerprint_level must be minimal, standard, or detailed" >&2
					return 1
					;;
			esac
			;;
		*)
			echo "Unknown hub preference key: $key" >&2
			echo "Keys: hub_url, publish_token, machine_label, fingerprint_level" >&2
			return 1
			;;
	esac
}

# handle_hub_prefs_subcommand — Manage hub.conf (show, reset, set).
handle_hub_prefs_subcommand() {
	local action=${1:-show} json=0
	shift || true
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json) json=1; shift ;;
			*) break ;;
		esac
	done
	load_hub_prefs
	case "$action" in
		show)
			show_hub_prefs "$json"
			;;
		reset)
			reset_hub_prefs || return $?
			;;
		set)
			local key=${1:-} val=${2:-}
			[[ -n "$key" && -n "$val" ]] || {
				echo "Usage: $0 --hub-prefs set KEY VALUE" >&2
				echo "Keys: hub_url, publish_token, machine_label, fingerprint_level" >&2
				return 1
			}
			hub_prefs_set_key "$key" "$val" || return $?
			save_hub_prefs
			echo "Set $key=$val"
			;;
		*)
			echo "Usage: $0 --hub-prefs {show|reset|set} [args...] [--json]" >&2
			return 1
			;;
	esac
}
