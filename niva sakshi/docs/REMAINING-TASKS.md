# Niva Sakshi — complete remaining-work checklist

Updated **2 October 2026**. Work in `niva sakshi/`, the local app/firmware copy inside Niva. This folder is not a separate remote GitHub fork. Preserve the startup and Aavishkar projects.

This document is the current execution checklist. `../TASKS.md` preserves the original A–L plan and history. Complete an item only when its evidence is recorded; code passing tests and hardware working on a phone are different milestones.

## Priorities and ownership

- **P0 submission:** needed before presenting or submitting the current evidence.
- **P0 station:** needed for the complete physical station and demonstration.
- **P1:** important resilience, usability or pilot work after the core chain works.
- **P2:** optional extensions; keep them behind the working station.
- **Software:** can be completed in this folder. **Team:** needs hardware, volunteers, administrative facts or external decisions.
- The earlier 5 October deadline and December finale plan are planning assumptions inherited from earlier work. Verify current official dates and submission requirements on the portal before relying on them.

## Already available

- Local Flutter/firmware copies, separate Android package identity, a six-page deck and its sources.
- Insole event processing, validity gates, Flamingo/Vrikshasana sessions, teacher confirmation, local trial storage and CSV.
- Device timestamps per loss, beam source codes and app-side routing. The production beam stream is empty until the hub transport exists.
- Class roster, One-Leg Minute and counts-only Witness record screens. Their remaining pieces are below.
- Current redesigned ARM64 Android APK built successfully (21.4 MB, rebuilt 3 Oct with the splash crop fix, motion and demo mode, debug signed for team sideloading); installation and real-device checks remain open.
- The redesign adds compact Summary/Tests/Live/Device navigation, measured telemetry cards, one insole diagram, a finite launch animation and grouped settings. Current checks and physical limitations belong in `UI-REDESIGN.md`.
- No verified live phone-to-insole assessment or measured agreement study is established by the evidence available in this chat. Synthetic tests and rendered previews do not establish physical performance.

## Execution order

1. Verify registration facts; build and install the current app.
2. Run the existing insole → phone → test → saved record → export path with an adult.
3. Capture honest evidence and refresh the submission artifacts.
4. Build the beam and connect both witnesses through a station hub.
5. Complete saving, lifecycle, reconnect and event/clock handling.
6. Finish class history/export, practice and audio usability.
7. Measure agreement, throughput, durability and battery life.
8. Rehearse the demonstration and prepare recovery equipment.
9. Consider optional extensions after the preceding work is dependable.

## 1. Registration, scope and claims

### ADM-01 — Verify portal registration

**P0 submission · Team · Earlier A14 · Dependencies: none.**

- [ ] Confirm exact PS number/title, theme, category, team name/ID and college.
- [ ] Check available slots, deadline and upload format against current official instructions.
- [ ] Update deck metadata, portal text and filenames consistently.

**Completion evidence:** a dated portal-fact check matching the final artifacts. Inherited Team Palanteen/121295 values are not independently confirmed here.

### ADM-02 — Confirm scope and originality wording

**P0 submission · Team/software · Earlier A2/A3/A10/A13 · Depends on ADM-01.**

- [ ] Keep Niva Sakshi and Flamingo as the main story; describe Vrikshasana as an existing secondary mode.
- [ ] Disclose the existing sensing core and new station work accurately; check current originality/IP terms.
- [ ] Use named reviewer feedback only with permission. Describe Expo photos as demonstrations/discussions unless stronger evidence exists.

**Completion evidence:** claims backed by prototype history, official instructions and permission records. Do not use unverified award counts, partnerships or novelty claims.

### ADM-03 — Maintain a claim and asset register

**P0 submission · Team/software · Earlier D2/B3/I · Depends on ADM-02.**

- [ ] Record a source/page/access date for every number, quote, specification and price.
- [ ] Distinguish implemented software, physically verified behaviour, proposals and measurements pending.
- [ ] Label real photos, live screenshots, test-rendered previews, CAD and concepts; exclude retired knee/OA, simulator and shin-pod material.

**Completion evidence:** every slide/portal claim maps to evidence or a planned label. An unsuccessful repository search does not establish that no competitor exists.

## 2. Actual phone and insole chain

### RUN-01 — Install the current redesigned APK

