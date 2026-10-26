import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import server


def jwt(secret="TEST_WEBHOOK_SECRET", **overrides):
    encode = lambda value: base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")
    head = encode({"alg": "HS512", "typ": "JWT"})
    payload = encode({"service": "middleware", "exp": time.time() + 300, **overrides})
    sig = base64.urlsafe_b64encode(hmac.new(secret.encode(), f"{head}.{payload}".encode(), hashlib.sha512).digest()).decode().rstrip("=")
    return f"Bearer {head}.{payload}.{sig}"


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.inbox = server.Inbox(Path(self.folder.name) / "inbox.sqlite3")
        self.gateway = server.Gateway(("127.0.0.1", 0), self.inbox, "TEST_VENDOR", "TEST_PROGRAM", "TEST_WEBHOOK_SECRET", "relay_" + "x" * 40)
        self.worker = threading.Thread(target=self.gateway.serve_forever, daemon=True)
        self.worker.start()
        self.url = f"http://127.0.0.1:{self.gateway.server_address[1]}"

    def tearDown(self):
        self.gateway.shutdown(); self.gateway.server_close(); self.worker.join()
        self.folder.cleanup()

    def call(self, path, method="POST", payload=None, auth=None):
        req = Request(self.url + path, method=method, data=None if payload is None else json.dumps(payload).encode())
        if auth: req.add_header("Authorization", auth)
        req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req, timeout=10) as response:
                return response.status, json.load(response)
        except HTTPError as error:
            with error:
                return error.code, json.load(error)

    def order(self):
        return {"token": "PLATFORM_ORDER", "localInfo": {"platformKey": "TEST_PROGRAM"}, "products": [], "createdAt": "2026-10-25T10:00:00Z"}

    def test_auth_signature_service_expiry_and_restaurant_scope(self):
        for auth in [None, jwt("wrong"), jwt(service="plugin"), jwt(exp=1)]:
            self.assertEqual(self.call("/order/TEST_VENDOR", payload=self.order(), auth=auth)[0], 401)
        self.assertEqual(self.call("/order/OTHER", payload=self.order(), auth=jwt())[0], 400)
        self.assertEqual(self.call("/order/TEST_VENDOR", payload={**self.order(), "localInfo": {"platformKey": "OTHER"}}, auth=jwt())[0], 400)
        self.assertEqual(self.inbox.read("TEST_VENDOR", 0), [])

    def test_ack_is_durable_and_duplicate_replay_returns_same_remote_order_id(self):
        a = self.call("/order/TEST_VENDOR", payload=self.order(), auth=jwt())
        b = self.call("/order/TEST_VENDOR", payload=self.order(), auth=jwt())
        self.assertEqual(a, b); self.assertEqual(a[0], 200)
        self.assertTrue(a[1]["remoteOrderId"].startswith("NF-"))
        reopened = server.Inbox(Path(self.folder.name) / "inbox.sqlite3")
        self.assertEqual(len(reopened.read("TEST_VENDOR", 0)), 1)

    def test_concurrent_duplicate_callbacks_insert_one_event(self):
        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(lambda _: self.call("/order/TEST_VENDOR", payload=self.order(), auth=jwt()), range(12)))
        self.assertTrue(all(r[0] == 200 for r in results))
        self.assertEqual(len({r[1]["remoteOrderId"] for r in results}), 1)
        self.assertEqual(len(self.inbox.read("TEST_VENDOR", 0)), 1)

    def test_relay_requires_distinct_bearer_and_restaurant_and_cursor(self):
        self.call("/order/TEST_VENDOR", payload=self.order(), auth=jwt())
        path = "/v1/events?remoteId=TEST_VENDOR&after=0"
        self.assertEqual(self.call(path, method="GET", auth=jwt())[0], 401)
        auth = "Bearer " + self.gateway.relay_token
        code, body = self.call(path, method="GET", auth=auth)
        self.assertEqual(code, 200); self.assertEqual(len(body["events"]), 1)
        cursor = body["events"][0]["id"]
        self.assertEqual(self.call(f"/v1/events?remoteId=TEST_VENDOR&after={cursor}", method="GET", auth=auth)[1]["events"], [])
        self.assertEqual(self.call("/v1/events?remoteId=OTHER", method="GET", auth=auth)[0], 404)

    def test_status_events_keep_stable_remote_order_identity(self):
        _, ack = self.call("/order/TEST_VENDOR", payload=self.order(), auth=jwt())
        path = f"/remoteId/TEST_VENDOR/remoteOrder/{ack['remoteOrderId']}/posOrderStatus"
        self.assertEqual(self.call(path, method="PUT", payload={"status": "ORDER_CANCELLED"}, auth=jwt())[0], 200)
        events = self.inbox.read("TEST_VENDOR", 0)
        self.assertEqual(events[-1]["kind"], "status")
        self.assertEqual(events[-1]["remoteOrderId"], ack["remoteOrderId"])


if __name__ == "__main__":
    unittest.main()
