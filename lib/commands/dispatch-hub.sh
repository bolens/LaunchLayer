# shellcheck shell=bash
# lib/commands/dispatch-hub.sh

[[ -n "${LAUNCHLAYER_DISPATCH_HUB_LOADED:-}" ]] && return 0
LAUNCHLAYER_DISPATCH_HUB_LOADED=1

# dispatch_hub_subcommand — Return 0 when verb is handled.
dispatch_hub_subcommand() {
	local verb=${1:-}
	shift || true
	case "$verb" in
		--hub-fingerprint)
			load_profile_config
			load_config_file "$LAUNCHD_DIR/default.env" 0
			[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
			apply_defaults
			hub_show_fingerprint "$@"
			;;
		--hub-publish)
			hub_publish_config "$@"
			;;
		--hub-update)
			hub_update_config "$@"
			;;
		--hub-delete)
			hub_delete_config "$@"
			;;
		--hub-recommend)
			hub_recommend_configs "$@"
			;;
		--hub-apply)
			hub_apply_config "$@"
			;;
		--hub-search)
			hub_search_machines "$@"
			;;
		--hub-prefs)
			handle_hub_prefs_subcommand "$@"
			;;
		*)
			return 1
			;;
	esac
}