**P0 submission · Software builds; team tests · Earlier C2/E4 · Depends on automated checks.**

- [ ] Build the latest ARM64 release APK and record version, date, output and signing status.
- [ ] Install beside startup Niva using the separate Sakshi package; check cold launch, role persistence and restart.
- [ ] Verify native splash transition, permissions and navigation on the actual phone.

**Completion evidence:** phone model/OS and actual pass/fail results. A successful build alone does not complete installation or real-device testing. Proper release signing remains necessary before public distribution.

### RUN-02 — Flash and inspect the insole

**P0 submission · Team · Earlier C1 · Depends on physical access.**

- [ ] Flash the Sakshi firmware copy; record board/revision/settings.
- [ ] Verify unloaded tare, validity display and sensor-to-channel mapping.
- [ ] Exercise press/release events and timestamps over serial; inspect wiring, saturation and enclosure/cable arrangement.

**Completion evidence:** actual raw logs and hardware photos, including faults. Host detector tests remain synthetic checks.

### RUN-03 — Connect phone and insole

**P0 submission · Team/software · Earlier C2 · Depends on RUN-01/02.**

- [ ] Try Bluetooth and Wi-Fi separately and record which work.
- [ ] Tare through the app; check valid/invalid transitions, denied permissions and reconnect/old-firmware states.
- [ ] Verify timing gates and relative sensor shares on real data.

**Completion evidence:** an actual end-to-end session. Label any browser fallback as a browser build and state its transport limitations.

### RUN-04 — Run, save and export an assessment

**P0 submission · Team · Earlier C3 · Depends on RUN-03.**

- [ ] Use a consenting adult, trained tester and spotter; follow the chosen protocol.
- [ ] Record real flags, confirmations and tester-only losses; dismiss flags only when genuinely appropriate.
- [ ] Preserve video and matching trial/telemetry exports; check source, device time and teacher decision.

**Completion evidence:** the recording and CSV refer to the same real trial. Label scripted input and preserve failures instead of replacing them with simulated success.

### RUN-05 — Verify physical phone ergonomics

**P0 station · Team/software · Earlier E4 · Depends on RUN-01.**

- [ ] Check small/large phones, safe areas, enlarged text, landscape, keyboard and screen-reader reading order.
- [ ] Check actual haptics and Bluetooth permissions.
- [ ] Exercise screen lock, interruptions, background/foreground transitions and a complete 60-second trial.

**Completion evidence:** device matrix and recorded findings. Automated portrait fitting does not establish behaviour on every physical device.

## 3. Beam, station and firmware

### HW-01 — Design and source the physical beam

**P0 station · Team · Earlier A6/F1 · Depends on selected protocol/parts.**

- [ ] Verify official equipment/procedure before setting dimensions.
- [ ] Choose rated cells, mounting/support, anti-slip treatment, enclosure, strain relief and cable paths.
- [ ] Obtain actual quotes and a full bill of materials, including power, housing and assembly.

**Completion evidence:** inspectable mechanical/electrical drawings and sourced parts. Sensor load rating alone does not establish structural safety.

### HW-02 — Run the detector on real beam electronics

**P0 station · Team/software · Earlier F1 · Depends on HW-01.**

- [ ] Integrate cells, HX711 and ESP32; verify actual sample rate, zeroing and contact state.
- [ ] Tune hysteresis/debounce using measured traces.
- [ ] Check step-off, brief unloading, edge loading, return and repeated events.

**Completion evidence:** real traces/video with timestamp resolution and measured latency. Starting thresholds are not validated thresholds.

### HW-03 — Validate zero/fault gates

**P0 station · Team/software · Earlier F1 · Depends on HW-02.**

- [ ] Exercise invalid tare, missing/disconnected sensors and detectable rail/stuck states.
- [ ] Make faults visible and keep invalid hardware from producing a usable result.
- [ ] Verify recovery and preserve fault information if a trial becomes invalid.

**Completion evidence:** observed fault/recovery results for each supported failure. Do not claim detection of failures the hardware cannot identify.

### HW-04 — Build the wearable pod and power supply

**P0 station · Team · Earlier F2 · Depends on RUN-02/HW-01.**

