# Nohut Falafel

This repository now serves two separate experiences:

- **QR menu (preserved):** `nohut-menu/` — production, guest-facing site, left unchanged.
- **POS UI concept:** `pos-demo/` — Turkish responsive interactive *mockup* for future Flutter/Dart development. Fake example records only. No bank, ÖKC, POS, delivery API or real database connection.

The root `index.html` redirects to the existing QR menu. Keep `.nojekyll` for GitHub Pages.

- **Native Windows POS:** `flutter_desktop/` — native Flutter manager/cashier, embedded LAN staff ordering and shared SQLite. See [feature parity audit](flutter_desktop/FEATURE_PARITY.md) and [Windows instructions](flutter_desktop/README.md). External platform/payment connections remain simulated. XP-237B receipt printing uses its Windows driver; physical acceptance is still required.
