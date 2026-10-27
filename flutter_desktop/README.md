# Nohut Falafel — native Flutter for Windows

Native Yönetici Paneli / Kasa (PC), not a WebView. The original HTML demonstration and production QR menu remain in their existing folders.

Read [FEATURE_PARITY.md](FEATURE_PARITY.md) for the feature-by-feature audit, code/test mappings, synchronization decisions and remaining device acceptance checks. It separates native workflows, deliberate simulations and unverified physical connections.

## Windows download

Open the successful **Build Flutter Windows POS** Actions run for this branch/PR and download **NohutFalafel-Windows-Flutter**. Extract the entire ZIP before starting `nohut_falafel_desktop.exe`. Keep all DLLs and `data` beside the EXE. `build-manifest.json` identifies the source revision and SHA-256 of packaged files. An artifact being uploaded is not proof of physical-device integration.

The release includes the employee page and menu inside Flutter assets. There is no separate `site` folder or Python server to install. The PC opens the manager directly; the prototype has no role chooser or passwords.

See [UI_DESIGN.md](UI_DESIGN.md) for the Chrome-inspired visual revision, unified staff destination and shared phone floor plan.

## Worker phones

1. Keep the Windows app running and the laptop awake, on trusted private staff Wi-Fi.
2. Open **Personel & QR**. Its shared Wi-Fi settings section selects the actual laptop Wi-Fi IPv4.
3. In **Personel & QR → Telefon Bağlantıları**, select the worker and press **Telefon Bağla · QR Oluştur**. Scan the large inline QR in Chrome. Activate the device once within ten minutes. The URL uses the same laptop server, `http://<LAPTOP_IP>:8787/personel`. Later visits retain the worker’s device session; no name chooser or password.
4. Choose a table on the shared floor plan (or Gel-Al), open a menu section such as Dürümler / Porsiyonlar / İçecekler and tap product cards. Review quantities and optional notes in Sepet, then send. Telephone orders are pickup-only; occupied-table orders become additional batches.
5. Wait for the confirmed SQLite order number. On a lost response, use **Aynı İsteği Yeniden Dene**. The persisted request ID prevents double submission. On a revision conflict, fetch current data, inspect the retained cart and resubmit.

Payments and management are native PC workflows. The LAN server does not serve the old manager HTML and rejects snapshot PUT requests. Device sessions use HttpOnly/SameSite cookies, server-side hashed tokens, CSRF checks, expiry and immediate manager revocation. LAN HTTP remains unencrypted; use trusted private Wi-Fi. Keep it off guest Wi-Fi/public Internet. A real two-phone Wi-Fi test is still required. Windows Firewall private-network permission must be handled on the actual laptop. Do not run the older Python server on port 8787 at the same time.

## Native workflows

- Exactly five interactive tables with saved draggable floor positions.
- Local catalog/category selection, notes/removals, added batches, quantity/full cancellation with correction tickets, pickup details and independent service completion.
- Cash/card/partial/mixed entries, change, partial/full refunds, product-level guest shares, equal cent-conserving splits and mapping earlier payments to guests.
- Opening/closing cash sessions, counted variance, cash in/out and historical refund dates.
- Staff creation/editing/activation, local price configuration, filtered history and collection/product/staff reports, CSV exports, consistent SQLite backups.
- Table floor and selected check side by side; searchable order list with a fixed check summary/actions and separate product, guest split, receipt/refund and history tabs.
- Single kitchen printer queue with pending/error/completed filters, selected-batch preview and explicit simulated success/failure/retry; informational bill summary.
- Explicit platform simulation tabs for orders, acceptance/status/cancellation, store hours, catalog/mapping/prices, claims, reviews, invoice links and sync request log; settlements under Reports, configuration under Settings.

**No restaurant account, bank POS, physical printer or fiscal ÖKC has been connected or verified.** API adapters and encrypted credential settings are implemented, with explicit capability gates. See [INTEGRATIONS.md](INTEGRATIONS.md) for the exact supported contracts and outstanding live requirements. Trendyol Go order polling is implemented; its Meal accept/ready/reject mutations remain blocked pending the current official contract. Yemeksepeti restaurant callbacks require an approved account and an HTTPS webhook gateway; generic Delivery Hero support is not proof of Yemeksepeti account access. Card and platform entries are prototypes. Courier delivery and platform collections remain with the platforms; the restaurant has no courier workflow. Yemeksepeti unverified management capabilities stay gated. Invoice-link submission does not generate a fiscal invoice. The example 15% commission is not an accounting rate.

