# HTML → native Windows feature parity audit

**25 October 2026 security/API update:** see [INTEGRATIONS.md](INTEGRATIONS.md) for the new parity matrix, secure per-worker QR sessions and exact platform capability boundaries. This historical baseline is superseded on those points.

Audit baseline: repository `main` commit `13d2518acfd47e8f6700879dada9bab90fd13274`, 25 October 2026.

Sources read: `pos-demo/index.html` (including its extended platform and cash-book functions), `pos-demo/split-bill.html`, `pos-demo/PLATFORM_CONCEPT.md`, `pos-demo/LOCAL_SERVER_README.md`, and the original six Flutter library files and tests. The HTML demo and QR menu are retained. This document distinguishes implemented prototype workflows from real integrations and from physical-device acceptance.

**N** = native Flutter/Dart workflow, with automated coverage for the named domain or screen. **S** = explicit local simulation, never a connected external integration. **D** = actual device/account verification still required. These statuses do not assert production or fiscal certification. Tests verify behavior, not identical pixel layout.

| Feature / source contract | Before this change | Current implementation | Evidence / boundary |
| --- | --- | --- | --- |
| PC opens Yönetici Paneli/Kasa (PC), no role chooser/password | Native MVP | N: direct manager startup; all PC orders use Kasa (PC) | Manager navigation widget tests; prototype has no login |
| Exactly 5 tables, matching KAPI sketch | Already native | N: existing geometry, occupancy, empty-table order, occupied-table details; draggable positions saved in SQLite | `floor_plan.dart`, `activeTable`, range/duplicate-table tests |
| Local table orders | Basic | N: catalog prices, batches, current total and receivable | Core order tests; no own courier source accepted |
| Counter / telephone orders pickup-only | Basic | N: Gel-Al and Telefon, optional customer/name/phone/pickup time | Composer, staff command, pickup lifecycle tests |
| Menu categories, unavailable prices | Bundled catalog | N: categories, quantity controls, unavailable-price disabling; native local price editing, phone menu refresh | `localMenu` persisted separately from platform menu; source website unchanged |
| Product notes / removed ingredients | Missing PC controls | N: tap product to edit note/removals; per-batch snapshots preserve history | Composer + browser page; staff server validates fields |
| Additional products | Basic | N: new kitchen batch, preserving older price/name/note | `addOrderBatch`, command merge tests |
| Product quantity cancellations | Missing | N: quantity/reason checks, guest-allocation and overpayment safeguards | `cancelProduct`, cancellation tests; separate correction kitchen job |
| Whole local order cancellation | Missing | N: first refund/unallocate, cancel remaining items, release table | `cancelLocalOrder`; retained event/void history |
| Local service lifecycle | Incomplete | N: preparing → ready → delivered, independent of payment | `setLocalService`; pickup closure requires paid + delivered |
| Table closure / reuse | Basic | N: paid closure releases table; historical refunds never reoccupy a reused table | Reuse/refund test |
| Cash / card / mixed / partial payments | Basic | N: repeated partial entries, received cash and change, current-balance revalidation | Payment and guest tests; card recording is S/manual, no bank request |
| Partial/full refund of a receipt | Missing | N: retained refund event with amount/reason/date/operator; rejects excess | `refundPayment`, cash/report tests; no real terminal refund |
| Equal guest split including odd kuruş | UI-only algorithm | N: shared `splitEqually`, 2–10 people, exact conservation | Equal split test: 10001 → 3334 + 3334 + 3333 |
| Per-product guest allocation | Missing | N: arbitrary cent share per stable batch:index, edit/return shares, guest add/rename/remove | `allocateProduct`, `changeGuest`, guest/payment safeguards |
| Payments before splitting | Missing | N: map an earlier general receipt across guest shares without collecting twice | `assignExistingPayment`; unmatched receipts block further guest payment |
| Guest mixed/partial checkout | Partial | N: per-guest cash/card payments and refunds; rechecks current guest balance on commit | Guest domain tests; allocation reductions cannot undercut received amount |
| Cash opening float | Missing | N: one open session, opening operator/time | `CashPanel`, cash tests |
| Manual cash in/out | Missing | N: signed movement, reason, nonnegative available cash | `moveCash`; card/platform excluded |
| Cash closing/count/variance | Missing | N: counted vs expected, frozen closed values, later-shift refund date | Cash test; no fiscal Z-report |
| Order history filters | Source-only | N: source, ID/table/customer/product text, staff, status, Istanbul date range | Native history; no 100-row truncation |
| Collection/refund reports | All-time totals | N: source/method/event/staff/date filters and precise event amounts | `LedgerEntry`, `ledger`, report screen tests |
| Product/staff sales report | Missing | N: retained batch staff, sold quantity, source price and timestamp, CSV | `SaleEntry`, `sales`; platform item gross can differ from discounted net |
| CSV export | Missing | N: local output path, quoted cells, UTF-8 BOM, integer kuruş, formula protection | CSV domain test; refuses to overwrite existing files |
| Staff administration | Active switch only | N: add/edit/name/role/active, stable IDs, duplicate-name checks | `saveEmployee` tests; historical batch names retained |
| One kitchen printer queue | Mark-only | N/S: initial/addition/correction jobs, preview, explicit success/failure simulation and retry counts | `PrinterPanel`, `receiptText`; no physical printer configured |
| Bill summary | Missing | N: native selectable paid/due/item/payment summary | `billText`; informational, not a fiscal receipt |
| No KOPYA FİŞ | No explicit copy | N: no copy-print action or duplicate receipt generation | Queue jobs uniquely identified by order/batch |
| Windows printer settings | Read-only text | N/S: one printer name, simulation mode persisted | `SettingsPanel`; selecting a name does not connect a device |
| Platform order snapshots | Read-only listing | N/S: source/package IDs, source prices/modifiers, discount, ETA/PIN/call placeholders, payment label, pickup/courier distinction | `platformFixture`, `importPlatform`; DEMO values visibly labelled |
| Platform import/replay | Missing native | N/S: package identity + monotonic source revision; duplicates/older events ignored | Idempotency and terminal-import tests |
| Incoming item revisions | Missing | N/S: superseded lines retained, current batch replaces earlier content, preparation jobs deduplicated | `importPlatform`; no real webhook receiver |
| Platform acceptance | Missing | N/S: 1–180 min prep request, pending acknowledgement; Yemeksepeti defaults to Vendor App | `queuePlatform` / `resolvePlatform`; no implied POS acceptance entitlement |
| Ready vs invoice | Missing | N/S: ready moves Picking → Invoiced; no fiscal invoice generated | Request tests and separate invoice workflow |
| Platform courier events | Read-only | N/S: explicit incoming test events; pickup excludes Shipped | `externalPlatformEvent`; no restaurant delivery controls |
| Delivery vs collection | Partial | N/S: Delivered never auto-collects; separate platform confirmation; no restaurant receivable | Import/finance tests |
| TGO item cancellation | Missing | N/S: selected package items, prototype reason codes, acknowledgement, proportional discount, last-item remainder | Cancellation tests; separate kitchen correction and platform financial adjustment |
| Yemeksepeti unverified management | Not ported | Intentionally gated: no TGO cancellation codes or invented management API | Queue capability gates tested; real account approval is D |
| Platform product/category availability | Missing | N/S: pending requests, explicit ack, independent per-source catalogs | Menu request tests and screen coverage |
| Platform/local product mapping | Missing | N/S: local mapping validates selected local ID, old snapshots unaffected | Native platform menu; local-only mapping |
| Mandatory free modifiers | Missing | N/S: retain required active/free option; fixture selects available required option | Native local scenario; not an asserted modifier-write API |
| Bulk platform prices | Missing | N/S: selected items, explicit success/failure per item; successful rows retained | Partial-batch test; failed rows resubmitted from menu |
| Platform store open/close | Missing | N/S: pending state, result only on ack | Store tab; no external request |
| Weekly hours / midnight / week rollover | Missing | N/S: seven days, closed day, time validation, next-day overlap checking | `validateHours` tests |
| Claims / refund / resend examples | Missing | N/S: delivered-order samples, per-item selection/acceptance/objection, 4-hour deadline, evidence count | Claim test; no claim acceptance creates a cash refund |
| Claim platform review | Missing | N/S: objection becomes Unresolved, explicit final test result | Native claim tab; genuine evidence upload/API is D |
| Reviews / category scores | Missing | N/S: rating aggregates, date/text/comment/reply/moderation filters | Review workflow tests, screen tests; example customers only |
| Review replies / moderation | Missing | N/S: pending request then WAITING_FOR_APPROVE, explicit approve/reject | Disabled for YS and opt-in simulated Uber Eats migration |
| Invoice HTTPS links | Missing | N/S: eligible order, HTTPS host, pending ack, duplicate protection, delete-before-replace | Invoice tests; no invoice generation or fiscal service |
| Sync request log | Missing | N/S: durable pending/completed/error state, trace ID, attempt count | `jobs`, native tab, request tests |
| 429 backoff / retry / stale ack | Missing | N/S: 10-sec example backoff, retries reissue trace IDs, status precondition prevents stale mutation | Request/backoff/stale-ack tests |
| Missed platform order recovery | Missing | S: explicit test import using the same idempotent importer | No real paging/cursor polling adapter |
| Platform settlements | Missing | N/S: separate gross/cancellation/commission/included-discount/net/payment-order records | Finance test, report/CSV; 15% is fictitious, no bank settlement |
| Staff Chrome on local Wi-Fi | HTML snapshot client | N: embedded Dart server, dedicated asset-bundled mobile page, per-worker QR enrollment/session, no phone cashier UI | Real HTTP tests; QR → physical phone on restaurant Wi-Fi is D |
| Shared SQLite | Optimistic snapshot | N: one laptop DB, WAL, FULL sync, busy timeout, BEGIN IMMEDIATE, PC revision CAS | Two SQLite connection tests and rollback tests |
| Phone simultaneous submission | Whole-snapshot PUT | N: constrained order command, authoritative server catalog, revision conflict, merged table additions | Simultaneous HTTP test (one success + one 409), no financial snapshot writes |
| Lost-response retry | Not idempotent | N: persisted request/result in same SQLite transaction; same ID/different payload rejected | Durable replay and transaction tests |
| Offline state / acknowledgement | HTML concept | N: browser blocks unconfirmed submission, retains pending request and distinguishes success/error/conflict | Dedicated staff page; reconnect testing on actual phones is D |
| Staff URL / QR / embedded assets | Separate site folder needed | N: private IPv4 discovery/selection, QR to `/personel`, all page/menu assets in Windows bundle | No Python or external site directory needed |
| Prototype management separation | Remote HTML manager reachable | N: native PC manager only; server does not serve old manager HTML or accept PUT `/api/state` | HTTP test verifies PUT rejected; no passwords; authenticated per-device sessions added |
| SQLite backup | Missing | N: consistent `VACUUM INTO` backup even with WAL, refuses overwrite | Reopen-backup test |
| Build/release verification | Analysis warnings ignored | Native runner committed; strict analysis, tests, HTML regression, Windows release, artifact + SHA-256 manifest | Actions workflow; successful run/artifact links recorded in PR |

