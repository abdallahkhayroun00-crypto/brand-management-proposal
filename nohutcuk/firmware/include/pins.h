#pragma once
// PROVISIONAL, breadboard ONLY — Espressif ESP32-S3-DevKitC-1 (not every ESP32-S3 variant).
// DEFAULT screen: Waveshare standalone 2.4" SPI TFT ILI9341 (SKU 18366), 240x320.
// LEGACY reference: Waveshare 1.9" LCD ST7789V2, 170x320.
// Both use SPI and 8 labeled signals; verify PH2.0 connector pin order on the actual 2.4".
// Compare every name with the silkscreen AND board schematic before powering.
// Never power motors or a loudspeaker directly from GPIO/ESP32 3V3 pins.
namespace nohut {
constexpr int LCD_DC    = 9;
constexpr int LCD_CS    = 10;
constexpr int LCD_SCLK  = 12;
constexpr int LCD_MOSI  = 11;
constexpr int LCD_RST   = 8;
constexpr int LCD_BL    = 7;   // BACKLIGHT control input; only connect after checking module revision.
constexpr int TOUCH_OUT = 4;   // optional TTP223 OUT, active-high 3.3V only.
constexpr int TOF_SDA   = 17;  // future VL53L0X carrier SDA
constexpr int TOF_SCL   = 18;  // future VL53L0X carrier SCL
constexpr int SERVO_PWM = 16;  // RESERVED; servo disabled and not driven in bench firmware.
constexpr int I2S_BCLK  = 5;   // RESERVED; no audio driver in this build.
constexpr int I2S_LRC   = 6;
constexpr int I2S_DOUT  = 15;
// Both displays rotate to 320px width. The new 2.4" ILI9341 is 320x240,
// while legacy 1.9" ST7789V2 is 320x170 with a 35px RAM column offset.
#ifndef NOHUT_DISPLAY_ILI9341
#define NOHUT_DISPLAY_ILI9341 1
#endif
#if NOHUT_DISPLAY_ILI9341
constexpr int PANEL_NATIVE_W=240;
constexpr int PANEL_NATIVE_H=320;
constexpr int PANEL_OFFSET_X=0;
constexpr int FACE_W=320;
constexpr int FACE_H=240;
#else
constexpr int PANEL_NATIVE_W=170;
constexpr int PANEL_NATIVE_H=320;
constexpr int PANEL_OFFSET_X=35;
constexpr int FACE_W=320;
constexpr int FACE_H=170;
#endif
static_assert(FACE_W==320 && (FACE_H==240 || FACE_H==170),"Unsupported color face geometry");
static_assert(LCD_CS!=LCD_DC && LCD_CS!=LCD_RST && LCD_DC!=LCD_RST,"Conflicting display pins");
} // namespace nohut
