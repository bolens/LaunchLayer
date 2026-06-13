#!/usr/bin/env bash
# Fail if staged files include hub secrets, deps, or local Convex deployment state.
set -euo pipefail

is_blocked_path() {
	local path=$1
	case "$path" in
		hub/.env|hub/.env.*)
			[[ "$path" == hub/.env.example ]] && return 1
			return 0
			;;
		hub/.convex|hub/.convex/*)
			return 0
			;;
		hub/node_modules|hub/node_modules/*)
			return 0
			;;
		hub/.agents|hub/.agents/*|hub/.claude|hub/.claude/*)
			return 0
			;;
		hub/skills-lock.json|hub/AGENTS.md|hub/CLAUDE.md)
			return 0
			;;
		hub/convex/_generated/ai|hub/convex/_generated/ai/*)
			return 0
			;;
		.pnpm-store|.pnpm-store/*|node_modules|node_modules/*)
			return 0
			;;
	esac
	return 1
}

blocked=0
while IFS= read -r path; do
	[[ -n "$path" ]] || continue
	if is_blocked_path "$path"; then
		printf 'Refusing to commit ignored hub secret/state path: %s\n' "$path" >&2
		blocked=1
	fi
done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if ((blocked)); then
	exit 1
fi
