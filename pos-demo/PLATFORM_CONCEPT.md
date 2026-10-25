# Online platform concept — 2026-10-25

This is a browser-only POS concept. All new orders, claims, reviews, invoice links, API results and financial records are clearly labelled examples. No platform API, bank, fiscal printer, public webhook receiver or cross-device database is connected. Do not enter API credentials.

## Implemented flows

| Area | Concept behaviour |
| --- | --- |
| Orders | Separate platform snapshots, package and item identifiers, source prices and modifiers, discount totals, contact/PIN placeholders, courier ETA and platform pickup priority. |
| Payments | Card, meal card and platform-collected payment on delivery examples; no second restaurant collection. Collection is tracked separately from restaurant receivables and bank settlement. |
| Acceptance | Validated preparation time; request remains pending until an explicit simulated result. Yemeksepeti defaults to Vendor App acceptance; direct POS acceptance is a labelled test assumption. |
| Delivery | Ready is distinct from invoice submission. Courier pickup/delivery are incoming platform events in a test-only drawer, not restaurant courier commands. |
| Cancellation | Trendyol partial/full item cancellation with permitted restaurant reason codes. Platform cancellation and restaurant cancellation use different states. No invented Yemeksepeti item cancellation capability. |
| Kitchen | Partial cancellation creates a separate kitchen correction job. Remaining-order prints exclude correction lines and show the current discount. |
| Menu | Separate per-platform catalog and local mapping; product/category availability, mandatory free-option validation, bulk price jobs with per-item success/failure. Option switching is explicitly a local scenario, not an asserted modifier-write API. |
| Store | Example identifiers, acceptance mode, open/close requests, weekly hours including next-day midnight intervals and overlap validation. |
| Claims | Item-level partial acceptance/objection, four-hour response deadline, refund/resend examples, evidence presence and unresolved platform review. Claim acceptance does not itself manufacture a cash refund. |
| Reviews | Example category scores, combined date/text/reply filters, draft reply and moderation states. Disabled for the simulated Uber Eats migration and unverified Yemeksepeti access. |
| Invoices | HTTPS link submission, pending results, duplicate prevention, delete-before-replace. No fiscal invoice is generated. |
| Synchronization | Pending/completed/error requests, trace identifiers, 429 backoff, conflict protection, retries, duplicate-package replay and missed-order recovery examples. |
| Finance | Separate sales, cancellation adjustment, example commission and net payout records, payment order matching and CSV. Discounts already included in an order are informational, never deducted twice. Commission is an explicitly fictitious 15% scenario. |
| Navigation | Online features are tabs under Online Siparişler; connection configuration is under Ayarlar; settlement is under Raporlar. Staff selection remains password-free, and PC order entry always acts as Kasa (PC). |

## Platform limits

Trendyol Go features are based on the restaurant/Yemek documentation, not the grocery/Market API. Merchant-own-courier delivery regions, fees and manual shipping/delivery controls are intentionally outside this restaurant's platform-courier workflow. The promotion-management API is Market-only and is not offered here.

Yemeksepeti restaurant account capabilities need verification through its restaurant integration portal and local representative. Its Local Shops/Q-Commerce site is not the restaurant contract. Menu/store/claims/reviews/invoices/finance management is therefore not advertised as connected or confirmed. Trendyol cancellation codes are never used for Yemeksepeti.

Uber Eats migration is opt-in simulation, not inferred from the restaurant's location. It gates review availability and automatic-ready test events.

## Before a real connection

Implement platform-specific adapters, authenticated secret storage outside public source, required request headers, real paging/cursors and rate limits, source event revisions/ordering, durable transactional storage and a suitable receiver where required. Obtain platform/account approval, Stage credentials and access, and run official end-to-end tests. The current local sample generator is not a successful Stage integration.

Real financial APIs can contain taxes, fees, coupons, commissions, refunds and other adjustments beyond this simplified, explicitly labelled illustration. Do not use its payout figures for accounting.

## Validation

Run from the repository root:

```sh
node pos-demo/tests/logic.test.cjs
```

107 regression scenarios cover local checkout/drafts and the new platform concept. Browser checks cover request acknowledgement, partial cancellation, courier events, claim objections, review replies, settlement and phone-width layout.

## Official references

- https://developers.tgoapps.com/docs/category/8-uber-eats-trendyol-go---yemek-entegrasyonu
- https://developers.tgoapps.com/docs/authorization
- https://developers.tgoapps.com/docs/canli-test-ortam-bilgileri
- https://developers.tgoapps.com/docs/category/4-muhasebe-ve-finans-entegrasyonu
- https://developers.tgoapps.com/docs/uber-eats-gecisi
- https://developers.tgoapps.com/docs/category/9-promosyon-entegrasyonu
- https://developer.yemeksepeti.com/en/documentation/introduction
- https://integration.yemeksepeti.com/en/
- https://developers.deliveryhero.com/documentation/pos.html
