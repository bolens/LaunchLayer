import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { similarityScore } from "./similarity";
import { sampleFingerprint } from "./fixtures";
import {
  compareRankedConfigRows,
  rankConfigRecommendations,
} from "./ranking";

describe("compareRankedConfigRows", () => {
  it("sorts by similarity, then published_at, then downloads", () => {
    const older = {
      config_id: "older",
      similarity: 80,
      published_at: 1_700_000_000_000,
      downloads: 500,
    };
    const newer = {
      config_id: "newer",
      similarity: 80,
      published_at: 1_800_000_000_000,
      downloads: 10,
    };
    const popular = {
      config_id: "popular",
      similarity: 80,
      published_at: 1_800_000_000_000,
      downloads: 999,
    };

    assert.ok(compareRankedConfigRows(newer, older) < 0);
    assert.ok(compareRankedConfigRows(popular, newer) < 0);
  });
});

describe("rankConfigRecommendations", () => {
  it("filters zero-similarity configs and prefers newer ties at equal similarity", () => {
    const rows = [
      {
        config_id: "older",
        similarity: 72,
        published_at: 1_700_000_000_000,
        downloads: 200,
      },
      {
        config_id: "zero",
        similarity: 0,
        published_at: 1_900_000_000_000,
        downloads: 999,
      },
      {
        config_id: "newer",
        similarity: 72,
        published_at: 1_800_000_000_000,
        downloads: 50,
      },
    ];

    const ranked = rankConfigRecommendations(rows);
    assert.deepEqual(
      ranked.map((row) => row.config_id),
      ["newer", "older"],
    );
  });

  it("uses downloads as final tiebreaker when similarity and published_at match", () => {
    const rows = [
      {
        config_id: "low",
        similarity: 72,
        published_at: 1_800_000_000_000,
        downloads: 50,
      },
      {
        config_id: "high",
        similarity: 72,
        published_at: 1_800_000_000_000,
        downloads: 200,
      },
    ];

    const ranked = rankConfigRecommendations(rows);
    assert.deepEqual(
      ranked.map((row) => row.config_id),
      ["high", "low"],
    );
  });

  it("respects limit after filtering and sorting", () => {
    const query = sampleFingerprint();
    const match = sampleFingerprint();
    const now = Date.now();
    const rows = Array.from({ length: 5 }, (_, index) => ({
      config_id: `cfg-${index}`,
      similarity: similarityScore(query, match),
      published_at: now - index * 86_400_000,
      downloads: index,
    }));

    assert.equal(rankConfigRecommendations(rows, 2).length, 2);
  });
});

describe("similar machine ranking", () => {
  it("filters zero-similarity machines and sorts by similarity", () => {
    const query = sampleFingerprint();
    const near = sampleFingerprint();
    const unrelated = sampleFingerprint({
      gpu_vendor: "intel",
      os_family: "windows",
      session_type: "x11",
      display_tier: "720p",
      profiles: [],
      desktop: "unknown",
      refresh_tier: undefined,
      vram_tier: undefined,
      monitor_layout: undefined,
      primary_aspect: undefined,
      audio: undefined,
      has_x3d: false,
      has_igpu: false,
      vrr: false,
    });

    const rows = [
      { machine_id: "m1", similarity: similarityScore(query, near) },
      { machine_id: "m2", similarity: similarityScore(query, unrelated) },
    ].filter((row) => row.similarity > 0);

    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.machine_id, "m1");
  });
});
