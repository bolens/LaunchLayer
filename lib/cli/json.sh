# shellcheck shell=bash
# lib/cli/json.sh — JSON encoding helpers for --json CLI output.

[[ -n "${LAUNCHLAYER_CLI_JSON_LOADED:-}" ]] && return 0
LAUNCHLAYER_CLI_JSON_LOADED=1

# json_string — Escape and quote a value for JSON output.
json_string() {
	local s=${1-}
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	s="${s//$'\n'/\\n}"
	s="${s//$'\r'/\\r}"
	s="${s//$'\t'/\\t}"
	printf '"%s"' "$s"
}

# json_bool — Emit JSON true/false from common shell truthiness.
json_bool() {
	case "${1:-0}" in
		1|yes|true|on) printf 'true' ;;
		*) printf 'false' ;;
	esac
}

# json_number_or_string — Numeric JSON value or quoted string when not numeric.
json_number_or_string() {
	local v=${1-}
	if [[ "$v" =~ ^-?[0-9]+$ ]]; then
		printf '%s' "$v"
	else
		json_string "$v"
	fi
}

# json_array_strings — JSON array from a bash array of strings.
json_array_strings() {
	local -n _items=$1
	local first=1 item
	printf '['
	for item in "${_items[@]}"; do
		(( first )) || printf ','
		first=0
		json_string "$item"
	done
	printf ']'
}

# json_object_pair — Print one "key":value object field (comma prefix optional).
json_object_pair() {
	local key=$1 value=$2 prefix_comma=${3:-0}
	(( prefix_comma )) && printf ','
	printf '%s:' "$(json_string "$key")"
	printf '%s' "$value"
}

# printf_cache_path_bytes_json — Print [{"path":...,"bytes":...,"gb":...},...] from path|bytes entries.
printf_cache_path_bytes_json() {
	local -n _entries=$1
	local first=1 entry path bytes
	printf '['
	for entry in "${_entries[@]}"; do
		path="${entry%%|*}"
		bytes="${entry##*|}"
		(( first )) || printf ','
		first=0
		printf '{"path":%s,"bytes":%s,"gb":%s}' \
			"$(json_string "$path")" "$bytes" "$(json_string "$(bytes_to_gb "${bytes:-0}")")"
	done
	printf ']'
}

# printf_cache_dirs_json_pair — Print ,"shader_cache":[...],"compatdata":[...].
printf_cache_dirs_json_pair() {
	local -n _shader=$1 _compat=$2
	printf ',"shader_cache":'
	printf_cache_path_bytes_json _shader
	printf ',"compatdata":'
	printf_cache_path_bytes_json _compat
}
