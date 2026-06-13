import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { sampleFingerprint } from "./fixtures";
import {
  canonicalFingerprintJson,
  fingerprintHashFromRecord,
} from "./fingerprint_hash";

describe("fingerprintHashFromRecord", () => {
  it("matches the LaunchLayer client hash algorithm", async () => {
    const fingerprint = sampleFingerprint({
      gpu_vendor: "nvidia",
      os_family: "arch",
      session_type: "wayland",
      desktop: "kde",
      profiles: ["arch-linux"],
      display_tier: "1440p",
      refresh_tier: "mid75_120",
      has_x3d: true,
      vrr: true,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
      container: false,
    });

    assert.equal(
      canonicalFingerprintJson(fingerprint),
      '{"container":false,"desktop":"kde","display_tier":"1440p","flatpak_steam":false,"gpu_vendor":"nvidia","has_x3d":true,"immutable":false,"os_family":"arch","profiles":["arch-linux"],"refresh_tier":"mid75_120","session_type":"wayland","steam_deck":false,"vrr":true,"wsl2":false}',
    );

    const hash = await fingerprintHashFromRecord(fingerprint);
    assert.equal(hash, "858056a201fe58437ad682936363e89095ca57930cbe5d00712e4c20316a9ac9");
    assert.match(hash, /^[a-f0-9]{64}$/);
  });

  it("serializes missing hash fields as null", () => {
    const json = canonicalFingerprintJson(
      sampleFingerprint({
        desktop: undefined,
        has_x3d: undefined,
        refresh_tier: undefined,
      }),
    );
    assert.match(json, /"desktop":null/);
    assert.match(json, /"has_x3d":null/);
    assert.match(json, /"refresh_tier":null/);
  });
});
