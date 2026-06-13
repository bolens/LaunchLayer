#!/usr/bin/env bash
# One-time workstation tuning: irqbalance, btrfs autodefrag, X3D IRQ affinity.
# Run: sudo scripts/setup-workstation-tuning.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"
IRQ_AFFINITY_CANDIDATES=(
	"$TARGET_HOME/.local/bin/irq-affinity-x3d"
	"$CONFIG_DIR/bin/irq-affinity-x3d"
	"/usr/local/bin/irq-affinity-x3d"
)

if [[ $EUID -ne 0 ]]; then
	echo "Run as root: sudo $0" >&2
	exit 1
fi

install_irqbalance() {
	if command -v irqbalance >/dev/null 2>&1; then
		return 0
	fi
	if command -v pacman >/dev/null 2>&1; then
		pacman -S --noconfirm irqbalance
	elif command -v apt-get >/dev/null 2>&1; then
		apt-get update && apt-get install -y irqbalance
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y irqbalance
	elif command -v zypper >/dev/null 2>&1; then
		zypper --non-interactive install irqbalance
	elif command -v apk >/dev/null 2>&1; then
		apk add irqbalance
	elif command -v emerge >/dev/null 2>&1; then
		emerge --ask=n sysutils/irqbalance
	elif command -v xbps-install >/dev/null 2>&1; then
		xbps-install -Sy irqbalance
	else
		echo "Install irqbalance manually (unsupported package manager)" >&2
		exit 1
	fi
}

resolve_irq_affinity_src() {
	local candidate
	for candidate in "${IRQ_AFFINITY_CANDIDATES[@]}"; do
		if [[ -f "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	return 1
}

echo "==> Installing irqbalance (if missing)"
install_irqbalance

echo "==> Enabling irqbalance"
systemctl enable --now irqbalance.service

echo "==> Enabling btrfs autodefrag on / and /home"
for mount in / /home; do
	if findmnt -n "$mount" >/dev/null 2>&1 && findmnt -n -o FSTYPE "$mount" | grep -q btrfs; then
		if btrfs property set "$mount" autodefrag true 2>/dev/null; then
			echo "  autodefrag on $mount"
		else
			echo "  warning: could not set autodefrag on $mount" >&2
		fi
	else
		echo "  skip $mount (not btrfs or not mounted)"
	fi
done

IRQ_AFFINITY_SRC="$(resolve_irq_affinity_src || true)"
if [[ -n "$IRQ_AFFINITY_SRC" && -f "$(launchlayer_share_dir)/systemd/irq-affinity-x3d.service" ]]; then
	echo "==> Installing X3D IRQ affinity helper + systemd service"
	install -Dm755 "$IRQ_AFFINITY_SRC" /usr/local/bin/irq-affinity-x3d
	install -Dm644 "$(launchlayer_share_dir)/systemd/irq-affinity-x3d.service" /etc/systemd/system/irq-affinity-x3d.service
	systemctl daemon-reload
	systemctl enable --now irq-affinity-x3d.service
else
	echo "==> Skipping X3D IRQ affinity (helper or service file not found)"
fi

echo
echo "Done."
echo "  irqbalance:     systemctl status irqbalance"
echo "  IRQ affinity:   systemctl status irq-affinity-x3d"
echo "  autodefrag:     btrfs property get /home autodefrag"
echo "  vm.max_map_count: launchlayer --sysctl status"
echo "  nvidia gaming:  enabled via NVIDIA_POWER_MODE=1 in competitive preset"
