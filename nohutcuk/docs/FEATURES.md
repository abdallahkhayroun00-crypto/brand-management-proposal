# Nohutçuk — Complete Interactions & Features

This is the design **specification**, not a claim that electronics/firmware are finished. The Arabic/Darija source proposal and the two supplied infographics are the requirements references.

## 1. Character & visual expressions

Eyes animate on an OLED. A 1–2 servo head can tilt/nod when supported. Do not require a motor for every animation. The 15 initial expressions and the additional infographic states are:

| Mode | Face / behavior |
|---|---|
| Normal | bright open eyes, natural blinking |
| Happy / Mutlu | two smiling arcs; slight nod |
| In Love / Aşık | pink hearts; gentle tilt |
| Shy / Utangaç | small eyes, look away |
| Laughing / Gülüyor | squeezed cheerful eyes; rhythmic nod |
| Sad / Üzgün | drooping eyes, head down |
| Angry / Kızgın | narrowed eyebrows, gentle disapproving tilt |
| Sleeping / Uykulu | closed lids / zzz and low animation |
| Surprised / Şaşkın | big open eyes, slight tilt back |
| Thinking / Düşünüyor | asymmetrical eyes / '?' |
| Cool / Havalı | glasses-like or squinting eyes |
| Kissing / Öpücük | puckered face / heart animation |
| Hungry / Aç | excited circular eyes |
| Dizzy / Başı dönüyor | spinning eyes |
| Bored / Sıkılmış | half-closed eyes, slow blink |
| Celebrating / Kutlama | stars / sparkles |
| Hello / Selam | friendly eyes + greeting |
| Goodbye / Veda | farewell eyes |
| Confused / Kararsız | alternating uncertain looks |
| Drama | exaggerated face and recovery to laugh |

Optional: add nonrepeating random micro-animations to avoid mechanical monotony. Do not claim genuine feelings or vision capabilities without sensors.

## 2. Customer interaction states

**Welcome / Karşılama** — proximity detects approach; robot wakes, opens eyes, nods, says “Hoş geldiiin!” (or chosen language). Enforce a greeting cooldown so repeat readings do not spam guests.

**Pet Me / Başımı Okşa** — head touch:
- 1 touch → smile;
- 2 touches → shy;
- 3 touches → hearts;
- long press → closed eyes, relaxed gentle sound.
Optional “one eye opens” idle response after petting ends.

**Look at Me / Bana Bak** — a basic proximity sensor can detect presence, not accurately track a face. Directional tracking or actual gesture recognition requires appropriate extra hardware (sensors/camera), explicit privacy design and testing.

**Wave / El Salla** — button- or proximity-assisted interaction can be implemented; real hand-gesture recognition within this same complete release requires suitable detection hardware, an explicit privacy design, and testing.

**Friendship Mode / Arkadaşlık** — sequential interactions change scripted responses: first shy → second smile → third hearts → fourth short dance. Store temporary interaction count only; no guest identity required.

**Photo Mode** — hold an attractive still pose for approximately 10 seconds on activation.

## 3. No games — confirmed product decision

Nohutçuk is a friendly restaurant mascot, **not a gaming device**. No rock-paper-scissors, quizzes, reaction-time challenges, memory games, rhythm games, game controls, scoring or leaderboards. Touch, greetings, expressions and affectionate reactions are natural interactions, not games.

## 4. Eight funny behaviors

1. **Drama Mode:** repeated petting → exaggerated angry look → laughter.
2. **Don't Leave Me:** farewell command → sad eyes; “Yine gel, tamam mı?”
3. **Fake Sleeping:** fake asleep, wake surprised on touch.
4. **Dance Mode:** gentle head movements and coordinated face/music.
5. **Cool Mode:** cool expression followed by comic twist.
6. **Shy Mode:** blush and shy-looking eyes after a greeting.
7. **Love Attack:** animated hearts + happy sound.
8. **Falafel Lover:** receives allowed falafel order signal and celebrates.

