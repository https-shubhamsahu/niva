# Niva Flutter redesign — implementation plan

Approved scope: user brainstorming and instruction to plan and start, 1 October 2026 (Asia/Kolkata).
This plan is for `startup/niva flutter` and SIH26213. Aavishkar-specific rules do not apply.

## Read first

1. `tasks/HANDOFF.md`: current state, next task, latest checks, resume prompt.
2. `tasks/todo.md`: ordered tasks and acceptance criteria; update after every verified slice.
3. This document: decisions and boundaries.
4. `sih-26213/README.md` and `PROJECTS.md`: claims and project ownership.

Do not depend on chat history. Keep these documents accurate before stopping or handing over.

## Product brief

SIH26213 is AICTE/MIC Student Innovation, Hardware, Fitness & Sports: ideas that boost fitness activities and assist in keeping fit. Fit India assessment is our selected solution, not a sponsor-mandated feature. First assessments remain Flamingo and Vrikshasana (18–65 protocol).

Approved decisions:
- Participant and trainer roles equally supported, remembered with an accessible role switch.
- Assessment is the primary home action.
- Separate participant and trainer phones, Android first.
- Both local Wi-Fi/hotspot sessions and internet sessions.
- Default light appearance, white surfaces, Niva teal, coral and lime accents; Apple Health-inspired hierarchy with original branding.
- Original bold 2D sneaker mascot, energetic teammate personality; avoid copying Duolingo's character.
- Logo, icons, illustrations, rich motion, spoken guidance, chimes and haptics.
- Separate voice, sound and vibration preferences; respect reduced motion and text scaling.

## Architecture decisions

- Keep Flutter/Riverpod, the existing firmware telemetry contract, pure-Dart test sessions and Hive trial records.
- The trainer device owns the canonical test clock, sensor connection, fall decisions and saved trial. Participant is a guided observer; it must not create authoritative results or change trainer decisions.
- A versioned `SharedAssessmentSnapshot` transports phase, test, participant ID, standing leg, canonical elapsed time, fall counts, flag state and final result. Include a revision and session/trial identity so stale or reordered packets cannot replace current state.
- Start with one participant per trainer session. A room/join credential grants observer access; a separate trainer credential grants control. No participant names are needed; existing IDs suffice.
- Local: trainer-hosted WebSocket room on Android using conditional `dart:io` code; participant joins by address + room credential. No laptop/server or internet should be necessary. QR support follows manual-code/address joining.
- Internet: a separate room broker using the existing Node/ws runtime, not the ESP32 passthrough relay. Trainer publishes snapshots through `wss://`; participant subscribes with scoped credentials. Configure a broker endpoint at runtime. Implement/test locally before external hosting; do not silently deploy or invent a configured service.
- On link loss, trainer can continue and save locally; participant shows disconnected/stale state, never a live-looking frozen reading. Rejoin retrieves the latest snapshot and confirmed result. A new trial must clear old display state.
- Mascot assets live in app assets, with a provenance/prompt record. Use real Niva logo assets from `media/brand`.
- Bundle the display font locally so a fitness assessment UI does not depend on runtime font downloads.
- Keep haptics and audio in a testable feedback service, not inside protocol timing code. Spoken guidance finishes before the canonical timing starts; countdown is a preparation stage, not balancing time.

## Screen map

- Welcome: original mascot, logo, participant/trainer choices and concise descriptions.
- Home: trainer starts assessment / participant joins; recent real results; changing role is explicit.
- Assessments: illustrated cards, protocol-specific setup, readiness and placement, role-aware flow.
- Preparation: mascot guidance, written instructions, optional spoken instructions, ready confirmation.
- Runner: trainer clock/controls; participant pose guidance/status. Restrained motion during scoring; never move controls out from under fingers.
- Results: measured count/hold time, saved status, event agreement, participant celebration for completion. No invented health or stability scores.
- Progress: real saved trials, participant filters and like-for-like comparisons by test/standing leg. Missing baseline remains an empty state.
- Device: BLE/Wi-Fi, tare and truthful readiness; advanced endpoints tucked behind progressive disclosure.
- Preferences: role, voice, chimes, haptics, motion and shared-session endpoint/transport.

## Implementation order

Tasks T01–T04 establish a complete single-device visual experience and persistent preferences. T05–T07 finish guided assessments and feedback. T08 defines shared-session contracts before T09–T12 implement local and internet paths. T13–T15 add progress, QR convenience and Android verification. See `todo.md` for individually verifiable slices.

## Verification bar

- Existing Flamingo/Vrikshasana rules, sensor-derived timing and trial exports must remain correct.
- Tests exercise functional behavior, reconnection, authorization, timing and accessible layout, not copies of UI implementation.
- `flutter analyze`; record pre-existing diagnostics separately.
- `flutter test`; full suite after shared foundations or protocol/transport changes.
- `flutter build web --no-wasm-dry-run` for the reviewable browser preview; conditional native transports must have honest web fallbacks.
- Android APK compile and physical two-phone/insole check before calling mobile networking/audio/haptics verified.
- Review actual light-theme screens at small phone size, 200% text, landscape, keyboard visible, disconnected/empty/error states. Exercise reduced motion.
- Broker integration checks: two clients, bad join credentials, forbidden observer writes, duplicate/out-of-order revisions, disconnect/rejoin and result recovery.

## Boundaries

No diagnostic, screening, fall-risk or injury-risk claims. No force/pressure output from the relative FSR indices. No accuracy claims until F1–F5 have real measurements. No national benchmark/partnership claim. Photos, renders and generated illustrations must retain their provenance. Rewards celebrate effort/completion, not invented fitness ratings.

Preserve the earlier local UI polish and cleanup fixes. Do not discard unrelated untracked assets or rewrite the Aavishkar material. Do not commit, push, open/merge PRs, or deploy solely because this plan exists; the current user request authorizes planning and implementation in the workspace.

## Risks / unresolved external requirements

- Phone-hosted local sessions: hotspot client isolation, Android network permission and actual-device addressing need testing early.
- Internet broker: public hosting/URL/TLS/provider not selected. Implementation and local verification can proceed; an external deployment cannot be marked done without a real endpoint and appropriate authorization.
- True sensor agreement still requires F1–F5; UI quality is not evidence of measurement accuracy.
- Audio/haptics: Android native plugins may need device-specific configuration; browser visuals do not verify vibration or speech engines.
- Generated mascot transforms are not a frame-by-frame pose demonstration. Additional pose/expression assets or a rig must be explicitly implemented and checked.
- Startup currently initializes settings/Hive before UI; failures need a recoverable startup view before release.

## Handoff discipline

At each checkpoint, update current task, actual implemented behavior, touched files, exact checks/results, remaining risks and the next concrete action. Mark a checkbox complete only after its acceptance criteria pass. Save asset paths and dependency versions. Prefer the existing working directory; changes are currently uncommitted and must be preserved. A successor should start with `git status`, read this plan, and resume the first unchecked task without repeating the brainstorming.
