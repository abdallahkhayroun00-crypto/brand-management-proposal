# Native and staff UI revision — 25 October 2026

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
