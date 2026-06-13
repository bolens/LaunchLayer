export const MAX_CONFIGS_PER_MACHINE = 500;

export function machineConfigQuotaExceeded(configCount: number): boolean {
  return configCount >= MAX_CONFIGS_PER_MACHINE;
}

export function quotaExceededError(): never {
  throw new Error(
    `QUOTA_EXCEEDED: Machine has reached the ${MAX_CONFIGS_PER_MACHINE} shared config limit`,
  );
}
