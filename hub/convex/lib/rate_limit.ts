export const RATE_LIMIT_WINDOW_MS = 60_000;

export const RATE_LIMITS = {
  recommend: 30,
  similarMachines: 30,
  myConfig: 60,
  getConfig: 120,
} as const;

export type RateLimitRoute = keyof typeof RATE_LIMITS;

export function rateLimitBucketKey(
  route: RateLimitRoute,
  identifier: string,
): string {
  return `${route}:${identifier}`;
}

export function rateLimitWindowStart(now: number): number {
  return now - (now % RATE_LIMIT_WINDOW_MS);
}

export function rateLimitAllows(count: number, max: number): boolean {
  return count < max;
}

export function rateLimitExceededError(): never {
  throw new Error("RATE_LIMITED: Too many requests — try again later");
}

export function requestIdentifier(
  request: Request,
  body?: Record<string, unknown>,
): string {
  const fingerprintHash = body?.fingerprint_hash;
  if (typeof fingerprintHash === "string" && fingerprintHash.length > 0) {
    return `hash:${fingerprintHash}`;
  }

  const forwarded = request.headers.get("X-Forwarded-For");
  if (forwarded) {
    const ip = forwarded.split(",")[0]?.trim();
    if (ip) {
      return `ip:${ip}`;
    }
  }

  const realIp = request.headers.get("X-Real-IP")?.trim();
  if (realIp) {
    return `ip:${realIp}`;
  }

  return "ip:unknown";
}
