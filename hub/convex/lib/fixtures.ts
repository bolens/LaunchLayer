import type { Doc, Id } from "../_generated/dataModel";
import type { Fingerprint } from "./similarity";

export function sampleFingerprint(
  overrides: Partial<Fingerprint> = {},
): Fingerprint {
  return {
    gpu_vendor: "nvidia",
    os_family: "arch",
    session_type: "wayland",
    desktop: "kde",
    profiles: ["arch-linux", "nvidia-desktop"],
    display_tier: "ultrawide",
    refresh_tier: "mid75_120",
    has_x3d: true,
    vram_tier: "12gb",
    monitor_layout: "triple+",
    primary_aspect: "21:9",
    audio: "pipewire",
    has_igpu: true,
    vrr: true,
    wsl2: false,
    flatpak_steam: false,
    steam_deck: false,
    immutable: false,
    container: false,
    ...overrides,
  };
}

export function sampleMachineDoc(
  id: string,
  fingerprint: Fingerprint,
  overrides: Partial<Doc<"machines">> = {},
): Doc<"machines"> {
  return {
    _id: id as Id<"machines">,
    _creationTime: 1_700_000_000_000,
    fingerprintHash: "abc123",
    fingerprint,
    machineLabel: "test-box",
    updatedAt: 1_700_000_000_000,
    ...overrides,
  };
}
