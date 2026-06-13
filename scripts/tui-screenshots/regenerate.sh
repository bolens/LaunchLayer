#!/usr/bin/env bash
# Regenerate README TUI screenshots with VHS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
chmod +x scripts/tui-screenshots/*.sh
command -v vhs >/dev/null || {
	echo "vhs is required (paru -S vhs)" >&2
	exit 1
}
for tape in main game-picker quick-toggles; do
	echo "==> capture-${tape}.tape"
	vhs "scripts/tui-screenshots/capture-${tape}.tape"
done
echo "Wrote:"
ls -la docs/assets/tui-*.png
