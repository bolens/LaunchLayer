import type { Fingerprint } from "./similarity";

/** Match-relevant fingerprint fields hashed by the LaunchLayer client. */
const HASH_KEYS = [
  "gpu_vendor",
  "os_family",
  "session_type",
  "profiles",
  "display_tier",
  "refresh_tier",
  "desktop",
  "has_x3d",
  "vrr",
  "wsl2",
  "flatpak_steam",
  "steam_deck",
  "immutable",
  "container",
] as const;

export function canonicalFingerprintPayload(
  fingerprint: Fingerprint,
): Record<string, unknown> {
  const record = fingerprint as Record<string, unknown>;
  const canonical: Record<string, unknown> = {};
  for (const key of HASH_KEYS) {
    const value = record[key];
    canonical[key] = value === undefined ? null : value;
  }
  return canonical;
}

export function canonicalFingerprintJson(fingerprint: Fingerprint): string {
  const canonical = canonicalFingerprintPayload(fingerprint);
  const sorted: Record<string, unknown> = {};
  for (const key of Object.keys(canonical).sort()) {
    sorted[key] = canonical[key];
  }
  return JSON.stringify(sorted);
}

export async function fingerprintHashFromRecord(
  fingerprint: Fingerprint,
): Promise<string> {
  const json = canonicalFingerprintJson(fingerprint);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(json),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
