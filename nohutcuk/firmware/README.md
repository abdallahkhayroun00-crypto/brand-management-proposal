# Nohutçuk — ESP32-S3 color eyes firmware (bench project)

**Stage:** C++ proof-of-concept targeting **Espressif ESP32-S3-DevKitC-1** + **standalone Waveshare 1.9inch LCD Module**, controller ST7789V2, 170×320 SPI IPS (landscape 320×170). This is the *separate 8-pin LCD breakout*, not the combined Waveshare ESP32-S3-LCD-1.9 development board. Their wiring/firmware are **not interchangeable**.

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
- The screen model is an initial bench candidate. The 1.9-inch active image is small compared to the robot's concept render; validate it physically before final 3D printing.
- A successful build is not a successful hardware test. Do not power servo or speaker from the ESP32 GPIO or 3.3V pin. Use the separate electronics plan.

**No games; one approved product scope.**
