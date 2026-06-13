import { convexTest } from "convex-test";
import { describe, expect, it } from "vitest";
import { internal } from "./_generated/api";
import schema from "./schema";
import { modules } from "../test/convex_test_modules";
import { buildPublishArgs } from "../test/test_helpers";

describe("hub HTTP routes", () => {
  it("reports whether publish auth is enforced", async () => {
    const t = convexTest(schema, modules);

    const response = await t.fetch("/api/auth");
    expect(response.status).toBe(200);

    const body = await response.json();
    expect(body).toMatchObject({ publish_auth_required: false });
  });

  it("returns validation errors for malformed recommend requests", async () => {
    const t = convexTest(schema, modules);

    const response = await t.fetch("/api/recommend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fingerprint: {},
        appid: "not-a-number",
      }),
    });

    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.code).toBe("VALIDATION_ERROR");
  });

  it("returns a shared config and records deduped downloads", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "271590" });
    const published = await t.mutation(internal.configs.publishConfig, args);

    const first = await t.fetch(`/api/config/${published.config_id}`, {
      headers: { "X-Forwarded-For": "203.0.113.50" },
    });
    expect(first.status).toBe(200);
    const firstBody = await first.json();
    expect(firstBody).toMatchObject({
      config_id: published.config_id,
      appid: "271590",
    });

    const second = await t.fetch(`/api/config/${published.config_id}`, {
      headers: { "X-Forwarded-For": "203.0.113.50" },
    });
    expect(second.status).toBe(200);

    const config = await t.run(async (ctx) => ctx.db.get(published.config_id));
    expect(config?.downloads).toBe(1);
  });

  it("rejects invalid config ids on GET /api/config", async () => {
    const t = convexTest(schema, modules);

    const response = await t.fetch("/api/config/cfg-test-1");
    expect(response.status).toBe(400);

    const body = await response.json();
    expect(body.code).toBe("VALIDATION_ERROR");
  });

  it("rejects delete requests with invalid config ids", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "252950" });
    await t.mutation(internal.configs.publishConfig, args);

    const response = await t.fetch("/api/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        config_id: "cfg-test-1",
        fingerprint_hash: args.fingerprintHash,
      }),
    });

    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.code).toBe("VALIDATION_ERROR");
  });
});
