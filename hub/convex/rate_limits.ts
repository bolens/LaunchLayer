import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import {
  RATE_LIMITS,
  rateLimitAllows,
  rateLimitBucketKey,
  rateLimitExceededError,
  rateLimitWindowStart,
  type RateLimitRoute,
} from "./lib/rate_limit";

export const enforceRateLimit = internalMutation({
  args: {
    route: v.string(),
    identifier: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const route = args.route as RateLimitRoute;
    const max = RATE_LIMITS[route];
    if (!max) {
      return null;
    }

    const now = Date.now();
    const windowStart = rateLimitWindowStart(now);
    const bucketKey = rateLimitBucketKey(route, args.identifier);

    const existing = await ctx.db
      .query("rateLimitBuckets")
      .withIndex("by_bucket_key", (q) => q.eq("bucketKey", bucketKey))
      .unique();

    if (!existing || existing.windowStart !== windowStart) {
      if (existing) {
        await ctx.db.patch(existing._id, { windowStart, count: 1 });
      } else {
        await ctx.db.insert("rateLimitBuckets", {
          bucketKey,
          windowStart,
          count: 1,
        });
      }
      return null;
    }

    if (!rateLimitAllows(existing.count, max)) {
      rateLimitExceededError();
    }

    await ctx.db.patch(existing._id, { count: existing.count + 1 });
    return null;
  },
});
