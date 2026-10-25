# Nohut Falafel — Flutter Desktop (Windows)

This is the **native Flutter desktop migration** of Nohut Falafel's GitHub Pages POS concept. It is a separate application, **not a WebView wrapper**.

## What is already in Flutter

- Native Windows Yönetici Paneli / dashboard (no first-run panel chooser).
- **Exactly 5 tables** in the interactive floor plan matching the restaurant sketch: 2 and 1 near KAPI, long tables 3 and 4, small table 5 on the left; draggable layout.
- Local Masa, counter Gel-Al and phone-to-pickup orders, kitchen batches and added products.
- Source-derived product menu from `../nohut-menu/menu-data.js`: currently 51 products, 44 with configured prices. Products without prices remain unavailable until configured.
- PC cashier recording of Nakit or Kart and partial payments, even multi-guest splitting in kuruş. Card entries do **not** send payment to a real bank terminal.
- Five-table occupancy, staff active toggles, print job queue, basic reports, read-only platform order listings.
- Embedded Dart LAN HTTP server on port **8787** — no separate Python server needed.
- **SQLite on the laptop**, persisted by default to `%APPDATA%\NohutFalafel\nohut-pos.sqlite3`.
- Staff QR screen detects local private IPv4 addresses, lets you select the correct Wi-Fi IP and displays a scannable QR.
- Staff phones continue to use the **existing Chrome/Safari employee order UI**, bundled in the Windows release. The phone UI talks to the Flutter-embedded server's `/api/bootstrap`, `/api/state` and `/api/health`. All orders go to the same SQLite data.
- Optimistic version protection to reject stale writes instead of silently overwriting another device's change.

## What is NOT converted or live yet

The previous HTML concept is extensive; this is **the first native Windows MVP**, not a claim of 1:1 feature parity. In particular, cash shift opening/closing, full product-level guest allocation, refunds, full platform menu/store/claim/review/invoice management, detailed CSV reports, auto thermal printing, a fiscal ÖKC and bank POS integration are not yet fully ported/connected in native Flutter. **Yemeksepeti and Trendyol Go APIs are simulated only.** Platform couriers handle delivery; the restaurant has no own courier.

Phone staff ordering intentionally remains HTML in Chrome for now; only the **manager's Windows application** is Flutter-native. Flutter does not run on GitHub Pages as a Windows EXE: GitHub stores source and Actions builds a Windows release folder.

## Download Windows app from GitHub

Open **Actions → Build Flutter Windows POS** in this repository, choose a successful run, and download the `NohutFalafel-Windows-Flutter` artifact. Extract the **entire ZIP**, keep its DLL / data / `site` folders next to the EXE, and double-click `nohut_falafel_desktop.exe`.

**You must extract the ZIP.** A Windows Flutter desktop release is a **folder** containing the EXE and required DLLs, not a standalone EXE.

If no successful run is available, use the build instructions below or check the action logs.

## Build on your own Windows laptop

Prerequisites: Flutter stable, Dart supported by Flutter stable, Visual Studio with Desktop development with C++ installed, Windows 10/11.

```powershell
cd flutter_desktop
flutter create --platforms=windows --project-name=nohut_falafel_desktop .
flutter pub get
flutter test
flutter build windows --release
```

When building manually, copy the web staff files into the Release folder:
- `Release/site/pos-demo/index.html`
- `Release/site/pos-demo/split-bill.html`
- `Release/site/pos-demo/vendor/qrcode.min.js`
- `Release/site/nohut-menu/` (the full existing website assets/menu).

GitHub Actions packages them automatically.

## Connect worker phones

1. Run Flutter on the **laptop**. Its local server starts automatically.
2. Ensure PC and phones are on the same **private staff Wi-Fi**. Approve Windows Firewall **Private network** access if prompted. Don't enable public-network firewall access.
3. Go to **Personel Wi-Fi** in the Flutter app. If multiple IPs are shown, select the correct Wi-Fi IPv4.
4. Scan QR with a staff phone's Chrome/Safari. The URL has this form: `http://<LAPTOP_LAN_IP>:8787/pos-demo/?panel=personel`.
5. On the phone, choose worker's name, take a Masa 1–5 or Gel-Al order. The native Flutter admin and phone load/modify the same SQLite state.
6. Keep laptop awake and Flutter open. Stop the app to shut down the LAN server.

**There are no passwords/roles enforced on the HTTP endpoint in this prototype.** The UI separation is **not security**. Do not publish the local server on the Internet, forward port 8787, expose it on guest Wi-Fi, or enter sensitive customer/payment-card details. To operate real transactions, add authentication, authorization, encrypted links, backups, transaction/audit trails and official payment/fiscal integrations.

## Existing SQLite data

The older Python prototype stores a database at `pos-demo/local-data/nohut-pos.sqlite3`. Flutter creates a new database in Windows AppData by default. It does **not** automatically import the old demo into Flutter; back up existing restaurant data before any later migration.

## Tests and source of truth

```powershell
cd flutter_desktop
flutter analyze
flutter test
```

The native Windows build is verified in GitHub Actions. The previous HTML regression suite remains active and unchanged. Flutter's `assets/menu.json` is generated from the current QR menu source; refresh it when menu prices change.

## Safety constraints

- The restaurant has **no own delivery**. Phone orders are Gel-Al only; deliveries belong to Yemeksepeti / Trendyol Go.
- PC always acts as **Kasa (PC)**, staff selects a name on Chrome phone once.
- No duplicate KOPYA FİŞ path.
- Only five physical tables.
- No payment terminal automation until the actual device model and integration are available.
