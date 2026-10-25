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
- Single kitchen printer queue and native previews with explicit simulated success/failure; informational bill summary.
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
