# Nohutçuk ↔ Restaurant System Integration

## Purpose and boundary

Nohutçuk is a **non-critical notification and guest-interaction device**, not a cash register, order-taker, authorization system or financial record. **Its single source of restaurant data is the Nohut Falafel PC application.** Keep it isolated from payment credentials and personal order details. The current POS/QR projects are concept/demo work, so all integration below is **planned**, not operational.

## Exactly ONE event source: our restaurant application on the PC

**Nohutçuk receives ALL restaurant information from the Nohut Falafel PC management system we are building, NOT directly from any delivery-platform, cash-register, payment-device or other third-party API.** It only listens for events the local PC app has already received/recorded/validated.

```text
Platform orders / table orders / POS transaction results
       ↓ handled ONLY by our Nohut Falafel PC app
Nohut Falafel PC management application + local SQLite
       ├── cashier screen, staff phones, local printer (normal restaurant operation)
       ├── integrations with marketplaces or supported ÖKC/POS where authorized
       └── publishes safe, small mascot notifications on restaurant Wi-Fi
                                      ↓
                             Nohutçuk ESP32-S3
                       facial reaction / gesture / sound only
```

The robot **does not call, poll, authenticate with, or hold API credentials for** Yemeksepeti, Trendyol Go, Migros Yemek or a payment terminal. Even if a marketplace order is not imported into our PC app, the robot **does not fetch that order itself**. All platform integration complexities belong to the PC system, not the mascot. The PC application must work normally while the mascot is disconnected.

## Allowed event schema — proposal

Example event (no user-sensitive data):
```json
{
  "id": "event-unique-id",
  "kind": "ORDER_NEW",
  "source": "TRENDYOL_GO",
  "occurred_at": "2026-10-26T12:30:00+03:00",
  "severity": "info",
  "display_hint": "happy"
}
```

Event IDs allow duplicate suppression. Timezone must be explicit. Use versioned format, TTL/expiry and retry semantics; **robot must never be the primary operational alarm**.

## Event mapping

| System event | Mascot response | Required truth condition |
|---|---|---|
| `ORDER_NEW` tagged Trendyol Go | wake + orange/chime | PC app has already saved/validated the platform order |
| `ORDER_NEW` tagged Yemeksepeti | happy + distinct chime | PC app has already saved/validated the platform order |
| `ORDER_NEW` tagged Migros Yemek | platform alert | PC app has already saved/validated that platform's order |
| `TABLE_ORDER_NEW` | eager falafel eyes | newly submitted in-house order |
| `ORDER_ITEM_ADDED` | nod/blink | saved incremental item(s), not draft |
| `CARD_PAYMENT_SUCCEEDED` | wink/smile | **confirmed POS settlement/approval**, never mere button press |
| `CASH_PAYMENT_RECORDED` | hearts | actual authorized cash record saved |
| `PAYMENT_FAILED` | confused expression | verified failure/error state |
| `ORDER_DELAYED` | concerned look | configured threshold crossed |
| `ORDER_CANCELLED` | sad | committed cancellation |
| `ORDER_READY` | stars/dance | preparation completed |
| `RESTAURANT_CLOSED` | “İyi geceler!” sleep | store shift closed |

Do not expose customer names, phone numbers, addresses, ticket item details, tender amounts, full order IDs or card information to mascot. In a restaurant, public verbal announcements of payment failure may embarrass a customer; **make payment-related responses admin-configurable and silent by default**.

## Local connection design

- Mascot should connect to a **restricted private Wi-Fi** or protected IoT segment, not a public guest network.
- Use unique per-device authentication and encrypted transport where available; allow gateway/robot key rotation.
- Define predictable offline behavior: mascot continues its local expressions, greetings and touch responses if the PC or Internet is offline (without games).
- Apply rate limits, duplicate event filtering, event TTL, busy-mode batching and worker override/mute.
- Robot must never talk directly to marketplace/POS APIs or hold platform tokens, POS PINs, staff passwords or database copies. All its restaurant events originate in the PC app.
- Avoid direct internet exposure of ESP32 admin ports.
- For critical kitchen operations, use normal POS UI/sound alerts and printer instead of relying on a novelty robot.

## Restaurant admin screen: “Nohutçuk Yönetimi”

**Admin options:** online/offline indicator; Wi-Fi status; firmware version; allowed event toggles; language TR/EN/AR; volume/mute/quiet hours; expression preview; manual Dance Mode and Birthday Mode; sensor self-test; most recent event and error code.

**Staff permissions:** optionally trigger greeting/celebration/photo mode but no admin config or payment access.

## Relationship to payment and existing POS demo

A cashier on the **PC** remains responsible for `Nakit` / `Kart`, split bills and settling tables. Restaurant system **does not** infer successful card charge from UI clicks; wait for actual compatible POS confirmation. Prepaid marketplace orders stay marketplace records and must not be collected twice. The mascot only plays a response *after* the authoritative system records success.

## Acceptance tests

1. New in-store order recorded in the PC app produces one non-blocking mascot alert.
2. Duplicate event ID does not cause multiple sounds.
3. Silent mode suppresses all sound but retains logged notice.
4. Disconnected ESP32 does not prevent saving/printing an order or receiving payment.
5. Offline QR menu/POS guest transactions do not depend on mascot.
6. A failed POS transaction never triggers `CARD_PAYMENT_SUCCEEDED`.
7. Marketplace prepayment does not create a fictitious restaurant POS charge.
8. Restarting mascot does not replay expired alerts.
9. Restaurant Wi-Fi isolation and credentials pass basic security review.
10. Child-safe motion limits and hardware fault stop are enforced.
11. Disable the PC app: the mascot must NOT independently contact any marketplace or terminal.
12. A platform event unseen by the PC app must not appear on Nohutçuk.