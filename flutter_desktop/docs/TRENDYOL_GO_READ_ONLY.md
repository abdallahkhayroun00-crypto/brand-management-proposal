# Trendyol Go — Read-only integration (Nohut Falafel)

## Scope

This integration retrieves platform restaurant packages using **GET only**. It never accepts, rejects, cancels, updates status, sets prices, or changes any remote menu. Restaurant staff must manage orders through the official Trendyol Go Partner interface.

## Configuration on the restaurant Windows PC

1. Open **Ayarlar → Trendyol Go**.
2. Paste `Satıcı ID (Cari ID)`, `API Key`, `API Secret`, and the authorized integration email (required by the `x-executor-user` header).
3. Click **Güvenli Kaydet**. Once saved, blank API key/secret fields mean “retain already saved values.”
4. Click **Bağlantıyı Test Et / Güncelle** and read the connection status.

Secrets are stored separately from the SQLite database, encrypted using Windows Data Protection API for the currently signed-in Windows user, in `%APPDATA%\NohutFalafel\trendyol-go-credentials.dpapi`. Do not copy this file to GitHub or to another PC/account expecting it to decrypt. Replacing the app binary does not replace this file; deleting the user's AppData or changing Windows user credentials/account can affect recovery. No credentials are sent to employee phones.

## Data flow and screens

- **Genel Bakış:** counts valid incoming packages and, separately, delivered packages and their platform order totals. Platform totals do not enter the restaurant Nakit/Kart drawer figures.
- **Siparişler:** existing local orders plus a read-only Trendyol Go list, filtered by the platform.
- **Online Siparişler:** normalized packages (status, lines, unit selling prices, customer notes, platform total, payment labels) and a manual refresh.
- **Personel Paneli:** same read-only data in the Siparişler tab and dedicated Trendyol Go filter; API keys and customer contact/address are never provided to this page.

The latest normalized external packages live in separate SQLite JSON fields `trendyolGoOrders` and `tgoSyncInfo` (not the editable local `orders` list). Distinct external packages are deduplicated by supplier/store/order number. Platform product prices are never overwritten by the shop's QR menu or local POS price table.

## Unified daily POS order numbering

**One sequence** is used for all local and Trendyol Go tickets on the restaurant PC, regardless of channel. For example, `#0001 Masa`, `#0002 Trendyol Go`, `#0003 Gel-Al`. The number resets for new orders every Turkish calendar day at midnight (`UTC+03:00`), with the old orders retaining their numbers and dates. SQLite internal IDs and original external `orderNumber` remain unchanged.

The sequence represents the **order in which the POS first records the tickets for that business day**. Online orders fetched late or in the initial seven-day historical backfill receive the next available number of their original Turkish business day; the app **never renumbers an already issued local ticket** simply to reorder historic arrivals. Repeated API sync/status updates preserve the platform ticket number. The manager, Online Siparişler and employee screens show the Nohut number prominently and original Trendyol reference separately.

## Technical behavior and limitations

- Endpoint: `GET https://api.tgoapis.com/integrator/order/meal/suppliers/{supplierid}/packages`
- Basic API authentication, `User-Agent`, `x-agentname`, and `x-executor-user` sent on requests.
- Initial historical range: seven days, then overlapping 24-hour updates; auto-poll every 60 seconds while the Windows application is running.
- Maximum 10 pages of 50 packages per sync; if the limit is hit, sync fails visibly instead of silently storing incomplete results.
- External API operation requires access enabled for this restaurant's credentials; none were available during development. **Live auth, network, real response schema, and Windows DPAPI are not verified yet.** Verify on the restaurant PC before relying on production reporting.
- This work does not print remote orders, trigger financial payments, synchronize platform menu, or change the remote package.
- Do not merge until CI passes and a Windows smoke test is performed; earlier simulated Online Siparişler source remains in history but is not used for the live screen.

## Documentation

- https://developers.tgoapps.com/docs/authorization
- https://developers.tgoapps.com/docs/trendyol-go-yemek-entegrasyonu/siparis-entegrasyonu/ymk-siparis-paketlerini.cekme
