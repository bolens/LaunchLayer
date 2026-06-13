import { convexTest } from "convex-test";
import { describe, expect, it } from "vitest";
import { internal } from "./_generated/api";
import { RATE_LIMITS } from "./lib/rate_limit";
import { modules } from "../test/convex_test_modules";
import schema from "./schema";

describe("enforceRateLimit", () => {
  it("allows requests below the route cap", async () => {
    const t = convexTest(schema, modules);
    const identifier = "hash:rate-limit-ok";

    await expect(
      t.mutation(internal.rate_limits.enforceRateLimit, {
        route: "recommend",
        identifier,
      }),
    ).resolves.toBeNull();
  });

  it("throws RATE_LIMITED when the cap is exceeded in the same window", async () => {
    const t = convexTest(schema, modules);
    const identifier = "hash:rate-limit-blocked";

    for (let i = 0; i < RATE_LIMITS.recommend; i += 1) {
      await t.mutation(internal.rate_limits.enforceRateLimit, {
        route: "recommend",
        identifier,
      });
    }

    await expect(
      t.mutation(internal.rate_limits.enforceRateLimit, {
        route: "recommend",
        identifier,
      }),
    ).rejects.toThrowError(/RATE_LIMITED/);
  });

  it("tracks separate buckets per route and identifier", async () => {
    const t = convexTest(schema, modules);

    for (let i = 0; i < RATE_LIMITS.recommend; i += 1) {
      await t.mutation(internal.rate_limits.enforceRateLimit, {
        route: "recommend",
        identifier: "hash:shared-id",
      });
    }

    await expect(
      t.mutation(internal.rate_limits.enforceRateLimit, {
        route: "similarMachines",
        identifier: "hash:shared-id",
      }),
    ).resolves.toBeNull();
  });
});