## Storage and concurrency

Default database: `%APPDATA%\NohutFalafel\nohut-pos.sqlite3`. `NOHUT_POS_DATABASE` can select a separate test database before launch. The app never silently imports the old Python database or fake HTML seed orders.

SQLite uses WAL, FULL synchronous commits, a busy timeout and immediate writer transactions. PC writes compare revisions. Phones submit validated order commands rather than replacing the database. Request receipts and orders commit atomically, so retries survive restarts. The state remains a versioned JSON aggregate in SQLite, with explicit domain validation and typed report/check projections; it is not a certified accounting ledger.

Use **Ayarlar → Tutarlı SQLite Yedeği Oluştur** for a consistent single-file backup while WAL is active. Keep a backup before replacing any existing database. Restoring old data is a deliberate offline operation, not an automatic merge.

## Build and test on Windows

Prerequisites: Flutter stable and Visual Studio C++ Desktop development tools. Native runner source is committed; do not regenerate it over customizations.

```powershell
cd flutter_desktop
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build windows --release
```

At repository root:

```powershell
node pos-demo/tests/logic.test.cjs
python -m unittest discover -s pos-demo/tests -p test_local_server.py -v
python -m unittest discover -s integration_gateway -p "test_*.py" -v
```

GitHub Actions runs strict Flutter analysis, domain/SQLite/HTTP/widget tests, the preserved HTML regressions and a Windows release build, then uploads the whole release folder. Tests use isolated temporary databases. They do not establish real phone, printer, fiscal or platform readiness. Keep the HTML demo until the acceptance checks in the parity matrix are completed.

Browser order-entry checks (also run in Actions):

```powershell
cd ui-tests
npm ci --ignore-scripts
npx playwright install chromium
npm test
```

## 0.7.0 — branded tickets and invoice documents

See [PRINTING_AND_INVOICES.md](PRINTING_AND_INVOICES.md) for the new native **Fiş & Fatura** destination, branded immutable preparation batches, 80 mm PDF exports, one Windows USB driver, uncertain-output reconciliation and externally issued invoice registration. The Trendyol Meal invoice-link adapter is implemented and mock-tested; no credentials or live account test are available. Yemeksepeti invoice upload and fiscal issuance remain unavailable. Physical printer output is unverified. This supersedes earlier descriptions of all printing and invoice-link operations as simulation-only. The original HTML demo remains unchanged.


## v0.7.1 — local receipt updates on the v0.7 branch

This update retains v0.7 staff sessions/QR, integrations, original platform receipts, invoice workflows, secure storage and transactional PDF print service.

- Local Nohut PDF and preview use the campaign logo. XP-237B profile: 58 mm media, 48 mm content area, 203 DPI receipt mode. Choose the installed Windows queue in Settings and configure its driver for 58 mm continuous receipt paper. Windows printer settings are respected during direct printing; browser/PDF viewer dialog choices cannot be set by the app.
- Automatic local kitchen printing is on by default once the Windows queue is selected. Only newly committed Masa / Gel-Al and addition/correction jobs are selected; platform-original printing retains the existing v0.7 workflow. Failed, cancelled and uncertain sends never auto-retry. Old jobs remain available for deliberate manual handling.
- New display receipt numbers start at #1 for each Istanbul calendar day. Stable IDs, payment references and existing frozen ticket snapshots remain intact.
- Reports → Yoğunluk shows 24 Istanbul-hour arrival counts and CSV, with source/staff/date filters. Added products and payments do not count as new arrivals. Cancelled and unaccepted platform orders are excluded.
- Seven drinks without a price are 45 TL in the catalog and QR data; existing non-empty prices and historical order prices are preserved.

Physical XP-237B output acceptance is still required. Built from `codex/staff-sessions-platform-integrations`, version 0.7.1+8.
