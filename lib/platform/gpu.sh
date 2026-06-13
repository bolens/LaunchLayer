# shellcheck shell=bash
# lib/platform/gpu.sh — GPU vendor, enumeration, and VRAM helpers.

# _gpu_vendor_slug — Map PCI vendor id to launchlayer slug.
_gpu_vendor_slug() {
	local id=${1,,}
	id=${id#0x}
	case "$id" in
		10de) printf 'nvidia' ;;
		1002) printf 'amd' ;;
		8086) printf 'intel' ;;
		*) printf 'unknown' ;;
	esac
}

# _gpu_normalize_pci — Normalize PCI slot strings for deduplication.
_gpu_normalize_pci() {
	local slot=$1
	slot=${slot#00000000:}
	slot=${slot#0000:}
	printf '%s' "$slot"
}

# _gpu_role_guess — integrated vs discrete from vendor and device name.
_gpu_role_guess() {
	local vendor=$1 name=$2
	local lname=${name,,}

	case "$vendor" in
		intel) printf 'integrated' ;;
		nvidia) printf 'discrete' ;;
		amd)
			if [[ "$lname" =~ raphael|phoenix|hawk|monet|van[[:space:]]gogh|strix|ryzen[[:space:]]graphics|radeon[[:space:]]graphics ]]; then
				printf 'integrated'
			else
				printf 'discrete'
			fi
			;;
		*) printf 'unknown' ;;
	esac
}

# _gpu_primary_score — Higher score wins primary gaming GPU selection.
_gpu_primary_score() {
	local vendor=$1 role=$2
	case "$vendor" in
		nvidia)
			[[ "$role" == discrete ]] && { printf '300'; return; }
			printf '100'
			;;
		amd)
			[[ "$role" == discrete ]] && { printf '200'; return; }
			printf '50'
			;;
		intel) printf '40' ;;
		*) printf '0' ;;
	esac
}

# _gpu_sysfs_name — Human-readable GPU name from DRM device path.
_gpu_sysfs_name() {
	local device=$1 slot name card
	slot="$(grep -m1 '^PCI_SLOT_NAME=' "$device/uevent" 2>/dev/null | cut -d= -f2- || true)"
	if [[ -n "$slot" ]] && command -v lspci >/dev/null 2>&1; then
		name="$(lspci -s "$slot" 2>/dev/null | cut -d: -f3- | sed 's/^[[:space:]]*//')"
	fi
	if [[ -z "$name" ]]; then
		card="$(basename "$(dirname "$device")")"
		name="GPU ${card}"
	fi
	printf '%s' "$name"
}

# _gpu_collect_nvidia_smi — Append NVIDIA GPUs from nvidia-smi (TSV rows).
_gpu_collect_nvidia_smi() {
	local -n _out=$1
	local -n _seen=$2
	local idx pci name vram vendor role norm

	command -v nvidia-smi >/dev/null 2>&1 || return 0
	while IFS=',' read -r idx pci name vram _rest; do
		idx="${idx// /}"
		pci="${pci// /}"
		name="${name# }"
		name="${name% }"
		vram="${vram// /}"
		vram="${vram%MiB}"
		[[ "$idx" =~ ^[0-9]+$ ]] || continue
		[[ "$vram" =~ ^[0-9]+$ ]] || vram=0
		vendor=nvidia
		role=discrete
		norm="$(_gpu_normalize_pci "$pci")"
		[[ -n "$norm" ]] || continue
		[[ -n "${_seen[$norm]:-}" ]] && continue
		_seen[$norm]=1
		_out+=("${vendor}"$'\t'"${role}"$'\t'"0"$'\t'"${idx}"$'\t'"${vram}"$'\t'"${norm}"$'\t'"${name}")
	done < <(nvidia-smi --query-gpu=index,pci.bus_id,name,memory.total \
		--format=csv,noheader 2>/dev/null)
}

