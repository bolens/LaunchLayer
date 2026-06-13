import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  profileOverlapScore,
  similarityScore,
  type Fingerprint,
} from "./similarity";
import { sampleFingerprint } from "./fixtures";

describe("profileOverlapScore", () => {
  it("awards 4 points per shared profile", () => {
    assert.equal(
      profileOverlapScore(["arch-linux", "nvidia-desktop"], ["arch-linux"]),
      4,
    );
  });

  it("caps overlap contribution at six profiles", () => {
    const left = ["a", "b", "c", "d", "e", "f", "g", "h"];
    const right = ["a", "b", "c", "d", "e", "f", "g", "h"];
    assert.equal(profileOverlapScore(left, right), 24);
  });

  it("returns zero when there is no overlap", () => {
    assert.equal(profileOverlapScore(["arch-linux"], ["fedora"]), 0);
  });
});

describe("similarityScore", () => {
  it("scores identical fingerprints higher than mismatched ones", () => {
    const left = sampleFingerprint();
    const right = sampleFingerprint({
      gpu_vendor: "amd",
      os_family: "fedora",
      session_type: "x11",
      desktop: "gnome",
      display_tier: "1080p",
      refresh_tier: "std60",
      profiles: ["fedora"],
      has_x3d: false,
      has_igpu: false,
      vrr: false,
    });

    const same = similarityScore(left, left);
    const different = similarityScore(left, right);
    assert.ok(same >= 80);
    assert.ok(different < same);
  });

  it("awards desktop and refresh tier matches", () => {
    const left = sampleFingerprint();
    const hypr = sampleFingerprint({ desktop: "hyprland" });
    assert.ok(similarityScore(left, left) > similarityScore(left, hypr));
  });

  it("ignores unknown desktop values", () => {
    const left = sampleFingerprint({ desktop: "kde" });
    const unknown = sampleFingerprint({ desktop: "unknown" });
    const kde = sampleFingerprint({ desktop: "kde" });
    assert.equal(similarityScore(left, unknown), similarityScore(left, kde) - 8);
  });

  it("does not award x3d_cpus when value is none", () => {
    const withCpus = sampleFingerprint({ x3d_cpus: "0-7" });
    const noneCpus = sampleFingerprint({ x3d_cpus: "none" });
    assert.ok(
      similarityScore(withCpus, withCpus) >
        similarityScore(withCpus, noneCpus),
    );
  });

  it("awards platform flags only when both sides match", () => {
    const base = sampleFingerprint({ vrr: false, wsl2: false });
    const bothVrr = sampleFingerprint({ vrr: true });
    const oneVrr = sampleFingerprint({ vrr: true, wsl2: true });
    assert.ok(similarityScore(bothVrr, bothVrr) > similarityScore(bothVrr, base));
    assert.ok(
      similarityScore(oneVrr, oneVrr) > similarityScore(oneVrr, bothVrr),
    );
  });

  it("awards has_igpu when both sides agree (including false)", () => {
    const bothFalse = sampleFingerprint({ has_igpu: false });
    const mixed = sampleFingerprint({ has_igpu: true });
    assert.ok(
      similarityScore(bothFalse, bothFalse) > similarityScore(bothFalse, mixed),
    );
  });

  it("caps the total score at 100", () => {
    const rich = sampleFingerprint({
      profiles: [
        "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
      ],
      vrr: true,
      wsl2: true,
      flatpak_steam: true,
      steam_deck: true,
      immutable: true,
      container: true,
    });
    assert.equal(similarityScore(rich, rich), 100);
  });

  it("returns zero for completely unrelated fingerprints", () => {
    const left: Fingerprint = {
      gpu_vendor: "nvidia",
      os_family: "arch",
      session_type: "wayland",
      profiles: [],
      display_tier: "1080p",
      has_igpu: false,
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    };
    const right: Fingerprint = {
      gpu_vendor: "amd",
      os_family: "fedora",
      session_type: "x11",
      profiles: [],
      display_tier: "4k",
      has_igpu: true,
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    };
    assert.equal(similarityScore(left, right), 0);
  });
});
