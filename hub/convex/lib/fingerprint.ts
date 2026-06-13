import type { Fingerprint } from "./similarity";

function optionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function requiredBool(value: unknown): boolean {
  return value === true || value === "true" || value === 1;
}

function parseProfiles(raw: unknown): string[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.map(String);
}

function parseGpus(raw: unknown): Fingerprint["gpus"] {
  if (!Array.isArray(raw)) {
    return undefined;
  }
  return raw.map((entry) => {
    const gpu = entry as Record<string, unknown>;
    return {
      vendor: String(gpu.vendor ?? "unknown"),
      name: String(gpu.name ?? "unknown"),
      role: String(gpu.role ?? "unknown"),
      primary: gpu.primary === true || gpu.primary === "true" || gpu.primary === 1,
      index: Number(gpu.index ?? 0),
      vram_mb: Number(gpu.vram_mb ?? 0),
      pci_slot: String(gpu.pci_slot ?? ""),
    };
  });
}

function parseDisplays(raw: unknown): Fingerprint["displays"] {
  if (!Array.isArray(raw)) {
    return undefined;
  }
  return raw.map((entry) => {
    const display = entry as Record<string, unknown>;
    return {
      name: String(display.name ?? ""),
      width: Number(display.width ?? 0),
      height: Number(display.height ?? 0),
      refresh: Number(display.refresh ?? 0),
      primary:
        display.primary === true ||
        display.primary === "true" ||
        display.primary === 1,
    };
  });
}

/** Parse client fingerprint JSON from HTTP bodies into the stored Fingerprint shape. */
export function parseFingerprint(raw: unknown): Fingerprint {
  const fp = (raw ?? {}) as Record<string, unknown>;

  return {
    fingerprint_level: optionalString(fp.fingerprint_level),
    gpu_vendor: String(fp.gpu_vendor ?? "unknown"),
    gpus: parseGpus(fp.gpus),
    os_family: String(fp.os_family ?? "unknown"),
    os_id: optionalString(fp.os_id),
    os_pretty: optionalString(fp.os_pretty),
    session_type: String(fp.session_type ?? "unknown"),
    desktop: optionalString(fp.desktop),
    profiles: parseProfiles(fp.profiles),
    display: optionalString(fp.display),
    display_tier: String(fp.display_tier ?? "unknown"),
    refresh_tier: optionalString(fp.refresh_tier),
    vram_tier: optionalString(fp.vram_tier),
    monitor_layout: optionalString(fp.monitor_layout),
    primary_aspect: optionalString(fp.primary_aspect),
    has_igpu:
      typeof fp.has_igpu === "boolean"
        ? fp.has_igpu
        : fp.has_igpu === "true" || fp.has_igpu === 1
          ? true
          : fp.has_igpu === "false" || fp.has_igpu === 0
            ? false
            : undefined,
    has_x3d:
      typeof fp.has_x3d === "boolean"
        ? fp.has_x3d
        : fp.has_x3d === "true" || fp.has_x3d === 1
          ? true
          : fp.has_x3d === "false" || fp.has_x3d === 0
            ? false
            : undefined,
    active_output: optionalString(fp.active_output),
    primary_output: optionalString(fp.primary_output),
    displays: parseDisplays(fp.displays),
    x3d_cpus: optionalString(fp.x3d_cpus),
    vrr: requiredBool(fp.vrr),
    wsl2: requiredBool(fp.wsl2),
    flatpak_steam: requiredBool(fp.flatpak_steam),
    steam_deck: requiredBool(fp.steam_deck),
    immutable: requiredBool(fp.immutable),
    container:
      typeof fp.container === "boolean"
        ? fp.container
        : fp.container === "true" || fp.container === 1
          ? true
          : fp.container === "false" || fp.container === 0
            ? false
            : undefined,
    audio: optionalString(fp.audio),
  };
}
