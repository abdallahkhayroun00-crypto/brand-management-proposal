"""Delivery Hero restaurant webhook inbox, deployed behind an HTTPS proxy.

This process is NOT the staff LAN server. It never accepts phone sessions or
cashier commands. Configure one approved restaurant/program per deployment.
"""
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import base64
import hashlib
import hmac
import json
import os
import sqlite3
import time
from urllib.parse import urlparse, parse_qs, unquote


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def verify_middleware_jwt(value, secret, now=None):
    if not secret or not value.startswith("Bearer "):
        raise ValueError("unauthorized")
    token = value[7:]
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("unauthorized")
    decode = lambda part: base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))
    header, claims = json.loads(decode(parts[0])), json.loads(decode(parts[1]))
    if header.get("alg") != "HS512" or claims.get("service") != "middleware":
        raise ValueError("unauthorized")
    signature = hmac.new(secret.encode(), f"{parts[0]}.{parts[1]}".encode(), hashlib.sha512).digest()
    if not hmac.compare_digest(signature, decode(parts[2])):
        raise ValueError("unauthorized")
    stamp = time.time() if now is None else now
    if "exp" in claims and (not isinstance(claims["exp"], (int, float)) or claims["exp"] <= stamp):
        raise ValueError("unauthorized")
    if "nbf" in claims and claims["nbf"] > stamp + 30:
        raise ValueError("unauthorized")


class Inbox:
    def __init__(self, file):
        self.file = str(file)
        Path(self.file).parent.mkdir(parents=True, exist_ok=True)
        with closing(self.connect()) as db:
            db.execute("CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY AUTOINCREMENT, identity TEXT UNIQUE NOT NULL, remote_id TEXT NOT NULL, remote_order_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL)")

    def connect(self):
        db = sqlite3.connect(self.file, timeout=15, isolation_level=None)
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        return db

    def put(self, remote_id, remote_order_id, kind, payload):
        encoded = canonical(payload)
        identity = hashlib.sha256(f"{remote_id}\0{remote_order_id}\0{kind}\0{encoded}".encode()).hexdigest()
        with closing(self.connect()) as db:
            db.execute("BEGIN IMMEDIATE")
            try:
                db.execute("INSERT OR IGNORE INTO events(identity,remote_id,remote_order_id,kind,payload) VALUES(?,?,?,?,?)", (identity, remote_id, remote_order_id, kind, encoded))
                event_id = db.execute("SELECT id FROM events WHERE identity=?", (identity,)).fetchone()[0]
                db.execute("COMMIT")
                return event_id
            except Exception:
                db.execute("ROLLBACK")
                raise

    def read(self, remote_id, after):
        with closing(self.connect()) as db:
            rows = db.execute("SELECT id,remote_id,remote_order_id,kind,payload FROM events WHERE remote_id=? AND id>? ORDER BY id LIMIT 100", (remote_id, after)).fetchall()
        return [dict(id=r[0], remoteId=r[1], remoteOrderId=r[2], kind=r[3], payload=json.loads(r[4])) for r in rows]


class Gateway(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, inbox, remote_id, platform_key, webhook_secret, relay_token):
        if not all([remote_id, platform_key, webhook_secret, relay_token]) or len(relay_token) < 32:
            raise ValueError("Gateway credentials and approved restaurant identifiers required")
        self.inbox, self.remote_id, self.platform_key = inbox, remote_id, platform_key
        self.webhook_secret, self.relay_token = webhook_secret, relay_token
        super().__init__(address, Handler)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log request bodies, callback URLs, JWTs or credentials.

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        auth = self.headers.get("Authorization", "")
        if not hmac.compare_digest(auth, "Bearer " + self.server.relay_token):
            self.reply(401, {"error": "unauthorized"}); return
        query = parse_qs(parsed.query)
        if parsed.path != "/v1/events" or query.get("remoteId") != [self.server.remote_id]:
            self.reply(404, {"error": "not_found"}); return
        try:
            after = int(query.get("after", ["0"])[0])
            if after < 0: raise ValueError()
            self.reply(200, {"events": self.server.inbox.read(self.server.remote_id, after)})
        except ValueError:
            self.reply(400, {"error": "invalid_cursor"})

    def do_POST(self):
        self.incoming("order")

    def do_PUT(self):
        self.incoming("status")

    def incoming(self, kind):
        try:
            verify_middleware_jwt(self.headers.get("Authorization", ""), self.server.webhook_secret)
        except Exception:
            # Consume a bounded rejected POST body before replying. Closing a
            # socket with unread body bytes can reset Windows HTTP clients
            # before they receive the 401 response.
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if 0 < size <= 2 * 1024 * 1024:
                    self.connection.settimeout(5)
                    self.rfile.read(size)
            except (ValueError, OSError):
                pass
            self.reply(401, {"error": "unauthorized"}); return
        parts = [unquote(p) for p in urlparse(self.path).path.split("/") if p]
        if kind == "order" and len(parts) == 2 and parts == ["order", self.server.remote_id]:
            remote_order_id = None
        elif kind == "status" and len(parts) == 5 and parts[0] == "remoteId" and parts[1] == self.server.remote_id and parts[2] == "remoteOrder" and parts[4] == "posOrderStatus":
            remote_order_id = parts[3]
        else:
            self.reply(400, {"error": "restaurant_mismatch"}); return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size <= 0 or size > 2 * 1024 * 1024:
                raise ValueError()
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict): raise ValueError()
            if kind == "order":
                if payload.get("localInfo", {}).get("platformKey") != self.server.platform_key or not isinstance(payload.get("token"), str) or not payload["token"]:
                    raise ValueError()
                remote_order_id = "NF-" + hashlib.sha256(f"{self.server.remote_id}:{payload['token']}".encode()).hexdigest()[:40]
            else:
                if not isinstance(payload.get("status"), str): raise ValueError()
        except Exception:
            self.reply(400, {"error": "invalid_order"}); return
        try:
            self.server.inbox.put(self.server.remote_id, remote_order_id, kind, payload)
        except sqlite3.Error:
            self.reply(500, {"error": "not_persisted"}); return
        self.reply(200, {"remoteOrderId": remote_order_id} if kind == "order" else {"ok": True})


if __name__ == "__main__":
    gateway = Gateway(("127.0.0.1", int(os.getenv("PORT", "8080"))),
        Inbox(os.environ["GATEWAY_DATABASE"]), os.environ["YS_REMOTE_ID"],
        os.environ["YS_PLATFORM_KEY"], os.environ["YS_WEBHOOK_SECRET"], os.environ["RELAY_TOKEN"])
    gateway.serve_forever()
