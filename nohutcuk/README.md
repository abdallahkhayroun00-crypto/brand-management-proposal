# 🌱 Nohutçuk — Nohut Falafel Robot Mascot

> **Status: concept & product requirements, not yet manufactured.** Nohutçuk is the friendly, modular, animated mascot for **Nohut Falafel**, designed to interact with guests, appear in social media, and eventually receive safe restaurant-event notifications.


## 🛒 Türkiye hardware BOM — researched, not final (2026-10-27)

**Full researched shortlist:** [BOM_TURKIYE.md](docs/BOM_TURKIYE.md), covering controller, LCD options, touch/proximity/gesture, voice amp/speaker, head servo, power, small electronics, wiring, 3D hardware, research links and provisional Turkish price references.

**Purchase decision (27 October 2026): buy ONE Waveshare 2.4-inch ILI9341 SPI TFT (SKU 18366), not the 1.9-inch reference. No order placed or hardware wired yet.** Official board is 70.5×43.3 mm and active screen is 48.96×36.72 mm horizontally, **taller than the existing 77×34 mm bezel opening**. Do not finalize CAD or print yet. **C++ firmware now defaults to the 2.4-inch ILI9341 (320x240)**; the legacy 1.9-inch ST7789V2 remains an optional reference. **Both builds pass GitHub CI; physical testing is pending.** This is documented so we do not accidentally buy a screen incompatible with the code.

## ✅ Full Shop-Day Simulation — 82 cases

**Try it:** open [Nohutçuk Eye Studio](./index.html) and select **Shop Day Tests**.

The mascot now includes a completely simulated operating-day rule engine in [day.js](day.js) with **82 named opening-to-closing situations**, **63 safety/service mode checks**, and **4,000 reproducible stress events** over 50 simulated workdays. Test inputs use an **example schedule of 10:45–21:30**. This is not a real operating-hours feed or proof of physical sensor performance.

**Full numbered checklist:** [DAY_SCENARIOS.md](docs/DAY_SCENARIOS.md) (all 82 situations grouped into 8 shop phases).

- Eight phases from pre-opening through opening, first guests, lunch rush, afternoon, evening, closing and after-hours.
- 30-second welcome debounce/cooldown, infrequent voice, child/accidental touch safeguards, worker-controlled birthday/photo and touch-safe 10-second poses.
- No talking/dance during rush, mute, cleaning or fault; idle rest; safe response to Wi-Fi outage, lost power, reconnection, unsafe input, repeated commands and closure.
- Live browser **Shop Day Tests** panel: run all scenarios; filter and select individual situations; preview a silent, accelerated day. A "pass" can mean **correctly ignoring** an event.
- The separate personal-character tabs stay independent of a real restaurant schedule. No external delivery-platform APIs, payments, customer data or hardware are wired into the test simulation.
- Automated acceptance: `node nohutcuk/tests/day.mjs` plus `node nohutcuk/tests/smoke.mjs` for UI wiring. GitHub Actions runs both.

**Important:** this proves the specified simulated software state transitions, **not** operation with real touch/proximity sensors, actual speaker/servo electronics, real-time Wi-Fi events or the restaurant POS application. Those remain separate hardware/integration tasks.

## 🔌 ESP32-S3 multicolor hardware and C++ firmware (bench stage)

**We have started actual embedded development**, not just browser simulations.

