# Niva Sakshi: every remaining task

Written 2 Oct 2026. The earlier **5 Oct 2026** idea deadline and **December 2026** finale plan are inherited planning assumptions; verify the current official portal before relying on them.

**Deck (3 Oct 2026):** the final submitted deck is `docs/NIVA-SAKSHI-SIH2026-PS26213.pdf`. The `deck/` builder folder was deleted after the deck was finished, so `deck/...` paths below are historical.

## Current execution checklist and UI update

The detailed current checklist is [docs/REMAINING-TASKS.md](docs/REMAINING-TASKS.md): priorities, owners, dependencies and completion criteria for registration, device bring-up, hardware, transport, app resilience, class/practice/audio, accessibility, evidence, submission, demonstration and repository work. The A–L list below preserves earlier tracking; its older test counts and built/planned descriptions are historical snapshots.

The compact Apple Health-inspired redesign is recorded in [docs/UI-REDESIGN.md](docs/UI-REDESIGN.md). Software layout checks are separate from real Android/insole checks. Earlier E9 runner styling is superseded by this design; a preparation countdown, audio and physical review remain separate tasks.

**Current software verification:** 72 tests pass; analyzer clean; web release and ARM64 Android release builds succeed. Updated APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.4 MB, team sideloading/debug signing; rebuilt 3 Oct with the cropped-splash fix, app-wide motion and demo mode). Compact overview checks pass at 360 × 800 and 390 × 844. Rendered previews: `docs/previews/`. Physical phone/insole verification remains open.

## Status after the one-pass build (2 Oct 2026, end of day)

**Done and verified in this folder**
- Deck: `deck/NIVA-SAKSHI-SIH2026-PS26213.pdf`, exactly 6 pages, 2.6 MB, built from the kit with the template frame untouched; text scan found no placeholders, "GaitGuard", "knee", "26004" or banned words. Sources in `deck/slides/`, previews in `deck/render/preview/`.
- App (`app/`): `flutter analyze` clean, `flutter test` 56 passed. Added: `lossDeviceMs` CSV column (E1); beam as a second flag source with codes B and X and CSV columns (E2, logic and controller stream, no UI source yet); `agreement_summary.dart` counts-only (E5 logic); `roster.dart` roll-ID queue (E3 logic); `one_leg_minute.dart` practice round and class total (E6 logic); button text now uses the bundled font.
- Firmware (`firmware/`): `sakshi_beam.h` step-off detector with zero-check and fault gate (F1 logic) and `tests/sakshi_beam_test.cpp`, both tests pass on synthetic signals. Not run on hardware.
- Screens: `app/tool/capture_screens.dart` renders the real run screen with a scripted flag; used on slides 3 and 5, labelled as drawn from app code, not a live trial.
- Pages deploy: `.github/workflows/deploy-pages.yml` is manual-only (uncommitted).

**Still needs the team, or cannot be done from here**
- C1-C6: flashing, the phone chain, the filmed trial, real screenshots, beam v0. No QR is on the deck because no real video exists yet.
- A14: confirm Team ID, Team Name, free PS slot, exact portal title (deck uses 121295 / Team Palanteen from the 26004 file).
- D9-D10: your own read of the PDF, then upload before the deadline; the one-line originality disclosure.
- E4 real-device pass (the APK is built; no phone was connected to test it); E7-E8 voice and save robustness; E9-E16.

