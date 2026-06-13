import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
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
  validateConfigDeleteTarget,
  validateConfigUpdateTarget,
} from "./lib/publish";
import { resolveDownloadIncrement } from "./lib/download_dedup";
import {
  machineConfigQuotaExceeded,
  quotaExceededError,
} from "./lib/quotas";
import {
  assertFingerprintHashMatches,
  capScoredCandidates,
  MAX_CONFIGS_SCORED,
  validateDeleteRequest,
  validateLookupIdentity,
  validatePublishSubmission,
  validateRecommendRequest,
} from "./lib/validation";

export const publishConfig = internalMutation({
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
    validatePublishSubmission({
      ...args,
      configId: args.configId,
    });
    await assertFingerprintHashMatches(args.fingerprint, args.fingerprintHash);

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

    const machineConfigs = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_machine_and_appid", (q) => q.eq("machineId", machineId))
      .collect();
    if (machineConfigQuotaExceeded(machineConfigs.length)) {
      quotaExceededError();
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

export const findMyConfig = internalQuery({
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
    validateLookupIdentity(args);

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

export const recommendConfigs = internalQuery({
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
    const limit = validateRecommendRequest({
      fingerprint: args.fingerprint as Fingerprint,
      appid: args.appid,
      limit: args.limit,
    });
    const configs = await ctx.db
      .query("sharedConfigs")
      .withIndex("by_appid", (q) => q.eq("appid", args.appid))
      .collect();

    const bounded = capScoredCandidates(configs, MAX_CONFIGS_SCORED);

    const scored = await Promise.all(
      bounded.map(async (config) => {
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

export const getConfig = internalQuery({
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

export const recordDownload = internalMutation({
  args: {
    configId: v.id("sharedConfigs"),
    identifier: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const config = await ctx.db.get(args.configId);
    if (!config) {
      throw new Error("Config not found");
    }

    const existing = await ctx.db
      .query("configDownloadDedup")
      .withIndex("by_config_and_identifier", (q) =>
        q.eq("configId", args.configId).eq("identifier", args.identifier),
      )
      .unique();
    if (existing) {
      return null;
    }

    const { nextDownloads } = resolveDownloadIncrement(config.downloads, false);

    await ctx.db.insert("configDownloadDedup", {
      configId: args.configId,
      identifier: args.identifier,
      recordedAt: Date.now(),
    });
    await ctx.db.patch(args.configId, {
      downloads: nextDownloads,
    });
    return null;
  },
});

export const deleteConfig = internalMutation({
  args: {
    configId: v.id("sharedConfigs"),
    fingerprintHash: v.string(),
  },
  returns: v.union(
    v.object({
      deleted_config_id: v.id("sharedConfigs"),
      deleted_machine: v.boolean(),
    }),
    v.null(),
  ),
  handler: async (ctx, args) => {
    validateDeleteRequest({
      configId: args.configId,
      fingerprintHash: args.fingerprintHash,
    });

    const config = await ctx.db.get(args.configId);
    const machine = config ? await ctx.db.get(config.machineId) : null;
    validateConfigDeleteTarget(config, machine, {
      fingerprintHash: args.fingerprintHash,
    });

    const machineId = config!.machineId;
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
