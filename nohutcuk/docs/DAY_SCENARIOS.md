# Nohutçuk — 82 Opening-to-Closing Shop Scenarios

**Scope:** deterministic mascot **software simulation** with the example Nohut Falafel shop day **10:45–21:30**. These clock times are an assumed operating window for this test, not a real-time opening-hours verifier. No online restaurant APIs, payments, personal data, hardware motors or sensors are connected here.

## Verification

- **82 predefined named cases** checked by `nohutcuk/tests/day.mjs`.
- **63 safety/service matrix checks**, including quiet, closed, cleaning, offline, fault and power modes.
- **4,000 deterministic pseudo-random interaction events** across 50 independently initialized simulated days.
- **All passing in GitHub Actions** at time of this documentation (re-run CI after each change).
- UI: go to the **Shop Day Tests** tab in [the browser simulator](../index.html) to select a phase, open any scenario, run all checks or watch an accelerated silent day preview.
- Both shown and intentionally ignored reactions can be **correct**; muted/closed/safety events must not be answered with cheerful speech.

## Expected behavior and priorities

1. A powered-off mascot never reacts; an unresolved fault overrides customer interactions. Staff acknowledgment restores safe state.
2. The robot does not greet people before opening or after closing. Repeated detection within **30 seconds** is suppressed.
3. Automatic talking is **rare**: minimum 22 seconds between short phrases and 60 seconds before repeating the same phrase. This is behavior-model policy; live browser speaking follows its separate speech engine.
4. In a lunch rush, staff-muted mode or cleaning, speech and audible effects are suppressed; dance/reels are refused in busy/muted mode; ordinary guest-friendly eye gestures may remain.
5. Photo/selfie/social poses hold their animation for up to **10 seconds**; incidental touches cannot interrupt, but shop closing and safety issues can.
6. If Wi-Fi disconnects, locally simulated touch and greeting behaviors remain available. Future PC notifications must tolerate dropped Wi-Fi and never be required for restaurant operations.
7. A worker must explicitly initiate birthday and other service-linked interactions; simulated manual actions must not pretend that Nohutçuk can see hands or identify a customer's face.
8. At closing, previous performances, promises to speak, movements and sounds must stop; sleep/off visuals become the default.

## All 82 named situations

### Preparation — 10:25–10:44 (10 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T001 | Power on while shop closed | `powerOn` | Ignored (correct) |
| T002 | Closed before opening | `approach` | Ignored (correct) |
| T003 | Touch during preparation | `single` | Ignored (correct) |
| T004 | Wave before opening | `wave` | Ignored (correct) |
| T005 | Try opening too early | `open` | Ignored (correct) |
| T006 | Already closed on boot | `close` | Ignored (correct) |
| T007 | Sensor fault before opening | `fault` | Reaction shown |
| T008 | Fault acknowledged before opening | `clearFault` | Reaction shown |
| T009 | Power outage before opening | `powerOff` | Reaction shown |
| T010 | Restart while closed | `powerOn` | Reaction shown |

### Opening — 10:45–11:14 (11 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T011 | Open shop at 10:45 | `open` | Reaction shown |
| T012 | Double opening is ignored | `open` | Ignored (correct) |
| T013 | First guest comes in | `approach` | Reaction shown |
| T014 | Second near trigger too soon | `approach` | Ignored (correct) |
| T015 | Guest remains near sensor | `approach` | Ignored (correct) |
| T016 | Greet new arrival after cooldown | `approach` | Reaction shown |
| T017 | Person walking past door | `walkPast` | Ignored (correct) |
| T018 | Accidental double sensor pulse | `tapping` | Ignored (correct) |
| T019 | Long gentle head pet | `long` | Reaction shown |
| T020 | Single head tap | `single` | Reaction shown |
| T021 | Two taps make robot shy | `double` | Reaction shown |

### First guests / before lunch — 11:15–12:59 (13 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T022 | Three taps show love | `triple` | Reaction shown |
| T023 | Wave by staff control | `wave` | Reaction shown |
| T024 | Unknown gesture without camera | `unauthorized` | Ignored (correct) |
| T025 | Look at visitor without face recognition | `look` | Reaction shown |
| T026 | Quick goodbye after hello | `farewell` | Reaction shown |
| T027 | Too much automatic talking prevented | `triple` | Reaction shown |
| T028 | Touch while network is offline | `single` | Reaction shown |
| T029 | Reconnect after Wi-Fi returns | `wifiOn` | Reaction shown |
| T030 | Repeated Wi-Fi loss ignored | `wifiOff` | Ignored (correct) |
| T031 | Photo pose 10 seconds | `photo` | Reaction shown |
| T032 | Pet during photo pose ignored | `single` | Ignored (correct) |
| T033 | Another photo after pose | `photo` | Reaction shown |
| T034 | Staff cancels photo pose | `socialStop` | Reaction shown |

