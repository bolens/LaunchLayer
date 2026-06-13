# shellcheck shell=bash
# lib/commands/dispatch-tui.sh

[[ -n "${LAUNCHLAYER_DISPATCH_TUI_LOADED:-}" ]] && return 0
LAUNCHLAYER_DISPATCH_TUI_LOADED=1

# dispatch_tui_subcommand — Return 0 when verb is handled.
dispatch_tui_subcommand() {
	local verb=${1:-}
	shift || true
	case "$verb" in
		--tui-prefs)
			handle_tui_prefs_subcommand "$@"
			;;
		--tui-game-preview)
			local preview_appid=${1:-}
			[[ -n "$preview_appid" ]] || {
				echo "Usage: $0 --tui-game-preview APPID" >&2
				return 1
			}
			tui_render_game_preview "$preview_appid"
			;;
		--tui-game-preview-line)
			[[ $# -gt 0 ]] || {
				echo "Usage: $0 --tui-game-preview-line PICKER_ROW" >&2
				return 1
			}
			tui_render_game_preview_line "$@"
			;;
		--tui-picker-appid)
			[[ $# -gt 0 ]] || return 1
			tui_parse_game_picker_line "$@"
			;;
		--tui-help)
			local help_topic=${1:-menu}
			tui_show_help_overlay "$help_topic"
			;;
		--tui-panel)
			tui_panel_render
			;;
		--tui-panel-preview)
			[[ $# -gt 0 ]] || return 1
			tui_panel_preview_for_selection "$@"
			;;
		--tui-status-page)
			tui_render_status_page
			;;
		--tui)
			run_tui
			;;
		--tui-games-menu-reload)
			tui_games_menu_reload
			;;
		--tui-games-menu-footer)
			tui_games_menu_footer
			;;
		--tui-games-menu-header)
			tui_games_menu_header
			;;
		--tui-games-menu-resize-reload)
			tui_games_menu_resize_reload
			;;
		--tui-games-picker-reload)
			tui_games_picker_reload
			;;
		--tui-games-picker-footer)
			tui_games_picker_footer
			;;
		--tui-games-picker-header)
			tui_games_picker_header
			;;
		--tui-games-picker-resize-reload)
			tui_games_picker_resize_reload
			;;
		--tui-quick-toggles-reload)
			local toggle_appid=${1:-}
			[[ -n "$toggle_appid" ]] || {
				echo "Usage: $0 --tui-quick-toggles-reload APPID" >&2
				return 1
			}
			tui_quick_toggles_reload "$toggle_appid"
			;;
		--tui-quick-toggles-flip)
			local flip_appid=${1:-} flip_line=${2:-}
			[[ -n "$flip_appid" && -n "$flip_line" ]] || {
				echo "Usage: $0 --tui-quick-toggles-flip APPID LINE" >&2
				return 1
			}
			tui_quick_toggles_flip "$flip_appid" "$flip_line"
			;;
		*)
			return 1
			;;
	esac
}
