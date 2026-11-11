# Niva redesign — agent handoff

Last updated: 1 October 2026, Asia/Kolkata. Update this before ending any implementation session.

## Current checkpoint

Checkpoint A complete: T01–T04 verified. Resume T05. No shared phone sessions or spoken/chime feedback implemented yet.

## User authorization and choices

User explicitly asked to plan the full long task so another coding agent can resume when tokens run out, and to start working. The previous brainstorming approved: equal participant/trainer roles; assessment-first home; separate phones; local AND internet sessions; Android first; light teal/white/coral/lime; original 2D animated sneaker mascot; energetic teammate personality; voice guidance + chimes + independent sound/vibration controls. Do not re-ask these questions.

Read `plan.md` and `todo.md` in this folder. Those contain architecture, acceptance criteria and remaining external dependencies.

## Workspace and prior state

- Repo: `C:/Users/shubh/_Active_Projects/niva`.
- Flutter: `startup/niva flutter` (paths contain spaces).
- Shell: PowerShell. Flutter: `C:/Users/shubh/AppData/Local/flutter/bin/flutter.bat`; Python: `C:/Python313/python.exe`.
- Existing branch/working changes must be inspected with `git status` and preserved. Nothing from this task has been committed/pushed.
- Before this redesign, local edits already existed in README, theme, shell, cards, Tests tab/tests, BLE cleanup and providers. These are intentional earlier polish; do not reset them.
- Untracked Aavishkar/SIH/media material predates this task; do not remove it or include it in a broad commit.
- Previous verified baseline: 40 Flutter tests passed; web build succeeded; analyzer had only two existing info notes in `features/device/device_screen.dart` (curly braces). Real-phone/insole testing has not happened.
- Previous preview: Python static server on `127.0.0.1:5189`, serving `startup/niva flutter/build/web`. Browser preview is NOT physical Android verification. Refresh/rebuild to see current edits.

## Important implementation facts

- `main.dart` initializes SharedPreferences and Hive before `NivaApp`.
- `features/shell/app_shell.dart` preserves Home/Tests/Trends/Device via animated opacity; outgoing opacity animation must stay outside disabled TickerMode, or a hidden tab freezes onscreen. Trends remains actual sensor trends until T13; live readings can be opened from Home.
- Existing Tests tab supports setup, tester-only mode, insole flags, local trial storage, search/filter and CSV export.
- Protocol engines are pure Dart in `core/fitness/`; avoid changing rules merely for visual effects.
- Trainer controller owns monotonic timing and confirms/rejects contact flags; firmware device times are mapped to phone time upstream.
- `StateNotifierProvider` disposes its notifier automatically. The old duplicate dispose callback was removed.
- BLE cleanup now avoids emission into a closed stream.
- Existing web relay is only ESP32 passthrough, not multi-phone session synchronization.
- Logos: `media/brand/niva_logo_assets/`; copy selected app-consumed assets into Flutter assets.

## In-progress / verification log

- Default appearance is light with teal/white/coral/lime; `NivaSans` is bundled Inter, no runtime font download. `google_fonts` dependency removed.
- Original imagegen sneaker asset: `startup/niva flutter/assets/mascot/sneaker-wave.png`. Existing logo copied to `assets/brand/niva-lockup.png`. Font/license: `assets/fonts/Inter-Variable.ttf`, `OFL-Inter.txt`. `assets/PROVENANCE.md` records sources, generation mode and full prompt.
- Native float/tilt and welcome reveal implemented. OS/app reduced motion stop/simplify effects; hidden mascot tickers stop. The waving pose is decorative, not pose instruction. Other mascot states remain T07.
- Experience preferences use atomic JSON under `niva.experience.v1` in SettingsRepository. `core/experience/` model/provider, `features/experience/` welcome/home/preferences, and `main.dart` gate remembered roles. Participant cannot reach trainer controls through its home.
- Voice/chime controls persist but playback awaits T06; settings copy explicitly says this. Existing widget and controller haptics respect the preference via HapticPreferences/AppHaptics and a controller callback. Native vibration has not been observed on hardware.
- Trainer home opens current setup/run directly and shows up to two actual saved trials; no fake streaks or scores. Participant join displays an explicit unavailable-preview sheet; no simulated pairing.
- Added 7 experience tests (total 47); all pass. Previous runner tests now use the real bundled-font theme. A new test completes a 12-second hold from home and sees its saved result; large-text/role/feedback/motion checks included.
- Analyzer reports **No issues found**. Two prior device brace lint notes fixed in the touched file. `git diff --check` passes. Web release build succeeded (82.4s); existing missing unused CupertinoIcons-family tree-shaking warning remains. Android build/physical devices not verified.
- Root `.gitignore` had a broad `data/` research rule hiding ALL `lib/core/data/` Flutter source. Added a narrow exception for that source folder. Its existing repository files now appear untracked; preserve/include these source files in a future intentional commit. Nothing committed or pushed.
- Browser checked welcome, trainer home, role preferences, participant home after reload, and truthful join messaging. Static preview remains `http://127.0.0.1:5189/`. Flutter accessibility activation: press Enter on the tiny `Enable accessibility` placeholder (a click alone may not activate it).
- Screenshots in `C:/Users/shubh/.codex/visualizations/2026/10/01/01a0f7b2-9b4e-7eb1-b234-5d93de39ea83/`: `niva-welcome.png`, `niva-trainer-home.png`, `niva-participant-home.png`. These are browser evidence, not Android verification.
- Build/test commands: run Flutter from `startup/niva flutter`; full-path executable above. `flutter test`, `flutter analyze`, `flutter build web`. Existing static server serves build/web. No Flutter hot-reload process is currently maintained.

