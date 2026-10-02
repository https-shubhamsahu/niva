# Niva showcase video: script and shot list

Target length: about 5:45. English narration with burned-in captions.

**Speakers:**
- **M1, M2, M3:** the three team members. Swap in your names.
- **FRIEND:** the person wearing the insole.
- **VO:** voiceover, recorded later in a quiet room. Any team member can record it.

**Rules for every shot:**
- **App footage:** every app shot is a raw phone screen recording, synced to the camera on the heel stomp. No mock-ups.
- **Numbers:** every number on screen shows its source in the bottom-right corner.
- **Banned words:** screening, diagnosis, fall risk, injury, patient, clinical, AI, accuracy %.

Before shooting, every readiness-gate item in the plan must work in a home dry run:
- app cleanup;
- firmware contact events;
- Test mode;
- shin strap and power;
- a pair of insoles, if available.

---

## 0:00–0:30 Cold open

| # | Time | Picture | Sound / words |
|---|---|---|---|
| 1 | 0:00 | Black | One stopwatch click. Silence. |
| 2 | 0:02 | ECU (extreme close-up): a thumb on a stopwatch. Rack focus to FRIEND wobbling on a wooden beam, holding one foot | M1, off camera, counting: "One… two…" |
| 3 | 0:06 | Sunrise at Marine Drive, 240 fps, feet only, many walkers | VO: "Every morning, India walks to stay fit." |
| 4 | 0:10 | Low tracking shot of FRIEND's shoe in slow motion | VO: "But nobody measures how." |
| 5 | 0:12 | **Split screen snaps in.** Left: the same heel landing. Right: the app, heel zone lights, then toe | Text on screen: **Heel first.** A soft tick sound on each zone. |
| 6 | 0:18 | Back to the beam. FRIEND wobbles. Split: the app counter goes 0 → 1 | M1, off camera: "One." The app ticks at the same instant. |
| 7 | 0:24 | Hold on the two counts side by side | VO: "What if the shoe kept score?" |
| 8 | 0:27 | Title card on black | Text: **NIVA**, then "Fit India's balance and walking tests, measured at the foot". Music hit. |

## 0:30–1:15 The problem (M1, at the college ground)

M1 stands on the ground holding the stopwatch, looking at the camera.

