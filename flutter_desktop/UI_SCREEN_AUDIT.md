# Whole-app UI review — 0.6.0

This review covers the actual native manager destinations and the staff Chrome interface, using the existing HTML visual concept: pine sidebar, cream background, white bordered panels, consistent rounded controls, selected states and direct operational actions. It does not declare full business/API parity or pixel-identical HTML copying. The original `pos-demo` files are untouched.

| Destination | Layout and interaction reviewed | Evidence |
| --- | --- | --- |
| Genel Bakış | Metrics navigate to the relevant workspace; source rankings drill into orders | Navigation test, populated native render |
| Masalar | Exactly five tables, saved geometry, selected check beside the floor, payment action in viewport | Both Windows test sizes, native render |
| Tüm Siparişler | Search/status/source/date/staff filters, one product list, guest allocation, receipt/refund/history tabs | Existing composer/split/refund tests, native renders |
| Online Siparişler | Both platform order columns; persistent tabs and selected-platform control; store/menu/claims/reviews/invoices/sync panels; separate actor/result/retry log | Seven-tab navigation at both sizes, native renders; existing platform/outbox/security tests |
| Kasa & Ödemeler | Open-order drill-through; daily opening, movements, counted close; historical expected/count/variance | Four tabs at both sizes; UI test opens 100 TRY, adds 50, closes at 149.50 and verifies -0.50 variance |
| Yazdırma Kuyruğu | Queue filters, selected batch preview, simulation-only error/retry, completed replay blocked | Existing printer test and native render |
| Personel & QR | One shared LAN server; personal pairing and revocation; searchable active/inactive directory and controlled role selection | Both staff tabs at both sizes; existing session/permission tests; native renders |
| Raporlar | Summary rankings, collections, products, staff and demo finance; date/source/staff filters; method/refund filters; CSV and order drill-through | All five tabs at both sizes; UI test compares refund-filtered CSV, date filtering and product order selection |
| Ayarlar | General, local menu editor, secure platform setup, printer, backup; explicit save feedback | All five sections at both sizes; UI test verifies saved price, unchanged old check, secret exclusion from SQLite and readable backup |
| Phone Masalar | Same five-table geometry, busy table additions and shared PC server | Browser checks and renders at 320/390/768px; geometry/security tests |
| Phone Sipariş Al / Sepet | Categories, global search, persistent cart, quantity/removal/notes, visible send, exact retry after uncertain response | Browser interaction checks and renders at all three widths |
| Phone Siparişler | Search/source filters, visible local ready action, no ready before platform acceptance, no cashier/accept/reject buttons | Browser checks and renders at all three widths |

## Verification limits

- Native layout/navigation checks use 1280×720 and 1600×900. PNGs are native-widget renders with synthetic data and Windows fonts; the QA LAN server is disabled.
- Browser checks use a synthetic local HTTP fixture. They do not prove actual restaurant Wi-Fi, multiple physical phones or printer output.
- Platform management and finance remain explicitly DEMO. API credentials are absent. Current capability gates, PC-only acceptance/payment, secure key storage and command-only staff LAN access remain enforced.
- Bank POS, fiscal ÖKC and physical printing are not connected. A CSV or app record is not a certified accounting/fiscal document.
- Tests cover representative action flows, not every possible data volume, Windows scale factor or visual preference. The screens remain reviewable without claiming that all live integrations or migration gaps are complete.

## 0.7.0 — branded tickets and invoice documents

See [PRINTING_AND_INVOICES.md](PRINTING_AND_INVOICES.md) for the new native **Fiş & Fatura** destination, branded immutable preparation batches, 80 mm PDF exports, one Windows USB driver, uncertain-output reconciliation and externally issued invoice registration. The Trendyol Meal invoice-link adapter is implemented and mock-tested; no credentials or live account test are available. Yemeksepeti invoice upload and fiscal issuance remain unavailable. Physical printer output is unverified. This supersedes earlier descriptions of all printing and invoice-link operations as simulation-only. The original HTML demo remains unchanged.
