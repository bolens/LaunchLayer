import type { MutationCtx } from "../_generated/server";
import type { Doc, Id } from "../_generated/dataModel";
import type { Fingerprint } from "./similarity";

type FingerprintInput = Fingerprint;

/** Merge machine query results without duplicate ids (vendor + display-tier indexes). */
export function mergeMachineCandidates(
  ...groups: Array<Array<Doc<"machines">>>
): Array<Doc<"machines">> {
  const seen = new Set<Id<"machines">>();
  const merged: Array<Doc<"machines">> = [];
  for (const group of groups) {
    for (const machine of group) {
      if (seen.has(machine._id)) {
        continue;
      }
      seen.add(machine._id);
      merged.push(machine);
    }
  }
  return merged;
}

export async function upsertMachineRecord(
  ctx: MutationCtx,
  args: {
    fingerprintHash: string;
    fingerprint: FingerprintInput;
    machineLabel?: string;
  },
): Promise<Id<"machines">> {
  const existing = await ctx.db
    .query("machines")
    .withIndex("by_fingerprint_hash", (q) =>
      q.eq("fingerprintHash", args.fingerprintHash),
    )
    .unique();

  const now = Date.now();
  if (existing) {
    await ctx.db.patch(existing._id, {
      fingerprint: args.fingerprint,
      machineLabel: args.machineLabel ?? existing.machineLabel,
      updatedAt: now,
    });
    return existing._id;
  }

  return await ctx.db.insert("machines", {
    fingerprintHash: args.fingerprintHash,
    fingerprint: args.fingerprint,
    machineLabel: args.machineLabel,
    updatedAt: now,
  });
}

export async function machineSummary(
  machine: Doc<"machines">,
): Promise<{
  machine_id: Id<"machines">;
  machine_label?: string;
  gpu_vendor: string;
  display: string;
  profiles: string[];
}> {
  return {
    machine_id: machine._id,
    machine_label: machine.machineLabel,
    gpu_vendor: machine.fingerprint.gpu_vendor,
    display: machine.fingerprint.display ?? "",
    profiles: machine.fingerprint.profiles,
  };
}
