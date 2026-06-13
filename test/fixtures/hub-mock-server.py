#!/usr/bin/env python3
"""Minimal LaunchLayer hub HTTP mock for bats privileged-route tests."""

from __future__ import annotations

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REQUIRED_TOKEN = "test-secret"
AUTH_REQUIRED = True


class HubMockHandler(BaseHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _send_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            return json.loads(raw.decode() or "{}")
        except json.JSONDecodeError:
            return {}

    def _privileged_ok(self) -> bool:
        if not AUTH_REQUIRED:
            return True
        auth = self.headers.get("Authorization", "")
        return auth == f"Bearer {REQUIRED_TOKEN}"

    def do_GET(self) -> None:
        if self.path == "/api/auth":
            self._send_json(200, {"publish_auth_required": AUTH_REQUIRED})
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        body = self._read_json()

        if self.path in ("/api/publish", "/api/delete"):
            if not self._privileged_ok():
                self._send_json(
                    401,
                    {
                        "error": "Unauthorized",
                        "message": "Privileged hub action requires Authorization: Bearer token matching HUB_PUBLISH_TOKEN",
                    },
                )
                return

            if self.path == "/api/delete":
                config_id = body.get("config_id")
                if not config_id:
                    self._send_json(400, {"error": "config_id is required"})
                    return
                if config_id == "missing":
                    self._send_json(404, {"error": "Config not found"})
                    return
                self._send_json(
                    200,
                    {"deleted_config_id": config_id, "deleted_machine": False},
                )
                return

            if self.path == "/api/publish":
                self._send_json(
                    200,
                    {"config_id": "mock-config-id", "machine_id": "mock-machine-id"},
                )
                return

        if self.path == "/api/recommend":
            self._send_json(200, {"results": []})
            return

        self._send_json(404, {"error": "not found"})


def main() -> int:
    global REQUIRED_TOKEN, AUTH_REQUIRED
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--token", default="test-secret")
    parser.add_argument(
        "--open",
        action="store_true",
        help="Do not require Authorization on privileged routes",
    )
    args = parser.parse_args()
    REQUIRED_TOKEN = args.token
    AUTH_REQUIRED = not args.open

    server = ThreadingHTTPServer(("127.0.0.1", args.port), HubMockHandler)
    port = server.server_address[1]
    print(port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
