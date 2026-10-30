"""Loopback-only anonymous auth fixture for T10 iOS overlay proof.

No real credentials or user data. Never logs request headers or bodies.
Run with python3 tool/t10_auth_upgrade_fixture.py; bind is always 127.0.0.1.
"""

import base64
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

USER_ID = "00000000-0000-4000-8000-000000000010"
PROFILE = {
    "id": USER_ID,
    "display_name": "T10 Yerel Misafir",
    "player_tag": "T10LOCAL",
    "avatar_color": "#246B4A",
    "total_xp": 0,
    "level": 1,
}
USER = {
    "id": USER_ID,
    "aud": "authenticated",
    "role": "authenticated",
    "email": "",
    "phone": "",
    "created_at": "2026-10-30T00:00:00Z",
    "updated_at": "2026-10-30T00:00:00Z",
    "is_anonymous": True,
    "app_metadata": {"provider": "anonymous", "providers": ["anonymous"]},
    "user_metadata": {"display_name": PROFILE["display_name"]},
    "identities": [],
}
LAST_SESSION = None


def segment(value):
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")


def session():
    expiry = int(time.time()) + 86400
    token = ".".join([
        segment({"alg": "HS256", "typ": "JWT"}),
        segment({"sub": USER_ID, "exp": expiry, "role": "authenticated"}),
        "local-fixture-not-a-signature",
    ])
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 86400,
        "expires_at": expiry,
        "refresh_token": "t10-local-fixture-refresh",
        "user": USER,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self):
        global LAST_SESSION
        path = urlparse(self.path).path
        # Drain request without decoding or logging it.
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if path in ("/auth/v1/signup", "/auth/v1/token"):
            LAST_SESSION = session()
            value = LAST_SESSION
        elif path == "/auth/v1/user":
            value = USER
        elif path == "/rest/v1/profiles":
            value = PROFILE if "object" in self.headers.get("Accept", "") else [PROFILE]
        elif path == "/rest/v1/rpc/presence_heartbeat":
            value = None
        else:
            value = []
        data = json.dumps(value).encode()
        same_session = LAST_SESSION is not None and self.headers.get("Authorization") == (
            "Bearer " + LAST_SESSION["access_token"]
        )
        print(json.dumps({"method": self.command, "path": path,
                          "fixture_user": USER_ID,
                          "same_guest_session": same_session}), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = respond
    do_POST = respond
    do_PATCH = respond
    do_DELETE = respond


if __name__ == "__main__":
    print("T10 fixture listening on http://127.0.0.1:55441", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 55441), Handler).serve_forever()
