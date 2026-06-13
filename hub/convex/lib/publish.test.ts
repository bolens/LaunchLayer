import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { Doc, Id } from "../_generated/dataModel";
import { sampleFingerprint } from "./fixtures";
import {
  buildPublishConfigPatch,
  publishHttpStatusForError,
  validateConfigUpdateTarget,
} from "./publish";

function sampleConfig(
  id: string,
  machineId: string,
  appid: string,
): Doc<"sharedConfigs"> {
  return {
    _id: id as Id<"sharedConfigs">,
    _creationTime: 1,
    machineId: machineId as Id<"machines">,
    appid,
    gameName: "Test Game",
    envContent: "GAMEMODE=1",
    settings: [],
    detection: { native: false, anticheat: false },
    publishedAt: 1_700_000_000_000,
    downloads: 3,
  };
}

function sampleMachine(
  id: string,
  fingerprintHash: string,
): Doc<"machines"> {
  return {
    _id: id as Id<"machines">,
    _creationTime: 1,
    fingerprintHash,
    fingerprint: sampleFingerprint(),
    updatedAt: 1_700_000_000_000,
  };
}

describe("validateConfigUpdateTarget", () => {
  it("accepts matching fingerprint hash and appid", () => {
    const config = sampleConfig("sharedConfigs:1", "machines:1", "42424242");
    const machine = sampleMachine("machines:1", "hash-abc");
    const result = validateConfigUpdateTarget(config, machine, {
      fingerprintHash: "hash-abc",
      appid: "42424242",
    });
    assert.equal(result._id, config._id);
  });

  it("rejects when fingerprint hash differs", () => {
    const config = sampleConfig("sharedConfigs:1", "machines:1", "42424242");
    const machine = sampleMachine("machines:1", "hash-abc");
    assert.throws(
      () =>
        validateConfigUpdateTarget(config, machine, {
          fingerprintHash: "hash-other",
          appid: "42424242",
        }),
      /FINGERPRINT_MISMATCH/,
    );
  });

  it("rejects when appid differs", () => {
    const config = sampleConfig("sharedConfigs:1", "machines:1", "42424242");
    const machine = sampleMachine("machines:1", "hash-abc");
    assert.throws(
      () =>
        validateConfigUpdateTarget(config, machine, {
          fingerprintHash: "hash-abc",
          appid: "99999999",
        }),
      /APPID_MISMATCH/,
    );
  });

  it("rejects missing config", () => {
    assert.throws(
      () =>
        validateConfigUpdateTarget(null, sampleMachine("machines:1", "hash"), {
          fingerprintHash: "hash",
          appid: "1",
        }),
      /NOT_FOUND/,
    );
  });
});

describe("publishHttpStatusForError", () => {
  it("maps validation errors to HTTP statuses", () => {
    assert.equal(
      publishHttpStatusForError("FINGERPRINT_MISMATCH: nope"),
      409,
    );
    assert.equal(publishHttpStatusForError("APPID_MISMATCH: nope"), 400);
    assert.equal(publishHttpStatusForError("NOT_FOUND: nope"), 404);
  });
});

describe("buildPublishConfigPatch", () => {
  it("includes publishedAt in the patch payload", () => {
    const patch = buildPublishConfigPatch(
      {
        gameName: "Game",
        envContent: "X=1",
        settings: [],
        detection: { native: true, anticheat: false },
      },
      1_800_000_000_000,
    );
    assert.equal(patch.publishedAt, 1_800_000_000_000);
    assert.equal(patch.gameName, "Game");
  });
});
