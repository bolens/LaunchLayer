import { convexTest } from "convex-test";
import { describe, expect, it } from "vitest";
import { internal } from "./_generated/api";
import { MAX_CONFIGS_PER_MACHINE } from "./lib/quotas";
import schema from "./schema";
import { modules } from "../test/convex_test_modules";
import { buildPublishArgs } from "../test/test_helpers";

describe("publishConfig", () => {
  it("inserts a new shared config for a machine", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "42424242" });

    const result = await t.mutation(internal.configs.publishConfig, args);

    expect(result.updated).toBe(false);
    expect(result.machine_id).toBeTruthy();

    const stored = await t.run(async (ctx) => ctx.db.get(result.config_id));
    expect(stored).toMatchObject({
      appid: "42424242",
      gameName: "Test Game",
      downloads: 0,
    });
  });

  it("updates an existing config for the same machine and appid", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "2357570", note: "first" });

    const created = await t.mutation(internal.configs.publishConfig, args);
    const updated = await t.mutation(
      internal.configs.publishConfig,
      await buildPublishArgs({
        appid: "2357570",
        note: "second",
        gameName: "Updated Game",
      }),
    );

    expect(updated.updated).toBe(true);
    expect(updated.config_id).toEqual(created.config_id);

    const stored = await t.run(async (ctx) => ctx.db.get(updated.config_id));
    expect(stored?.note).toBe("second");
    expect(stored?.gameName).toBe("Updated Game");
  });

  it("rejects publishes when the machine config quota is reached", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "99999999" });

    await t.run(async (ctx) => {
      const machineId = await ctx.db.insert("machines", {
        fingerprintHash: args.fingerprintHash,
        fingerprint: args.fingerprint,
        updatedAt: Date.now(),
      });

      for (let i = 0; i < MAX_CONFIGS_PER_MACHINE; i += 1) {
        await ctx.db.insert("sharedConfigs", {
          machineId,
          appid: String(1_000_000_000 + i),
          gameName: `Game ${i}`,
          envContent: "GAMEMODE=1\n",
          settings: [],
          detection: { native: false, anticheat: false },
          publishedAt: Date.now(),
          downloads: 0,
        });
      }
    });

    await expect(
      t.mutation(internal.configs.publishConfig, args),
    ).rejects.toThrowError(/QUOTA_EXCEEDED/);
  });
});

describe("findMyConfig", () => {
  it("returns config metadata for a published machine and appid", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "570" });
    const published = await t.mutation(internal.configs.publishConfig, args);

    const found = await t.query(internal.configs.findMyConfig, {
      fingerprintHash: args.fingerprintHash,
      appid: "570",
    });

    expect(found).toMatchObject({
      config_id: published.config_id,
      downloads: 0,
    });
    expect(found?.published_at).toEqual(expect.any(Number));
  });

  it("returns null when the machine has not published the appid", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs();

    const found = await t.query(internal.configs.findMyConfig, {
      fingerprintHash: args.fingerprintHash,
      appid: "42424242",
    });

    expect(found).toBeNull();
  });
});

describe("recordDownload", () => {
  it("increments downloads once per config and identifier", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "730" });
    const published = await t.mutation(internal.configs.publishConfig, args);
    const identifier = "hash:download-test";

    await t.mutation(internal.configs.recordDownload, {
      configId: published.config_id,
      identifier,
    });
    await t.mutation(internal.configs.recordDownload, {
      configId: published.config_id,
      identifier,
    });

    const config = await t.run(async (ctx) => ctx.db.get(published.config_id));
    expect(config?.downloads).toBe(1);

    const dedupRows = await t.run(async (ctx) =>
      ctx.db
        .query("configDownloadDedup")
        .withIndex("by_config_and_identifier", (q) =>
          q.eq("configId", published.config_id).eq("identifier", identifier),
        )
        .collect(),
    );
    expect(dedupRows).toHaveLength(1);
  });
});

describe("deleteConfig", () => {
  it("deletes a config owned by the matching fingerprint hash", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "440" });
    const published = await t.mutation(internal.configs.publishConfig, args);

    const result = await t.mutation(internal.configs.deleteConfig, {
      configId: published.config_id,
      fingerprintHash: args.fingerprintHash,
    });

    expect(result).toMatchObject({
      deleted_config_id: published.config_id,
      deleted_machine: true,
    });

    const deleted = await t.run(async (ctx) => ctx.db.get(published.config_id));
    expect(deleted).toBeNull();
  });

  it("rejects delete when fingerprint hash does not match", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "1174180" });
    const published = await t.mutation(internal.configs.publishConfig, args);

    await expect(
      t.mutation(internal.configs.deleteConfig, {
        configId: published.config_id,
        fingerprintHash: "a".repeat(64),
      }),
    ).rejects.toThrowError(/FINGERPRINT_MISMATCH/);
  });

  it("keeps the machine record when other configs remain", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "620" });
    const other = await buildPublishArgs({ appid: "621" });
    const first = await t.mutation(internal.configs.publishConfig, args);
    await t.mutation(internal.configs.publishConfig, other);

    const result = await t.mutation(internal.configs.deleteConfig, {
      configId: first.config_id,
      fingerprintHash: args.fingerprintHash,
    });

    expect(result?.deleted_machine).toBe(false);

    const machine = await t.run(async (ctx) => {
      const config = await ctx.db.get(first.config_id);
      return config;
    });
    expect(machine).toBeNull();
  });
});

describe("recommendConfigs", () => {
  it("returns ranked configs for the requested appid", async () => {
    const t = convexTest(schema, modules);
    const queryFingerprint = (await buildPublishArgs()).fingerprint;
    const publishArgs = await buildPublishArgs({
      appid: "1086940",
      fingerprint: queryFingerprint,
    });
    const published = await t.mutation(internal.configs.publishConfig, publishArgs);

    const results = await t.query(internal.configs.recommendConfigs, {
      fingerprint: queryFingerprint,
      appid: "1086940",
      limit: 5,
    });

    expect(results).toHaveLength(1);
    expect(results[0]).toMatchObject({
      config_id: published.config_id,
      game_name: "Test Game",
    });
    expect(results[0]?.similarity).toBeGreaterThan(0);
  });
});

describe("similarMachines", () => {
  it("returns machines with positive similarity scores", async () => {
    const t = convexTest(schema, modules);
    const args = await buildPublishArgs({ appid: "753" });
    await t.mutation(internal.configs.publishConfig, args);

    const results = await t.query(internal.machines.similarMachines, {
      fingerprint: args.fingerprint,
      limit: 5,
    });

    expect(results.length).toBeGreaterThan(0);
    expect(results[0]?.similarity).toBeGreaterThan(0);
    expect(results[0]?.gpu_vendor).toBe(args.fingerprint.gpu_vendor);
  });
});
