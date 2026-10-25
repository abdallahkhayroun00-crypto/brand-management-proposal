#!/usr/bin/env python3
"""Nohut Falafel offline LAN prototype: one Windows laptop, SQLite, phone QR."""
from __future__ import annotations

import argparse
import ipaddress
import json
import logging
import os
from pathlib import Path
import socket
import sqlite3
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import webbrowser

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "pos-demo" / "local-data"
DB_PATH = DATA_DIR / "nohut-pos.sqlite3"
MAX_BODY = 4 * 1024 * 1024
LOCK = threading.RLock()
DEFAULT_STATE = {
    "employees": [
        {"id": 1, "name": "Ömer", "role": "Yönetici", "active": True},
        {"id": 2, "name": "Mehmet", "role": "Personel", "active": True},
        {"id": 3, "name": "Abdallah", "role": "Personel", "active": True},
    ],
    "orders": [],
    "nextId": 1200,
    "printJobs": [],
}


def lan_ip() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("192.0.2.1", 80))  # no packet sent, just OS routing lookup
        candidate = sock.getsockname()[0]
        if ipaddress.ip_address(candidate).is_private:
            return candidate
    except OSError:
        pass
    finally:
        sock.close()
    try:
        for _, _, _, _, addr in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            candidate = addr[0]
            if ipaddress.ip_address(candidate).is_private and not candidate.startswith("127."):
                return candidate
    except OSError:
        pass
    return "127.0.0.1"


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=15, isolation_level=None)
    conn.execute("PRAGMA busy_timeout = 15000")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def initialize() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with connect() as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS state_snapshot ("
            "id INTEGER PRIMARY KEY CHECK (id=1), "
            "revision INTEGER NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL)"
        )
        conn.execute(
            "INSERT OR IGNORE INTO state_snapshot (id, revision, payload, updated_at) "
            "VALUES (1, 0, ?, datetime('now'))",
            (json.dumps(DEFAULT_STATE, ensure_ascii=False),),
        )


def snapshot() -> tuple[int, dict, str]:
    with connect() as conn:
        revision, payload, updated = conn.execute(
            "SELECT revision, payload, updated_at FROM state_snapshot WHERE id=1"
        ).fetchone()
    return revision, json.loads(payload), updated


def validate_state(obj: object) -> dict:
    if not isinstance(obj, dict):
        raise ValueError("State must be a JSON object")
    for key in ("orders", "employees", "printJobs"):
        if not isinstance(obj.get(key), list):
            raise ValueError(f"Missing state list: {key}")
    if not isinstance(obj.get("nextId"), int) or obj["nextId"] < 1:
        raise ValueError("Invalid next order ID")
    orders = obj["orders"]
    if len(orders) > 50000 or len(obj["printJobs"]) > 100000:
        raise ValueError("Order limit exceeded")
    ids = [o.get("id") for o in orders if isinstance(o, dict)]
    if len(ids) != len(orders) or any(type(i) is not int or i < 1 for i in ids):
        raise ValueError("Invalid order records")
    if len(set(ids)) != len(ids) or (ids and obj["nextId"] <= max(ids)):
        raise ValueError("Duplicate order ID or invalid nextId")
    if any(not isinstance(o.get("batches"), list) or not isinstance(o.get("payments"), list)
           for o in orders):
        raise ValueError("Invalid order batches/payments")
    return obj