- [Electronics & wiring bench plan](docs/ELECTRONICS_BENCH.md) — component candidates, official sources, safe sequence, dimensions, provisional GPIO pin map.
- [PlatformIO project](firmware/) — ESP32-S3 board configuration and dependencies.
- [Actual 20-expression C++ face renderer](firmware/src/main.cpp) — 320x240 multicolor eyes for the selected SPI ILI9341 panel, with old ST7789V2 build retained.
- [Portable C++ character state machine](firmware/include/character.hpp) — 20 moods, hello cooldown, touch gestures and photo hold.
- [Host C++ tests](firmware/tests/character_test.cpp) — 20 emotion roundtrips, 30-second hello debounce, photo lock, sleep, quiet mode, uint32 clock rollover.
- [Firmware build CI](https://github.com/abdallahkhayroun00-crypto/brand-management-proposal/actions/workflows/nohutcuk-firmware.yml) — checks native logic and attempts an actual PlatformIO ESP32-S3 compilation.

**Proposed color face:** the **standalone 8-pin Waveshare 1.9inch IPS LCD Module, ST7789V2 170×320** rotated to 320×170, plus **Espressif ESP32-S3-DevKitC-1**. The module measures about 51.2×27.3 mm and its visible area about 42.72×22.70 mm. This fits nominally within the CAD prototype's placeholder opening (77×34 mm), but may **look too small compared to the artwork**; do not lock the outer shell without seeing the real panel first. This is a test-platform selection, not the final confirmed hardware package.

**Safety:** servo, amplifier and Wi-Fi-PC integration are NOT turned on in this initial firmware. TTP223 head touch and VL53L0X carrier distance sensor are future opt-in flags. This code is **not yet confirmed on a physically wired screen**; the GitHub C++/PlatformIO build is only a compile test. Browser JavaScript remains separate and operational.

## 🌈 Multicolor Eye & Sound Studio — live browser simulator

**Live preview:** https://abdallahkhayroun00-crypto.github.io/brand-management-proposal/nohutcuk/

Built with [index.html](index.html), [styles.css](styles.css), [app.js](app.js), the original [Web Audio synthesizer](audio.js) and a separate [selective voice engine](voice.js) in HTML, CSS, JavaScript and SVG. No additional build tools or external song libraries are necessary.

- **20 animated facial moods:** happy, shy, laughing, love, sleeping, surprised and 14 more, with neon cyan, pink, orange, green and purple; rainbow and custom color modes.
- **Character interactions:** simulated touch, proximity welcome, waving, friendship, funny reactions, social modes and seasonal celebrations.
- **Voice & Sounds tab** replaces the old restaurant/platform simulation tab. It includes small replayable speech cards, music and SFX. There are **no Yemeksepeti/Trendyol Go/Migros buttons** in the mascot's browser experience; the PC-system integration specification remains documented separately for future work.
- **Four original synthesized tunes:** Nohutçuk Theme, Tiny Dance, Sleepy Stars and Happy Hello, plus 10 manually playable samples and optional reactive sounds for emotions.
- **Talking, but only occasionally:** 7 short phrases (welcome, thanks, 3× head touch/love, goodbye, falafel, photo and birthday) in Turkish, English and Moroccan Arabic. Only specially triggered reactions speak; ordinary eye movements and most touches are silent. The simulated robot enforces a **22-second pause between automatic voice cues** and a **60-second repeat limit on the same phrase**. Test buttons bypass the timing so we can hear each phrase on demand. Browser speech is initially enabled; Quiet mode stops all speech.
- **Character voice studio:** choose from 3 Nohutçuk voice styles (**Minik**, **Yumuşacık**, **Zıpır**). Each style changes browser voice pitch and speed; browse voices installed for the selected Turkish/English/Arabic language. For genuinely personalized dialogue, select a phrase and supply your own short MP3/WAV clip — that clip replaces text-to-speech for that phrase during the active browser session, is not uploaded or saved by the app, and can be cleared. The underlying voice quality still varies by device; browser pitch changes alone cannot create a new voice actor.
- **Audio controls:** Music Play / Stop, main volume for sound and voice, effects opt-in, selective browser voice and private preview of your own audio file without uploading it.
- **No copyrighted tracks bundled:** Web Audio creates original playful instrument tones directly in the browser; for richer samples, use the local audio picker or later add licensed audio files.
- **No physical hardware:** face, touch and head movement are browser previews, not actual sensors/servos. Browser audio only plays after user input; system voice availability varies by platform.
- **No games:** the product's approved one-build scope remains unchanged.

**Run locally:** open nohutcuk/index.html in any modern browser, or serve the repository root using `python -m http.server 8000` and visit `http://localhost:8000/nohutcuk/`.

**Run automated checks:** `node --check nohutcuk/app.js`, `node --check nohutcuk/audio.js`, `node nohutcuk/tests/smoke.mjs`, `node nohutcuk/tests/audio.mjs` and `node nohutcuk/tests/voice.mjs`; GitHub Actions also executes these checks.

**Audio realism:** browser speech uses voices installed in the visitor’s operating system and may sound synthetic. For a consistent cute mascot voice in the physical build, use licensed or self-recorded short clips, a small speaker and an appropriate audio amplifier. No microphone or always-listening recognition is required. The PC simulator does not output actual ESP32-S3 firmware.

**Hardware requirement:** simultaneous multicolor eyes require an actual **color OLED or TFT/IPS display** rather than a monochrome OLED. Display hardware, speaker circuitry, ESP32-S3 firmware, power and mechanics need dedicated tests before the 3D print is approved.

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