# Tickets, USB printing and external invoices — 0.7.0

The owner confirmed USB printing and no current e-Fatura/e-Arşiv provider. No physical printer model or working platform credentials have been supplied. Hardware output and live platform delivery remain unverified.

## Documents and ownership

**Fiş & Fatura** is a native, searchable order workspace. Hesap Özeti previews and exports an 80 mm non-fiscal bill, including paid and outstanding amounts. Satış Belgeleri registers an invoice already issued elsewhere; it does not issue one. Mali Fatura Kes stays disabled until a fiscal provider is implemented and approved. No tax rates, legal issuer identity, ETTN or fiscal invoice numbers are invented.

Kitchen tickets use the supplied black-and-white Nohut wordmark: YENİ SİPARİŞ, EK SİPARİŞ and product-cancellation corrections. Added tickets contain only the new batch. Persisted immutable snapshots preserve the original products, notes and amounts after subsequent edits. Kitchen output excludes customer contact and payment details. For Trendyol Go and Yemeksepeti, the owner requested the platform’s own ready-made receipt instead: Nohut receipt rendering is blocked. Automatic original-receipt download is not connected. The operator can print from the partner panel, or attach its original PDF (maximum 5 MB) after confirming the order match. Original bytes and SHA-256 are saved in SQLite. Preview and the single printer use those unchanged bytes. Import provenance is a user attestation, not an independently verified platform signature. Completed or uncertain jobs cannot be replaced. Every preparation ticket says “Hazırlık Fişi · Mali fiş değildir”. A printable PDF is not fiscal issuance.

Restaurant sales documents, platform delivery/service documents and platform commission/settlement invoices are separate responsibilities. Payment arrangements can affect document obligations; the application does not infer fiscal treatment from payment method alone. See the [Yemeksepeti merchant contract](https://kurumsal.yemeksepeti.com/uye-isyeri-sozlesmesi/) and [official customer FAQ](https://www.yemeksepeti.com/contents/contact.htm). Fiscal setup must follow the restaurant's actual provider and [GİB guidance](https://ynokc.gib.gov.tr/Home/SSS).

## One Windows USB printer

Install the manufacturer's Windows USB driver, then choose that device in **Ayarlar → Yazıcı → Windows Yazıcısı Seç**. The application stores one printer destination. Printer enumeration may also include virtual/network drivers; select the actual USB printer. Configure 80 mm paper in its driver and inspect margins, Turkish characters and cutter behaviour on the real device. No physical test has yet been performed.

The queue offers preview, PDF export and explicit Windows dispatch. “Sürücüye Gönderildi” means the driver accepted the job, not that paper output was verified. SQLite claims and a process/file lock serialize dispatch. Completed jobs cannot be replayed and there is no KOPYA FİŞ. A driver exception or interrupted dispatch becomes **Belirsiz**; automatic retries are blocked. Inspect the physical output and Windows spooler, then record a reason before marking it produced or safely re-queuing it. Simulation controls are separate and cannot claim physical output.

## Platform invoice-link adapter

The [official Trendyol Go Meal invoice-link contract](https://developers.tgoapps.com/docs/trendyol-go-yemek-entegrasyonu/siparis-entegrasyonu/ymk-fatura-besleme) uploads an existing hosted invoice link; it does not generate an invoice:

`POST /integrator/invoice/meal/suppliers/{supplierId}/supplier-invoice-links/4/{serviceSourceId}`

`serviceSourceId` is the platform's actual **orderId**, not its package ID or a local POS ID. Body: `{"invoiceLink":"https://..."}`. Expected success: HTTP 201. The adapter pins stage/live Meal origins, channel 4 and the configured supplier. A user must attest that the invoice was issued externally, matches the order and its HTTPS URL will remain accessible for the required ten years. URL availability or retention is not independently verified by the app.

DEMO orders cannot enter this adapter. Commercial-content fingerprints block changed amounts/products while allowing normal preparation-status updates. Each upload has a durable claim and audit. Successful uploads do not repeat. Known failures allow explicit retry; rate limits impose a delay. Network/ambiguous results require platform-side reconciliation before retry. Account changes cannot redirect old jobs. Credentials stay in encrypted Windows storage, not shared SQLite or staff responses.

Yemeksepeti invoice upload is **not connected**: no approved public invoice-upload route/account contract has been verified. Use its partner panel for now. No guessed upload endpoint is sent. Existing simulated invoice/store/menu/claims/reviews/finance tools remain labelled DEMO. Trendyol Meal accept/ready/reject writes remain blocked pending verified mutation contracts; adding invoice links does not enable these unrelated operations.

## Validation

Domain, PDF, SQLite/concurrency and mocked transport tests cover immutable batches, Turkish fonts, 80 mm page geometry, long orders, one-printer claims, uncertain outcomes, external invoice validation, correct Meal route/order ID, DEMO/account guards, timed retries and interrupted dispatch. Native navigation tests cover both document tabs. Sample PDFs are generated by the actual application renderer. None of these tests substitute for a USB printer test, fiscal-provider onboarding or authorized platform acceptance testing.
