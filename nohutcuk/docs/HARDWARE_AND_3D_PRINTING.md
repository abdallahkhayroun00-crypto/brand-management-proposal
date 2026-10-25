# Hardware, CAD and 3D-printing design

> **Concept / engineering backlog. Nothing here is a tested STL or a final electrical diagram.**

## Visual target and reference dimensions

- Rounded rectangular **matte-black head**, recessed dark OLED face, minimal bright animated eye shapes.
- Black base with **Nohut Falafel** logo; optional soft amber or green underglow.
- Top **two-leaf green plant ornament**, detachable and replaceable.
- Optional black/green/white/wood-look plastic shells using the same mechanical interface.
- Concept envelope from first proposal: **height 120–150 mm; width 90–100 mm; depth 70–80 mm**.
- The second infographic independently shows approximately **85 mm overall width, 70 mm head height, 60 mm body height and 60 mm depth**. These are *concept measurements*, not verified or reconciled. **Final dimensions cannot be fixed until component models are chosen**.

## Mechanical architecture

Exploded modular stack (top to bottom):

1. Removable leaf/plant accessory, with no exposed sharp attachment.
2. Interchangeable face bezel.
3. Head front shell, OLED lens opening and face display cradle.
4. Back head shell / maintenance access.
5. Servo collar + tilt mechanism; clearance for 1 or optional 2 motors.
6. Central electronics carrier with ESP32-S3 and board mounts.
7. Body/main torso shell with logo and sound-port option.
8. Speaker enclosure / optional battery module and future expansion bay.
9. Weighted/stable base and nonslip feet; optional diffused LED ring.
10. Cable channels, mounting screws and removable service cover.

Design rules:
- Keep all externally accessible edges rounded and comfortably handled.
- Use captive screws or secured fasteners where possible; don't leave loose small parts near children.
- Include proper air gaps, strain relief and ventilation; no exposed electric contacts.
- Avoid needless printed supports; choose wall thickness and bridging per actual printer/material.
- Keep motor hard-stop clearances and avoid collision with rear wires/speaker.
- Label removable face/front and electronics platform for service.
- Maintain interchangeable connection geometry across color variants.

## Provisional printable part naming

```text
cad/             (future editable source — NOT present)
stl/
  01_head_front.stl
  02_head_rear.stl
  03_face_bezel.stl
  04_display_mount.stl
  05_servo_bracket.stl
  06_electronics_tray.stl
  07_body_shell.stl
  08_base_cover.stl
  09_leaf_accessory_left.stl
  10_leaf_accessory_right.stl
```

**These are proposed target filenames, not fabricated files.** Choose a CAD package and validate hole locations after physical parts are measured. Source CAD + STEP + STL + optional 3MF + renders will be a release package after prototypes pass fit checks.

## Electronics / provisional BOM

| Component | Suggested family | Purpose | Status |
|---|---|---|---|
| Controller | ESP32-S3 dev board | Wi-Fi and local state machine | family selected, model TBD |
| Face display | 1 or 2 OLED panel(s) | animated eyes | type/size/resolution TBD |
| Touch | capacitive touch sensor | petting head | model TBD |
| Movement | 1 or 2 mini servos | nod / tilt | torque and fit TBD |
| Proximity | ToF / IR distance sensor | wake on approaching guest | model TBD |
| Sound | mini speaker | words/music/tones | impedance and model TBD |
| Amplifier | suitable audio module | drive speaker as required | optional / TBD |
| Buttons | momentary pushbuttons | game inputs | optional / TBD |
| Light | addressable RGB LEDs | base illumination | optional / TBD |
| Audio storage | microSD or flash | prerecorded voice cues | optional |
| Power | approved USB-C source | low-voltage supply | design TBD |
| Connectors | keyed internal connectors | modular repair | specify during wiring |

The image annotations show **ESP32-S3**, OLED, servo, speaker, proximity, touch, RGB LED, Wi-Fi and modular electronics — use them as product requirements, not as verified schematic wiring.

## Electronics integration rules

- Calculate servo **stall current**, amplifier draw and screen draw before committing to regulator/USB-C implementation.
- Separate servo supply/decoupling from logic supply as required; use common reference only when correctly designed.
- Safe low-voltage enclosed wiring with proper fusing, strain relief and thermal checks.
- Use a known-good local power supply during prototypes; no improvised Li-ion battery without protection, charging and enclosure design.
- Avoid blind servo travel into hard stops; hardcode safe angle limits after assembly.
- For proximity sensing, minimize false triggers with debounce/cooldown.
- Place physical mute or quiet-mode control if sound is enabled.
- Audio and Wi-Fi must not compromise restaurants' other operational electronics; evaluate RF conditions.

## Proposed firmware architecture

```text
boot / self-test
  ├── sensor drivers (touch, distance, optional buttons)
  ├── OLED eye renderer / animation scheduler
  ├── servo controller with travel limits
  ├── sound player
  ├── game and gesture state machine
  ├── local Wi-Fi event listener (in the single complete version; dependent on secure integration testing)
  ├── admin controls / quiet mode
  ├── fault monitor and telemetry (no personal data)
  └── idle / low-power manager
```

Priority: hardware safety > confirmed alert > live guest interaction > animation. Use nonblocking timings so Wi-Fi and input detection remain responsive. Provide offline graceful behavior.

## Print workflow — definition of 'ready to print'

A slicer cannot guarantee that an arbitrary STL fits the actual electronics. Completion checklist:

1. Select/buy/measure actual component SKUs and all connector clearance.
2. Produce parametric CAD with tolerance notes and fastening scheme.
3. Export manifold, watertight, correct-scale STL parts.
4. Test in slicer (Cura, PrusaSlicer or Bambu Studio); supports/orientation, wall count, material profiles and dimensional scale.
5. Print head front, bracket, servo neck and screen fit test before full body.
6. Test movement, access, thermal behavior, drop/stability and cable strain.
7. Iterate CAD and issue release version and changelog.
8. Provide **assembly guide (PDF), wiring diagram, BOM for Türkiye, firmware**, and optional tuned 3MF.

**Terminology:** STL = triangle geometry mesh; STEP = editable-ish 3D exchange geometry; 3MF = print-project settings, if supported; G-code = machine-specific sliced instructions. No one should present an untested STL as “ready print.”