export const RATE_LIMIT_WINDOW_MS = 60_000;

export const RATE_LIMITS = {
  recommend: 30,
  similarMachines: 30,
  myConfig: 60,
  getConfig: 120,
  publish: 10,
  delete: 5,
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

/**
 * Client IP for rate limiting / download dedupe.
 * Prefer platform-assigned headers; fall back to common proxy headers.
 * Do not key rate limits on client-supplied fingerprint hashes alone —
 * those are trivial to rotate and bypass per-client caps.
 */
export function clientIpFromRequest(request: Request): string {
  const cfConnecting = request.headers.get("CF-Connecting-IP")?.trim();
  if (cfConnecting) {
    return `ip:${cfConnecting}`;
  }

  const trueClient = request.headers.get("True-Client-IP")?.trim();
  if (trueClient) {
    return `ip:${trueClient}`;
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

export function requestIdentifier(
  request: Request,
  _body?: Record<string, unknown>,
): string {
  return clientIpFromRequest(request);
}