> **M1:** "India already has a national fitness test. It's the Fit India protocol, made by the sports and health ministries."
>
> *(Cutaway: the protocol PDF cover. Source: Fit India Fitness Protocols, 18–65, MoYAS with MoHFW.)*
>
> **M1:** "For balance, a tester like me watches you stand on one leg and counts every wobble. By eye."
>
> *(Cutaway: the Flamingo test, the tester's thumb on the stopwatch. Source: p. 24.)*
>
> **M1:** "The two-kilometre walk records one number: your finish time."
>
> *(Source: p. 22.)*
>
> **M1:** "And for the tree pose, the protocol itself says the benchmarks will be developed once there are enough data points."
>
> *(Cutaway: slow zoom on the p. 39 line, with that sentence highlighted. Source: p. 39.)*
>
> **M1:** "So we built something that collects those data points."

## 1:15–2:15 Meet Niva (M2, at the workbench)

Macro shots on a dark desk mat with soft window light.

> **M2:** "This is Niva. It's a foam insole with four small pressure sensors: heel, the base of the big toe, the outer forefoot, and the toe."
>
> *(Macro: each disc, then the real prototype photo labelled "real photo".)*
>
> **M2:** "A piezo disc under the heel feels each landing. A motion sensor and an ESP32 send everything to the phone over Bluetooth."
>
> *(Macro: the piezo, the IMU, the board. Then the strap going onto the shin.)*
>
> **M2:** "Here's the honest part. These sensors are cheap, and under your full body weight they max out. So Niva doesn't tell you force."
>
> *(Motion graphic: two traces rise and flatten at a dashed ceiling.)*
>
> **M2:** "But they're very good at timing: when each part of your foot lands, and when it lifts. And timing is exactly what these fitness tests ask about."
>
> *(The graphic highlights the edges with the labels "heel on", "toe on". Caption: "schematic, not measured data".)*

## 2:15–3:50 Three tests in the field (split screen)

Layout: left 1080×1080 action, right 840×1080 app recording, labelled **LIVE APP · REAL RECORDING**. Every take starts with a heel stomp for sync. Cut the stomp out of the final edit.

### Test 1: brisk walk (about 30 s, Marine Drive or the college track)
| Picture | Words |
|---|---|
| A title chip: "Test 1 · Brisk walk" | |
| FRIEND walks, low tracking shot at foot height. The app shows "collecting 1/12 … 12/12" | VO: "Fit India's walking advice says: let your heel land before your toes." *(Source: p. 28)* |
| The app reveals heel-first share and cadence | VO: "Niva checks that on every step, and shows your cadence, once it has twelve steps to go on." |
| FRIEND glances at the phone, smiles, keeps walking | FRIEND (natural, unscripted reaction) |

### Test 2: Flamingo balance test (about 35 s, college ground)
| Picture | Words |
|---|---|
| A title chip: "Test 2 · Flamingo balance" | |
| M1 runs it the official way, stopwatch and counting out loud. FRIEND on the beam | M1: "Ready… go." Then counting losses aloud. |
| The split shows the app counter rising with each wobble | (No VO. Let the two counts play.) |
| End: the stopwatch count and the app count shown side by side as on-screen text | VO: "Same test, two scorekeepers." If the counts differ, say so: "They don't always agree yet. That's what we're testing." |

### Test 3: Vrikshasana, tree pose (about 25 s, terrace at sunrise)
| Picture | Words |
|---|---|
| A title chip: "Test 3 · Tree pose" | |
| A wide, calm shot. FRIEND rises into the pose. The app hold timer runs | Music drops to near silence. |
| The pose breaks. The timer stops on its own | VO: "Hold time, measured to the moment the pose breaks. No one has to watch the clock." |

## 3:50–4:35 It tells you when not to trust it (M3, at the workbench, then the ground)

> **M3:** "Most fitness gadgets always show you a number. Niva shows a number only when it can stand behind it."
>
> *(The app screen: "not valid", metrics hidden.)*
>
> **M3:** "Before every session, you lift your foot and tap Tare. Until then, Niva shows nothing."
>
> *(Live: lift the foot, tap Tare. The state turns valid and metrics appear.)*
>
> **M3:** "And some things it will never show: force, calories, heart rate, or anything medical. Four sensors can't honestly tell you those."
>
> *(Card: **What Niva never shows**, followed by the list.)*
>
> **M3:** "Next, we're teaching it to notice when a sensor is wearing out, and to stop reporting before it goes wrong."
>
> *(Caption: "in development".)*

## 4:35–5:15 How we're checking it (all three, at the ground)

| Picture | Words |
|---|---|
| A wide shot of the validation setup: a slow-motion phone on a tripod, M1 with the stopwatch, FRIEND on the beam wearing Niva | M2: "Before we claim anything, we test it." |
| Close-ups of each "scorekeeper" in turn | M3: "Every trial is scored three ways: by a tester, by slow-motion video, and by Niva." |
| Automation Expo 2026 photos, captioned "real photo · Automation Expo 2026, Mumbai" | M1: "We've shown it to industry professionals and physiotherapists. The comparison results are being measured now, and we'll publish them." |

## 5:15–5:45 Close

| Picture | Words |
|---|---|
| Sunrise promenade. FRIEND walks away from the camera, insole strap visible | VO: "Fitness you can measure." |
| The three team members together, looking at the camera, one beat | VO: "Measurement you can trust." |
| End card: NIVA logo, team names, "SIH 2026 · PS 26213", repo/contact link | Music resolves. A subscribe prompt for the last 3 s. |

---

## Shot checklist by location (for the shoot day)
**Marine Drive, 5:45–8:00:**
- shots 3 and 4;
- the split-screen heel landing (shot 5);
- Test 1 walk (three takes, both directions);
- the closing walk-away.

**College ground, 8:30–11:00:**
- shots 1–2, 6–7;
- the M1 piece to camera;
- Test 2 (at least five trials);
- the validation wide and close-ups;
- the team group shot.

**Terrace, golden hour:** Test 3 (three takes, each side).

**Workbench (day 2):**
- M2 macros and piece to camera;
- the M3 tare demo;
- the "never shows" card plate;
- pickups.

## Before publishing
- [ ] Pause-test every frame: no disease, clinical or simulator screens.
- [ ] Every number on screen has its source.
- [ ] Captions match the audio. Upload the .srt too.
- [ ] Signed release from FRIEND and anyone identifiable.
- [ ] Three outsiders watch the first 30 s and can say what Niva does.