# _gpu_collect_sysfs — Append GPUs from /sys/class/drm/cardN/device.
_gpu_collect_sysfs() {
	# shellcheck disable=SC2178  # nameref to caller's rows[] / seen_pci[] arrays
	local -n _out=$1
	# shellcheck disable=SC2178
	local -n _seen=$2
	local device vendor_file vendor slug name role slot norm vram idx

	is_linux || return 0
	for vendor_file in /sys/class/drm/card[0-9]/device/vendor; do
		[[ -f "$vendor_file" ]] || continue
		device="$(dirname "$vendor_file")"
		vendor="$(<"$vendor_file")"
		slug="$(_gpu_vendor_slug "$vendor")"
		[[ "$slug" != unknown ]] || continue
		slot="$(grep -m1 '^PCI_SLOT_NAME=' "$device/uevent" 2>/dev/null | cut -d= -f2- || true)"
		norm="$(_gpu_normalize_pci "${slot:-}")"
		[[ -n "$norm" ]] || continue
		[[ -n "${_seen[$norm]:-}" ]] && continue
		name="$(_gpu_sysfs_name "$device")"
		role="$(_gpu_role_guess "$slug" "$name")"
		vram=0
		if [[ -f "$device/mem_info_vram_total" ]]; then
			vram="$(<"$device/mem_info_vram_total")"
			[[ "$vram" =~ ^[0-9]+$ ]] && vram=$(( vram / 1024 / 1024 )) || vram=0
		fi
		idx="${#_out[@]}"
		_seen[$norm]=1
		_out+=("${slug}"$'\t'"${role}"$'\t'"0"$'\t'"${idx}"$'\t'"${vram}"$'\t'"${norm}"$'\t'"${name}")
	done
}

# _gpu_collect_pciconf — Append GPUs from pciconf on BSD.
_gpu_collect_pciconf() {
	# shellcheck disable=SC2178  # nameref to caller's rows[] / seen_pci[] arrays
	local -n _out=$1
	# shellcheck disable=SC2178
	local -n _seen=$2
	local line slug name role idx norm

	is_bsd || return 0
	command -v pciconf >/dev/null 2>&1 || return 0
	idx=0
	while IFS= read -r line; do
		local slug=""
		[[ "$line" == *0x10de* ]] && slug=nvidia
		[[ "$line" == *0x1002* ]] && slug=amd
		[[ "$line" == *0x8086* ]] && slug=intel
		[[ -n "$slug" ]] || continue
		name="${line#*:}"
		name="${name#*:}"
		name="${name# }"
		role="$(_gpu_role_guess "$slug" "$name")"
		norm="bsd-${idx}"
		[[ -n "${_seen[$norm]:-}" ]] && continue
		_seen[$norm]=1
		_out+=("${slug}"$'\t'"${role}"$'\t'"0"$'\t'"${idx}"$'\t'"0"$'\t'"${norm}"$'\t'"${name}")
		idx=$((idx + 1))
	done < <(pciconf -l 2>/dev/null | grep -iE 'class=0x03[0-9a-f]*' || true)
}