- [ ] Secure electronics/leads and select actual battery, regulation, charging/protection and attachment.
- [ ] Check comfort, cable interference, cleaning and repeated setup.
- [ ] Photograph the built arrangement; keep renders labelled as concepts.

**Completion evidence:** the setup can be used without holding loose electronics and its construction is documented.

### HW-05 — Connect the single station hub

**P0 station · Team/software · Earlier A7/F2 · Depends on HW-02/04.**

- [ ] Define packet version, device ID, source timestamps, sequence numbers and validity fields.
- [ ] Build insole-to-hub and hub-to-phone transport; feed real beam events into the existing app provider.
- [ ] Test radio coexistence, packet loss/delay, reboot and reconnection; retain a USB diagnostic path.

**Completion evidence:** both physical witnesses feed a saved trial through one real hub. ESP-NOW remains the proposed link until verified on the boards.

### HW-06 — Complete hardware feedback

**P1 · Team/software · Earlier F2 · Depends on HW-03/05.**

- [ ] Add required display/buttons/buzzer and optional lights for ready, running, review and fault states.
- [ ] Keep teacher decisions authoritative; feedback must not silently confirm a flag.
- [ ] Verify indications, mute behaviour and app/hub consistency physically.

**Completion evidence:** a tester can identify every station state from actual hardware feedback.

## 4. App correctness and feature completion

### APP-01 — Make saving recoverable

**P0 station · Software · Earlier E8 · Depends on existing store.**

- [ ] Distinguish unsaved, saving, saved and failed; declare success only after storage succeeds.
- [ ] Add retry while preserving the result and preventing duplicate writes.
- [ ] Cover leaving during save, storage failure/restart/deletion and correct roster completion.

**Completion evidence:** failure-injection tests demonstrate no lost result or false saved confirmation.

### APP-02 — Handle lost/invalid links during trials

**P0 station · Team/software · Earlier E4/E8 · Depends on RUN-03/HW-05.**

- [ ] Specify continue-as-tester-only, pause or invalidation behaviour for each failure.
- [ ] Preserve validity/source changes in the record, rather than only the initial mode.
- [ ] Show actionable reconnect state and prevent stale flags being replayed.

**Completion evidence:** interruption tests and real logs match the documented behaviour without silent provenance loss.

### APP-03 — Synchronize clocks and combine witnesses

**P0 station · Team/software · Earlier E2/F2 · Depends on HW-05.**

- [ ] Synchronize each device independently with identity, sequence and reboot epoch.
- [ ] Define one counted loss for a shared incident while retaining both witness observations.
- [ ] Cover duplicates, delayed/out-of-order packets, timer wrap and reboot; separate observation/receipt/decision times as needed.

**Completion evidence:** logs/tests demonstrate no double counting or invented time. Ignoring a second flag while checking is not a complete study record for combined witnesses.

### APP-04 — Manage wake/lifecycle behaviour

**P0 station · Team/software · Earlier E4 · Depends on RUN-05.**

- [ ] Keep the phone awake while needed and restore normal behaviour on exit.
- [ ] Define background, interruption, back-navigation and cancellation behaviour.
- [ ] Keep timing based on the monotonic clock, independent of animation/frame rate.

**Completion evidence:** real interruptions do not silently change the clock or save unintended trials.

### APP-05 — Finish class history and term export

**P1 · Software · Earlier E3 · Depends on APP-01.**

- [ ] Add per-roll history, leg/test/session filters and class/term exports with defined fields.
- [ ] Mark done using the actual matching saved trial, not merely an increase in total store count.
- [ ] Handle reruns, interrupted trials, duplicate IDs, class switching and archival without losing results.

**Completion evidence:** a class can be completed, reopened and exported correctly using roll IDs only.

### APP-06 — Filter Witness record

**P1 · Software · Earlier E5 · Depends on APP-03/05.**

- [ ] Add class/session/date filtering and inspection of underlying events.
- [ ] Retain beam/insole/tester-only decisions, dismissed flags and missing observation periods.
- [ ] Reconcile totals with trial CSV; keep counts separate from measured agreement.

**Completion evidence:** selected counts match their actual records without an unsupported accuracy percentage.

### APP-07 — Complete One-Leg Minute

**P1 · Team/software · Earlier E6 · Depends on APP-04/HW-05.**

