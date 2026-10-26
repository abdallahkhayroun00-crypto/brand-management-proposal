# Integration and staff update — 25 October 2026

Version 0.2.0. Previous migration published by merging PR #1 into main at `a5f4c91b746fa20d5b7fb38aacdcca84bd452de1`. HTML demonstration remains intact. The owner has no platform credentials yet. No live restaurant connection, platform acceptance test, printer or terminal test has been performed.

## Feature parity addition

This table supersedes the earlier name-selection and unauthenticated staff descriptions in the original parity audit.

| Requirement | Implementation | Verification / remaining boundary |
| --- | --- | --- |
| Per-worker enrollment QR | Personel → QR Yönetimi; single use, ten-minute expiry, SHA-256 token hash in SQLite | Staff security tests; physical phone scan still required |
| Persistent personal device session | HttpOnly SameSite cookie; 30-day expiry, worker identity from server; no passwords or name chooser | Restart, expiry, inactive-worker and spoofing tests |
| Multiple devices / revoke | Device list, individual revoke, worker access off, QR rotation revokes prior QR and all sessions | Automated tests; shared laptop LAN server throughout |
| Phone scoped operations | View projected kitchen orders/menu, create/add local orders, ready and retry ready | Unauthorized/CSRF/admin/payment/state-PUT rejection tests |
| PC-only platform acceptance/rejection | Native accept/reject commands with PC actor; phone cannot invoke them | Domain and HTTP permission tests; account capability gates apply |
| Ready and audit | Staff actor/time, local kitchen readiness separate from platform acknowledgement; durable SQLite outbox | Success/error/unknown tests; source confirmations required before claiming platform success |
| Safe retries | Atomic command receipts; semantic action deduplication; 429 delay; timeout/crash becomes Belirsiz with no automatic replay | SQLite, transport and restart tests. Unknown results require platform-side reconciliation; no blind retry button |
| Added local batches after readiness | Return to preparation; each batch generation has a distinct readiness key | Additional-batch regression coverage |
| API settings | Ayarlar → Platform API Bağlantıları; off/stage/live; account/capability fields; authentication-only test | Windows encrypted credential storage; no credentials in POS snapshot, staff response, CSV or source. Secure storage failure never falls back to plaintext |
| Trendyol Go by Uber Eats order intake | Authenticated Meal package polling, pagination, overlapping modification window, atomic cursor/import; supplier/store checks | Mock contract tests. **Meal accept/ready/reject writes blocked** until current platform contract verified; Grocery endpoints are not substituted |
| Yemeksepeti restaurant intake | Delivery Hero restaurant-contract adapter and authenticated durable HTTPS gateway inbox; source callback capability checks | Mock tests only. Restaurant onboarding must confirm this program, platformKey, restaurant ID, direct-flow and preparation-completed permissions |
| Management APIs | Existing store/menu/claims/reviews/invoice/finance workflows remain explicitly DEMO | No live writes or accounting claims; real orders cannot be changed through legacy simulation jobs |

## Credentials and operations

Configure each provider in native Settings. Blank secret fields retain saved values. Use stage first and obtain official approval before enabling live. Secrets are stored using `flutter_secure_storage` on Windows (encrypted local storage with Credential Manager key protection); they are not stored in the shared POS state. Protect Windows user access and backups: the database contains customer orders and session hashes. Raw platform errors are not surfaced because providers can echo credentials.

Trendyol Go requires supplierId, storeId, API key/secret and executor email. This is the Turkish restaurant partner contract; a global Uber Eats OAuth client is not a substitute. Polling success means one authorized read, not complete integration. Unknown collection state remains pending: payment type alone does not prove collection.

Yemeksepeti requires official restaurant-program username/password, chainCode, remoteId, platformKey, callback permissions and an approved public HTTPS plugin URL. The adapter uses only callback URLs provided with the order, matching the configured official origin and exact order path. Ready uses `orderPreparedUrl` and POST `preparation-completed`, conditional on account permission; it never substitutes pickup/delivery status. Acceptance uses the provider's expected pickup timestamp. Platform delivery remains platform-owned; vendor delivery is rejected.

See [gateway deployment](../integration_gateway/README.md). No hosting, account registration or firewall/public endpoint deployment has been performed. The staff LAN server must never become the public webhook server.

## Primary contract references

Reviewed 25 October 2026. Exact restaurant-account capabilities still require onboarding confirmation.

- [Trendyol authorization](https://developers.tgoapps.com/en/docs/authorization): partner Basic authentication and required headers.
- [Trendyol Meal package polling](https://developers.tgoapps.com/docs/trendyol-go-yemek-entegrasyonu/siparis-entegrasyonu/ymk-siparis-paketlerini.cekme) and [package states](https://developers.tgoapps.com/docs/trendyol-go-yemek-entegrasyonu/siparis-entegrasyonu/ymk-paket-modelleri). Current direct documentation routes sometimes resolve to the overview; current Meal mutation details could not be verified, so writes remain disabled.
- [Delivery Hero restaurant POS integration](https://developers.deliveryhero.com/documentation/pos.html): approved direct/indirect flows.
- [Restaurant middleware API](https://integration-middleware.stg.restaurant-partners.com/apidocs/pos-middleware-api), official schemas `middlewareExternalApi.yaml`, `pluginApi.yaml`, `pluginOrder.yaml`, `shared-components.yaml` under the same `apidocs` directory: login, source order payload, callback paths, HS512 webhook authentication and status notifications.
- [Windows secret storage](https://pub.dev/packages/flutter_secure_storage).

## Acceptance still required

Two real Chrome phones on private Wi-Fi, Windows restart/revocation, API stage accounts and partner callback certification, gateway TLS/backup/access controls, source status and payment reconciliation, and all bank/printer/fiscal device tests remain outstanding. API tests here use fake credentials and transports. A passing release build does not establish a live external connection.

## 0.7.0 — branded tickets and invoice documents

See [PRINTING_AND_INVOICES.md](PRINTING_AND_INVOICES.md) for the new native **Fiş & Fatura** destination, branded immutable preparation batches, 80 mm PDF exports, one Windows USB driver, uncertain-output reconciliation and externally issued invoice registration. The Trendyol Meal invoice-link adapter is implemented and mock-tested; no credentials or live account test are available. Yemeksepeti invoice upload and fiscal issuance remain unavailable. Physical printer output is unverified. This supersedes earlier descriptions of all printing and invoice-link operations as simulation-only. The original HTML demo remains unchanged.
