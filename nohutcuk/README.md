# 🌱 Nohutçuk — Nohut Falafel Robot Mascot

> **Status: concept & product requirements, not yet manufactured.** Nohutçuk is the friendly, modular, animated mascot for **Nohut Falafel**, designed to interact with guests, appear in social media, and eventually receive safe restaurant-event notifications.


## 🌈 Multicolor Eye Studio — live browser simulator

**Preview:** https://abdallahkhayroun00-crypto.github.io/brand-management-proposal/nohutcuk/

The simulator is implemented in [index.html](index.html), [styles.css](styles.css), and [app.js](app.js), using **HTML, CSS, JavaScript and SVG** (no build step or external JS libraries).

- All 20 documented face states: normal, happy, in love, shy, laughing, sad, angry, sleeping, surprised, thinking, cool, kissing, hungry, dizzy, bored, celebrating, hello, goodbye, confused and drama.
- Multicolor eyes by emotion (aqua/blue, pink, amber, mint, purple), rainbow gradient mode and a custom color picker; the body follows the matte-black/green Nohut Falafel concept.
- Adjustable reaction duration, blink interval, animation speed; natural blinking, pointer gaze, idle and optional automatic sleep.
- Simulated proximity welcome with cooldown, single/double/triple/long touch, wave, friendship stages, photo/selfie, funny reactions, holidays, restaurant-PC notifications and speech preview in Turkish/English/Arabic when supported by the browser.
- One-click automatic walkthrough of the 20 moods; action history. **No games**, following the approved scope.
- **No external integrations or hardware control:** touch/proximity/payment/order buttons simulate events only. This prototype does not connect to marketplace APIs, POS, customer data, Wi-Fi robot hardware or servo motors.

