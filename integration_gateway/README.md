# Approved restaurant webhook gateway

This is an optional, separately hosted Delivery Hero restaurant-program inbox. It is not the laptop staff LAN server. No gateway has been deployed. Yemeksepeti must confirm this restaurant program and approve the public plugin URL before use.

Run Python 3.12+ behind a managed HTTPS reverse proxy, bound to loopback. Configure secrets through the host's secret manager, never source control:

| Environment variable | Value |
| --- | --- |
| `GATEWAY_DATABASE` | Absolute path on a durable private volume |
| `YS_REMOTE_ID` | Approved restaurant remoteId |
| `YS_PLATFORM_KEY` | Exact platform program key supplied by partner |
| `YS_WEBHOOK_SECRET` | Partner-provided webhook HS512 shared secret |
| `RELAY_TOKEN` | Independent random token of at least 32 characters |
| `PORT` | Internal loopback port, default 8080 |

Start `python integration_gateway/server.py`. Configure HTTPS proxy routes to the process and enforce a request size limit and reasonable timeouts. Preserve Authorization headers and configure logs to omit tokens and request bodies. Use a private service account, protected database directory, encrypted backups and a defined retention policy for customer data. The stdlib server is a reference service behind that proxy, not a public TLS hosting solution.

Partner routes: `POST /order/<remoteId>`, `PUT /remoteId/<remoteId>/remoteOrder/<stableId>/posOrderStatus`. JWT HS512 signature and middleware service claim are checked before storing. Acknowledgement follows durable SQLite commit; duplicate order deliveries get the same remote order ID. The desktop retrieves ordered events from `GET /v1/events?remoteId=...&after=...` over HTTPS with the independent relay bearer token. Configure that public base URL and relay token in native Settings. Only the configured restaurant can use this inbox; there is no cashier/payment administration API.

Tests: `python -m unittest discover -s integration_gateway -p "test_*.py" -v`. They cover signature rejection, account scope, expiry, durable replay, concurrent duplicates, relay authentication/cursors and stable order identity. Production onboarding and real platform callbacks have not been tested.