### Lunch rush — 13:00–15:59 (12 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T035 | Rush-hour silent mode starts | `crowdOn` | Reaction shown |
| T036 | Welcome without voice in rush | `approach` | Reaction shown |
| T037 | Touch should be quiet in rush | `single` | Reaction shown |
| T038 | Love reaction no speech in rush | `triple` | Reaction shown |
| T039 | No dance to distract workers | `dance` | Ignored (correct) |
| T040 | No reels performance in rush | `reels` | Ignored (correct) |
| T041 | Busy mode does not double-activate | `crowdOn` | Ignored (correct) |
| T042 | Worker requests mute | `staffMute` | Reaction shown |
| T043 | Muted robot stays visually interactive | `single` | Reaction shown |
| T044 | Unmute after busy period | `staffUnmute` | Reaction shown |
| T045 | Crowd over restores normal movement | `crowdOff` | Reaction shown |
| T046 | No-op crowd reset when not busy | `crowdOff` | Ignored (correct) |

### Afternoon — 16:00–18:59 (13 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T047 | Rest after 5 min inactivity | `idle` | Reaction shown |
| T048 | Do not sleep immediately after touch | `idle` | Ignored (correct) |
| T049 | Wake on new guest after rest | `approach` | Reaction shown |
| T050 | Staff starts cleaning | `clean` | Reaction shown |
| T051 | Touch while cleaning ignored | `single` | Ignored (correct) |
| T052 | Welcome while cleaning ignored | `approach` | Ignored (correct) |
| T053 | Cleaning finished | `unclean` | Reaction shown |
| T054 | Birthday only with staff action | `birthday` | Reaction shown |
| T055 | Untrusted birthday trigger blocked | `birthday` | Ignored (correct) |
| T056 | Selfie holds face pose | `selfie` | Reaction shown |
| T057 | Instagram pose for photo | `instagram` | Reaction shown |
| T058 | Staff starts quiet music/dance demo | `dance` | Reaction shown |
| T059 | Worker announces falafel is ready | `foodReady` | Reaction shown |

### Evening — 19:00–21:29 (12 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T060 | Evening guests welcomed normally | `approach` | Reaction shown |
| T061 | Fast farewell stays friendly | `farewell` | Reaction shown |
| T062 | Photo request during evening | `photo` | Reaction shown |
| T063 | Battery/power goes out | `powerOff` | Reaction shown |
| T064 | Touch ignored while off | `single` | Ignored (correct) |
| T065 | Power returns without re-greeting | `powerOn` | Reaction shown |
| T066 | Sensor reports fault | `fault` | Reaction shown |
| T067 | Guest interaction ignored during fault | `approach` | Ignored (correct) |
| T068 | Dance ignored during fault | `dance` | Ignored (correct) |
| T069 | Fault cleared by worker | `clearFault` | Reaction shown |
| T070 | Repeated fault clear is no-op | `clearFault` | Ignored (correct) |
| T071 | Unknown commands do nothing | `unauthorized` | Ignored (correct) |

### Closing — 21:30 (5 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T072 | Shop closes exactly at 21:30 | `close` | Reaction shown |
| T073 | Close twice does not talk twice | `close` | Ignored (correct) |
| T074 | No guest welcome after closing | `approach` | Ignored (correct) |
| T075 | Closing cancels active photo | `close` | Reaction shown |
| T076 | Closing cancels celebration | `close` | Reaction shown |

### After closing — 21:31 onward (6 cases)

| ID | Situation | Input | Expected |
|---|---|---|---|
| T077 | No accidental night speech | `triple` | Ignored (correct) |
| T078 | No late-night music command | `dance` | Ignored (correct) |
| T079 | Reopening after closing blocked | `open` | Ignored (correct) |
| T080 | Restart after closing stays asleep | `powerOn` | Reaction shown |
| T081 | No interaction if forgot close command | `approach` | Ignored (correct) |
| T082 | Reopen command outside hours rejected | `open` | Ignored (correct) |

## Bugs and boundary conditions under test

| Failure mode | Fix/required protection |
|---|---|
| Repeating welcome for the same nearby customer | 30-second greeting cooldown and no voice spam |
| Touch during photo | Hold photo pose until timeout; close/fault overrides |
| Talking or performing during rush / cleaning | Quiet/movement suppression and ignored dances |
| Friendly greeting after closing | Reject all guest events outside operating state |
| Wi-Fi outage stopping local interactions | Keep touch and face reactions independent of network |
| Power loss or safety fault | Block normal reactions until recovery |
| Multiple open/close commands | Idempotent transitions |
| Accidental rapid touch pulses | Suppress simulated sensor bounce; **real sensor debounce requires hardware** |
| Face tracking/hand gesture recognition claims | Treat as simulated; camera-free proximity does not track faces |
| Service or payment data reaching mascot | No such live inputs in this browser experience |

## What this does **not** validate

Automated simulation proves the logic coded in `day.js` behaves as its specifications say. It does **not** prove the response of physical proximity/touch sensors, voice pleasantness, servo angle/power safety, real opening hours, accidental hardware restarts, actual Wi-Fi deliveries or restaurant platform integrations. Those need bench/field testing on the eventual ESP32-S3, color display, speaker, sensors and PC app.
