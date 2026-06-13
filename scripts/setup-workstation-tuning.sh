#!/usr/bin/env bash
# One-time workstation tuning: irqbalance, btrfs autodefrag, X3D IRQ affinity.
# Run: sudo /path/to/setup-workstation-tuning.sh
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
if [[ -n "$IRQ_AFFINITY_SRC" && -f "$CONFIG_DIR/systemd/irq-affinity-x3d.service" ]]; then
	echo "==> Installing X3D IRQ affinity helper + systemd service"
	install -Dm755 "$IRQ_AFFINITY_SRC" /usr/local/bin/irq-affinity-x3d
	install -Dm644 "$CONFIG_DIR/systemd/irq-affinity-x3d.service" /etc/systemd/system/irq-affinity-x3d.service
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
echo "  nvidia gaming:  enabled via NVIDIA_POWER_MODE=1 in competitive preset"
