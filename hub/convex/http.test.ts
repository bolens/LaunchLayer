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

    const config = await t.run(async (ctx) => ctx.db.get("sharedConfigs", published.config_id));
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

  it("can fetch config history list and a specific historical config", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "271590", note: "version 1" });
    const published = await t.mutation(internal.configs.publishConfig, args);

    // Update config to generate a second history record
    const updateArgs = await buildPublishArgs({ appid: "271590", note: "version 2" });
    await t.mutation(internal.configs.publishConfig, updateArgs);

    // 1. Fetch history list via HTTP GET /api/config/<configId>/history
    const historyRes = await t.fetch(`/api/config/${published.config_id}/history`);
    expect(historyRes.status).toBe(200);
    const historyList = await historyRes.json();
    expect(historyList).toHaveLength(2);
    expect(historyList[0].note).toBe("version 2");
    expect(historyList[1].note).toBe("version 1");

    // 2. Fetch specific historical version via HTTP GET /api/config-history/<historyId>
    const historyId = historyList[1].history_id;
    const historyDocRes = await t.fetch(`/api/config-history/${historyId}`);
    expect(historyDocRes.status).toBe(200);
    const historyDoc = await historyDocRes.json();
    expect(historyDoc).toMatchObject({
      history_id: historyId,
      config_id: published.config_id,
      appid: "271590",
      note: "version 1",
    });
    expect(typeof historyDoc.appid).toBe("string");
    expect(historyDoc.appid).toMatch(/^\d+$/);
  });

  it("returns 404 for history of a missing config", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "11111", note: "temp" });
    const published = await t.mutation(internal.configs.publishConfig, args);
    await t.mutation(internal.configs.deleteConfig, {
      configId: published.config_id,
      fingerprintHash: args.fingerprintHash,
    });
    const historyRes = await t.fetch(`/api/config/${published.config_id}/history`);
    expect(historyRes.status).toBe(404);
  });
});