## 5. Voice and sound

| Language | Sample phrases from concept |
|---|---|
| Turkish | “Hoş geldiiin!”, “Beni seviyor musun?”, “Başımı okşa!”, “Çok teşekkür ederim!”, “Yine beklerim!”, “Afiyet olsun!”, “Nasılsın?!” |
| English | “Hellooo!”, “You're my friend!”, “Pet my head!”, “Come back soon!” |
| Arabic / Moroccan Darija | “مرحبا بيك!”, “واش بغيتي نلعبو؟”, “شكراً بزاف!”, “بالصحة والراحة!” |

Start with **prerecorded voice assets**. Language selection, mute, quiet hours, noise-aware volume and no-sound busy mode in admin panel. Avoid autonomous recording.

## 6. Social media, loyalty & special occasions

- **Photo Mode** 10-second pose and **Selfie Mode** head tilt.
- **Instagram Mode:** hearts and “Beni etiketle!” / #Nohutçuk (subject to owner's approval).
- **Reels Mode:** scripted synchronized dancing/expressions for short recordings.
- **QR Menu Companion:** a small card and matching Nohut Falafel sign; QR opens public menu only.
- **Special Events:** Ramadan, Eid/Bayram, New Year, birthdays; themed eyes/hats *as optional physical decorations*.
- **Occasional surprise expressions:** natural, noncompetitive visual reactions without scores or puzzles.
- **Birthday celebration:** worker-activated greeting; avoid retaining personal birthdays unnecessarily.

## 7. Smart/autonomous behavior

| Function | Intended behavior |
|---|---|
| Auto Sleep | rest after inactivity |
| Random Eye Movement | natural blink/glance motions |
| Mood System | choose context-appropriate scripted responses |
| Affection Level | respond more enthusiastically to interactions |
| Random Reactions | vary responses to repeated inputs |
| Energy Simulation | lively morning, relaxed evening (simulated) |
| Quiet Mode | low-volume/no movement during service peaks |
| Surprise expressions | infrequent spontaneous face animations, with no challenge mechanic |
| Auto Recovery | restart from transient recoverable state; log real failures |

A simple priority model prevents overlapping behaviors: **safety / hardware fault > urgent operational alert > direct guest interaction > spontaneous expression > idle**. Implement interrupt limits so new events don't repeatedly interrupt a customer.

## 8. Restaurant event reactions

All restaurant events come **only from the Nohut Falafel PC management application**, never directly from marketplace or POS APIs. Full trigger details in [RESTAURANT_INTEGRATION.md](RESTAURANT_INTEGRATION.md). Planned reactions:

| Event | Face / cue |
|---|---|
| Trendyol Go new order | wake + distinct notification |
| Yemeksepeti new order | lively face + separate chime |
| Migros Yemek new order | optional platform notification |
| Table order | excited eyes |
| Extra order / new drink | quick nod |
| Card payment confirmed | smile + wink |
| Cash payment confirmed | celebratory hearts |
| Payment failure | confused face / caution |
| Delayed order | concerned look and chime |
| Order cancelled | sad |
| Preparation finished | celebrate |
| Closing time | “Good night” + Sleep |

## 9. Admin control — Nohutçuk Yönetimi

Restaurant manager can view robot connectivity, mute/unmute, change language, sound level, Birthday/Dance Mode, choose expressions, test sensors, adjust alerts and review last sanitized device event. Worker can optionally trigger a restricted friendly mode.

## 10. Future-safe design

Use detachable face panel, screen bracket, electronics deck, servo housing and removable leaf ornament; modularize the same body for classic black, green, white and wood-look/custom variations. **Appearance changes must not imply redesigned electronics or print-ready color variants.**

## Open design questions before production

Choose actual OLED module and front opening, servo model and kinematics, touch/proximity sensor, speaker/amp, controller power requirements, source CAD dimensions, fasteners and tolerances. Only then freeze STL/STEP models.