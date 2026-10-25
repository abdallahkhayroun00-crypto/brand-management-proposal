# Nohut Falafel — Laptop Local Server / Personel QR

**Status:** Offline LAN prototype. The QR-coded mobile personnel panels and the PC management panel share the **same SQLite store on the laptop**, once the server is started. The standalone GitHub Pages demo remains separate. There is no real Yemeksepeti, Trendyol Go, card/POS, printer-driver or fiscal-device integration.

## Windows quick start

1. On the always-on restaurant laptop, get the full repository from GitHub → Code → Download ZIP, and extract the entire brand-management-proposal folder. Do not copy only pos-demo; it needs the nohut-menu assets too.
2. Install Python 3 for Windows, if not already installed. There is no pip or Node dependency.
3. Connect the laptop and worker phones to the **same trusted staff Wi-Fi** (not guest Wi-Fi). Make sure client/AP isolation is disabled.
4. Double-click **pos-demo/start-local-server.bat** on the laptop. Keep the black terminal window open. If Windows Firewall asks, enable **Private networks only**.
5. The laptop browser opens the management panel automatically at http://127.0.0.1:8787/pos-demo/?panel=yonetici. Navigate to **Yönetici Paneli → Personel Wi-Fi**.
6. The page reads the actual local IPv4/port from the laptop server and generates the employee QR offline. Workers scan the QR with their phones on the staff Wi-Fi.
7. Chrome/Safari opens the **Personel Paneli**. The worker selects their name (no password in the current concept) and records tables 1–5 or Gel-Al pickup orders. The laptop admin can view the orders on the next synchronization tick, about every 2.2 seconds. Payments remain on the laptop/admin panel.
8. Keep the laptop awake and server running. Press Ctrl+C to stop. SQLite orders persist at **pos-demo/local-data/nohut-pos.sqlite3**.

If the staff QR uses the wrong address on a laptop with a VPN/multiple network adapters, obtain the real Wi-Fi IPv4 from Windows ipconfig and start the server in the pos-demo folder with:
    py -3 local_server.py --advertise-ip 192.168.1.123
Replace 192.168.1.123 with YOUR local IPv4; it is not a universal address. For a different port:
    py -3 local_server.py --port 8790

## Shared records

Employees, five table accounts, dishes and additions, cancellation, pickup orders, product batches, notes, payments, split checks, demo print queue, cash-register sessions, and simulated platform state. The floorplan drag positions, menu browsing, active worker browser session and unfinished order drafts remain on their own device/browser.

## Data integrity

- GET /api/bootstrap returns server status, staff QR URL and the current SQLite state.
- GET /api/state returns the current record and its monotonically increasing revision.
- PUT /api/state accepts the full snapshot **only if the caller's baseVersion is current**. Two devices writing concurrently cannot silently overwrite the same revision: the stale write returns HTTP 409 and must be reviewed and retried.
- GET /api/health reports connectivity and revision.

When a device disconnects, the UI blocks new actions and prompts a reconnect/reload. UI changes may appear before a server write is confirmed; operators must recheck an order/payment after a conflict or disconnect. This is a test prototype, not a transaction-certified production system.

The first SQLite database is empty of fake orders (only the three example worker accounts are initialized). GitHub Pages demo seed orders are isolated and **never** imported silently into the live restaurant database.

## Security and limits

- By request there are no passwords yet. The staff/admin separation is visual **not secure authorization**. Anyone with local Wi-Fi access may reach the admin URL by changing the path/query. Use only a trusted/private staff Wi-Fi; do not put real customer or payment-card details in this prototype.
- HTTP over local Wi-Fi is not encrypted; do not expose it to the internet, set up port forwarding, public hostnames or tunnels.
- Before actual restaurant deployment, add employee login/roles, audit logging, stronger transactional writes, backup automation, TLS and device hardening.
- The real Yemeksepeti and Trendyol Go order APIs, bank/card POS, fiscal ÖKC, and automatic physical printer are not connected.
- The restaurant has **no own courier**. Direct telephone orders are pickup-only.
- To back up, stop the server first and copy the entire pos-demo/local-data folder. The web server blocks access to SQLite and Python source files.
- The locally bundled QRCode.js library includes its MIT license in pos-demo/vendor/LICENSE.qrcodejs.

## Test commands

    node pos-demo/tests/logic.test.cjs
    python3 -m unittest discover -s pos-demo/tests -p 'test_local_server.py' -v

GitHub Actions runs both suites. Automated checks do not replace a manual Wi-Fi trial with the actual laptop and employee phones.
