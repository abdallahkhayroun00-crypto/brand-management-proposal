# Nohutçuk — Roadmap, package contract and acceptance plan

> **27 October 2026 decision:** The user chose to purchase the Waveshare **2.4-inch ILI9341 SKU 18366** directly and skip the 1.9-inch panel. **Default 320x240 ILI9341 firmware and legacy 1.9-inch builds passed GitHub CI.** Hardware not ordered, connected or physically tested. The 77x34 mm front aperture must be redesigned for the 48.96x36.72 mm active image. Full component shortlist: [BOM_TURKIYE.md](BOM_TURKIYE.md).

## Scope and delivery status (2026-10-27 — verified GitHub assets vs physical tests)

| Workstream | Status |
|---|---|
| Brand visuals & two infographics | concept references supplied |
| Product feature list (moods, guest interactions, PC-app reactions) | documented |
| Electronics / selected exact components | **provisional bench selections**: ESP32-S3-DevKitC-1 + Waveshare selected 2.4-inch ILI9341 color TFT, VL53L0X/TTP223/MAX98357A candidates; physical fit and power unverified |
| CAD source / STEP | **prototype assets now in repository**, see main README and CAD_Source/STEP; hardware-fit unverified |
| STL set validated with chosen hardware | prototype STL set committed; **not validated against selected real hardware** |
| 3MF/G-code / print profile | **not yet created** |
| Wiring diagram, verified power design | **provisional GPIO table in docs/ELECTRONICS_BENCH.md**, not an electrically verified schematic or power budget |
| ESP32-S3 firmware, unit and hardware tests | **firmware/ C++ LCD renderer + portable tests created; native tests and PlatformIO ESP32-S3 compilation passed in GitHub Actions; hardware tests not performed** |
| Restaurant integration | **planned, not deployed** |
| Assembly manual and maintenance | **planned** |
| Separate GitHub assets | upload status tracked in assets/README.md |

## One complete version — final scope

**Delivery policy: ONE complete Nohutçuk build, with NO games.** There are no V1–V6 product releases. All remaining approved features are part of the same robot. The rows below are internal engineering work packages and their acceptance checks, **not versions**.

| Work package (same release) | All required capabilities | Completion check |
|---|---|---|
| Personality & face | full eye expression library, blinking, emotional reactions, auto sleep, randomized idle, mood and affection modes | expressions respond to events correctly |
| Guest interaction | proximity welcome, touch patterns, greetings in TR/EN/AR, safe servo nod/tilt, look/wave interaction and friendship mode | live guest tests, touch debounce, no repeated greetings |
| Natural personality & fun reactions | eight funny behaviors, spontaneous face expressions, gentle guest response; **no games, leaderboards, competitions or timed challenges** | animations behave safely and do not interrupt service |
| Restaurant connection | **only the Nohut Falafel PC management app** sends sanitized order/payment/status events via local Wi-Fi; it handles any marketplace/API integration itself | verify no direct robot ↔ marketplace/POS/API connection; no sensitive data or payment dependencies |
| Social & events | photo, selfie, Instagram/Reels, QR menu card, Ramadan/Eid/New Year/birthday animations | tested interaction and branding |
| Full physical build | unified modular body, final BOM, wired ESP32-S3, verified power, CAD/STEP/STL/3MF, printed and assembled parts | print-fit, electrical safety, movement and stability tests |
| Documentation & package | full wiring, firmware, release files, assembly and maintenance guide, reference art | one consistent reproducible release archive |

Feature enablement may depend on the actual selected hardware or platform permissions. **Do not silently remove a feature:** flag external blockers explicitly. Restaurant order or payment handling must keep working even if mascot alerts are unavailable.

## Production package / file layout (planned)

```
nohutcuk/
├── README.md
├── assets/
│   ├── README.md
│   ├── concept-infographic-en.png          [pending original upload]
│   ├── concept-infographic-tr.png          [pending original upload]
│   ├── expressions/                       [future PNG frames]
│   └── audio/                             [future TR, EN, AR cues]
├── cad/                                    [future editable CAD/STEP]
├── stl/                                    [future printable STL meshes]
├── slicer/                                 [future verified 3MF files]
├── electronics/                            [future schematic, wiring, BOM]
├── firmware/                               [future ESP32-S3 source + tests]
└── docs/
    ├── FEATURES.md
    ├── HARDWARE_AND_3D_PRINTING.md
    ├── RESTAURANT_INTEGRATION.md
    ├── ROADMAP.md
    └── ASSEMBLY_GUIDE.md                  [future]
```

Only real, verified artifacts should be put into engineering folders; do not create dummy `.stl` files or assert ZIP contents that have not been produced.

## Immediate engineering decisions

1. **Display selected for purchase:** Waveshare standalone **2.4-inch ILI9341 SKU 18366**, 240x320 TFT, module 70.5x43.3 mm. Verify orientation and viewing angles on actual hardware; redesign the old aperture.
2. **Bench controller selected:** ESP32-S3-DevKitC-1 using Arduino + PlatformIO; confirm exact purchased board/module variant.
3. Choose capacitive touch sensor, proximity sensor and audio solution; optional worker control button is not a game input.
4. Measure servo travel, torque, current and mounting screws.
5. Decide line-powered USB-C versus battery; ensure adequate electrical safety.
6. Freeze first CAD envelope and wall thickness; reconcile concept drawings.
7. Build cardboard/printed proof of fit, then prototype printed parts.
8. Test face expressions and touch interactions on a breadboard.
9. Add proximity/speech and motion only after standalone stability.
10. Integrate to a local backend simulator before live restaurant systems.

## Test and release gate

- Mechanics: dimensions, tolerances, screws, user touch comfort, tip resistance, leaf accessory safety.
- Electronics: acceptable surface temperature, power drop resilience, overcurrent margin, servo stall and cable strain.
- Software: startup, reconnect, event deduplication, sleep/wake, mute, handling invalid inputs.
- Restaurant: cannot block orders/payment; never stores customer or card personal data.
- Printability: mesh watertight/manifold, oriented appropriately, sliced test, printed fit test documented.
- Product: logo and face are consistent with Nohut Falafel branding.

## Friendly warning about concept-image labels

Some visual panels say “Package Contents (ZIP File): STL, 3MF, STEP, renders, assembly PDF, wiring, firmware”. This is a **proposed deliverable list** visible in the concept image, **not evidence that such ZIP/files exist yet**. No verified ready-to-print files are part of this documentation release.