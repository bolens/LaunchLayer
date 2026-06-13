import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { resolveDownloadIncrement } from "./download_dedup";

describe("resolveDownloadIncrement", () => {
  it("increments downloads for a first-time identifier", () => {
    assert.deepEqual(resolveDownloadIncrement(3, false), {
      shouldIncrement: true,
      nextDownloads: 4,
    });
  });

  it("skips increment when the identifier was already recorded", () => {
    assert.deepEqual(resolveDownloadIncrement(3, true), {
      shouldIncrement: false,
      nextDownloads: 3,
    });
  });
});
