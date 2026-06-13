export type Fingerprint = {
  fingerprint_level?: string;
  gpu_vendor: string;
  gpus?: Array<{
    vendor: string;
    name: string;
    role: string;
    primary: boolean;
    index: number;
    vram_mb: number;
    pci_slot: string;
  }>;
  os_family: string;
  os_id?: string;
  os_pretty?: string;
  session_type: string;
  desktop?: string;
  profiles: string[];
  display?: string;
  display_tier: string;
  refresh_tier?: string;
  vram_tier?: string;
  monitor_layout?: string;
  primary_aspect?: string;
  has_igpu?: boolean;
  has_x3d?: boolean;
  active_output?: string;
  primary_output?: string;
  displays?: Array<{
    name: string;
    width: number;
    height: number;
    refresh: number;
    primary: boolean;
  }>;
  x3d_cpus?: string;
  vrr: boolean;
  wsl2: boolean;
  flatpak_steam: boolean;
  steam_deck: boolean;
  immutable: boolean;
  container?: boolean;
  audio?: string;
};

export function profileOverlapScore(left: string[], right: string[]): number {
  const rightSet = new Set(right);
  let matches = 0;
  for (const profile of left) {
    if (rightSet.has(profile)) {
      matches += 1;
    }
  }
  return Math.min(matches, 6) * 4;
}

function platformFlagScore(left: Fingerprint, right: Fingerprint): number {
  let score = 0;
  if (left.vrr && right.vrr) score += 2;
  if (left.wsl2 && right.wsl2) score += 2;
  if (left.flatpak_steam && right.flatpak_steam) score += 2;
  if (left.steam_deck && right.steam_deck) score += 2;
  if (left.immutable && right.immutable) score += 2;
  if (left.container && right.container) score += 2;
  return score;
}

function fieldMatch(
  left: string | undefined,
  right: string | undefined,
  options?: { ignoreUnknown?: boolean },
): boolean {
  if (!left || !right) {
    return false;
  }
  if (options?.ignoreUnknown && (left === "unknown" || right === "unknown")) {
    return false;
  }
  return left === right;
}

export function similarityScore(left: Fingerprint, right: Fingerprint): number {
  let score = 0;

  if (left.gpu_vendor && left.gpu_vendor === right.gpu_vendor) {
    score += 18;
  }
  if (left.display_tier && left.display_tier === right.display_tier) {
    score += 10;
  }
  if (fieldMatch(left.refresh_tier, right.refresh_tier)) {
    score += 5;
  }
  if (left.os_family && left.os_family === right.os_family) {
    score += 7;
  }
  if (left.session_type && left.session_type === right.session_type) {
    score += 7;
  }
  if (
    fieldMatch(left.desktop, right.desktop, { ignoreUnknown: true })
  ) {
    score += 8;
  }
  if (left.has_x3d && right.has_x3d) {
    score += 5;
  }
  if (
    left.x3d_cpus &&
    right.x3d_cpus &&
    left.x3d_cpus === right.x3d_cpus &&
    left.x3d_cpus !== "none"
  ) {
    score += 3;
  }
  if (fieldMatch(left.vram_tier, right.vram_tier, { ignoreUnknown: true })) {
    score += 5;
  }
  if (fieldMatch(left.monitor_layout, right.monitor_layout)) {
    score += 3;
  }
  if (
    fieldMatch(left.primary_aspect, right.primary_aspect, { ignoreUnknown: true })
  ) {
    score += 3;
  }
  if (fieldMatch(left.audio, right.audio, { ignoreUnknown: true })) {
    score += 4;
  }
  if (left.has_igpu === right.has_igpu) {
    score += 2;
  }

  score += profileOverlapScore(left.profiles, right.profiles);
  score += platformFlagScore(left, right);

  return Math.min(score, 100);
}
