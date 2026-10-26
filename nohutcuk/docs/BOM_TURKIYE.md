# Nohutçuk — Türkiye BOM + purchasing decisions

**Updated:** 2026-10-27. **Status: engineering shortlist, NOT a validated/approved final basket.** This document records the complete component research discussed for one physical Nohut Falafel mascot. **Do not buy every item based on this list yet.** Check prices, stock and electrical compatibility at purchase. The retailer figures below are **historical approximate quotes from project research**, not live confirmed prices on this page.

> **SUPERSEDING DECISION — 27 October 2026:** User selected ONE **3.2-inch ILI9341 SPI 240x320 display** for Nohutçuk. **Do not buy the old 2.4-inch Waveshare SKU 18366 or 1.9-inch ST7789V2.** Suggested **specific retail candidate**, pending photo/pinout verification: **Voltaj MZK-6 3.2-inch 4-wire SPI, without touch**, [seller listing](https://www.voltaj.net/tft-lcd-spi-seri-arayuzlu3.2-incili9341-ekran-modulu-dokunmatiksiz). Seller lists a PCB of **55.04 x 89.3 mm**; landscape orientation makes it **89.3 mm wide x 55.04 mm high**. Active area **64.8 x 48.6 mm**, compared with current CAD head ~100 x 58 mm and *opening* 77 x 34 mm. The old head CANNOT safely fit this PCB with mounting and wall allowance. **Enlarge/rebuild head and bezel** before final 3D printing. **No purchase or physical validation has happened.** Default firmware target is now `esp32-s3-ili9341-32`, same 320x240 driver pixel layout as 2.4-inch, but **pinout, voltage, backlight and connector are NOT interchangeable without checking the actual module**.



## Display choice and mechanical fit (3.2-inch ILI9341)

- **Selected specification:** 3.2-inch ILI9341, native 240x320, SPI breakout, used as **320x240 landscape**.
- **Shortlisted exact retail SKU:** Voltaj **MZK-6 (no touchscreen)**. Vendor lists **55.04 x 89.3 mm PCB**, 4-wire SPI, 3.3/5V supply (verify onboard regulator/level shifter and the specific connector before wiring). [Retailer](https://www.voltaj.net/tft-lcd-spi-seri-arayuzlu3.2-incili9341-ekran-modulu-dokunmatiksiz).
- **Display active image:** about **64.8 x 48.6 mm** in landscape, as supported by 3.2-inch ILI9341 display specifications ([Raystar](https://www.raystar-optronics.com/3.2-3.5-3.9-tft-lcd-display/240x320-ili9341.html)).
- **Current body constraint:** head outer ~100 x 58 x 50 mm, LCD aperture 77 x 34 mm. In landscape the retail module PCB height ~55 mm leaves just 3 mm total within the outer shell height, **not enough for walls/mounts/wire relief**; opening height also hides ~14.6 mm of the image. Consider a redesigned **~115 x 75–80 mm outer head** as an *engineering starting envelope*, NOT final validated CAD.
- **Beware misleading listings:** The [Alkatronik touch module](https://alkatronik.com/tr/product/lcd/3-2-tft-lcd-modul-381) mentions Arduino Mega, **16-bit data bus** AND SPI, so do not assume that version uses the same simple SPI wiring. The [Waveshare 3.2-inch Touch LCD (D)](https://www.waveshare.com/3.2inch-320x240-touch-lcd-d.htm) uses parallel display wiring even though touch uses SPI; **not a drop-in SPI module**.
- **Legacy:** 2.4-inch Waveshare ILI9341 and 1.9-inch ST7789V2 are preserved in source as **old software targets only**, quantity **0** for procurement.
- **Firmware:** same ILI9341 320x240 eye renderer works at the pixel level with 3.2-inch panels. PlatformIO 3.2 profile compiles in CI; it does **not** prove physical wiring or that a supplier’s board is actually 4-wire SPI.
- **Safety:** verify ESP32-S3 3.3V GPIO levels and LCD electrical requirements; never connect a 5V output signal to ESP32 pins.

## Controller and active components (1 robot)

| ID | Component | Exact candidate/specification | Qty | Status / caveat | Research links |
|---|---|---|---:|---|---|
| E01 | Controller | **Espressif ESP32-S3-DevKitC-1-N8R8** (8 MB flash / 8 MB PSRAM version), 3.3 V GPIO | 1 | Selected test target; verify original board/module revision | [Espressif](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s3/esp32-s3-devkitc-1/user_guide_v1.0.html) · [Türkiye](https://www.beti.com.tr/urun/esp32-s3-devkitc-1-n8r8-gelistirme-karti) |
| E02 | **Selected 3.2-inch LCD (1 piece)** | **ILI9341 SPI 240x320, no touch**, provisional retail SKU Voltaj MZK-6 | 1 | **Selected display size/driver; verify exact SPI pinout and dimensions; head redesign required** | [Voltaj MZK-6](https://www.voltaj.net/tft-lcd-spi-seri-arayuzlu3.2-incili9341-ekran-modulu-dokunmatiksiz) |
| E02a | Old displays **not to buy** | 2.4-inch ILI9341 / 1.9-inch ST7789V2 | 0 | Historical software reference only | — |
| E03 | Touch | **TTP223** capacitive touch breakout, 3.3 V output, active-high verified | 1 | Prototype candidate; test through PETG/PLA and debounce | [Türkiye](https://www.robotistan.com/ttp223-tekli-dokunmatik-anahtar-1-way-touch-switch) |
| E04 | Guest approach | **VL53L0X** ToF I²C **carrier/breakout with safe power/logic levels**, not bare IC | 1 | Candidate; vendor-specific power circuitry to verify. Does not recognize waves | [Adafruit documentation](https://learn.adafruit.com/adafruit-vl53l0x-micro-lidar-distance-sensor-breakout/pinouts) · [Türkiye example](https://alkatronik.com/tr/product/vl53l0xv2-lazer-mesafe-sensoru-1802/sensorler-2) |
| E05 | Hand wave (optional) | **APDS-9960 / GY-APDS-9960** proximity/gesture breakout, 3.3 V-compatible | 0–1 | Optional **short-range** gesture sensing, not reliable across restaurant room; shared I²C electrical address/optical interference testing required | [Türkiye](https://www.tlsrobotik.com/urun/gy-9960-3-3-apds-9960-renk-ve-temassiz-hareket-tanima-sensor-modulu/) |
| E06 | Audio amp | **MAX98357A** digital I²S mono class-D amplifier breakout | 1 | Candidate; speaker wire + audio playback driver/software not yet implemented | [Adafruit guide](https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/pinouts) · [Türkiye](https://argerobo.com/max98357a-i2s-3w-amplifikator-modulu) |
| E07 | Speaker | **8 Ω, rated 3 W, nominal 40 mm** miniature speaker | 1 | **Fit not validated**. Actual volume/current and enclosure space to measure | [Türkiye](https://www.motorobit.com/hoparlor-8-ohm-3w-40mm) |
| E08 | Servo (first axis) | **MG90S-size, metal-gear micro servo, nominal 180°** | 1 candidate | **Not a final torque/mechanical approval**; measure fully assembled head mass, pivot, stall current and clearance first | [Türkiye](https://www.robotistan.com/mg90s-servo-motor) |
| E08b | Servo (second axis) | A *second* appropriately sized servo **only if** a safe two-axis mechanism is chosen | 0 for initial order | **Conditional**, do not order blindly | — |
| E09 | Power adapter | Reputable certified **5 V 3 A isolated USB supply**, with appropriate wiring/connectors | 1 candidate | **15 W is a starting candidate, not proven sufficient**; servo stall/audio peak and USB voltage drop require measurements | [Türkiye reference](https://www.aykom.com.tr/urun/retro-5v-3a-15w-usb-c-type-c-hizli-sarj-adaptoru) |
| E10 | Decorative LED | 1 or 2 warm/RGB low-current LEDs with proper current limiting/driver | 0–2 | Optional; no direct high-current LED from MCU pins | — |
| E11 | Local audio storage | ESP32-S3 onboard flash for a few short audio cues | 1 built-in | No microSD purchase unless measured space proves necessary | — |
| E12 | Service input | Latching power switch **for the designed supply** + a separate mute/service button | 1 each | Switch current and placement must be rated/checked | — |

## Mechanical, power and assembly items (not fully specified)

| ID | Item | Qty / condition | Decision gate |
|---|---|---|---|
| M01 | PETG/PLA for black body + green leaf; removable front bezel | As printed | **Only after** exact LCD dimensions + screen view opening are reconciled |
| M02 | 3.2-inch LCD bracket + standoffs + opaque face lens/clear protector | 1 kit | Redesign opening for active image 64.8 x 48.6 mm and PCB 89.3 x 55.04 mm (landscape) |
| M03 | Stable base and head-pivot support (bearing/shaft or mechanical support as needed) | 1 | Servo shaft should not bear unverified whole head weight |
| M04 | Servo horn, screw/collar and safe end stops | 1 set | Validate real servo and travel |
| M05 | M2/M3 stainless screws, nuts, thermal inserts and spacers | Sized kit | Confirm CAD hole/thread sizes |
| M06 | Connector and cabling matched to purchased 3.2-inch breakout | 1 harness | **Actual pin names, pitch, voltage to be verified on real MZK-6**, not borrowed from 2.4-inch cable map |
| M07 | Jumper wires + breadboard for first tests | 1 pack | Not for permanent vibration-resistant install |
| M08 | Perfboard / custom PCB with protected 5 V/3.3 V distribution, connector strain relief | 1 | Electrical schematic and load test required |
| M09 | Suitable separate servo supply branch, decoupling caps (e.g. 470–1000 µF as an engineering starting point), protection and shared reference | Design-dependent | Size only using measured peak currents |
| M10 | Short USB *data* cable and multimeter | 1 each | Confirm flashing and voltage checks |
| M11 | Speaker acoustic grille + internal sound enclosure | 1 | Check speaker fit and sound quality |
| M12 | Cable grommets, heat shrink, accessible screws, non-slip base feet | As needed | Child-facing shop safety and maintenance |

## Price references — NOT verified live quotes

These are **approximate historical Turkish offers discussed in this project**, not a guarantee of the exact items, VAT, stock, shipping or price on 2026-10-27. Recheck each linked page before ordering.

| ID | Approx. Turkish reference price |
|---|---:|
| E01 ESP32-S3 N8R8 | 1,418 TL |
| E02 3.2-inch MZK-6 display | 838.83 TL research listing price; recheck at checkout |
| E03 TTP223 | 55 TL |
| E04 VL53L0XV2 budget breakout | 149 TL |
| E05 APDS-9960 | 200 TL |
| E06 MAX98357A | 172 TL |
| E07 8 Ω / 3 W speaker | 104 TL |
| E08 MG90S | 126 TL |
| E09 5 V / 3 A adapter | 702 TL |

**Do not sum the table into a definitive project cost.** Display is a *candidate* and prices exclude many missing items above: safe power distribution, connectors, cable, enclosure, printed parts, fasteners, revisions and replacement modules. Previous broad 5,000–7,000 TL target remains **rough planning only** and could be exceeded.

## Sensor and system compatibility rules

1. **3.3 V logic everywhere on ESP32 GPIO**, do not feed a 5 V output into pins. A seller's label "3.3–5 V" does not automatically guarantee compatible I²C pull-ups.
2. VL53L0X and APDS-9960 may share I²C if address, pull-ups, bus speed and optical operation are checked. Gesture is **near-field**, not camera/face tracking.
3. A single servo supports **one mechanical axis**. Two independent head movements require a designed 2-axis mechanism, safe servo selection and enough current.
4. MAX98357A works over I²S, but **no real Nohutçuk voice is included in firmware yet**. Prefer short character recordings rather than generic browser speech.
5. Power architecture: independently size speaker and servo peaks, fuse/protect low-voltage distribution, isolate motor noise and test for controller brownout. **Never power the servo from an ESP32 GPIO.**
6. The ESP32-S3 already has Wi-Fi; no extra Wi-Fi module, Raspberry Pi, Arduino Uno, webcam or always-listening microphone is needed for the approved scope.
7. The robot **never** talks directly to marketplace/POS APIs; the PC handles those. Orders/payment must remain operational if Nohutçuk is unplugged.
8. No games and no unnecessary personal data collection.

## Purchase decision gates

**Stage A — purchase exactly one 3.2-inch ILI9341 **SPI** breakout (prefer non-touch, verify Voltaj MZK-6 pins before ordering); do not buy either smaller screen.** Test 320x240 face firmware and check LCD dimensions, connector and real viewing angle. Redesign head and bezel before printing.

**Stage B — sensing and speech.** Add E03, E04, E06, E07; gesture E05 only if needed after near-field range test. Select prerecorded Turkish/Nohutçuk voice. Confirm file storage and audio volume.

**Stage C — safe movement, power, assembly.** Measure head mass and geometry; only then select servo torque, pivot, supply amperage, power distribution, fasteners, final 3D printed body.

### Current GitHub implementation vs hardware decision

| Software / hardware layer | Reality |
|---|---|
| Browser SVG face and 82 shop-day scenarios | Implemented; automated tests passed |
| ESP32-S3 C++ face | Default 3.2-inch ILI9341 profile; same 320x240 pixel driver family as prior 2.4-inch. Software compilation ≠ physical validation |
| Selected 3.2-inch ILI9341 face | One panel to purchase, not ordered. Real wiring, enclosure enlargement, viewing-angle and reliability tests pending |
| TTP223 / VL53L0X / APDS-9960 | Touch/ToF scaffolding for initial sensor candidates; not bench verified; gesture integration absent |
| MAX98357A, voice, head servo | Names shortlisted; drivers/hardware safety/actual robot assembly not completed |
| CAD | Prototype exists; final screen/servo/speaker-fit must be reworked |

Next gate: compile new 3.2-inch default profile in GitHub Actions; then verify a supplier-specific SPI pinout and real LCD prototype. Do not print CAD based on the old 100x58 mm head.
