# 🌱 Nohutçuk — Nohut Falafel Robot Mascot

> **Status: concept & product requirements, not yet manufactured.** Nohutçuk is the friendly, modular, animated mascot for **Nohut Falafel**, designed to interact with guests, appear in social media, and eventually receive safe restaurant-event notifications.

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

1. **Friendly companion:** emotion-filled expressive OLED eyes, gentle servo movement, spoken greetings, touch/proximity interaction, mini-games and easter eggs.
2. **Restaurant helper:** optional notifications for new/ready/delayed/cancelled orders and confirmed transactions; the restaurant POS remains the authoritative source.
3. **Social-media mascot:** photo/selfie/reels modes, QR-menu companion and festive animations.

**Style:** matte-black rounded rectangular head, recessed animated display, matching black base with Nohut Falafel leaf logo, small green leaf/seedling top piece, optional warm base lighting. Keep green/cream brand colors, matching the restaurant's current QR menu. The illustrations are **visual references**, not dimensionally validated engineering drawings.

## Core interaction loop

`IDLE / SLEEP` → detect proximity (with cooldown) → wake, eye animation and “Hoş geldiiin!” → respond to touch and optional games → return to idle. Touch patterns: single = smile; double = shy; triple = hearts; long = calm/relax. Friendship-mode reactions progress from shy to happy, hearts and a small dance. Motion and speech remain optional/mutable with quiet mode.

## Feature inventory

**Visual emotions:** Normal, Happy, In Love, Shy, Laughing, Sad, Angry, Sleeping, Surprised, Thinking, Cool, Kissing, Hungry, Dizzy, Bored, Celebrating, Hello, Goodbye, Confused and Drama. Initial functional proposal described 15 expressive emotions; the second visual reference adds states such as Normal, Hello, Goodbye, Confused and Drama.

**Guest interactions:** Welcome, Pet Me, Look at Me, Wave, Friendship Mode, photo/selfie, daily secret expression and weekly reaction challenge.

**Ten mini-games:** Taş Kağıt Makas; Guess My Mood; Reaction Challenge; Make Me Happy; Memory Game; Lucky Eyes; Follow the Rhythm; Don't Wake Me; Pet Challenge; Secret Expressions.

**Funny behaviors:** Drama Mode, Don't Leave Me, Fake Sleeping, Dance Mode, Cool Mode, Shy Mode, Love Attack and Falafel Lover.

**Marketing:** Photo Mode, Selfie Mode, Instagram Mode (“Beni etiketle!”), Reels Mode, celebrations for Ramadan/Eid/New Year/birthdays, and QR Menu Companion.

**Languages:** Turkish, English, Arabic voice samples; prerecorded audio is the preferred initial approach. Configurable language, volume, mute and quiet periods.

**Smart behaviors:** Auto Sleep, Random Eye Movement, Mood System, Affection Level, Random Reactions, Energy Simulation, Quiet Mode, Secret Easter Eggs and Auto Recovery.

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

**STL files are not currently verified as existing.** Neither are source CAD/STEP, 3MF, wiring diagrams or working firmware. Even when STL is available, slicing/calibration/fit-check are required before printing; a marketing infographic that says “ZIP/STL included” is not itself a downloadable print-ready kit.

## Planned deliverables

`cad/`: dimensioned editable STEP/native CAD; `stl/`: validated printable parts; `slicer/`: tested 3MF profiles; `electronics/`: wiring schematic and BOM; `firmware/`: versioned ESP32-S3 code; `assets/`: reference images, eye graphics and voice files; `docs/`: assembly, testing and maintenance instructions.

## Versions

| Version | Planned scope |
| --- | --- |
| V1 | OLED eyes / 15 core moods + head touch + stable idle loop |
| V2 | 1–2 servo movements, speech and proximity greetings |
| V3 | Ten games and playful character behavior |
| V4 | Local restaurant-POS event integration |
| V5 | Instagram/reels/celebrations and special modes |
| V6 | Advanced mood, modularity and refined interactions |

### Integration boundary

The existing PC-based restaurant system is the authority for orders and payments. A local gateway publishes a **sanitized notification** to Nohutçuk on the restaurant Wi-Fi. The robot does not receive customer personal data, POS credentials or card data, and never authorizes financial events. Online delivery-platform integration is separate and subject to official API access. See [RESTAURANT_INTEGRATION.md](docs/RESTAURANT_INTEGRATION.md).

### Reference materials

Two supplied Nohutçuk concept infographics were provided on 26 October 2026:
1. **“Infographie du robot mascotte Nohutçuk-1.png”** — English full feature panels, modular design, variants and package ideas.
2. **“Nohutçuk, le robot mascotte du falafel-2.png”** — Turkish emotion matrix, guest interactions, restaurant events, modular diagram, indicative dimensions.

Original images are included in the companion archive; see [assets/README.md](assets/README.md) for GitHub upload status. Do not treat rendered concept images or their “download ZIP” labels as proof of existing engineering files.

© Project concept for Nohut Falafel.