## Data and synchronization decisions

The persisted `state_snapshot` schema stays compatible with the existing prototype. Typed projections (`CheckLine`, `LedgerEntry`, `SaleEntry`, `PosSnapshot`, `WriteResult`) and validated domain commands enforce money and state transitions. This is a versioned aggregate, not a newly normalized accounting database. A snapshot allows the five-table prototype to update an order, its payments and its print jobs atomically. Retained history is not a tamper-proof accounting ledger.

PC edits use revision-checked transactions. Phone writes use `/api/staff/orders` commands with persistent idempotency receipts. Two requests based on one revision cannot silently overwrite one another. On a 409 the phone keeps its cart, fetches current state and asks the operator to resubmit. On an uncertain network result it retries the *same* request ID. Phones cannot write payments, prices, employees or integrations. Snapshot endpoints now require a valid worker session and expose only a kitchen projection; use trusted staff Wi-Fi only. No port forwarding or public deployment is part of this migration.

Partial refunds are additive events under the original payment and are included at their refund timestamp in cash/report calculations. Legacy `reversed` records are still read. Closing a check and refunding an old check do not change the occupant of a physical table. Local product cancellations retain a void record and a correction batch; platform cancellations retain a financial adjustment rather than creating restaurant cash refunds.

## Acceptance boundary

Automated native screen checks run at 1600×900 and 1280×720 with populated orders, claims, reviews, cash and staff. They complement domain, HTTP, persistence, concurrency and export tests. The HTML regression suite remains in place. A green build proves compilation/tests for that source revision, **not** a real platform/device connection or an exhaustive operator acceptance run.

Before declaring restaurant deployment accepted, test the release ZIP on the actual Windows laptop with two real Chrome phones: scan the chosen Wi-Fi QR, submit concurrently, disconnect/reconnect during submission, verify order IDs and totals in the PC, and restart the PC app to check persistence. Inspect cash and CSV using restaurant test scenarios. Check Windows Firewall private-network access manually. Do not run the older Python server on the same port.

Actual Yemeksepeti/TGO credentials, approved account capabilities, end-to-end verified event/poll accounts, bank POS/ÖKC, fiscal invoices and the single physical printer are **not connected**. Their verification requires accounts/devices and is outside a simulated prototype. Staff sessions now authenticate devices; HTTP is still not encrypted. No credentials should be entered into this source or simulation UI. The original HTML demo must remain until operator parity/device acceptance is signed off.
