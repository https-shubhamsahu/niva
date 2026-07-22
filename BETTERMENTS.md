# Betterment ideas for GaitGuard Nexus

Organized roughly by effort. None of this is required to use the app - it's
the "everything you're open to" list.

## Already done in this rebuild

- Apple Health-style triple ring (Stability / Cadence / Impact safety) instead of a single Recharts radial bar.
- Procedural foot pressure map with animated center-of-pressure marker and fading trail - no image asset to ship or go stale.
- Single `TelemetryController` as the source of truth, so Dashboard/Trends/Insights/Device all read one state instead of four screens each re-deriving it from raw packets.
- Runtime-configurable connection settings (Device tab) instead of build-time `.env` files - point the app at a different insole without rebuilding.
- Dark mode follows system automatically (`ThemeMode.system`).

## High-value, moderate effort

- **Bluetooth LE transport.** WiFi WebSocket requires the insole and phone to share a network (or the phone to join the insole's AP). BLE would let the app connect directly, works better for a "wearable" product, and uses far less power on the ESP32 side than keeping WiFi radio up. `flutter_reactive_ble` is the most actively maintained option; the firmware would need a GATT service alongside (or instead of) the WebSocket server.
- **Auto-discovery instead of manually typing an IP.** mDNS/Bonjour (`multicast_dns` package) or BLE advertising so the Device tab can show "GaitGuard-3F2A found nearby" instead of asking someone to find `192.168.4.1` themselves.
- **Apple HealthKit / Google Health Connect integration.** Apple already ships a "Walking Steadiness" metric in HealthKit that is conceptually almost identical to this app's Stability Index - writing GaitGuard's score into HealthKit would let it show up in the stock Health app's own trends, and let this app read step count / walking speed HealthKit already has instead of only trusting the insole's own step detector.
- **Clinician PDF export.** The web app had `ClinicianPDF.tsx` / `ClinicianPDFDark.tsx`; this rebuild doesn't have an equivalent yet. The `pdf` + `printing` Flutter packages would let you generate the same kind of one-page clinical summary and share/print it directly from the Insights tab.
- **Local notifications for anomaly flags.** Right now an anomaly flag only shows up if someone has the app open. A `flutter_local_notifications` push the moment "Ischemic pressure risk" or "High sway instability" fires would make this genuinely useful for someone wearing the insole during normal daily activity, not just during a supervised session.
- **Biometric app lock.** This is health data tied to a specific person's gait pattern - `local_auth` (Face ID / fingerprint) before showing any dashboard content is a low-effort, high-trust addition, especially once HealthKit sync is in place.
- **Move the biomechanics engine onto a background isolate.** At the moment `BiomechanicsEngine.process()` runs on the UI isolate. It's cheap per-call today, but if you raise the sample rate or add heavier per-frame analysis later, an `Isolate`/`compute()` boundary keeps the ring animations from ever janking.

## Product/clinical direction

- **Multi-profile support.** One device, multiple people (e.g. a household member helping a parent with neuropathy monitor their own risk) - session/trial metadata already exists in the data model, this is mostly a UI + local-profile-switcher exercise.
- **Week-over-week trend comparison**, the way Apple Health's own "Trends" tab flags "your walking steadiness is declining" - the rolling history buffer this app already keeps per-session would need to persist and aggregate across sessions (the Hive dataset store already has everything needed; it just isn't aggregated by day yet).
- **Apple Watch / Wear OS companion** showing the live Stability ring on the wrist during a walk, using the phone as the WebSocket bridge to the insole.
- **Colorblind-safe palette option** for the pressure map - right now "high pressure" is signaled by a shift toward red, which is the single worst choice for red-green colorblind users. An alternative palette (e.g. blue→yellow) toggle would fix this cheaply.
- **Second insole / bilateral support.** The current hardware and data model are single-insole. If a second board ever gets built, the data model (`TelemetrySample`) would need a `foot: left | right` field and the dashboard would show two foot maps side by side - worth deciding early since it touches the wire protocol.

## Robustness / infra

- **Offline upload queue with retry/backoff.** The dataset upload today is a single fire-and-forget attempt (`ResearchUploadService.uploadCsv`). A durable queue (e.g. `workmanager` for background retry on Android) would matter a lot if this is ever used somewhere with unreliable connectivity.
- **Compress CSV before upload** (gzip) once dataset sizes grow past a few thousand samples.
- **CI.** The original repo deploys via GitHub Actions to GitHub Pages. A parallel Actions workflow running `flutter analyze && flutter test` on every PR would catch regressions before they reach a device - and would have caught anything wrong with this handoff, since this environment couldn't run that step itself.
- **Golden tests** for `HealthRings` and `FootPressureView` (`flutter_test`'s `matchesGoldenFile`) - these are the two custom-painted widgets and the ones most likely to visually regress silently.

## Accessibility

- **Dynamic Type support.** Current text styles are fixed sizes; wrapping them to respect `MediaQuery.textScaleFactor` (or migrating to `TextScaler`) matters a lot for a health app specifically.
- **VoiceOver/TalkBack labels** on the rings and foot map - right now both are purely visual; a screen-reader user gets nothing from them. `Semantics` widgets wrapping the ring value and each pressure zone would fix this.
- **Reduce-motion respect.** The ring fill animation and COP marker movement should check `MediaQuery.disableAnimations` and skip the tween when the system-level "reduce motion" setting is on.

## Testing

- `test/biomechanics_engine_test.dart` is included but **has not been run** (no Dart SDK in the environment this was built in) - running `flutter test` should be the very first thing you do after `flutter pub get`, before trusting anything else here.
- Integration tests driving the on-device simulator end-to-end (start simulation → assert ring values move → stop) would catch state-management regressions that unit tests on the engine alone can't.
