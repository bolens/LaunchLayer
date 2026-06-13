import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import {
  detectionValidator,
  fingerprintValidator,
  settingValidator,
} from "./schema";
import { similarityScore, type Fingerprint } from "./lib/similarity";
import { rankConfigRecommendations } from "./lib/ranking";
import { upsertMachineRecord } from "./lib/machines";
import {
  buildPublishConfigPatch,
  validateConfigUpdateTarget,
} from "./lib/publish";

export const publishConfig = mutation({
  args: {
    fingerprintHash: v.string(),
    fingerprint: fingerprintValidator,
    machineLabel: v.optional(v.string()),
    appid: v.string(),
    gameName: v.string(),
    envContent: v.string(),
    settings: v.array(settingValidator),
    preset: v.optional(v.string()),
    note: v.optional(v.string()),
    detection: detectionValidator,
    launchlayerVersion: v.optional(v.string()),
    configId: v.optional(v.id("sharedConfigs")),
  },
  returns: v.object({
    config_id: v.id("sharedConfigs"),
    machine_id: v.id("machines"),
    updated: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const machineId = await upsertMachineRecord(ctx, {
      fingerprintHash: args.fingerprintHash,
      fingerprint: args.fingerprint,
      machineLabel: args.machineLabel,
    });

    const content = buildPublishConfigPatch(
      {
        gameName: args.gameName,
        envContent: args.envContent,
        settings: args.settings,
        preset: args.preset,
        note: args.note,
        detection: args.detection,
        launchlayerVersion: args.launchlayerVersion,
      },
      Date.now(),
    );

    if (args.configId) {
      const config = await ctx.db.get(args.configId);
      const machine = config
        ? await ctx.db.get(config.machineId)
        : null;
      const target = validateConfigUpdateTarget(config, machine, {
        fingerprintHash: args.fingerprintHash,
        appid: args.appid,
      });

      await ctx.db.patch(target._id, content);
      return {
        config_id: target._id,
        machine_id: machineId,
        updated: true,
      };
    }

    const existing = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_machine_and_appid", (q) =>
        q.eq("machineId", machineId).eq("appid", args.appid),
      )
      .unique();

    if (existing) {
      await ctx.db.patch(existing._id, content);
      return {
        config_id: existing._id,
        machine_id: machineId,
        updated: true,
      };
    }

    const configId = await ctx.db.insert("sharedConfigs", {
      machineId,
      appid: args.appid,
      gameName: content.gameName,
      envContent: content.envContent,
      settings: content.settings,
      preset: content.preset,
      note: content.note,
      detection: content.detection,
      launchlayerVersion: content.launchlayerVersion,
      publishedAt: content.publishedAt,
      downloads: 0,
    });

    return { config_id: configId, machine_id: machineId, updated: false };
  },
});

export const findMyConfig = query({
  args: {
    fingerprintHash: v.string(),
    appid: v.string(),
  },
  returns: v.union(
    v.object({
      config_id: v.id("sharedConfigs"),
      published_at: v.number(),
      downloads: v.number(),
    }),
    v.null(),
  ),
  handler: async (ctx, args) => {
    const machine = await ctx.db
      .query("machines")
      .withIndex("by_fingerprint_hash", (q) =>
        q.eq("fingerprintHash", args.fingerprintHash),
      )
      .unique();
    if (!machine) {
      return null;
    }

    const config = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_machine_and_appid", (q) =>
        q.eq("machineId", machine._id).eq("appid", args.appid),
      )
      .unique();
    if (!config) {
      return null;
    }

    return {
      config_id: config._id,
      published_at: config.publishedAt,
      downloads: config.downloads,
    };
  },
});

export const recommendConfigs = query({
  args: {
    fingerprint: fingerprintValidator,
    appid: v.string(),
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      config_id: v.id("sharedConfigs"),
      similarity: v.number(),
      machine_label: v.optional(v.string()),
      gpu_vendor: v.string(),
      display: v.string(),
      profiles: v.array(v.string()),
      game_name: v.string(),
      preset: v.optional(v.string()),
      note: v.optional(v.string()),
      published_at: v.number(),
      downloads: v.number(),
    }),
  ),
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    const configs = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_appid", (q) => q.eq("appid", args.appid))
      .collect();

    const scored = await Promise.all(
      configs.map(async (config) => {
        const machine = await ctx.db.get(config.machineId);
        if (!machine) {
          return null;
        }
        return {
          config_id: config._id,
          similarity: similarityScore(
            args.fingerprint as Fingerprint,
            machine.fingerprint as Fingerprint,
          ),
          machine_label: machine.machineLabel,
          gpu_vendor: machine.fingerprint.gpu_vendor,
          display: machine.fingerprint.display ?? "",
          profiles: machine.fingerprint.profiles,
          game_name: config.gameName,
          preset: config.preset,
          note: config.note,
          published_at: config.publishedAt,
          downloads: config.downloads,
        };
      }),
    );

    return rankConfigRecommendations(
      scored.filter((row): row is NonNullable<typeof row> => row !== null),
      limit,
    );
  },
});

export const getConfig = query({
  args: { configId: v.id("sharedConfigs") },
  returns: v.union(
    v.object({
      config_id: v.id("sharedConfigs"),
      appid: v.string(),
      game_name: v.string(),
      env_content: v.string(),
      preset: v.optional(v.string()),
      note: v.optional(v.string()),
      published_at: v.number(),
      downloads: v.number(),
    }),
    v.null(),
  ),
  handler: async (ctx, args) => {
    const config = await ctx.db.get(args.configId);
    if (!config) {
      return null;
    }

    return {
      config_id: config._id,
      appid: config.appid,
      game_name: config.gameName,
      env_content: config.envContent,
      preset: config.preset,
      note: config.note,
      published_at: config.publishedAt,
      downloads: config.downloads,
    };
  },
});

export const recordDownload = mutation({
  args: { configId: v.id("sharedConfigs") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const config = await ctx.db.get(args.configId);
    if (!config) {
      throw new Error("Config not found");
    }
    await ctx.db.patch(args.configId, {
      downloads: config.downloads + 1,
    });
    return null;
  },
});

export const deleteConfig = mutation({
  args: { configId: v.id("sharedConfigs") },
  returns: v.union(
    v.object({
      deleted_config_id: v.id("sharedConfigs"),
      deleted_machine: v.boolean(),
    }),
    v.null(),
  ),
  handler: async (ctx, args) => {
    const config = await ctx.db.get(args.configId);
    if (!config) {
      return null;
    }

    const machineId = config.machineId;
    await ctx.db.delete(args.configId);

    const remaining = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_machine_and_appid", (q) => q.eq("machineId", machineId))
      .first();

    let deletedMachine = false;
    if (remaining === null) {
      await ctx.db.delete(machineId);
      deletedMachine = true;
    }

    return {
      deleted_config_id: args.configId,
      deleted_machine: deletedMachine,
    };
  },
});
