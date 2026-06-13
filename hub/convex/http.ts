import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import {
  publishAuthEnforced,
  verifyPrivilegedHubAuth,
} from "./lib/auth";
import { parseFingerprint } from "./lib/fingerprint";
import { publishHttpStatusForError } from "./lib/publish";

const http = httpRouter();

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

async function readJson(request: Request): Promise<unknown> {
  return await request.json();
}

http.route({
  path: "/api/auth",
  method: "GET",
  handler: httpAction(async () => {
    return jsonResponse({ publish_auth_required: publishAuthEnforced() });
  }),
});

http.route({
  path: "/api/publish",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const authError = verifyPrivilegedHubAuth(request);
    if (authError) {
      return authError;
    }

    const body = (await readJson(request)) as Record<string, unknown>;
    const settings = (body.settings as Array<{ key: string; value: string }>) ?? [];
    const detection = body.detection as {
      native: boolean;
      anticheat: boolean;
      engine?: string;
    };
    const configIdRaw = body.config_id ? String(body.config_id) : undefined;

    try {
      const result = await ctx.runMutation(api.configs.publishConfig, {
        fingerprintHash: String(body.fingerprint_hash),
        fingerprint: parseFingerprint(body.fingerprint),
        machineLabel: body.machine_label ? String(body.machine_label) : undefined,
        appid: String(body.appid),
        gameName: String(body.game_name),
        envContent: String(body.env_content),
        settings,
        preset: body.preset ? String(body.preset) : undefined,
        note: body.note ? String(body.note) : undefined,
        detection: {
          native: Boolean(detection.native),
          anticheat: Boolean(detection.anticheat),
          engine: detection.engine ? String(detection.engine) : undefined,
        },
        launchlayerVersion: body.launchlayer_version
          ? String(body.launchlayer_version)
          : undefined,
        configId: configIdRaw
          ? (configIdRaw as Id<"sharedConfigs">)
          : undefined,
      });

      return jsonResponse(result);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Publish failed";
      const status = publishHttpStatusForError(message);
      return jsonResponse({ error: message.replace(/^[^:]+:\s*/, ""), code: message.split(":")[0] }, status);
    }
  }),
});

http.route({
  path: "/api/my-config",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = (await readJson(request)) as Record<string, unknown>;
    const result = await ctx.runQuery(api.configs.findMyConfig, {
      fingerprintHash: String(body.fingerprint_hash),
      appid: String(body.appid),
    });
    return jsonResponse(result);
  }),
});

http.route({
  path: "/api/delete",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const authError = verifyPrivilegedHubAuth(request);
    if (authError) {
      return authError;
    }

    const body = (await readJson(request)) as Record<string, unknown>;
    const configId = String(body.config_id ?? "");
    if (!configId) {
      return jsonResponse({ error: "config_id is required" }, 400);
    }

    const result = await ctx.runMutation(api.configs.deleteConfig, {
      configId: configId as Id<"sharedConfigs">,
    });
    if (!result) {
      return jsonResponse({ error: "Config not found" }, 404);
    }

    return jsonResponse(result);
  }),
});

http.route({
  path: "/api/recommend",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = (await readJson(request)) as Record<string, unknown>;
    const results = await ctx.runQuery(api.configs.recommendConfigs, {
      fingerprint: parseFingerprint(body.fingerprint),
      appid: String(body.appid),
      limit: body.limit ? Number(body.limit) : undefined,
    });
    return jsonResponse({ results });
  }),
});

http.route({
  path: "/api/similar-machines",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = (await readJson(request)) as Record<string, unknown>;
    const results = await ctx.runQuery(api.machines.similarMachines, {
      fingerprint: parseFingerprint(body.fingerprint),
      limit: body.limit ? Number(body.limit) : undefined,
    });
    return jsonResponse({ results });
  }),
});

http.route({
  pathPrefix: "/api/config/",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const configId = url.pathname.replace(/^\/api\/config\//, "") as Id<"sharedConfigs">;
    const config = await ctx.runQuery(api.configs.getConfig, { configId });
    if (!config) {
      return jsonResponse({ error: "Config not found" }, 404);
    }
    await ctx.runMutation(api.configs.recordDownload, { configId });
    return jsonResponse(config);
  }),
});

export default http;