**Added later on 2 Oct**
- Screens: Class roster, Witness record (counts only) and One-Leg Minute, reached from the Tests tab under "Station tools". 4 widget tests; `flutter test` 60 passed, `flutter analyze` clean.
- Android: `flutter build apk --release --split-per-abi --target-platform android-arm64` builds `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.1 MB, package `com.shubhamsahu.niva.sakshi`, label "Niva Sakshi", so it installs beside the main Niva app). Signed with the debug key: fine for sideloading on team phones, not for the Play Store. Build time about 7 min cold, 2 min warm.
- Build memory: `android/gradle.properties` is set for a busy 16 GB laptop (1.5 GB heap, one worker, Kotlin in-process). With 3-8 GB heaps the Gradle JVM crashed with native out-of-memory while other apps were open. If it crashes again, close browsers and chat apps, then rebuild.
- Not done: installing and running the APK on a phone. No phone or emulator was connected.
- F1 beam hardware, F2 ESP-NOW and pod, section G agreement study, section H finale. All "to be measured" or "finale build" on the slides.
- Slide wording choices to re-check: "BUILT" on slides means code exists and passes tests on synthetic input; the first live trial is still in progress.

---

**Rules for every task below**
- Never invent a number. Every figure carries a source, or says "to be measured".
- No diagnosis, screening, fall-risk or injury wording. "Fall" appears only as the protocol's own term, glossed as "loss of balance (protocol term: fall)".
- Label every image: real photo, real screenshot, CAD render or concept.
- Mark every item BUILT, FINALE BUILD, PLANNED or TO BE MEASURED. Nothing unbuilt may look built.
- Never claim "first", "accurate", "objective", "replaces the teacher".

**Ambition level (decided 2 Oct): go flashy.** Every open decision A2-A14 defaults to the most ambitious option that stays honest: lead with both school and adult settings; build the full station (four-cell beam, display, buzzer, LED strip, voice prompts in Hindi plus one regional language); beam v0 and the filmed trial before 5 Oct; phone-free mode promoted from P2 to P1; show the lab-plate price comparison; make the repo private until results. "Anything to win" stops at the hard rules above: no invented numbers, no staged footage, no unbuilt item shown as built, no clinical wording. A deck that overclaims is the fastest way to be rejected, since finalists are grilled on the prototype and accuracy.

**Where things stand (verified 2 Oct 2026)**
- BUILT: insole sensing core (4 FSR402, MPU6050, heel piezo, ESP32); contact edges; tare-gated validity; Flamingo and Vrikshasana rules; flag then Confirm / Dismiss / tester-only; trial store; CSV. `flutter analyze` clean, `flutter test` 47 passed, firmware `contact_detector_test` passed (synthetic signals only).
- NOT BUILT (as of the start of 2 Oct; class roster, One-Leg Minute and the Android APK were built later that day, see the status section): the beam, ESP-NOW hub, phone-free mode, any real-phone or real-insole session, any recorded trial, any agreement measurement.

Legend: **P0** must exist for the 5 Oct deck or the December finale, **P1** should, **P2** only if solid. Owner: **You** = needs the team's hands or decisions, **Claude** = I can do it in the repo.

---

## A. Decisions to lock first (before 5 Oct)

| # | Decision | Recommended | Owner |
|---|---|---|---|
| A1 | Name | "Niva Sakshi" (decided 2 Oct) | done |
| A2 | Lead setting on slide 1 | Class 1-3 school battery first, adults second | You |
| A3 | Expo photos | One photo, slide 4, captioned as the existing sensing core. No award wording. | You |
| A4 | GitHub | Pages auto-deploy already paused locally; decide whether to make the repo private until results | You |
| A5 | Evidence for 5 Oct | One filmed trial is a must-try; beam v0 photo only if time allows | You |
| A6 | Beam load cells | Two 80 kg bar cells vs a four-cell half-bridge layout | You |
| A7 | Finale wiring | Beam ESP32 as the hub; insole joins over ESP-NOW; never two Bluetooth links at once | You |
| A8 | Phone-free mode | Keep P2; demo only if solid | You |
| A9 | Agreement study design | Named trained tester, adult volunteers, N reported as actually recruited, fixed video frame rate, F1-F5 written down before data | You |
| A10 | Outside validation | Name a PE teacher or physiotherapist only with permission; drop the unverified "5+ experts" and "5+ hackathons" | You |
| A11 | RFID contrast line | Keep for Q&A, not on slides | You |
| A12 | Lab-plate price comparison | Include on slide 4, captioned as a different category, no ratio | You |
| A13 | IP | SIH Guidelines (Miscellaneous Information, slide 17, PDF p.24 of 26): winning idea IP is split equally with the PS organisation, or by agreement. Decide what the SIH entry covers vs the core Niva platform. | You |
| A14 | Portal administration | Confirm free PS slot (max 2 per team); confirm Team ID and Team Name for 26213 (`deck.json` still holds 26004 values: Team Palanteen, 121295); confirm exact PS title string on sih.gov.in/sih2026PS | You |
| A15 | Practice-mode name | **"One-Leg Minute"** (decided 2 Oct) | done |
| A16 | Git: commit strategy | Nothing is committed. The working tree holds the Flutter redesign, the Sakshi folders and the workflow edit. Decide branches and commit grouping. | You |

---

## B. Housekeeping before anything is shown

- [ ] **B1 (done locally, uncommitted).** `.github/workflows/deploy-pages.yml` is now `workflow_dispatch` only. It still deploys on every push to `main` until this change is merged. Merge it, or disable the workflow in the repo's Actions settings. Verify the live Pages site is unpublished.
- [ ] **B2.** Put no GitHub link in the deck or the portal text. The public repo contains the old GaitGuard dashboard history.
- [ ] **B3.** Do not reuse: `dash-top.jpg`, `dash-fsr.jpg`, `shot-dash-sim.png` (GaitGuard, disease simulator, risk flags); `r-*.jpg` (retired shin-pod renders, "screening kit"); `c-*.jpg` (26004 concepts); old `qr-demo.svg`; any 26004 slide text.
- [ ] **B4.** Decide whether to keep `startup/niva web` public at all; it still says "Ischemic Risk" and shows a simulator.
- [ ] **B5.** Remember `.gitignore` now has a narrow exception for `startup/niva flutter/lib/core/data/`. The `niva sakshi/app` copy inherits it; check the copy's source tree is not hidden by the root `data/` rule.

---

## C. Bring up the real chain (nobody has done this yet) **P0, before 5 Oct**

Highest-value evidence for the template's "Describe your Idea/Solution/Prototype" and "working prototype" pointers.

### C1. Firmware on the bench
- [ ] Open `niva sakshi/firmware/niva_hardware/niva_hardware.ino` (or the original in `startup/niva arduino/`), flash an ESP32.
- [ ] Confirm the OLED shows validity state: readings stay zero until a 100-sample unloaded tare completes, then "valid".
- [ ] Send a tare with the foot raised and unloaded.
- [ ] Watch contact events on USB serial; press each FSR; note which sensor maps to which edge.
- [ ] Write what actually happened into `tasks/HANDOFF.md` (incl. failures).
- [ ] Re-run `tests/contact_detector_test.cpp`: `g++ -std=gnu++17 -Wall -Wextra -Werror -I"niva sakshi/firmware/tests/stub" -I"niva sakshi/firmware/niva_hardware" "niva sakshi/firmware/tests/contact_detector_test.cpp" -o contact_detector_test` (use `gnu++17`, not `c++17`, or `M_PI` fails).

### C2. App on a phone
- [x] Build an Android APK. DONE 2 Oct: `app-arm64-v8a-release.apk`, see the status section. Install it with `adb install -r` or by copying it to the phone.
- [ ] Connect to the insole over Wi-Fi WebSocket or BLE. Record which worked.
- [ ] Fallback: serve the web build to a phone browser on the same Wi-Fi; caption it "browser build".
- [ ] Check native haptics on a real device (never observed so far).

### C3. Film one scripted Flamingo trial (adult teammate only)
Set-up: participant stands on a wooden block; insole in a shoe on the held foot; ESP32 box clipped at the waist, cable taped along the leg.
1. Tare with the foot raised.
2. A few warm-up touch-downs (detector thresholds follow the learned load level).
3. Deliberate touch-downs, each should raise a flag the tester confirms.
4. Let go of the foot once without touching down; the tester adds it as a tester-only loss.
5. Dismiss any genuine false flag. Do not stage one.
6. Finish the trial, show the saved result, show both CSVs.
- [ ] Second phone: wide shot, close-up, plus a slow-motion clip for later.
- [ ] Upload as an unlisted YouTube video; make the QR with `deck-kit/tools/qr.py`.
- [ ] Caption exactly: "Scripted demonstration, adult volunteer, agreement to be measured."
- [ ] **Cut-off:** if the chain is not working by Saturday 3 Oct noon, drop the video, use the real insole photo and app screenshots, and put "first phone session in progress" on the NOW rung. Never simulate.

### C4. Screenshots (light theme)
- [ ] Test mode with a flag awaiting Confirm / Dismiss.
- [ ] Result screen.
- [ ] CSV excerpt showing C / D / T codes.
- [ ] Label each: "Real screenshot, Android build" or "browser build", whichever is true.
- [ ] Optional polish: relabel the UI's "falls" as "losses of balance (protocol: falls)".

### C5. Optional: Beam v0 (only after C3 works)
- [ ] Insole fixed on top of a wooden block under the standing foot; film the live contact view switching on and off as someone steps on and off.
- [ ] Caption: "rough prototype: existing insole on a wooden block, Oct 2026". Skip if time is short.

### C6. Optional: one outside voice
- [ ] Call a PE teacher; ask how Flamingo is run today. Quote only with their name and permission.

---

## D. The 5 Oct deck **P0**

Use `sih-26213/deck-kit` (read `GUIDE.md` fully first). Official rules win over house style: exactly 6 slides including title; PDF only (under about 10 MB); pointer headings verbatim; points, diagrams and photos, no paragraphs; real photos of the prototype at least on slides 1 and 3.

### D1. Prepare a kit copy
- [ ] Copy `sih-26213/deck-kit/` to a new working folder (e.g. `niva sakshi/deck/`); never edit the 26004 files.
- [ ] Never edit `chrome.css`, `tokens.css`, `fonts.css` or `chrome()` in `build.py`.
- [ ] Python 3 with `pillow`, `pypdf`, `qrcode`, plus Chrome or Edge.
- [ ] Update `deck.json`: `ps_id` 26213; `ps_title` exact portal string; `theme` Fitness & Sports; `ps_category` Hardware; `idea_title` "Niva Sakshi"; `output_pdf` e.g. `NIVA-SAKSHI-SIH2026-PS26213.pdf`; `pdf_title`; `pdf_keywords`; `team_id`, `team_name`, `college` confirmed (A14).

### D2. Research dossier
- [ ] Write `work/RESEARCH-DOSSIER.md` from the workflow findings (the 50-claim fact-check is the base). Items still open:
  - [ ] Re-check the Casio HS-3V price on Amazon.in (came from a search snippet) if the stopwatch comparison is used.
  - [ ] Open and re-check Probots, Robu, Hawkin snippets in a browser before any price goes on a slide.
  - [ ] Verify the Khelo India Assessor App CSV field list (admin manual site refused connections 1-2 Oct). Until then say "CSV in the same fields, to be verified".
  - [ ] Pull Eurofit beam dimensions from a primary source (secondary sources disagree on height).
  - [ ] Re-check fitindia.gov.in just before submitting that the 5-18 benchmark PDF still says "baseline reference point for current Academic Year (2020-21)".
  - [ ] Confirm the NCC / school meaning of "kadam taal" is irrelevant (idea dropped), skip.
  - [ ] Confirm "SIH26213 109/500" is from an unofficial tracker; don't print it, or label it unofficial.

### D3. Blueprint approval
- [ ] `docs/SLIDE-BLUEPRINT.md` is drafted. Approve or edit it. GUIDE has a hard stop here.

### D4. Assets
- [ ] Inline SVG (hand-written, labelled "concept illustration"): Sakshi Beam concept; 9-step flow; architecture; edge-detector mechanism; before/after; risk/roadmap graphics. The kit forbids AI images.
- [ ] Real photos: `p-proto.jpg` (prototype, caption "real photo"), one Automation Expo photo (caption: "Real photo: visitors handling our existing insole sensing core at Automation Expo 2026. The Sakshi station is new for SIH 2026."). Describe the prototype as "clear plastic box", no battery or strap visible.
- [ ] New screenshots (C4) and new QR (C3).
- [ ] Icons: `python tools/icon.py name1 name2`.

### D5. Build the six slides (`slides/slide1..6.html`)
1. **Title.** Metadata block verbatim (Problem Statement ID, Problem Statement Title, Theme, PS Category, Team ID, Team Name (Registered on portal)). NIVA SAKSHI + tagline "The station flags. The teacher decides. The record keeps both." Shock line: "Pause the stopwatch each time the subject loses balance." (Fit India 5-18 p.21; 18-65 p.24) + "Sakshi pauses and timestamps. The teacher still decides." Four pills: TIMESTAMPED, TEACHER DECIDES, WON'T GUESS (built), ANY FOOT SIZE (finale build). Hero column x 745-1125: beam (concept) / insole (real photo) / teacher decides (real screenshot). Demo box with QR only if real. College name. Content stays left of x 1125.
2. **Proposed Solution.** Lead sentence; TEST (built) and PRACTICE (planned) chips; 9-step flow; "protocol words -> our answer" 6 rows; six cards (Sakshi Beam finale; Witness Record built; Won't-Guess Gate built; Held-Foot Witness built, IMU release flag to be measured; No-Phone Mode planned; One-Leg Minute planned); comparison matrix (stopwatch + tally / phone-video apps / lab balance plate / Sakshi; unknown cells "~"; no price row).
3. **Technical Approach.** Architecture with numbered callouts; BUILT vs NEW stack grid (Hardware, Firmware, App, Analysis); flow ZERO CHECK, SENSE, FLAG, DECIDE, RECORD; edge-detector mechanism ("starting values, tuned from the agreement study"); working-prototype strip (real photo, screenshot, CSV, QR, "N app checks passing" only if re-run); limitations and ethics line.
4. **Feasibility and Viability.** Four pillars; cost panel; risk table (7 rows, designed-in / roadmap); spec bar (built: 100 Hz FSR/IMU, 500 Hz piezo, 10 ms edge resolution; planned: HX711 at 80 SPS; to be measured: battery life, time per child, agreement); roadmap NOW, Oct, Nov, Dec finale, 2027 proposed pilot (partners marked "(proposed)"); Expo photo strip.
5. **Impact and Benefits.** Before/after; six beneficiary tiles; three sourced stats; four benefit columns; UI panel (real screenshot + two "UI concept · example values" widgets).
6. **Research and References.** Ten research -> design cards; 15 numbered clickable references; demo link; honesty note.

Cost-panel content (parts only, Indian single-unit retail, checked 2 Oct 2026): insole pair about ₹2.4-4.0k; HX711 ₹59; 80 kg bar load cell ₹799 each (Probots, incl. GST); still to cost: wood, display, buzzer, enclosure, assembly. Lab plates KINVENT K-Force $2,990 (about ₹2.86 lakh) and BTrackS $3,150 (about ₹3.02 lakh) at ₹95.81/USD (FRED H.10, 25 Sep 2026). No ratio; cite BTrackS for price only (it markets a fall-risk metric).

Sourced stats: more than 4.5 lakh Fit India flag schools (PIB, June 2026); more than 15 lakh students assessed on the Khelo India app by 31 Dec 2019 (SAI), data meant to "lay foundation for creating National Fitness Index"; school benchmarks still a 2020-21 baseline (5-18 p.48); 49.4% of Indian adults insufficiently active in 2022 (WHO 2024 factsheet / Strain 2024) if an inactivity figure is wanted. Do not use the 74% adolescent figure or ICMR-INDIAB-17 diabetes data.

### D6. Visual QA
- [ ] `python render.py`; look only at the 1280 px JPEGs in `render/preview/slideN.jpg` (full-size PNGs crashed an earlier session).
- [ ] Check overflow, clipping, overlaps, text under the QR, awkward wraps, empty holes. Fix with small edits, re-render.

### D7. PDF
- [ ] `python make_pdf.py` must report exactly 6 pages.
- [ ] Extract text and grep for placeholders (`XXXXX`, `IDEA NAME`, `TODO`), "GaitGuard", "knee", "OA", "26004", and banned words: fall risk, screening, diagnosis, injury, accurate, first, objective, replaces the teacher, wobble, 5+ hackathons.

### D8. Portal text
- [ ] `docs/PORTAL-TEXT.md`: idea title and about 140-word description (drafted). Keep the same idea title as the deck.

### D9. Final red-team pass
- [ ] Every number traced to a source line; every image labelled; pointers verbatim; title fields exact; no placeholders.
- [ ] "Loss of balance (protocol term: fall)" glossed on first use. Quote the protocol exactly; never say the beam is required (protocol: the test "can be done by just standing on a beam/block").
- [ ] Originality clause: no "won 5+ hackathons"; the Expo photo is the existing sensing core; the Sakshi station is new. Have a one-line disclosure ready.
- [ ] CBSE wording: students "conduct SAI KHELO INDIA Fitness Test" (Class XII PE Unit 6). Do not write "6 marks for administering".
- [ ] Don't print "N automated checks passing" unless re-run the same day.

### D10. Submit (Mon 5 Oct, early)
- [ ] Upload the PDF; download it back to confirm; keep copies.
- [ ] Open the video link in a private window; confirm it does not require login.
- [ ] No free-tier app link that could be asleep.
- [ ] If SIH26004 needs changes, its one-time edit window is 2-5 Oct; max 2 PS per team.

---

## E. App work in `niva sakshi/app` (finale; start after the deck unless it blocks evidence)

Existing: pure-Dart Flamingo and Vrikshasana rules in `lib/core/fitness/`; `TestRunController` in `lib/features/tests/test_run_controller.dart` (monotonic timing; confirm/reject contact flags); Hive trial store; CSV export; roles; light theme; web release build.

- [x] **E1 (P0): device time per loss in the trial CSV. DONE 2 Oct in `niva sakshi/app`.** New trailing column `lossDeviceMs` (device clock per loss, `-` for tester-only); existing columns unchanged; test added; `flutter analyze` clean, fitness tests pass.
- [x] **E2 (P0): beam as a flag source. DONE 2 Oct (app side): codes B/X, `beamEventsProvider` stream, widget test; the stream is empty until a beam transport exists (F1/F2).** Extend flag routing so a beam event (load drops to near zero) raises a flag exactly like an insole contact edge, with `source` recorded. Keep protocol rules (`flamingo_session.dart`) unchanged. Add tests with synthetic beam events.
- [ ] **E3 (P0): class roster. PARTLY DONE 2 Oct: roll-ID queue screen, next child one tap away, marked done when a trial saves, kept across restarts. Still open: per-child trial history and term export.** Roster of roll IDs only (no names, no photos), queue next child, per-child trial history, term export. No data about children beyond roll ID and results.
- [ ] **E4 (P0): Android APK build and real-device pass. APK BUILT 2 Oct; real-device pass still open.** Permissions (BLE, Wi-Fi), foreground behaviour, large-text fit, sideways phone, haptics, wake lock during a 60 s trial. Record actual results separately from web results.
- [x] **E5 (P1): agreement summary screen. DONE 2 Oct as "Witness record" (all saved Flamingo trials on the phone; per-session filter not added).** Beam flags vs insole flags vs teacher decisions: counts of confirmed, dismissed, tester-only, with no accuracy percentage until measured.
- [ ] **E6 (P1): One-Leg Minute (practice). SCREEN DONE 2 Oct (longest hold, class total, no ranking); the touch-down chime waits on E7.** Short PE-period round: chime at each touch-down; each child's longest unbroken hold; class total practice time; no ranking of children; no outcome claims.
- [ ] **E7 (P1): voice and chime service.** Preferences already persist but playback is not built (HANDOFF T06). Hindi plus one regional-language prompt set; cancel on exit.
- [ ] **E8 (P1): save robustness.** Controller assigns `_saved` before `store.add` succeeds (HANDOFF T07); fix, add retry and failure state.
- [ ] **E9 (P1): preparation screen / runner styling** consistent with the new home (HANDOFF T05); any countdown before `TestRunController.start()`; cancellation must write no trial.
- [ ] **E10 (P2): phone-free mode.** Station buttons COUNT / NOT-COUNT / GO, rules in firmware, hotspot CSV page, recorded voice prompts. Demo only if solid.
- [ ] **E11 (P2): IMU release flag** for letting go of the held foot (IMU pitch/roll is streamed and exported but unused). Label "to be measured"; no stability score.
- [ ] **E12 (P2): plate-tapping board** to complete the Class 1-3 battery.
- [ ] **E13 (P2): signed records / tamper evidence.** Judges considered it a solution to an unshown problem and surveillance-like for children; keep out of the pitch.
- [ ] **E14: participant/trainer pairing.** Participant home is a preview; local and internet pairing not built. Keep it explicitly unavailable until real transport exists.
- [ ] **E15: web dashboard.** `startup/niva web` is the old GaitGuard; either rebuild around validity and events or retire it. Not in `niva sakshi/`.
- [ ] **E16: housekeeping.** Remove `diseaseLabel` leftovers if any; keep rows from older builds loading; re-run `flutter analyze`, `flutter test`, `flutter build web` after each slice; update `tasks/HANDOFF.md` and `tasks/todo.md` with actual results.

---

## F. Firmware and hardware work in `niva sakshi/firmware` **P0 for the finale**

### F1. Sakshi Beam v1
- [ ] Parts (priced so far): two 80 kg bar load cells ₹799 each, HX711 ₹59. Still to source and cost: wood, display, buzzer, enclosure, battery, charger.
- [ ] Wire HX711 for 80 SPS; ESP32 hub with battery and buzzer.
- [ ] Tare and validity: refuse to score until zeroed; unplugging a load cell mid-trial marks the trial "not valid".
- [ ] Load-drop edge detector (reuse the hysteresis + debounce pattern from `niva_signal.h` section 9); stamp at first crossing; constants are "starting values, not validated".
- [ ] Beam dimensions from a primary Eurofit source, or a wider block for 5-8 year olds, documented.
- [ ] A new off-target test beside `contact_detector_test.cpp`, using synthetic signals; do not describe it as validation.

### F2. Link and station
- [ ] ESP-NOW link: insole joins the beam hub so three witnesses share one clock. Beam ESP32 serves its own Wi-Fi for the phone. Never rely on venue Wi-Fi or on two Bluetooth links.
- [ ] USB-serial fallback and a recorded backup video for the finale.
- [ ] Child-facing display (clock and count) (P1).
- [ ] Insole pod: battery and strap (the prototype is a foam insole cabled to an ESP32 and OLED on perfboard in a clear plastic box, with no battery or strap). Spare FSRs and pre-crimped leads. Second insole optional.
- [ ] Interlink genuine FSRs add about ₹500 per insole over clones; optional credibility upgrade.
- [ ] Render any new enclosure only as a labelled concept; never reuse the retired shin-pod CAD.

### F3. Shared-firmware hygiene
- [ ] Changes in `startup/niva arduino/` reach all three Niva projects; record that a change was for Sakshi. Keep Sakshi variants in `niva sakshi/firmware/` and sync back deliberately.

---

## G. Evidence: agreement study (October - November) **P0 for the finale**

Definitions first, written down before any data is collected (as was done for R2).

| ID | Question | Reference | Status |
|---|---|---|---|
| F1 | Does Sakshi's loss-of-balance count agree with a trained tester's count in the Flamingo test? | Trained tester's count + phone slow-motion video, frame by frame | to be measured |
| F2 | Does Vrikshasana hold time agree with a stopwatch? | Stopwatch + video | to be measured |
| F3 | Does the heel-before-toe call match slow-motion video? | Phone slow-motion video | to be measured |
| F4 | Does cadence match a manual step count? | Step count from video | to be measured |
| F5 | Do the FSRs stay below saturation in single-leg stance? (decides whether a sway index is reported at all) | Bench loading per SOP-01 | to be measured |
| F6 (new) | Does beam load-drop agree with the tester and video? | Tester + slow-motion video | to be measured |
| F7 (new) | Time per child per station, and children per PE period | Stopwatch during real class runs | to be measured |
| F8 (new) | Battery life of beam hub and insole pod | Bench log | to be measured |

- [ ] Pick the trained tester: a named, consenting PE teacher or coach.
- [ ] Recruit adult volunteers; report the N actually recruited; written consent; a spotter beside every balance trial; warm-up per the protocol.
- [ ] Fix video frame rate and camera position.
- [ ] Log every disagreement; report agreement as counts, never as "accuracy".
- [ ] Children only after written school and parent consent and ethics sign-off.
- [ ] R1 and R3 (FSR drift over load cycles, whether the validity gate catches aged sensors) belong to Aavishkar; do not carry their claims into Sakshi.

---

## H. Finale preparation (December) **P0**

### H1. The demo: "Judge vs Sakshi"
1. Station boots showing "not ready"; team tares; shows "valid".
2. Judge A stands on the beam with the insole pod on the held foot; Judge B scores the official way (stopwatch and tally); a team member or third judge is the tester on the phone.
3. 60 seconds of balancing. Each flag pauses the clock and sounds the buzzer; the tester confirms or dismisses; if Judge A lets go without touching down, the tester adds a tester-only loss.
4. Three numbers side by side: Judge B's count, the station's flags, the confirmed count. Slow-motion video replays synced on the device clock.
5. Unplug a load cell mid-trial; station marks the trial "not valid" and refuses to score.
6. Close with the measured agreement table (numbers only if measured) and measured time per participant.
- [ ] Adults only. USB-serial fallback, backup video, spare FSRs, pre-crimped leads. Rehearse with at least two people who have never seen it.

### H2. Judge Q&A (prepare one-line answers)
- Why not a phone camera? Timing is captured under the foot; no video of children; no line-of-sight or lighting dependence. Any accuracy comparison is "to be measured".
- Isn't this a stopwatch replacement / a plank on a scale? The record (flag + decision + validity) is the product; the beam is one witness.
- Prior art? Moticon sells an Assessment Module; BrilliantWear publishes insole test batteries; Orphe won a CES 2026 award. Never claim "first". Claim the combination: this protocol, this setting, this record.
- Accuracy? Show the agreement plan now; show measured numbers at the finale only.
- Originality clause (Guidelines, Miscellaneous Information, slide 17)? Sakshi is new for SIH 2026, built on the team's existing sensing core.
- Children's data? No camera; roll IDs only; adults only until consent.
- Is a test a fitness activity? TEST + PRACTICE modes; the protocol's own practice advice ("practice one foot balance ... walking on beam"); senior students as testers.
- One station too slow for a class? Throughput is "to be measured"; stations per school set from measured time.
- Why not RFID or GPS for the 2 km? Run timing is already solved (RFID timing specified in a 2010 police tender; protocol allows a phone app for distance, 18-65 p.22). Out of scope.

### H3. Roadmap beyond December (proposed)
- [ ] Pilot with a partner school, with consent (mark "(proposed)").
- [ ] Verify the Khelo India Assessor App export path; no API claim until verified.
- [ ] Vrikshasana adult mode and 2 km item as secondary.
- [ ] 65+ items (chair stand, Up-and-Go) only as "agility and dynamic balance", never "fall risk".

---

## I. Wording and risk checklist (run before every export)

| Risk | Pre-empted by | Action |
|---|---|---|
| No real phone session by 5 Oct | BUILT chips only for real things; no QR unless the video is real | Do C1-C4 first; keep fallback layout |
| "Stopwatch replacement / plank on a scale" | Lead with witness record and won't-guess gate | One-line answer |
| "A test isn't a fitness activity" | TEST + PRACTICE chips, protocol practice quote, student testers | Build E6 |
| Accuracy grilling (as at the 2024 finale) | Plan on slide 4 marked "to be measured"; disagreements logged | Run section G |
| Beam does not exist | Labelled concept, sourced parts, P0 in October | Order load cells and HX711 now |
| Letting go without touching down not sensed | Stated limitation; teacher's tester-only count built; IMU flag to be measured | Test IMU in November |
| Originality clause | New SIH solution on an existing core; no hackathon wins; Expo photo captioned | One-line disclosure |
| Children's data and consent | No camera; roll IDs only; adults only until consent | Ethics line on slide 3 |
| Clinical drift | "Loss of balance (protocol term: fall)"; no score, stability index, fall-risk wording | Wording grep |
| Overclaiming Assessor App link | "CSV in same fields, to be verified"; no API claim | Verify field list |
| Public repo and GaitGuard dashboard | No GitHub link in the deck | Merge or disable Pages workflow |
| Two-device demo fails | Beam ESP32 as single hub, ESP-NOW, USB fallback, backup video | F2 |
| Prior-art challenge | Never say "first" | Q&A line (H2) |
| Benchmarks updated after 2020-21 | Quote the PDF as served on a stated date | Re-check before submitting |

Banned words: fall risk, screening, diagnosis, injury, accurate, first, objective, replaces the teacher, wobble, "5+ hackathons", "5+ experts".

---

## J. Repository and documentation chores

- [ ] Decide commit grouping (A16): Flutter redesign; `niva sakshi/` fork; `sih-26213/sakshi/` docs; `.github` workflow edit; `.gitignore` change; memory/docs. Nothing is committed or pushed yet.
- [ ] Keep `niva sakshi/docs/` and `sih-26213/sakshi/` in sync (they are copies as of 2 Oct); pick one source of truth.
- [ ] Update `PROJECTS.md` to list `niva sakshi/` beside `startup/`, `aavishkar/`, `sih-26213/`, `media/`, stating its rules.
- [ ] Update `sih-26213/README.md` fully (its idea section still describes the three-item pitch below the new Sakshi note).
- [ ] Do not edit anything in `aavishkar/`; its rules (no added sensors, no ML, sensor count as the independent variable) bind Aavishkar only.
- [ ] Keep `tasks/HANDOFF.md` and `tasks/todo.md` updated with actual results after each slice.
- [ ] The shared insole firmware stays in `startup/niva arduino/`; note which project asked for each change.

---

## K. Timeline

| When | What |
|---|---|
| Fri 2 Oct | Decisions A2-A15 (at least A14); B1-B3; C1 firmware on the bench; C2 app on a phone; blueprint approval (D3) |
| Sat 3 Oct | C3 film the trial (cut-off noon); C4 screenshots; optional C5 beam v0; start D4 assets |
| Sun 4 Oct | D5 build six slides; D6 QA; D7 PDF; D8 portal text; D9 red-team pass |
| Mon 5 Oct (early) | D10 submit; verify upload and video link |
| Oct | Order beam parts; E1-E4; F1-F2; draft agreement protocol (G); APK on real devices |
| Nov | Agreement study (G); E5-E8; time class runs (F7); battery logs (F8) |
| Dec | Finale prep and rehearsal (H); backup video; spares kit |

---

## L. Open questions for the team

1. Is Team ID 121295 / Team Palanteen the registration for 26213 as well as 26004?
2. Which of the two problem-statement slots is free?
3. Exact PS title string on the portal.
4. Who is the trained tester and who can be a consenting adult volunteer pool?
5. Can the team name a PE teacher or physiotherapist (with permission) as outside validation?
6. Is a battery-and-strap pod or a simpler foot clip better for the finale?
7. Private repo until results, or stay public with the dashboard removed?
8. Beam v0 before 5 Oct or after?
