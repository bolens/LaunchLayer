import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  MAX_CONFIGS_PER_MACHINE,
  machineConfigQuotaExceeded,
  quotaExceededError,
} from "./quotas";

describe("machineConfigQuotaExceeded", () => {
  it("allows inserts below the machine cap", () => {
    assert.equal(machineConfigQuotaExceeded(0), false);
    assert.equal(machineConfigQuotaExceeded(MAX_CONFIGS_PER_MACHINE - 1), false);
  });

  it("blocks inserts at or above the machine cap", () => {
    assert.equal(machineConfigQuotaExceeded(MAX_CONFIGS_PER_MACHINE), true);
    assert.equal(machineConfigQuotaExceeded(MAX_CONFIGS_PER_MACHINE + 1), true);
  });
});

describe("quotaExceededError", () => {
  it("throws a QUOTA_EXCEEDED error with the configured cap", () => {
    assert.throws(
      () => quotaExceededError(),
      (error: unknown) =>
        error instanceof Error &&
        error.message ===
          `QUOTA_EXCEEDED: Machine has reached the ${MAX_CONFIGS_PER_MACHINE} shared config limit`,
    );
  });
});