def write_snapshot(expected: int, obj: dict) -> tuple[bool, int, dict | None]:
    validate_state(obj)
    payload = json.dumps(obj, separators=(",", ":"), ensure_ascii=False, allow_nan=False)
    with LOCK:
        with connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            current, old_payload = conn.execute(
                "SELECT revision, payload FROM state_snapshot WHERE id=1"
            ).fetchone()
            if current != expected:
                conn.execute("ROLLBACK")
                return False, current, json.loads(old_payload)
            nxt = current + 1
            conn.execute(
                "UPDATE state_snapshot SET revision=?, payload=?, updated_at=datetime('now') WHERE id=1",
                (nxt, payload),
            )
            conn.execute("COMMIT")
    return True, nxt, None


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class Handler(SimpleHTTPRequestHandler):
    server_version = "NohutLocalPOS/0.1"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def _json(self, status: int, value: dict) -> None:
        raw = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(raw)

    def _urls(self) -> tuple[str, str]:
        address = self.server.advertise_ip
        port = self.server.server_address[1]
        return (f"http://{address}:{port}/pos-demo/?panel=personel",
                f"http://127.0.0.1:{port}/pos-demo/?panel=yonetici")

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            self.send_response(302)
            self.send_header("Location", "/pos-demo/?panel=yonetici")
            self.end_headers()
            return
        if path == "/personel":
            self.send_response(302)
            self.send_header("Location", "/pos-demo/?panel=personel")
            self.end_headers()
            return
        if path in ("/api/bootstrap", "/api/state", "/api/health"):
            rev, db, updated = snapshot()
            staff, pc = self._urls()
            if path == "/api/health":
                self._json(200, {"online": True, "revision": rev})
            elif path == "/api/state":
                self._json(200, {"revision": rev, "state": db})
            else:
                self._json(200, {"online": True, "revision": rev, "state": db,
                                 "updatedAt": updated, "staffUrl": staff, "adminUrl": pc,
                                 "ip": self.server.advertise_ip,
                                 "port": self.server.server_address[1],
                                 "storage": "SQLite (laptop)"})
            return
        parts = Path(path.lstrip("/")).parts
        if not parts or parts[0] not in ("pos-demo", "nohut-menu"):
            self.send_error(404)
            return
        # Prevent serving SQLite files, source code, hidden files and test internals.
        if any(x.startswith(".") or x in ("local-data", "tests", "__pycache__") for x in parts):
            self.send_error(403)
            return
        ext = Path(path).suffix.lower()
        if ext and ext not in (".html", ".css", ".js", ".png", ".jpg", ".jpeg", ".svg",
                               ".webp", ".gif", ".ico", ".woff", ".woff2", ".json", ".map"):
            self.send_error(403)
            return
        return super().do_GET()

    def do_PUT(self):
        if urlparse(self.path).path != "/api/state":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not (0 < length <= MAX_BODY):
                return self._json(413, {"error": "payload_size"})
            raw = self.rfile.read(length)
            packet = json.loads(raw)
            expected = packet.get("baseVersion")
            if type(expected) is not int:
                return self._json(400, {"error": "invalid_version"})
            obj = packet.get("state")
            ok, revision, latest = write_snapshot(expected, obj)
            if not ok:
                return self._json(409, {"error": "conflict", "revision": revision, "state": latest})
            self._json(200, {"ok": True, "revision": revision})
        except (json.JSONDecodeError, ValueError, TypeError) as exc:
            self._json(422, {"error": "invalid_state", "message": str(exc)})
        except Exception:
            logging.exception("state write failed")
            self._json(500, {"error": "server_failure"})

    def log_message(self, fmt, *args):
        logging.info("%s %s", self.address_string(), fmt % args)


def main():
    parser = argparse.ArgumentParser(description="Nohut Falafel laptop local server")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--advertise-ip", help="Laptop IPv4 for staff QR (e.g. 192.168.1.100)")
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    ip = args.advertise_ip or lan_ip()
    if not ipaddress.ip_address(ip).is_private:
        parser.error("QR address must be a private network IPv4 address")
    initialize()
    server = Server(("0.0.0.0", args.port), Handler)
    server.advertise_ip = ip
    staff, pc = (f"http://{ip}:{args.port}/pos-demo/?panel=personel",
                 f"http://127.0.0.1:{args.port}/pos-demo/?panel=yonetici")
    print("\nNOHUT FALAFEL · YEREL SUNUCU (SQLite)\n", flush=True)
    print("YÖNETİCİ (Laptop):", pc, flush=True)
    print("PERSONEL (QR):  ", staff, flush=True)
    print("VERİTABANI:    ", DB_PATH, flush=True)
    print("\nLaptop ve telefonlar AYNI Wi-Fi ağına bağlı olmalı.", flush=True)
    print("YALNIZCA güvenilir personel Wi-Fi ağı; parola koruması henüz yok.", flush=True)
    print("Windows firewall: yalnızca özel ağlara (Private) izin verin.", flush=True)
    print("Sunucuyu durdurmak için CTRL+C.\n", flush=True)
    if not args.no_browser:
        threading.Timer(1.0, lambda: webbrowser.open(pc)).start()
    try:
        server.serve_forever(poll_interval=.5)
    except KeyboardInterrupt:
        print("\nSunucu kapatılıyor...", flush=True)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