# detect_gpus_enumerate — TSV rows: vendor role primary index vram_mb pci_slot name.
detect_gpus_enumerate() {
	local -a rows=() scored=()
	local -A seen_pci=()
	local row vendor role pri idx vram pci name best_score=-1 best_i=0 score i

	_gpu_collect_nvidia_smi rows seen_pci
	_gpu_collect_sysfs rows seen_pci
	((${#rows[@]})) || _gpu_collect_pciconf rows seen_pci
	((${#rows[@]})) || return 0

	for i in "${!rows[@]}"; do
		IFS=$'\t' read -r vendor role _ idx vram pci name <<< "${rows[$i]}"
		score="$(_gpu_primary_score "$vendor" "$role")"
		scored+=("$score")
		if (( score > best_score )); then
			best_score=$score
			best_i=$i
		fi
	done

	for i in "${!rows[@]}"; do
		IFS=$'\t' read -r vendor role _ idx vram pci name <<< "${rows[$i]}"
		pri=0
		(( i == best_i )) && pri=1
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$vendor" "$role" "$pri" "$idx" "$vram" "$pci" "$name"
	done
	return 0
}

# detect_gpus_json — JSON array of detected GPUs.
detect_gpus_json() {
	local -a rows=()
	local first=1 row vendor role pri idx vram pci name

	mapfile -t rows < <(detect_gpus_enumerate)
	if ((${#rows[@]} == 0)); then
		printf '[]'
		return 0
	fi
	printf '['
	for row in "${rows[@]}"; do
		IFS=$'\t' read -r vendor role pri idx vram pci name <<< "$row"
		(( first )) || printf ','
		first=0
		printf '{"vendor":%s,"name":%s,"role":%s,"primary":%s,"index":%s,"vram_mb":%s,"pci_slot":%s}' \
			"$(json_string "$vendor")" \
			"$(json_string "$name")" \
			"$(json_string "$role")" \
			"$(json_bool "$pri")" \
			"$idx" \
			"${vram:-0}" \
			"$(json_string "$pci")"
	done
	printf ']'
}

# detect_gpu_vendor — Primary gaming GPU vendor (discrete preferred over integrated).
detect_gpu_vendor() {
	local vendor="" row pri

	while IFS=$'\t' read -r vendor _ pri _ _ _ _; do
		[[ "$pri" == "1" ]] && { printf '%s\n' "$vendor"; return 0; }
	done < <(detect_gpus_enumerate)

	while IFS=$'\t' read -r vendor role _ _ _ _ _; do
		[[ "$role" == discrete ]] && { printf '%s\n' "$vendor"; return 0; }
	done < <(detect_gpus_enumerate)

	vendor="$(detect_gpus_enumerate | awk -F'\t' 'NR == 1 { print $1; exit }')"
	[[ -n "$vendor" ]] && { printf '%s\n' "$vendor"; return 0; }
	printf 'unknown\n'
}

# detect_gpu_summary — Compact human-readable multi-GPU summary.
detect_gpu_summary() {
	local -a parts=()
	local row vendor role pri idx vram name label

	while IFS=$'\t' read -r vendor role pri idx vram _ name; do
		label="${vendor}"
		[[ -n "$name" ]] && label+=" (${name})"
		[[ "$role" == integrated ]] && label+=" [iGPU]"
		[[ "$pri" == "1" ]] && label="* ${label}"
		if [[ "$vram" =~ ^[0-9]+$ && "$vram" -gt 0 ]]; then
			label+=" · ${vram} MB"
		fi
		parts+=("$label")
	done < <(detect_gpus_enumerate)

	((${#parts[@]})) || { detect_gpu_vendor; return 0; }
	(IFS=' · '; printf '%s' "${parts[*]}")
}

# gpu_vram_free_mb — Best-effort free VRAM in MB for the primary GPU.
gpu_vram_free_mb() {
	local vendor free_mb="" row pri slug

	while IFS=$'\t' read -r slug _ pri _ _ _ _; do
		[[ "$pri" == "1" ]] && vendor=$slug && break
	done < <(detect_gpus_enumerate)
	[[ -n "$vendor" ]] || vendor="$(detect_gpu_vendor)"

	case "$vendor" in
		nvidia)
			command -v nvidia-smi >/dev/null 2>&1 || return 1
			local primary_idx=""
			while IFS=$'\t' read -r slug _ pri idx _ _ _; do
				[[ "$pri" == "1" && "$slug" == nvidia ]] && primary_idx=$idx && break
			done < <(detect_gpus_enumerate)
			if [[ -n "$primary_idx" ]]; then
				free_mb="$( { nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits \
					-i "$primary_idx" 2>/dev/null || true; } | head -1 | tr -d ' ')"
			else
				free_mb="$( { nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits \
					2>/dev/null || true; } | head -1 | tr -d ' ')"
			fi
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
				[[ "$total" -gt 0 ]] || continue
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
