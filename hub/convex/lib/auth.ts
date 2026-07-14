/** Expected publish token from Convex env (HUB_PUBLISH_TOKEN). */
export function configuredPublishToken(): string {
  return process.env.HUB_PUBLISH_TOKEN?.trim() ?? "";
}

/**
 * Explicit opt-in for unauthenticated publish/delete (local/dev only).
 * Production deployments must set HUB_PUBLISH_TOKEN instead.
 */
export function allowOpenPublish(): boolean {
  return process.env.HUB_ALLOW_OPEN_PUBLISH?.trim() === "1";
}

/**
 * True when privileged routes require a Bearer token from the client.
 * Also true when the hub is fail-closed (token unset and open publish not allowed),
 * so clients know to send publish_token / refuse to proceed without credentials.
 */
export function publishAuthEnforced(): boolean {
  if (configuredPublishToken().length > 0) {
    return true;
  }
  return !allowOpenPublish();
}

export function extractBearerToken(request: Request): string | null {
  const header = request.headers.get("Authorization");
  if (!header) {
    return null;
  }
  const match = /^Bearer\s+(.+)$/i.exec(header);
  const token = match?.[1]?.trim();
  return token && token.length > 0 ? token : null;
}

function tokensEqual(provided: string, expected: string): boolean {
  if (provided.length !== expected.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < provided.length; i += 1) {
    mismatch |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return mismatch === 0;
}

function unauthorizedResponse(message: string): Response {
  return new Response(
    JSON.stringify({
      error: "Unauthorized",
      message,
    }),
    {
      status: 401,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "WWW-Authenticate": 'Bearer realm="LaunchLayer Hub"',
      },
    },
  );
}

/**
 * Verify Authorization: Bearer for privileged hub routes (publish, delete).
 * Returns null when the request is allowed, otherwise a 401 Response.
 *
 * Fail-closed: if HUB_PUBLISH_TOKEN is unset, privileged routes are rejected
 * unless HUB_ALLOW_OPEN_PUBLISH=1 is set explicitly (local/dev).
 */
export function verifyPrivilegedHubAuth(request: Request): Response | null {
  const expected = configuredPublishToken();
  if (!expected) {
    if (allowOpenPublish()) {
      return null;
    }
    return unauthorizedResponse(
      "Privileged hub action rejected: set HUB_PUBLISH_TOKEN on the deployment, or HUB_ALLOW_OPEN_PUBLISH=1 for local/dev only",
    );
  }

  const provided = extractBearerToken(request);
  if (!provided || !tokensEqual(provided, expected)) {
    return unauthorizedResponse(
      "Privileged hub action requires Authorization: Bearer token matching HUB_PUBLISH_TOKEN",
    );
  }

  return null;
}

/** @deprecated Use verifyPrivilegedHubAuth */
export const verifyPublishAuth = verifyPrivilegedHubAuth;
