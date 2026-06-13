import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseFingerprint } from "./fingerprint";

describe("parseFingerprint", () => {
  it("parses minimal client fingerprints without optional fields", () => {
    const parsed = parseFingerprint({
      fingerprint_level: "minimal",
      gpu_vendor: "nvidia",
      os_family: "arch",
      session_type: "wayland",
      desktop: "kde",
      profiles: ["arch-linux", "nvidia-desktop"],
      display_tier: "ultrawide",
      refresh_tier: "mid75_120",
      has_x3d: true,
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
      container: false,
    });

    assert.equal(parsed.gpu_vendor, "nvidia");
    assert.equal(parsed.display, undefined);
    assert.equal(parsed.x3d_cpus, undefined);
    assert.equal(parsed.gpus, undefined);
    assert.equal(parsed.has_x3d, true);
  });

  it("parses standard and detailed enrichment fields", () => {
    const parsed = parseFingerprint({
      gpu_vendor: "nvidia",
      os_family: "arch",
      session_type: "wayland",
      profiles: ["arch-linux"],
      display: "3440x1440@120Hz",
      display_tier: "ultrawide",
      x3d_cpus: "0-7",
      audio: "pipewire",
      vram_tier: "12gb",
      monitor_layout: "triple+",
      primary_aspect: "21:9",
      has_igpu: true,
      gpus: [
        {
          vendor: "nvidia",
          name: "RTX 3080 Ti",
          role: "discrete",
          primary: true,
          index: 0,
          vram_mb: 12288,
          pci_slot: "01:00.0",
        },
      ],
      displays: [
        {
          name: "DP-1",
          width: 3440,
          height: 1440,
          refresh: 120,
          primary: true,
        },
      ],
      vrr: true,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
      container: false,
    });

    assert.equal(parsed.display, "3440x1440@120Hz");
    assert.equal(parsed.x3d_cpus, "0-7");
    assert.equal(parsed.audio, "pipewire");
    assert.equal(parsed.gpus?.[0]?.name, "RTX 3080 Ti");
    assert.equal(parsed.displays?.[0]?.name, "DP-1");
    assert.equal(parsed.has_igpu, true);
  });

  it("does not stringify missing display as undefined", () => {
    const parsed = parseFingerprint({
      gpu_vendor: "amd",
      os_family: "fedora",
      session_type: "wayland",
      profiles: [],
      display_tier: "1080p",
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    });
    assert.equal(parsed.display, undefined);
    assert.notEqual(parsed.display, "undefined");
  });

  it("defaults missing input to unknown core fields", () => {
    const parsed = parseFingerprint(null);
    assert.equal(parsed.gpu_vendor, "unknown");
    assert.equal(parsed.os_family, "unknown");
    assert.equal(parsed.session_type, "unknown");
    assert.equal(parsed.display_tier, "unknown");
    assert.deepEqual(parsed.profiles, []);
    assert.equal(parsed.vrr, false);
  });

  it("coerces string and numeric booleans for required flags", () => {
    const parsed = parseFingerprint({
      vrr: "true",
      wsl2: 1,
      flatpak_steam: "false",
      steam_deck: 0,
      immutable: "true",
    });
    assert.equal(parsed.vrr, true);
    assert.equal(parsed.wsl2, true);
    assert.equal(parsed.flatpak_steam, false);
    assert.equal(parsed.steam_deck, false);
    assert.equal(parsed.immutable, true);
  });

  it("parses optional booleans from strings and numbers", () => {
    const parsed = parseFingerprint({
      has_x3d: "true",
      has_igpu: 0,
      container: "false",
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    });
    assert.equal(parsed.has_x3d, true);
    assert.equal(parsed.has_igpu, false);
    assert.equal(parsed.container, false);
  });

  it("drops blank optional strings after trimming", () => {
    const parsed = parseFingerprint({
      desktop: "   ",
      audio: "",
      os_id: "  arch  ",
      display_tier: "1080p",
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    });
    assert.equal(parsed.desktop, undefined);
    assert.equal(parsed.audio, undefined);
    assert.equal(parsed.os_id, "arch");
  });

  it("parses gpu entries with string primary flag and defaults", () => {
    const parsed = parseFingerprint({
      gpus: [{ vendor: "amd", name: "7800X3D iGPU", primary: "true" }],
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    });
    assert.equal(parsed.gpus?.length, 1);
    assert.equal(parsed.gpus?.[0]?.vendor, "amd");
    assert.equal(parsed.gpus?.[0]?.role, "unknown");
    assert.equal(parsed.gpus?.[0]?.primary, true);
    assert.equal(parsed.gpus?.[0]?.vram_mb, 0);
  });

  it("returns empty gpu and display arrays when input is not an array", () => {
    const parsed = parseFingerprint({
      gpus: "not-an-array",
      displays: {},
      profiles: "also-wrong",
      vrr: false,
      wsl2: false,
      flatpak_steam: false,
      steam_deck: false,
      immutable: false,
    });
    assert.deepEqual(parsed.profiles, []);
    assert.equal(parsed.gpus?.length, undefined);
    assert.equal(parsed.displays?.length, undefined);
  });
});