**Run locally:** open the nohutcuk/index.html file in a browser (or serve the repository root with python -m http.server 8000 and open http://localhost:8000/nohutcuk/). The browser UI is designed for desktop and mobile. Browser speech depends on installed voices and requires the user to enable it.

**Hardware decision:** the reference images show multiple simultaneous luminous colors. A **monochrome OLED cannot reproduce them**. Choose and test a compatible color OLED or IPS/TFT display (exact panel and ESP32-S3 graphics stack TBD) *before* freezing the CAD face opening. SVG is a desktop preview; the final microcontroller renderer must be ported to its display resolution and firmware environment.

## 🖨️ Published 3D CAD prototype files — GitHub verified

**All the following are now committed and verified in this repository:**

| What you need | GitHub file / folder | Description |
|---|---|---|
| **All-in-one ZIP** | [Download complete STL + STEP + source package](downloads/NOHUTCUK_CAD_STL_COMPLETE_PROTOTYPE.zip) | CAD prototype bundle (not a tested printer profile) |
| **One-piece merged STL** | [NOHUTCUK_ONE_PIECE_SOLID_STATUE.stl](STL_Merged/NOHUTCUK_ONE_PIECE_SOLID_STATUE.stl) | One connected watertight **decorative statue**; cannot hold replaceable electronics |
| **All-parts assembled reference** | [NOHUTCUK_ALL_PARTS_ASSEMBLED_REFERENCE.stl](STL_Merged/NOHUTCUK_ALL_PARTS_ASSEMBLED_REFERENCE.stl) | View all components in assembly positions; **16 separate shells, not a single fused print** |
| **16 individual STL components** | [STL_Individual/](STL_Individual/) | Edit/inspect separate parts, coordinates suitable for assembled preview |
| **16 initially oriented STL components** | [STL_Print_Oriented/](STL_Print_Oriented/) | Starting orientations to test in Cura/PrusaSlicer/Bambu Studio |
| **2 STEP files** | [STEP/](STEP/) | CAD interchange for modular assembly and one-piece object |
| **Editable Python CAD source** | [CAD_Source/](CAD_Source/) | Parametric CadQuery generator, print orientation & mesh checks |
| **Mesh reports** | [Docs/](Docs/) | Validation of watertight geometry and connectedness |

**Prototype geometry dimensions:** approximate total height 155 mm including leaves; head 100 mm wide × 58 mm tall × 50 mm deep; body 74 mm wide × 47 mm tall × 58 mm deep. The 77 × 34 mm display cutout is a *placeholder* and needs an actual selected color display's measurements.

The 16 individual STL files, 16 oriented STL files and single connected one-piece mesh passed automated geometric checks. **These are not physically test-printed and are not confirmed to fit any specific OLED/TFT screen, servo, ESP32-S3, sensors, cables or battery.** The one-piece figure is for decorative printing; use the modular set for developing the functional robot. **No final 3MF slicer preset, firmware, tested wiring diagram or physical assembly has been completed.**

## Project links

- [Restaurant QR Menu](../nohut-menu/)
- [Restaurant POS concept](../pos-demo/)
- [Complete feature catalog](docs/FEATURES.md)
- [Mechanical & electronics design](docs/HARDWARE_AND_3D_PRINTING.md)
- [Restaurant integration contract](docs/RESTAURANT_INTEGRATION.md)
- [Implementation roadmap](docs/ROADMAP.md)
- [Reference-image status](assets/README.md)

## Vision

Nohutçuk has three roles:

1. **Friendly companion:** emotion-filled expressive OLED eyes, gentle servo movement, spoken greetings, touch/proximity interaction and natural expressive behaviors.
2. **Restaurant helper:** optional notifications for new/ready/delayed/cancelled orders and confirmed transactions; the restaurant POS remains the authoritative source.
3. **Social-media mascot:** photo/selfie/reels modes, QR-menu companion and festive animations.

**Style:** matte-black rounded rectangular head, recessed animated display, matching black base with Nohut Falafel leaf logo, small green leaf/seedling top piece, optional warm base lighting. Keep green/cream brand colors, matching the restaurant's current QR menu. The illustrations are **visual references**, not dimensionally validated engineering drawings.

## Core interaction loop

`IDLE / SLEEP` → detect proximity (with cooldown) → wake, eye animation and “Hoş geldiiin!” → respond to touch, show an expressive reaction and return to idle. Touch patterns: single = smile; double = shy; triple = hearts; long = calm/relax. Friendship-mode reactions progress from shy to happy, hearts and a small dance. Motion and speech remain optional/mutable with quiet mode.

## Feature inventory

**Visual emotions:** Normal, Happy, In Love, Shy, Laughing, Sad, Angry, Sleeping, Surprised, Thinking, Cool, Kissing, Hungry, Dizzy, Bored, Celebrating, Hello, Goodbye, Confused and Drama. Initial functional proposal described 15 expressive emotions; the second visual reference adds states such as Normal, Hello, Goodbye, Confused and Drama.

**Guest interactions:** Welcome, Pet Me, Look at Me, Wave, Friendship Mode, photo/selfie and gentle greetings.

**Funny behaviors:** Drama Mode, Don't Leave Me, Fake Sleeping, Dance Mode, Cool Mode, Shy Mode, Love Attack and Falafel Lover.

**Marketing:** Photo Mode, Selfie Mode, Instagram Mode (“Beni etiketle!”), Reels Mode, celebrations for Ramadan/Eid/New Year/birthdays, and QR Menu Companion.

**Languages:** Turkish, English, Arabic voice samples; prerecorded audio is the preferred initial approach. Configurable language, volume, mute and quiet periods.

**Smart behaviors:** Auto Sleep, Random Eye Movement, Mood System, Affection Level, Random Reactions, Energy Simulation, Quiet Mode, Surprise Expressions and Auto Recovery.

For detailed trigger/response specifications and all feature descriptions, read [FEATURES.md](docs/FEATURES.md).

## Engineering — provisional, not a print-ready design

- Main controller: **ESP32-S3**, Wi-Fi.
- Animated face: **OLED** screen (exact dimensions/resolution not chosen).
- Inputs: head-touch sensor, proximity sensor, optional buttons/gesture or camera hardware.
- Output: 1–2 servo motors, speaker + optional amp, optional RGB LEDs.
- Expansion: optional microSD, modular electronics tray, serviceable battery/power compartment.
- Power: USB-C preferred; voltage, power budget, fusing, thermal limits and battery architecture are **TBD**.
- Body: PLA or PETG, modular housing, removable faceplate/rear cover, internal screen and servo mounts.
- Early specification envelope: about **12–15 cm tall, 9–10 cm wide, 7–8 cm deep**. An infographic instead illustrates **85 mm width / 70 mm head / 60 mm base**; these are **illustrative and not approved CAD dimensions**.
- Required physical parts: head front/bezel, rear shell, screen bracket, electronics tray, servo mount, body, bottom cover/base, detachable leaf ornament, fasteners.

**Prototype STL and STEP files are now present and geometrically checked in this GitHub repository.** Exact electronics fit, printer profiles, final wiring and firmware still require development and testing. Marketing infographics do not prove print-fit.

## Planned deliverables

`cad/`: dimensioned editable STEP/native CAD; `stl/`: validated printable parts; `slicer/`: tested 3MF profiles; `electronics/`: wiring schematic and BOM; `firmware/`: versioned ESP32-S3 code; `assets/`: reference images, eye graphics and voice files; `docs/`: assembly, testing and maintenance instructions.

## One complete version — all features together

**Nohutçuk has ONE intended complete release, not V1–V6.** This single release is meant to include the full approved scope, with no later-version dependency:

- All face expressions, touch sensing, proximity welcome, greeting/voice, safe servo movement, look/wave interactions and friendship behavior.
- Funny behaviors, mood/idle/quiet modes and surprise expressions. **No games, challenges, scores or game menus.**
- Photo/selfie/Instagram/Reels and Ramadan/Eid/New Year/birthday modes.
- Nohut Falafel QR-menu companionship, plus notifications from **our restaurant's PC management application** over local Wi-Fi. Nohutçuk never connects directly to Trendyol Go, Yemeksepeti, Migros Yemek, POS terminals or their APIs.
- Modular printable body, 3D CAD/STL/3MF deliverables, electronics, wiring, firmware, assembly instructions and tests.
- All intended configuration options, including Turkish/English/Arabic voice cues.

**Build work can be organized into technical tasks and tested in sequence, but those are not separate product versions.** The single functional robot is not yet built: a first CAD/STL/STEP prototype now exists, but firmware, real hardware fitting, physical print tests and live PC-system integration must still be completed. See [one-release completion checklist](docs/ROADMAP.md).

### Integration boundary

**Single data source for the robot: the Nohut Falafel PC management app we are building.** The PC application processes and validates all order/payment events from its own database and authorized connections, then sends a **minimal, sanitized notification** to the robot via local Wi-Fi. The mascot itself has **no direct third-party API integrations**, does not poll marketplaces or POS devices, and never sees customer personal data, credentials or card details. It cannot authorize payments. The PC app continues normally if the mascot is offline. See [RESTAURANT_INTEGRATION.md](docs/RESTAURANT_INTEGRATION.md).

### Reference materials

Two supplied Nohutçuk concept infographics were provided on 26 October 2026:
1. **“Infographie du robot mascotte Nohutçuk-1.png”** — English full feature panels, modular design, variants and package ideas.
2. **“Nohutçuk, le robot mascotte du falafel-2.png”** — Turkish emotion matrix, guest interactions, restaurant events, modular diagram, indicative dimensions.

Original images are included in the companion archive; see [assets/README.md](assets/README.md) for GitHub upload status. Do not treat rendered concept images or their “download ZIP” labels as proof of existing engineering files.

© Project concept for Nohut Falafel.