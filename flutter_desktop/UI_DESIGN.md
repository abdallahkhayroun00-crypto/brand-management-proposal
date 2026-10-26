# Native and staff UI revision — 26 October 2026

Version 0.3.0 follows the existing `pos-demo/index.html` visual concept, including the owner's Chrome screenshot reference. The HTML prototype is unchanged. Flutter remains a native Windows application.

| Reference / feedback | Revision |
| --- | --- |
| Original Chrome brand | Reuses the original logo asset, pine `#183b2c`, cream `#f6f6f2`, muted green, white bordered cards, rounded buttons, grouped daily/business navigation and sidebar order shortcut |
| Empty-looking native online orders page | Separate Trendyol Go and Yemeksepeti panels; order identity/status cards, clear empty states and compact filters. Demo generators are collapsed. Source selection remains for platform management tabs |
| Duplicate staff / Wi-Fi navigation | One **Personel & QR** destination. Header QR shortcut. Staff administration is a tab inside it; shared network settings are a subordinate section |
| QR hidden too far down | Personnel selector and primary pairing action at the top; large inline 300px QR, no separate show-dialog step. Pairing action checked above the fold at 1280×720 and 1600×900 |
| Ten minutes confused with shift duration | Plain explanation beside QR: ten minutes only to enroll the device once; the enrolled session persists 30 days, including 10+ hour shifts, unless revoked. Expiration/security behavior unchanged |
| Phone tables differ from PC | One shared normalized geometry source for exactly five tables. Phone receives validated saved floor positions, live occupancy, door and chair layout. Large table shortcuts support smaller touch screens |
| Basic phone form | Same brand, separate Masalar / Sipariş Al / Siparişler views, product quantity steppers, explicit occupied-table additions, clear ready actions, fixed bottom navigation and session details |

Native widgets checked at 1600×900 and 1280×720, including both platform columns and the pairing action's visibility. Browser checks at 320, 390 and 768px exercise table occupancy, add-to-table selection, quantity controls, submission and absence of staff accept/reject controls, with no horizontal overflow. Browser visual checks use a synthetic local fixture; they are not restaurant Wi-Fi or live platform acceptance tests. Native review uses a separate QA database.

All permission, enrollment, payment and integration boundaries described in [INTEGRATIONS.md](INTEGRATIONS.md) remain in force. The newly exposed phone floor projection contains geometry and kitchen data, not payment administration. Saved layout parity and response allowlist are covered by tests.

## Faster ordering — version 0.4.0

Phone ordering now follows **Masa → Ürünler → Sepet → Gönder**. Sections use the real menu categories: Dürümler, Porsiyonlar and İçecekler first, then the other available sections. Product cards have one add action. Quantities, removals and optional notes are edited in the review basket. A persistent basket button shows count and total. The review total and send/retry action stay fixed above the bottom navigation, so long orders do not require scrolling to submit. Search works across sections and accepts Turkish names typed without accents. Changing destination with items present requires explicit confirmation. Uncertain submissions lock the draft and retry the same stored request.

Native PC ordering uses clickable product cards, category navigation, search and a persistent side basket. Quantities and notes update the running total; the selected table/source stays visible and Ctrl+Enter saves only a valid order. Removing the last unit clears its customization. Dashboard metrics navigate directly to orders, tables, cashier and printer. Turkish currency display uses decimal commas.

The native order-entry test at 1280×720 moves between categories/search without losing the basket, changes quantities and verifies the saved table and exact SQLite total. `ui-tests` runs browser checks at 320, 390 and 768px for categories, global search, notes/removals, unavailable prices and an interrupted submission followed by an identical retry. These checks also run in Windows Actions.

## Order and printer workspaces — version 0.5.0

The table floor fits the available window height. Selecting an occupied table opens its check beside the floor. All five tables remain available without scrolling the whole page. All Orders uses a searchable list beside the selected check, source chips, a status selector and date/personnel filters. Incoming orders do not replace the check being edited.

The selected check shows one product list, a persistent total/paid/balance summary and payment/addition/service actions. Products, guest splits, receipts/refunds and history have separate tabs. Select a product for cancellation. In Hesap Böl, select a guest and product, assign the remaining product amount or enter a specific share, then collect that guest's balance. Equal splitting and earlier-payment mappings retain their existing money guards. Platform collections remain outside the local till.

The printer workspace pairs a searchable queue with an embedded kitchen receipt preview. Pending, failed, completed and all filters show counts. Failed attempts expose an explicitly simulated retry; completed jobs cannot be replayed. No physical printer is connected. Tests exercise product allocation, guest-payment selection, partial refunds, queue error/retry filtering and prevention of completed replay, plus bounded table/order/printer layouts at 1280×720 and 1600×900.

On Windows, `flutter test tool/capture_workspace_previews_test.dart` renders the native widgets with an isolated synthetic database, Windows fonts and the LAN server disabled. It writes four PNG previews to `%TEMP%/nohut-workspace-previews` (override with `NOHUT_CAPTURE_DIR`). These are widget renders, not proof of real printer, restaurant Wi-Fi or platform connectivity.