- [ ] Verify physical sensor/manual touchdown, resume and repeated rounds.
- [ ] Decide whether class totals persist; label session-only totals clearly meanwhile.
- [ ] Add dependable exit/reset and validity/reconnect handling; connect beam events if retained for practice.

**Completion evidence:** practice totals reconcile, including interrupted rounds that must not be added. No child rankings or unmeasured improvement claims.

### APP-08 — Implement voice and chimes

**P1 · Team/software · Earlier E7 · Dependencies: agreed prompts/languages.**

- [ ] Implement start/review/resume/fault/completion audio with independent saved preferences.
- [ ] Review chosen Hindi/regional translations; cancel queued audio on exit or state changes.
- [ ] Test overlapping prompts, silence/mute, audio interruptions and haptics on devices.

**Completion evidence:** actual playback matches its toggles. Saved preferences alone do not mean audio works.

### APP-09 — Decide and implement pairing if needed

**P2 · Team/software · Earlier E14 · Depends on an actual participant-phone use case.**

- [ ] Decide whether the station needs participant phones.
- [ ] If retained, define session joining, trainer authority and reconnect handling; implement local sessions before internet ones.
- [ ] Keep unavailable-preview messaging until two actual phones work.

**Completion evidence:** a participant can join without editing teacher decisions.

### APP-10 — Harden export, upload and legacy storage

**P1 · Software · Earlier E16 · Depends on APP-01/03/05.**

- [ ] Check old rows, versioning and CSV escaping for commas/quotes/newlines/formula-like IDs.
- [ ] Distinguish sample/trial/class exports; document timestamps and schemas.
- [ ] Handle share cancellation, file failures and backend rejection/timeouts; review credentials/logging before wider distribution.

**Completion evidence:** round-trip/failure tests pass without losing local records.

## 5. UI/UX follow-through

### UX-01 — Review the redesign physically

**P0 submission · Team/software · Depends on RUN-01.**

- [ ] Check Summary/Tests/Live/Device on intended phones without the small forced scroll that triggered this work.
- [ ] Verify cold-launch animation, reopening and Reduce Motion.
- [ ] Check connected, collecting, invalid, error, empty and populated states.

**Completion evidence:** physical screenshots/findings. Long history, enlarged text and landscape may scroll; critical actions must stay reachable.

### UX-02 — Complete accessibility/responsive review

**P1 · Team/software · Depends on UX-01.**

- [ ] Check TalkBack/VoiceOver labels, focus and state announcements; review sensor-bar labels individually.
- [ ] Check readable enlarged text, targets, contrast, keyboard and safe areas.
- [ ] Review tablet/desktop and dark appearance if dark mode will be exposed.

**Completion evidence:** important flows work with real assistive technology. Automated layout checks do not certify full accessibility conformance.

### UX-03 — Refresh screenshots and walkthrough

**P0 submission · Team/software · Earlier C4/D4 · Depends on current build.**

- [ ] Replace stale design imagery with current-app captures.
- [ ] Label rendered/scripted previews separately from live phone evidence.
- [ ] Show setup, run, flag decision, completion and history/export; align deck navigation labels.

**Completion evidence:** presented UI matches the app the team can demonstrate.

## 6. Evidence and measurements

### STUDY-01 — Define the study before collecting results

**P0 station · Team · Earlier G · Depends on stable RUN-04/HW-05.**

- [ ] Recruit a named trained tester and consenting adults; report the actual recruited sample.
- [ ] Predefine losses, matched/missed/dismissed events, invalid trials and timing comparisons.
- [ ] Fix video frame rate/position/synchronization and independent reference scoring; define IDs/access/retention and any later school approvals.

**Completion evidence:** written protocol predates claim-supporting data. Validation video is separate from the camera-free product workflow.

### STUDY-02 — Measure Flamingo and beam agreement

**P0 station · Team · Earlier F1/F6 · Depends on STUDY-01/HW-03/APP-03.**

- [ ] Compare beam/insole observations, teacher decisions and independent tester/video reference.
- [ ] Report confirmed/dismissed/missed/duplicate events with denominators and conditions.
- [ ] Review timing differences, unusable trials and all disagreements.

**Completion evidence:** preserved data/analysis support every printed agreement claim.

### STUDY-03 — Validate secondary metrics

