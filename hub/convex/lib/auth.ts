/** Expected publish token from Convex env (HUB_PUBLISH_TOKEN). Empty = open publishes. */
export function configuredPublishToken(): string {
  return process.env.HUB_PUBLISH_TOKEN?.trim() ?? "";
}

export function publishAuthEnforced(): boolean {
  return configuredPublishToken().length > 0;
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

/**
 * Verify Authorization: Bearer for privileged hub routes (publish, delete).
 * Returns null when the request is allowed, otherwise a 401 Response.
 */
export function verifyPrivilegedHubAuth(request: Request): Response | null {
  const expected = configuredPublishToken();
  if (!expected) {
    return null;
  }

  const provided = extractBearerToken(request);
  if (!provided || !tokensEqual(provided, expected)) {
    return new Response(
      JSON.stringify({
        error: "Unauthorized",
        message:
          "Privileged hub action requires Authorization: Bearer token matching HUB_PUBLISH_TOKEN",
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

  return null;
}

/** @deprecated Use verifyPrivilegedHubAuth */
export const verifyPublishAuth = verifyPrivilegedHubAuth;
