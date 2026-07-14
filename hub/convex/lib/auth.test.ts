import assert from "node:assert/strict";
import { afterEach, describe, it } from "node:test";
import {
  allowOpenPublish,
  configuredPublishToken,
  extractBearerToken,
  publishAuthEnforced,
  verifyPrivilegedHubAuth,
} from "./auth";

const ORIGINAL_TOKEN = process.env.HUB_PUBLISH_TOKEN;
const ORIGINAL_ALLOW_OPEN = process.env.HUB_ALLOW_OPEN_PUBLISH;

afterEach(() => {
  if (ORIGINAL_TOKEN === undefined) {
    delete process.env.HUB_PUBLISH_TOKEN;
  } else {
    process.env.HUB_PUBLISH_TOKEN = ORIGINAL_TOKEN;
  }
  if (ORIGINAL_ALLOW_OPEN === undefined) {
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
  } else {
    process.env.HUB_ALLOW_OPEN_PUBLISH = ORIGINAL_ALLOW_OPEN;
  }
});

describe("extractBearerToken", () => {
  it("parses a Bearer authorization header", () => {
    const request = new Request("https://example.test", {
      headers: { Authorization: "Bearer abc-123" },
    });
    assert.equal(extractBearerToken(request), "abc-123");
  });

  it("accepts lowercase bearer scheme", () => {
    const request = new Request("https://example.test", {
      headers: { Authorization: "bearer secret-token" },
    });
    assert.equal(extractBearerToken(request), "secret-token");
  });

  it("trims whitespace around the token", () => {
    const request = new Request("https://example.test", {
      headers: { Authorization: "Bearer   padded-token  " },
    });
    assert.equal(extractBearerToken(request), "padded-token");
  });

  it("returns null when Authorization is missing", () => {
    const request = new Request("https://example.test");
    assert.equal(extractBearerToken(request), null);
  });

  it("returns null for non-Bearer schemes", () => {
    const request = new Request("https://example.test", {
      headers: { Authorization: "Basic abc" },
    });
    assert.equal(extractBearerToken(request), null);
  });

  it("returns null for Bearer with empty token", () => {
    const request = new Request("https://example.test", {
      headers: { Authorization: "Bearer" },
    });
    assert.equal(extractBearerToken(request), null);
  });
});

describe("configuredPublishToken", () => {
  it("trims whitespace from HUB_PUBLISH_TOKEN", () => {
    process.env.HUB_PUBLISH_TOKEN = "  trimmed-secret  ";
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
    assert.equal(configuredPublishToken(), "trimmed-secret");
    assert.equal(publishAuthEnforced(), true);
  });

  it("treats whitespace-only token as empty", () => {
    process.env.HUB_PUBLISH_TOKEN = "   ";
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
    assert.equal(configuredPublishToken(), "");
    assert.equal(publishAuthEnforced(), true);
  });
});

describe("allowOpenPublish", () => {
  it("requires explicit HUB_ALLOW_OPEN_PUBLISH=1", () => {
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
    assert.equal(allowOpenPublish(), false);
    process.env.HUB_ALLOW_OPEN_PUBLISH = "1";
    assert.equal(allowOpenPublish(), true);
    process.env.HUB_ALLOW_OPEN_PUBLISH = "true";
    assert.equal(allowOpenPublish(), false);
  });
});

describe("verifyPrivilegedHubAuth", () => {
  it("rejects requests when HUB_PUBLISH_TOKEN is unset (fail closed)", async () => {
    delete process.env.HUB_PUBLISH_TOKEN;
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
    const request = new Request("https://example.test", { method: "POST" });
    const response = verifyPrivilegedHubAuth(request);
    assert.ok(response);
    assert.equal(response.status, 401);
    assert.equal(publishAuthEnforced(), true);
    assert.equal(configuredPublishToken(), "");
    const body = (await response.json()) as { message: string };
    assert.match(body.message, /HUB_PUBLISH_TOKEN|HUB_ALLOW_OPEN_PUBLISH/);
  });

  it("allows requests when open publish is explicitly enabled", () => {
    delete process.env.HUB_PUBLISH_TOKEN;
    process.env.HUB_ALLOW_OPEN_PUBLISH = "1";
    const request = new Request("https://example.test", { method: "POST" });
    assert.equal(verifyPrivilegedHubAuth(request), null);
    assert.equal(publishAuthEnforced(), false);
  });

  it("rejects missing Authorization when token is configured", async () => {
    process.env.HUB_PUBLISH_TOKEN = "server-secret";
    delete process.env.HUB_ALLOW_OPEN_PUBLISH;
    const request = new Request("https://example.test", { method: "POST" });
    const response = verifyPrivilegedHubAuth(request);
    assert.ok(response);
    assert.equal(response.status, 401);
    assert.equal(response.headers.get("Content-Type"), "application/json");
    assert.equal(
      response.headers.get("Access-Control-Allow-Origin"),
      "*",
    );
    assert.equal(
      response.headers.get("WWW-Authenticate"),
      'Bearer realm="LaunchLayer Hub"',
    );
    const body = (await response.json()) as { error: string; message: string };
    assert.equal(body.error, "Unauthorized");
    assert.match(body.message, /HUB_PUBLISH_TOKEN/);
  });

  it("rejects wrong Bearer token", async () => {
    process.env.HUB_PUBLISH_TOKEN = "server-secret";
    const request = new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer wrong" },
    });
    const response = verifyPrivilegedHubAuth(request);
    assert.ok(response);
    assert.equal(response.status, 401);
  });

  it("rejects same-prefix token with different length", () => {
    process.env.HUB_PUBLISH_TOKEN = "server-secret";
    const request = new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer server-secret-extra" },
    });
    assert.ok(verifyPrivilegedHubAuth(request));
  });

  it("accepts a matching Bearer token", () => {
    process.env.HUB_PUBLISH_TOKEN = "server-secret";
    const request = new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer server-secret" },
    });
    assert.equal(verifyPrivilegedHubAuth(request), null);
    assert.equal(publishAuthEnforced(), true);
  });
});
