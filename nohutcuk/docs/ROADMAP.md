# Nohutçuk — Roadmap, package contract and acceptance plan

## Scope and delivery status (2026-10-26)

| Workstream | Status |
|---|---|
| Brand visuals & two infographics | concept references supplied |
| Product feature list (moods, games, restaurant reactions) | documented |
| Electronics / selected exact components | **not finalized** |
| CAD source / STEP | **not yet created** |
| STL set validated with chosen hardware | **not yet created** |
| 3MF/G-code / print profile | **not yet created** |
| Wiring diagram, verified power design | **not yet created** |
| ESP32-S3 firmware, unit and hardware tests | **not yet created** |
| Restaurant integration | **planned, not deployed** |
| Assembly manual and maintenance | **planned** |
| Separate GitHub assets | upload status tracked in assets/README.md |

## Versions and gates

| Version | Capabilities | Exit criteria |
|---|---|---|
| **V1 — Friendly face** | OLED eye engine, 15 primary expressions, capacitive pet sensor, Auto Sleep | fast reliable reaction, no accidental touch spam; standalone offline |
| **V2 — Alive** | one/two servos, prerecorded voice, proximity wake, optional LED | stable power, safe travel limits, quiet settings |
| **V3 — Play** | ten mini games, friendship meter, funny behaviors/easter eggs | repeatable gameplay, no crashes, nonintrusive controls |
| **V4 — Restaurant-aware** | POS backend event gateway, platforms when authorized, admin page | secure + sanitized events, no duplicated alerts, operational independence |
| **V5 — Social mascot** | photo/selfie/reels presets, events | usable branded content, quiet-mode and owner approval |
| **V6 — Refined** | adaptive timing, advanced mood and modular accessories | maintainability, consistent component/size interfaces |

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

1. Pick exact OLED (screen size, resolution, placement and supply).
2. Pick ESP32-S3 module/form factor and firmware framework (Arduino or ESP-IDF).
3. Choose capacitive sensor, range/proximity sensor, game buttons and audio solution.
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