**P1 · Team · Earlier F2/F3/F4/F5 · Depends on STUDY-01.**

- [ ] Compare hold timing, cadence and contact order against the agreed references if used in the pitch.
- [ ] Check FSR saturation and relative-load interpretation; no unsupported force/sway outcomes.
- [ ] Keep Aavishkar aging/drift claims separate unless independently applicable.

**Completion evidence:** each metric has a method/result/limit or remains to be measured.

### STUDY-04 — Measure throughput and repeated use

**P0 station · Team · Earlier F7 · Depends on class workflow.**

- [ ] Time setup, zeroing, explanation, trial, reset and record handling.
- [ ] Run an adult batch; observe tester burden, cleaning, fit variation and repeated hardware use.
- [ ] Base stations-per-class/deployment capacity on measured time.

**Completion evidence:** throughput claims follow observed conditions, not assumed one-kit capacity.

### STUDY-05 — Measure battery and reliability

**P0 station · Team · Earlier F8 · Depends on HW-04/06.**

- [ ] Log real insole/hub runtime with radios, display and feedback enabled.
- [ ] Exercise charging, low power, restart and long-session connection stability.
- [ ] Record voltage/power conditions and failures.

**Completion evidence:** usable runtime is measured on the presented hardware.

### STUDY-06 — Observe a tester using the station

**P1 · Team · Earlier C6/H3 · Depends on complete workflow.**

- [ ] Ask a teacher/coach to set up, test, review and export without builder coaching.
- [ ] Record confusion, corrections and time, then fix the important problems.
- [ ] Obtain permission for attributed feedback; distinguish interest from a partnership.

**Completion evidence:** documented observations lead to concrete changes.

## 7. Deck, submission and demonstration

### DECK-01 — Refresh the existing deck

**P0 submission · Software · Earlier D3–D8 · Depends on ADM-03/UX-03.**

- [ ] Keep required template/frame and update current built/planned labels and UI.
- [ ] Insert live photos/QR only when real evidence exists; preserve honest fallbacks.
- [ ] Recheck sourced prices/dates/protocol quotes and registration facts.

**Completion evidence:** rebuilt artifacts match scope/evidence without stale clinical/simulator material.

### DECK-02 — Inspect exports

**P0 submission · Team/software · Earlier D6/D7/D9 · Depends on DECK-01.**

- [ ] Review all pages for count, fonts, clipping, captions and presentation-size legibility.
- [ ] Check links/QRs and current portal length/file requirements.
- [ ] Preserve editable source and exact final files.

**Completion evidence:** the team reads the same verified file it intends to upload.

### DECK-03 — Submit and retain confirmation

**P0 submission · Team · Earlier D10 · Depends on ADM-01/DECK-02.**

- [ ] Upload agreed files/text before the verified deadline.
- [ ] Inspect uploaded/retrieved files if possible.
- [ ] Preserve confirmation, timestamp and submission version.

**Completion evidence:** actual portal confirmation. A local PDF is not a submitted idea.

### DEMO-01 — Rehearse the real workflow

**P0 station · Team · Earlier H1 · Depends on physical station/study.**

- [ ] Rehearse invalid → zero/valid → run → flag → decide → finish → export.
- [ ] Show independent stopwatch/tally comparison and real disagreements; demonstrate a fault the hardware actually detects.
- [ ] Use consenting adults/spotter and unfamiliar testers; judge participation is optional.

**Completion evidence:** the team can recover from a failed link/reset and explain limitations.

### DEMO-02 — Pack recovery equipment and prepare answers

**P0 station · Team/software · Earlier H2 · Depends on DEMO-01.**

- [ ] Pack working spare leads/sensors, power/cables, offline app/exports and labelled backup video.
- [ ] Prepare evidence-backed answers on cost, prior art, protocol, missed events, teacher authority, throughput and privacy.
- [ ] Distinguish implemented, physically tested and planned work consistently.

**Completion evidence:** demonstration and answers work without internet or unsupported novelty/accuracy claims.

## 8. Repository and handoff

### REPO-01 — Version Sakshi deliberately

**P1 · Team/software · Earlier A16/J · Depends on reviewed changes.**

- [ ] Agree branch/commit grouping; include no unrelated project edits.
- [ ] Check source tracking despite broad ignore rules; exclude generated caches.
- [ ] Document reproducible build/flash commands and shared changes to sync deliberately.

