import { sampleFingerprint } from "../convex/lib/fixtures";
import { fingerprintHashFromRecord } from "../convex/lib/fingerprint_hash";
import type { Fingerprint } from "../convex/lib/similarity";

export type PublishArgs = {
  fingerprintHash: string;
  fingerprint: Fingerprint;
  machineLabel?: string;
  appid: string;
  gameName: string;
  envContent: string;
  settings: Array<{ key: string; value: string }>;
  preset?: string;
  note?: string;
  detection: { native: boolean; anticheat: boolean; engine?: string };
  launchlayerVersion?: string;
  configId?: string;
};

export async function buildPublishArgs(
  overrides: Partial<PublishArgs> = {},
): Promise<PublishArgs> {
  const fingerprint = overrides.fingerprint ?? sampleFingerprint();
  const fingerprintHash =
    overrides.fingerprintHash ?? (await fingerprintHashFromRecord(fingerprint));

  return {
    fingerprintHash,
    fingerprint,
    appid: "42424242",
    gameName: "Test Game",
    envContent: "GAMEMODE=1\nMANGOHUD=1\n",
    settings: [{ key: "GAMEMODE", value: "1" }],
    detection: { native: false, anticheat: false },
    ...overrides,
  };
}
