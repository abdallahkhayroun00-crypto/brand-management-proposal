# Nohutçuk — ESP32-S3 color eyes firmware (bench project)

**Selected screen (27 October 2026):** **3.2-inch ILI9341 SPI TFT 240×320** rotated to **320×240** with **ESP32-S3-DevKitC-1**. Concrete candidate in Türkiye: **Voltaj MZK-6 no-touch, 4-wire SPI**; seller lists a PCB of 89.3×55.04mm in landscape. The exact breakout connector/pin order and voltage **must be verified before wiring**. Do not substitute a 16-bit parallel Arduino Mega shield because it says ILI9341.

**Default PlatformIO profile:** `esp32-s3-ili9341-32` — selected **3.2-inch SPI ILI9341, 320×240**. Software reference profiles `esp32-s3-ili9341-24` and `esp32-s3-st7789-19` remain for regression testing only. The ILI9341 source code already handles 320×240 pixels; physical 3.2-inch pinout, viewing angle, rotation, backlight and mount have not been tested. **A successful firmware build is not a hardware compatibility certificate.**

**Mechanical restriction:** 3.2-inch active image ~64.8×48.6mm (landscape), retail breakout PCB ~89.3×55.04mm, and current head outer ~100×58mm/aperture 77×34mm. This leaves practically no mounting clearance in height. **Resize the head and enlarge the view window** before any final printing; an outer head ~115×75–80mm is a concept starting point, not validated CAD. See [BOM_TURKIYE.md](../docs/BOM_TURKIYE.md).


## Project files

- [platformio.ini](platformio.ini) — Arduino framework and Arduino_GFX library dependency.
- [include/pins.h](include/pins.h) — **provisional** breadboard GPIO pin mapping.
- [include/character.hpp](include/character.hpp) — portable C++ state logic (20 moods, cooldown, gesture response, sleep, photo hold).
- [src/main.cpp](src/main.cpp) — physical SPI 16-bit-color renderer and serial test commands.
- [tests/character_test.cpp](tests/character_test.cpp) — offline tests of portable state logic.
- [docs/ELECTRONICS_BENCH.md](../docs/ELECTRONICS_BENCH.md) — hardware choice and the all-important *safety + wiring checklist*.

## Build and test

Open this directory with VS Code + PlatformIO; or at the repository root:

\`\`\`bash
pio run -d nohutcuk/firmware
\`\`\`

To run portable tests without Arduino SDK on Linux/macOS:

\`\`\`bash
g++ -std=c++17 -Wall -Wextra -Werror -I nohutcuk/firmware/include nohutcuk/firmware/tests/character_test.cpp -o /tmp/nohut-test
/tmp/nohut-test
\`\`\`

**Uploading requires the correctly selected and carefully checked physical board and LCD.** Then use \`pio run -d nohutcuk/firmware -t upload\` and open a serial terminal at **115200 baud**.

Enter \`help\`; commands include \`list\`, \`next\`, \`demo\`, \`mood love\`, \`mood happy\`, \`mood celebrating\`, \`greet\`, \`tap1\`, \`tap2\`, \`tap3\`, \`long\`, \`photo\`, \`selfie\`, \`stop\`, \`quiet on\`, \`quiet off\`. These emulate triggers from the serial port and display the corresponding colored eyes — do not claim that real touch sensing or head movement is tested by serial input.

To try the **optional** TTP223, change \`-D NOHUT_ENABLE_TOUCH=0\` to \`1\` only *after* verifying its 3.3V digital output and connecting the input. To try the **optional** VL53L0X, verify an electrically safe carrier + I2C wiring, add \`Adafruit VL53L0X\` dependency to PlatformIO, then set \`-D NOHUT_ENABLE_TOF=1\`. None of those conditions are prerequisites for the display-only build.

## Limits

- It renders all 20 named emotions using colored geometric primitives. These are first-pass reproductions, not full pixel-perfect ports of the browser SVG artwork. The face refresh uses simple full-screen drawing, to be optimized after actual performance measurements.
- **No servo output; no audio amplifier/MP3 playback; no live Wi-Fi / restaurant PC integration.** Speaker/servo pins are reserved but not active. Silence setting is stored but has nothing yet to mute in this initial build.
- There is no RTC or shop schedule on hardware. Operating-hours cases still run solely in the *browser* day simulator.
- The screen model is an initial bench candidate. The 3.2-inch active image and PCB require a significantly taller head and view opening; validate it physically before final 3D printing.
- A successful build is not a successful hardware test. Do not power servo or speaker from the ESP32 GPIO or 3.3V pin. Use the separate electronics plan.

**No games; one approved product scope.**