**Completion evidence:** another team member builds the intended version. This UI task does not itself create a remote fork, commit or push.

### REPO-02 — Establish document ownership

**P1 · Software · Earlier J · Dependencies: none.**

- [ ] Use this Sakshi docs folder for current execution/design notes; point duplicates here or explicitly synchronize them.
- [ ] Update project index/READMEs to distinguish each project and local copy.
- [ ] Record actual verification and limitations after every slice.

**Completion evidence:** no contradictory built/planned descriptions or ambiguous source of truth.

### REPO-03 — Resolve the old public dashboard

**P1 · Team/software · Earlier B1/B2/B4/E15 · Dependencies: external-state decision.**

- [ ] Verify actual Pages/workflow state; a local workflow edit does not unpublish an existing site.
- [ ] Decide to retire or separately rebuild the old startup dashboard; keep Sakshi links away from simulator/clinical claims.
- [ ] Decide visibility deliberately instead of treating an earlier private-repo suggestion as an executed action.

**Completion evidence:** shared public material matches demonstrated product claims.

### REPO-04 — Maintain release checks

**P1 · Software · Earlier E16/F3 · Depends on stable paths.**

- [ ] Run analyzer/relevant tests, web and Android builds; run host/board checks for firmware changes.
- [ ] Keep no-scroll/default-phone, enlarged-text/action and UI-validity regressions.
- [ ] Record version, binary path, signing and physical verification separately.
- [ ] Resolve the release build's `share_plus` legacy Kotlin Gradle Plugin warning before upgrading to a Flutter version that requires built-in Kotlin; choose and verify a compatible package/toolchain combination.

**Completion evidence:** reproducible releases without stale binaries or screenshots mistaken for current work.

## 9. Explicitly deferred extensions

Decide whether these belong in the product before implementation. They are not prerequisites for the Flamingo station.

- [ ] **OPT-01 — Phone-free mode (E10/A8):** implement verified rule parity, authoritative teacher buttons/display and local export. Depends on stable hub/feedback/saving/event handling.
- [ ] **OPT-02 — IMU release flag (E11):** collect labelled held-foot-release data and determine whether it is observable; retain manual input until measured. No stability/clinical score.
- [ ] **OPT-03 — Plate tapping (E12):** verify protocol/need, build separate equipment and validate timing. Do not call the current station a complete school battery.
- [ ] **OPT-04 — Tamper-evident records (E13):** establish user need before adding signing/cryptography.
- [ ] **OPT-05 — Official assessor integration (H3):** verify fields and supported integration. CSV alignment does not establish an API or partnership.
- [ ] **OPT-06 — 2 km/additional age-group tests (H3):** separate scope/protocol decisions and evidence; secondary to the station.
- [ ] **OPT-07 — School pilot (H3):** find an actual willing partner and complete required approvals/consent before children participate.
- [ ] **OPT-08 — Second insole:** add only for a justified use case; never mirror one measurement as another foot.
- [ ] **OPT-09 — Preparation countdown (E9):** if retained, place it before official timing begins, make cancellation save nothing and respect Reduce Motion/audio settings.

## Completion gates

### Submission ready

- [ ] Registration/claims/exports verified and portal confirmation retained.
- [ ] Software/rendered evidence and physical/proposed evidence clearly distinguished.
- [ ] No stale UI, unsupported price/novelty claim or unlabelled scripted measurement.

### Station ready

- [ ] Physical chain, beam/hub, fault handling, saving and lifecycle work reliably.
- [ ] A tester independently completes a trial, resolves flags, saves and exports.
- [ ] Required measurements are reproducible from preserved raw evidence.

### Demonstration ready

- [ ] Rehearsal and release checks pass on the actual packed hardware/app version.
- [ ] Recovery equipment and evidence work offline.
- [ ] The team can show useful operation and explain honest limitations.

## Team inputs still needed

The name **Niva Sakshi** and local-folder separation are settled. Remaining factual/physical inputs: verified portal facts; insole/ESP32/phone access and models; beam parts/budget; trained tester and consenting adults; chosen voice languages; actual study/throughput/battery data; remote/public-site decisions when publishing is intended.

Every unchecked item remains open until completion evidence is recorded.