## Next concrete action

Implement T05: a guided preparation screen and assessment runner styling consistent with the new home. Inspect existing `_SetupSheet`, `TestRunScreen` and pure-Dart rules first. Any readiness/countdown happens BEFORE `TestRunController.start()`; preparation cancellation must write no trial. Keep canonical timing/flag decisions untouched. Then T06 feedback service (voice/chimes/haptics, cancel on exit) and T07 true save progress/failure with retry and completion mascot states. The controller currently assigns `_saved` before `store.add` succeeds; fix this in T07 before claiming durable-save completion. Keep participant joining explicitly unavailable until T09/T10 implement real transport.

## Resume prompt (copy to another coding agent)

> Continue the Niva Flutter redesign in `C:/Users/shubh/_Active_Projects/niva`. First read `tasks/HANDOFF.md`, `tasks/plan.md`, `tasks/todo.md`, `PROJECTS.md`, and `sih-26213/README.md`; inspect `git status`. Preserve all existing work and unrelated assets. Resume the current task and first unchecked acceptance criteria, without repeating the brainstorming. Implement a complete, verifiable slice, run appropriate tests/builds, and update HANDOFF/todo with actual results and the next concrete action before stopping. Keep measurement claims honest; Android-first two-phone local AND internet sessions are in scope, but external hosting and physical-device checks must be recorded separately. Do not claim complete or production-ready while required tasks remain.

## 2 Oct 2026: SIH26213 direction change and verification

