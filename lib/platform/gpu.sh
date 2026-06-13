# shellcheck shell=bash
# lib/platform/gpu.sh — GPU vendor and VRAM helpers.
# detect_gpu_vendor — Return nvidia, amd, intel, or unknown.
detect_gpu_vendor() {
	local vendor pci_line
	if command -v nvidia-smi >/dev/null 2>&1 \
		&& nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -q .; then
		echo nvidia
		return 0
	fi
	if is_linux; then
		for vendor in /sys/class/drm/card*/device/vendor; do
			[[ -f "$vendor" ]] || continue
			case "$(<"$vendor")" in
				0x10de) echo nvidia; return 0 ;;
				0x1002) echo amd; return 0 ;;
				0x8086) echo intel; return 0 ;;
			esac
		done
	fi
	if is_bsd && command -v pciconf >/dev/null 2>&1; then
		pci_line="$(pciconf -l 2>/dev/null | grep -iE 'class=0x03[0-9a-f]*' | head -1 || true)"
		[[ "$pci_line" == *0x10de* ]] && { echo nvidia; return 0; }
		[[ "$pci_line" == *0x1002* ]] && { echo amd; return 0; }
		[[ "$pci_line" == *0x8086* ]] && { echo intel; return 0; }
	fi
	echo unknown
}

# gpu_vram_free_mb — Best-effort free VRAM in MB for the primary GPU.
gpu_vram_free_mb() {
	local vendor free_mb=""
	vendor="$(detect_gpu_vendor)"

	case "$vendor" in
		nvidia)
			command -v nvidia-smi >/dev/null 2>&1 || return 1
			free_mb="$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null \
				| head -1 | tr -d ' ')"
			[[ "$free_mb" =~ ^[0-9]+$ ]] && echo "$free_mb"
			;;
		amd)
			local mem node total used
			for mem in /sys/class/drm/card*/device/mem_info_vram_used; do
				[[ -f "$mem" ]] || continue
				node="${mem%/mem_info_vram_used}"
				total="$(cat "${node}/mem_info_vram_total" 2>/dev/null || echo 0)"
				used="$(cat "$mem" 2>/dev/null || echo 0)"
				[[ "$total" =~ ^[0-9]+$ && "$used" =~ ^[0-9]+$ ]] || continue
				free_mb=$(( (total - used) / 1024 / 1024 ))
				echo "$free_mb"
				return 0
			done
			return 1
			;;
		*)
			return 1
			;;
	esac
}
