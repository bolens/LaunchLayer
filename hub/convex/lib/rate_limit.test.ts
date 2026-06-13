import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  RATE_LIMITS,
  RATE_LIMIT_WINDOW_MS,
  rateLimitAllows,
  rateLimitBucketKey,
  rateLimitExceededError,
  rateLimitWindowStart,
  requestIdentifier,
} from "./rate_limit";

describe("rateLimitWindowStart", () => {
  it("aligns timestamps to fixed windows", () => {
    const now = 1_700_000_123_456;
    assert.equal(rateLimitWindowStart(now), now - (now % RATE_LIMIT_WINDOW_MS));
  });
});

describe("rateLimitAllows", () => {
  it("allows requests below the cap", () => {
    assert.equal(rateLimitAllows(0, RATE_LIMITS.recommend), true);
    assert.equal(rateLimitAllows(RATE_LIMITS.recommend - 1, RATE_LIMITS.recommend), true);
    assert.equal(rateLimitAllows(RATE_LIMITS.recommend, RATE_LIMITS.recommend), false);
  });
});

describe("rateLimitBucketKey", () => {
  it("namespaces route and identifier", () => {
    assert.equal(
      rateLimitBucketKey("recommend", "hash:abc"),
      "recommend:hash:abc",
    );
  });
});

describe("requestIdentifier", () => {
  it("prefers fingerprint hash when present", () => {
    const request = new Request("https://example.test/api/recommend", {
      method: "POST",
      headers: { "X-Forwarded-For": "203.0.113.10" },
    });
    assert.equal(
      requestIdentifier(request, { fingerprint_hash: "a".repeat(64) }),
      `hash:${"a".repeat(64)}`,
    );
  });

  it("falls back to forwarded client IP", () => {
    const request = new Request("https://example.test/api/config/id", {
      headers: { "X-Forwarded-For": "203.0.113.10, 198.51.100.2" },
    });
    assert.equal(requestIdentifier(request), "ip:203.0.113.10");
  });

  it("falls back to X-Real-IP when forwarded header is absent", () => {
    const request = new Request("https://example.test/api/config/id", {
      headers: { "X-Real-IP": "198.51.100.44" },
    });
    assert.equal(requestIdentifier(request), "ip:198.51.100.44");
  });

  it("uses ip:unknown when no client identity headers are present", () => {
    const request = new Request("https://example.test/api/config/id");
    assert.equal(requestIdentifier(request), "ip:unknown");
  });
});

describe("rateLimitExceededError", () => {
  it("throws a RATE_LIMITED error", () => {
    assert.throws(
      () => rateLimitExceededError(),
      /RATE_LIMITED: Too many requests/,
    );
  });
});
