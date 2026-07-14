#!/usr/bin/env bash
# Bump LaunchLayer CLI version strings to VERSION (X.Y.Z, no leading v).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

version=${1:-${VERSION:-}}
version="${version#v}"

if [[ -z "$version" || ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "usage: $0 X.Y.Z   (or make bump-version VERSION=X.Y.Z)" >&2
	exit 1
fi

current="$(sed -n 's/^LAUNCHLAYER_VERSION=//p' lib/cli.sh | head -1)"
[[ -n "$current" ]] || {
	echo "could not read LAUNCHLAYER_VERSION from lib/cli.sh" >&2
	exit 1
}

if [[ "$current" == "$version" ]]; then
	echo "already at $version"
	exit 0
fi

# lib/cli.sh
sed -i "s/^LAUNCHLAYER_VERSION=.*/LAUNCHLAYER_VERSION=${version}/" lib/cli.sh

# integration version assertion
if [[ -f test/integration/cli.bats ]]; then
	sed -i "s/version reports ${current}/version reports ${version}/g" test/integration/cli.bats
	sed -i "s/\\*\"${current}\"\\*/\*\"${version}\"\*/g" test/integration/cli.bats
fi

# docs examples that hardcode the version
if [[ -f docs/tui.md ]]; then
	sed -i "s/LaunchLayer ${current}/LaunchLayer ${version}/g" docs/tui.md
fi

echo "Bumped ${current} → ${version}"
echo "Next: edit CHANGELOG.md, then make check-version"