- SIH26213 pitch is now **Niva Sakshi**, a Flamingo balance-test station (beam + held-foot insole + teacher confirms). Plan, blueprint and portal text: `sih-26213/sakshi/`. App work it needs: beam as a flag source, class roster, device time per loss in the trial CSV, One-Leg Minute, Android APK. None of these exist yet.
- Re-run today: `flutter analyze` no issues; `flutter test` 47 passed; firmware `contact_detector_test` all checks passed (build with `-std=gnu++17`; `c++17` fails on `M_PI`). Still no real-phone or real-insole session.
- `.github/workflows/deploy-pages.yml` now has `workflow_dispatch` only, so the old GaitGuard dashboard stops auto-deploying once this branch merges. Uncommitted.
- Later on 2 Oct, in the fork `niva sakshi/app` (not `startup/niva flutter`): beam flag source (codes B/X, stream stub), device time per loss in the trial CSV, class roster, Witness record (counts only) and One-Leg Minute screens are built. `flutter test` 60 passed, `flutter analyze` clean.
- Android APK built: `niva sakshi/app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.1 MB, package `com.shubhamsahu.niva.sakshi`, debug-signed). Earlier builds crashed with Gradle JVM native out-of-memory; `android/gradle.properties` in the fork now uses a 1.5 GB heap, one worker and in-process Kotlin. **Not installed on any phone yet**: no device or emulator was connected. Next action: sideload it, then run the C2 checks in `niva sakshi/TASKS.md`.

## 2 Oct 2026 evening: Sakshi identity, foot map and photos (fork `niva sakshi/app`)

- Codex hit its usage limit mid-verification of the user's last request (live foot heat map from the earliest Niva app, real internet photos, a new Niva Sakshi logo family used across the app). Claude Code finished it.
- Built by Codex: witness-eye identity (`docs/brand/`, exporter `app/tool/build_brand.mjs`), Android/iOS/web/Windows icons and splash, Flutter launch animation and welcome mark, live foot map (`lib/features/dashboard/widgets/foot_load_view.dart`) with expandable sheet, two Pexels photos with credits. Doc: `niva sakshi/docs/BRAND-AND-IMAGERY.md`.
- Fixed by Claude: (1) the in-app eye mark had a notch at its left corner because `extractPath` stays open at full length; the finished eye is now drawn as the closed path (`lib/shared/widgets/sakshi_brand.dart`). (2) Contact rings covered the foot image's printed labels; they now enclose the label bubbles. (3) The capture tool's "UI PREVIEW · SCRIPTED SENSOR DATA" label rendered as red boxes; it is now styled and readable.
- Verified: `flutter analyze` no issues; `flutter test --concurrency=1` 65 passed (a parallel run crashed the test shell, 15 "did not complete"; not a code failure); captures regenerated and copied to `niva sakshi/docs/previews/` (11 PNGs); `flutter build web --release` passed; ARM64 release APK rebuilt, 21.3 MB, 18:57.
- Still not done: install on a real phone, native icon/splash check on device, real insole session. Next action unchanged: sideload the APK, then the C2 checks in `niva sakshi/TASKS.md`.

## 2 Oct 2026 night: first phone test → splash crop fix and motion (fork `niva sakshi/app`)

- User installed the APK. Android 12+ system splash cropped the eye's sides and the beam: the old icon filled its canvas, and Android crops splash icons to a centred circle 2/3 of the canvas. New `res/drawable/sakshi_splash_icon.xml` (+ night) puts the mark at 0.75 in a 192-unit/288dp canvas; `drawable-v31/sakshi_splash_animated.xml` animates it (beam, eye trace, dot pop; 900 ms, keyframes in `res/animator/`). Pre-12 launch mark now 144dp (`tool/build_brand.mjs` updated to match).
- User asked for Apple Health-like motion. Added `lib/shared/widgets/motion.dart` (Entrance, Pressable, RollingText, LivePulse, PopIn) and applied it to HealthPage, cards, Live tab, foot map, assessment ring/counter/result, tab switching, and Cupertino page transitions. Launch screen rebuilt to continue from the native splash frame and dissolve into the already-mounted app. Details: `niva sakshi/docs/UI-REDESIGN.md` § Motion.
- Verified: analyzer clean; `flutter test --concurrency=1` 70 passed (new `test/motion_test.dart`); captures and `docs/previews/launch-sequence.png`; web build ran in the browser pane without console errors; ARM64 APK 21.4 MB built (aapt accepted the animated vector). Not verified: the splash and motion on the physical phone; no device was connected over adb.
- If the phone shows no motion at all, check Android "Remove animations" / animator scale and the app's Reduce motion switch; the app deliberately honours them.

## 2 Oct 2026 night: web version deployed (fork `niva sakshi/app`)

- Live: **https://niva-sakshi.vercel.app** (Vercel project `niva-sakshi`, team https-shubhamsahus-projects, production). Redeploy: `bash "niva sakshi/app/tool/deploy_web.sh"` (stages `build/web` into `build/vercel/niva-sakshi`, which keeps the `.vercel` link).
- Desktop layout at ≥900px: sidebar shell, two-column `HealthPage`, landing-style Welcome, desktop Summary hero, large Live foot map, 680px assessment column. HTML loading animation, Open Graph image, browser-safe CSV export (`lib/shared/csv_share.dart`; removed the dart:io exporters).
- Verified: analyzer clean; 70 tests; 1440×900 widget captures in `niva sakshi/docs/previews/desktop-*.png`; live URL returns 200 publicly (no Vercel login), assets served; on the live site at 375px every card measured 20–355px. Not verified: Web Bluetooth with the insole (stated as untried in the UI).

## 2 Oct 2026 late night: demo mode (fork `niva sakshi/app`)

- User asked for a demo mode so judges can see live readings. Deliberate, user-approved exception to the earlier "no simulator" rule; rules recorded in `niva sakshi/docs/UI-REDESIGN.md` § Demo mode.
- `lib/core/demo/demo_walk.dart` (seeded firmware-format frames) → real `GaitTimingEngine` via `TelemetryController.startDemo/stopDemo`; `TelemetryState.isDemo`. Never written to the dataset, never published as contact events, `insoleStatusProvider` reports no insole, so assessments stay tester-only. Labelled DEMO / "simulated" on Live, Summary, sidebar, Device, foot-map sheet, Trends.
- Verified: analyzer clean; 72 tests (`test/demo_test.dart` added); demo captures in `niva sakshi/docs/previews/`; redeployed to https://niva-sakshi.vercel.app and the live bundle contains the demo. APK rebuilt on 3 Oct once memory allowed (ARM64, 21.4 MB; libapp contains the demo strings). Still not verified on a physical phone: no device was connected over adb.
- Laptop note: run tests with `flutter test --concurrency=1`, and close other heavy apps before APK builds.
