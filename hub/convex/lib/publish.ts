import type { Doc } from "../_generated/dataModel";

export type PublishConfigContent = {
  gameName: string;
  envContent: string;
  settings: Array<{ key: string; value: string; source?: string }>;
  preset?: string;
  note?: string;
  detection: { native: boolean; anticheat: boolean; engine?: string };
  launchlayerVersion?: string;
};

export type PublishConfigPatch = PublishConfigContent & {
  publishedAt: number;
};

export function buildPublishConfigPatch(
  content: PublishConfigContent,
  publishedAt: number,
): PublishConfigPatch {
  return {
    ...content,
    publishedAt,
  };
}

export function validateConfigDeleteTarget(
  config: Doc<"sharedConfigs"> | null,
  machine: Doc<"machines"> | null,
  args: { fingerprintHash: string },
): Doc<"sharedConfigs"> {
  if (!config) {
    throw new Error("NOT_FOUND: Shared config not found");
  }
  if (!machine) {
    throw new Error("MACHINE_MISSING: Config machine record not found");
  }
  if (machine.fingerprintHash !== args.fingerprintHash) {
    throw new Error(
      "FINGERPRINT_MISMATCH: Config belongs to a different machine fingerprint",
    );
  }
  return config;
}

export function validateConfigUpdateTarget(
  config: Doc<"sharedConfigs"> | null,
  machine: Doc<"machines"> | null,
  args: { fingerprintHash: string; appid: string },
): Doc<"sharedConfigs"> {
  if (!config) {
    throw new Error("NOT_FOUND: Shared config not found");
  }
  if (!machine) {
    throw new Error("MACHINE_MISSING: Config machine record not found");
  }
  if (machine.fingerprintHash !== args.fingerprintHash) {
    throw new Error(
      "FINGERPRINT_MISMATCH: Config belongs to a different machine fingerprint",
    );
  }
  if (config.appid !== args.appid) {
    throw new Error(
      "APPID_MISMATCH: appid does not match the config being updated",
    );
  }
  return config;
}

export function publishHttpStatusForError(message: string): number {
  if (message.startsWith("QUOTA_EXCEEDED:")) {
    return 403;
  }
  if (message.startsWith("RATE_LIMITED:")) {
    return 429;
  }
  if (message.startsWith("VALIDATION_ERROR:")) {
    return 400;
  }
  if (message.startsWith("NOT_FOUND:")) {
    return 404;
  }
  if (message.startsWith("FINGERPRINT_MISMATCH:")) {
    return 409;
  }
  if (message.startsWith("APPID_MISMATCH:")) {
    return 400;
  }
  if (message.startsWith("MACHINE_MISSING:")) {
    return 500;
  }
  return 500;
}
