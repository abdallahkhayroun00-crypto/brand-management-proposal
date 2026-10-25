"""Integration checks for the offline SQLite + LAN QR server (stdlib only)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

SERVER = Path(__file__).resolve().parents[1] / "local_server.py"
spec = importlib.util.spec_from_file_location("nohut_local_server", SERVER)
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)


class LocalServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tempdir = tempfile.TemporaryDirectory()
        app.DATA_DIR = Path(cls.tempdir.name)
        app.DB_PATH = app.DATA_DIR / "local-test.sqlite3"
        app.initialize()
        cls.server = app.Server(("127.0.0.1", 0), app.Handler)
        cls.server.advertise_ip = "127.0.0.1"
        cls.url = "http://127.0.0.1:" + str(cls.server.server_address[1])
        cls.worker = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.worker.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.worker.join(timeout=3)
        cls.tempdir.cleanup()

    def request(self, url, method="GET", data=None):
        body = None if data is None else json.dumps(data, ensure_ascii=False).encode("utf-8")
        req = Request(self.url + url, data=body, method=method)
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req, timeout=4) as resp:
                raw = resp.read()
                typ = resp.headers.get("Content-Type", "")
                return resp.status, json.loads(raw) if "application/json" in typ else raw
        except HTTPError as e:
            raw = e.read()
            try:
                return e.code, json.loads(raw)
            except ValueError:
                return e.code, raw

    def test_01_bootstrap_empty_sqlite_and_staff_url(self):
        code, body = self.request("/api/bootstrap")
        self.assertEqual(code, 200)
        self.assertEqual(body["revision"], 0)
        self.assertEqual(body["state"]["orders"], [])
        self.assertEqual(len(body["state"]["employees"]), 3)
        self.assertIn("?panel=personel", body["staffUrl"])
        self.assertIn("127.0.0.1:", body["staffUrl"])
        self.assertEqual(body["storage"], "SQLite (laptop)")

    def test_02_two_devices_conflict_and_persistence(self):
        _, first = self.request("/api/state")
        _, second = self.request("/api/state")
        db = first["state"]
        db["orders"].append({
            "id": db["nextId"], "source": "Masa", "table": 1,
            "closed": False, "batches": [], "payments": [], "events": []
        })
        db["nextId"] += 1
        code, accepted = self.request("/api/state", method="PUT", data={"baseVersion": first["revision"], "state": db})
        self.assertEqual(code, 200)
        self.assertEqual(accepted["revision"], first["revision"] + 1)
        code, rejected = self.request("/api/state", method="PUT", data={"baseVersion": second["revision"], "state": second["state"]})
        self.assertEqual(code, 409)
        self.assertEqual(rejected["revision"], accepted["revision"])
        self.assertEqual(rejected["state"]["orders"][0]["table"], 1)
        app.initialize()
        rev, persisted, _ = app.snapshot()
        self.assertEqual(rev, accepted["revision"])
        self.assertEqual(len(persisted["orders"]), 1)

    def test_03_invalid_duplicate_order_rejected(self):
        _, old = self.request("/api/state")
        db = old["state"]
        db["orders"].append(dict(db["orders"][0]))
        code, rejected = self.request("/api/state", method="PUT", data={"baseVersion": old["revision"], "state": db})
        self.assertEqual(code, 422)
        self.assertEqual(rejected["error"], "invalid_state")
        _, latest = self.request("/api/state")
        self.assertEqual(latest["revision"], old["revision"])

    def test_04_static_website_and_qrcode_offline(self):
        code, html = self.request("/pos-demo/?panel=personel")
        self.assertEqual(code, 200)
        self.assertIn(b"/vendor/qrcode.min.js", html)
        self.assertIn(b"/api/bootstrap", html)
        code, qr = self.request("/pos-demo/vendor/qrcode.min.js")
        self.assertEqual(code, 200)
        self.assertIn(b"QRCode", qr)
        code, menu = self.request("/nohut-menu/menu-data.js")
        self.assertEqual(code, 200)
        self.assertIn(b"NOHUT", menu.upper())

    def test_05_sensitive_backend_files_not_exposed(self):
        for path in ["/pos-demo/local_server.py", "/pos-demo/local-data/nohut-pos.sqlite3",
                     "/.git/config", "/pos-demo/start-local-server.bat"]:
            code, _ = self.request(path)
            self.assertIn(code, (403, 404), path)
        code, health = self.request("/api/health")
        self.assertEqual(code, 200)
        self.assertTrue(health["online"])

    def test_06_encoded_sensitive_files_blocked(self):
        for path in (
            "/pos-demo/%6cocal-data/nohut-pos%2esqlite3",
            "/pos-demo/%6cocal_server%2epy",
            "/pos-demo/%256cocal-data/nohut-pos%252esqlite3",
            "/pos-demo/%2e%2e/pos-demo/local_server%2epy",
            "/pos-demo/%2e%67itignore",
        ):
            code, _ = self.request(path)
            self.assertIn(code, (403, 404), path)

    def test_07_invalid_financial_snapshot_rejected(self):
        _, existing = self.request("/api/state")
        state = existing["state"]
        state["orders"][0]["payments"] = [
            {"method": "Nakit", "amount": -25}
        ]
        code, reply = self.request("/api/state", method="PUT",
                                   data={"baseVersion": existing["revision"], "state": state})
        self.assertEqual(code, 422)
        self.assertEqual(reply["error"], "invalid_state")
        state["orders"][0]["payments"] = []
        state["orders"][0]["batches"] = [{"id": 1, "lines": [
            {"price": 10, "qty": -2}
        ]}]
        code, reply = self.request("/api/state", method="PUT",
                                   data={"baseVersion": existing["revision"], "state": state})
        self.assertEqual(code, 422)
        self.assertEqual(reply["error"], "invalid_state")
        _, unchanged = self.request("/api/state")
        self.assertEqual(unchanged["revision"], existing["revision"])


if __name__ == "__main__":
    unittest.main()
