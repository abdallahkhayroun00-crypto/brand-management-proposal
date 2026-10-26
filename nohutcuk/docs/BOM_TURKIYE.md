# Nohutçuk — Türkiye BOM + purchasing decisions

**Updated:** 2026-10-27. **Status: engineering shortlist, NOT a validated/approved final basket.** This document records the complete component research discussed for one physical Nohut Falafel mascot. **Do not buy every item based on this list yet.** Check prices, stock and electrical compatibility at purchase. The retailer figures below are **historical approximate quotes from project research**, not live confirmed prices on this page.

> **DECISION — 27 October 2026:** Purchase **one Waveshare 2.4-inch ILI9341 LCD (SKU 18366)** as the first face module. Do **not** purchase the 1.9-inch alternative. The 2.4-inch ILI9341 is the **default PlatformIO build target**, and its firmware CI passed, but **no physical unit has been bought, connected or tested**. Update the CAD front cutout before printing: display active area is 48.96 x 36.72 mm versus the old 77 x 34 mm aperture. Other components remain provisional.

## Display specs and fit conditions

**Selected display:** **Waveshare 2.4inch LCD Module, SKU 18366, ILI9341, SPI, TFT, 240×320 pixels, 65K RGB**, used horizontally at **320×240**. [Manufacturer](https://www.waveshare.com/product/displays/lcd-oled/2.4inch-lcd-module.htm) · [datasheet/wiki](https://www.waveshare.com/wiki/2.4inch_LCD_Module)

- **Official board dimensions:** 70.50 × 43.30 mm.
- **Official active display dimensions:** 48.96 × 36.72 mm in landscape.
- CAD prototype head: ~100 × 58 × 50 mm; **placeholder screen cutout 77 × 34 mm**.
- **Important clearance conflict:** the *active image* is **36.72 mm high**, already **2.72 mm taller than the cutout**. The whole board is **43.30 mm high**, requiring sufficient head interior space, standoffs and an updated bezel. Merely fitting its width is not enough.
- A bigger, eye-friendlier active display is attractive, but **Waveshare describes this exact 2.4-inch SKU as TFT, not IPS**. Check viewing angle/contrast in real lighting before committing.
- **Earlier benchmark firmware targeted a DIFFERENT module:** Waveshare 1.9inch LCD Module SKU 23822, **IPS ST7789V2, 170×320**, rotated to **320×170**; board 51.2 × 27.3 mm, active image 42.72 × 22.70 mm in landscape. [Manufacturer](https://www.waveshare.com/1.9inch-LCD-Module.htm) · [Wiki](https://www.waveshare.com/wiki/1.9inch_LCD_Module).
- **2.4-inch ILI9341 now has its own default C++/PlatformIO profile, with CI build passing.** Wiring, actual screen appearance, orientation and mechanical fit have not been physically tested.

**Purchase choice:** one 2.4-inch ILI9341 module, zero 1.9-inch modules; no order placed by ChatGPT. Real-world fit and viewing-angle acceptance remain open.

## Controller and active components (1 robot)

| ID | Component | Exact candidate/specification | Qty | Status / caveat | Research links |
|---|---|---|---:|---|---|
| E01 | Controller | **Espressif ESP32-S3-DevKitC-1-N8R8** (8 MB flash / 8 MB PSRAM version), 3.3 V GPIO | 1 | Selected test target; verify original board/module revision | [Espressif](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s3/esp32-s3-devkitc-1/user_guide_v1.0.html) · [Türkiye](https://www.beti.com.tr/urun/esp32-s3-devkitc-1-n8r8-gelistirme-karti) |
| E02 | Selected color LCD | **Waveshare 2.4inch LCD Module SKU 18366**, ILI9341, 240×320, SPI | 1 | Selected for purchase and code build ready; **physical fit not verified** | [Maker](https://www.waveshare.com/product/displays/lcd-oled/2.4inch-lcd-module.htm) · [Türkiye listing](https://www.ankarobot.com/2.4-240x320-ili9341-tft-lcd-ekran) (seller's exact manufacturer SKU must be confirmed) |
| E02a | Legacy alternative (do not buy) | Waveshare **1.9inch LCD Module SKU 23822**, IPS ST7789V2, 170×320 | 0 unless bench testing | No purchase. Old software fallback only | [Maker](https://www.waveshare.com/1.9inch-LCD-Module.htm) |
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
| M02 | LCD bracket + standoffs + opaque face lens/clear protector | 1 kit | Avoid blocking 2.4-inch **36.72-mm-tall active image** |
| M03 | Stable base and head-pivot support (bearing/shaft or mechanical support as needed) | 1 | Servo shaft should not bear unverified whole head weight |
| M04 | Servo horn, screw/collar and safe end stops | 1 set | Validate real servo and travel |
| M05 | M2/M3 stainless screws, nuts, thermal inserts and spacers | Sized kit | Confirm CAD hole/thread sizes |
| M06 | Matching JST/PH/GH wiring harness depending on chosen modules | 1 harness | **Do not assume 1.9-inch GH and 2.4-inch PH cables match** |
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
| E02 2.4-inch screen | 1,351 TL |
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

**Stage A — choose physical face FIRST.** Check real module type, active view dimensions vs head/bezel and view angle. Pick **either E02 or E02a**, not both unless deliberately comparing displays. Rebuild the correct display driver and test with the exact purchased breakout.

**Stage B — sensing and speech.** Add E03, E04, E06, E07; gesture E05 only if needed after near-field range test. Select prerecorded Turkish/Nohutçuk voice. Confirm file storage and audio volume.

**Stage C — safe movement, power, assembly.** Measure head mass and geometry; only then select servo torque, pivot, supply amperage, power distribution, fasteners, final 3D printed body.

### Current GitHub implementation vs hardware decision

| Software / hardware layer | Reality |
|---|---|
| Browser SVG face and 82 shop-day scenarios | Implemented; automated tests passed |
| ESP32-S3 C++ face | 2.4-inch ILI9341 is the successful default CI build; old 1.9-inch profile remains optional. Neither physically tested |
| Selected 2.4-inch ILI9341 face | Selected for purchase; 320x240 source and build verified, physical test pending |
| TTP223 / VL53L0X / APDS-9960 | Touch/ToF scaffolding for initial sensor candidates; not bench verified; gesture integration absent |
| MAX98357A, voice, head servo | Names shortlisted; drivers/hardware safety/actual robot assembly not completed |
| CAD | Prototype exists; final screen/servo/speaker-fit must be reworked |

The next implementation change should be **an explicit new hardware profile for 2.4-inch ILI9341, followed by compilation and a physical LCD-only bench test**. Avoid silently replacing the existing known-compiled 1.9-inch profile.
