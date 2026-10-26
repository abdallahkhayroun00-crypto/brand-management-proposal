# Nohutçuk — electronics bench plan (color eyes first)

**Status: preliminary engineering selection, not a verified wiring diagram or shopping order.** The real restaurant mascot is one complete product; these are internal verification stages, not product versions. No games.

> **Newest purchase choice, 2026-10-27:** One **3.2-inch ILI9341 4-wire SPI TFT**, non-touch preferred (Voltaj MZK-6 candidate), rather than either 2.4-inch or 1.9-inch. Default code profile is `esp32-s3-ili9341-32`, matching ILI9341 pixel protocol and 320×240 geometry. **Seller-specific header/pinout, electrical levels and real rendering are not verified**, and the current head/bezel must be enlarged. See [BOM_TURKIYE.md](BOM_TURKIYE.md).

## First purchase / test candidates

| Part | Candidate | Why | Current software |
|---|---|---|---|
| Main controller | Genuine Espressif **ESP32-S3-DevKitC-1** (ideally **N8R8** if available) | Official development board, Wi-Fi, accessible pins; ESP32-S3 family is already in the approved design | PlatformIO board ID \`esp32-s3-devkitc-1\` |
| **Color face** | **3.2-inch ILI9341 SPI TFT 240×320**, no touch, shortlist **Voltaj MZK-6** | User-selected 3.2-inch face; about 89.3×55mm PCB in landscape, 64.8×48.6mm active view. Current 100×58mm head and 77×34mm aperture need redesign | Default 320×240 ILI9341 firmware profile; physical fit and wiring **not yet tested** |
| Pet sensor | 1× TTP223 capacitive touch breakout, active-high version (verify seller module) | One head-touch point; counts single/double/triple or long in software | Disabled by default, opt-in with \`NOHUT_ENABLE_TOUCH=1\` |
| Guest detection | 1× **VL53L0X breakout with onboard regulator and safe level shifting**, e.g. Adafruit or equivalent tested carrier | ToF distance detection without camera or face recognition | Optional, \`NOHUT_ENABLE_TOF=1\` and library after wiring tests |
| Sound amp | 1× **MAX98357A I2S mono** breakout | Intended for short **pre-recorded character voice clips** without continuous online speech | **Not implemented**; pins only reserved |
| Speaker | 1× enclosed **8Ω speaker**, rated appropriately for tested amplifier output | Little mascot voice. Test volume in the shop to avoid annoying guests | Not implemented |
| Head movement | 1× mini servo (SG90-size fit candidate, exact manufacturer/torque/stall current still TBD) | Gentle tilt/nod; must validate travel and stall torque with real head mass | **Not implemented or energized** |
| Wiring/test kit | Breadboard, quality jumpers, multimeter, USB data cable, known-good regulated 5V supply | Test safely before installing in printed head | Manual bench test |
| Power | **USB-C, mains-isolated approved supply** for eventual build; regulated servo/speaker branch sized from measured peak currents | No unprotected battery, no load powered from GPIO | Detailed power budget not verified |

**No need to buy everything immediately.** Start with the main board, exact LCD module, jumper wires and safe power. Verify that the colorful eyes run before choosing a body-sized sound/sensor/motor layout.

## Reference sources (manufacturer / engineering docs)
- Selected 3.2-inch non-touch 4-wire SPI retail candidate, Voltaj MZK-6: https://www.voltaj.net/tft-lcd-spi-seri-arayuzlu3.2-incili9341-ekran-modulu-dokunmatiksiz
- Reference 3.2-inch ILI9341 panel active area and board geometry: https://www.raystar-optronics.com/3.2-3.5-3.9-tft-lcd-display/240x320-ili9341.html
- Espressif DevKitC-1 pin map, variants and power: https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s3/esp32-s3-devkitc-1/user_guide_v1.0.html
- Adafruit VL53L0X **carrier**: https://learn.adafruit.com/adafruit-vl53l0x-micro-lidar-distance-sensor-breakout/pinouts
- Adafruit MAX98357A amplifier and speaker limits: https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/pinouts
- PlatformIO board ID: https://docs.platformio.org/en/latest/boards/espressif32/esp32-s3-devkitc-1.html

## Bench-only pin proposal (ESP32-S3-DevKitC-1)

These are **provisional ESP32 GPIO assignments only**, NOT actual 3.2-inch module pin numbers or an approved wiring harness. The Voltaj MZK-6 full pinout has NOT been independently verified. **Do not connect a screen until seller photos/schematic and voltage levels have been checked.** Read `firmware/include/pins.h`.

| Display breakout pin | DevKit GPIO | Purpose |
|---|---|---|
| VCC | **3V3** | Choose 3.3V supply; current capacity and wiring must be verified |
| GND | GND | Common ground |
| DIN | GPIO11 | SPI MOSI |
| CLK | GPIO12 | SPI SCK |
| CS | GPIO10 | Chip select |
| DC | GPIO9 | Command/data |
| RST | GPIO8 | Reset |
| BL | GPIO7 | Backlight **control**, not LED power; check module version and schematic |

Default software now initializes **Arduino_ILI9341**, 240×320 rotated to 320×240 for the selected 3.2-inch face. The prior 2.4-inch profile has the same pixel geometry, not necessarily the same electrical connector. Library is \`moononournation/GFX Library for Arduino\`. **If screen is clipped or mirrored, adjust offsets and rotation, not display wiring blindly.**

For later **optional** testing:
- TTP223 OUT (3.3V signal) → GPIO4, VCC according to breakout spec, GND common. One capacitive pad on insulated body head.
- VL53L0X breakout SDA → GPIO17, SCL → GPIO18, 3.3V and GND when compatible. The bare VL53L0X chip is **not** a 5V part; select an appropriate regulated carrier.
- GPIO5 / 6 / 15 reserved for future I2S BCLK / LRC / DOUT.
- GPIO16 reserved for **future** servo PWM. A servo must have separately sized power and common reference; **do not connect or power a servo in the first display test.**

ESP32-S3 **GPIO19/GPIO20 (native USB), GPIO0/45/46 (bootstrapping/restrictions)** are deliberately avoided. Rev-dependent onboard RGB pins are not required. Double-check all assignments if your actual board is NOT the official DevKitC-1.

## Critical safety gates

1. **No mains AC wires**, no exposed lithium pack/charger experiments. Use approved enclosed low-voltage supply.
2. ESP32 pins are **3.3V logic**. Never connect any 5V output directly to an ESP32 GPIO.
3. **Do not assume the purchased 3.2-inch breakout includes level conversion**. Check actual seller pinout, onboard regulator, panel VCC and 3.3V-compatible SPI signal levels before providing power.
4. Backlight pin may be an LED supply or control depending on the module. **Do not connect GPIO7 to BL until the actual 3.2-inch PCB's circuit and rating are verified.**
5. Measure idle and peak currents and enclosure temperature; don't size final power from assumed values.
6. Test **screen only** before attaching speaker, touch, ToF or servo.
7. A safe motor design needs actual head mass, servo stall-current data, mechanical hard stops, screw retention and cable strain relief. Current code does not drive motors.
8. Nohutçuk must never have payment/POS privileges or customer/card data. If later integrated, all sanitized notifications originate from the **restaurant PC application**, not from Yemeksepeti, Trendyol Go, or Migros directly.

## Test sequence

1. On PC, install VS Code and the PlatformIO extension. Open \`nohutcuk/firmware\` as project.
2. First compile: \`pio run -d nohutcuk/firmware\` from repo root. This **only validates build**, no wiring.
3. After comparing your real board/module revision with the pin map, wire **LCD + ESP32 only**. Keep motor and amplifier absent.
4. Connect the ESP32 board to PC with a USB data cable; \`pio run -d nohutcuk/firmware -t upload\` and \`pio device monitor -b 115200\`.
5. Serial commands: \`help\`, \`list\`, \`next\`, \`demo\`, \`mood happy\`, \`mood love\`, \`mood celebrating\`, \`tap1\`, \`tap2\`, \`tap3\`, \`long\`, \`photo\`, \`selfie\`, \`stop\`, \`greet\`, \`quiet on\`.
6. Validate all 20 moods, 320×240 landscape, pink/blue/mint/yellow, blinking, viewing angle, backlight behavior, heat, and stable operation. Photograph results; redesign 100×58 mm head and 77×34 mm viewing aperture for the 3.2-inch PCB/active image.
7. Add a TTP223 with \`NOHUT_ENABLE_TOUCH=1\` only after checking its output voltage, touch sensitivity, and insulation; test all gesture windows and false triggers.
8. Add VL53L0X with \`NOHUT_ENABLE_TOF=1\` only after confirming breakout/I2C pins and installing \`Adafruit VL53L0X\` dependency. Test guest range hysteresis (enter at ~650mm, reset after >1000mm), no repeated welcome within 30s.
9. Only then tackle short WAV/MP3 recordings, speaker/amplifier, quiet controls and safe servo movement.

## Status

- Browser simulator: 20 moods, 82 daily scenarios and logic tests exist; they are **not** real-world hardware validation.
- Portable C++ character logic and 320×170 color renderer are **implemented** in this repository.
- LCD **physical run**, speaker playback, live ToF, physical servo motion and safe print fit: **not verified**.
- The CAD files in this repo are prototypes. Do not print the final body until the exact screen/power/speaker/mount clearances have been checked.
