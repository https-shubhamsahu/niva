# Niva (GaitGuard Nexus) - Flutter

A from-scratch Flutter rebuild of the [niva](https://github.com/https-shubhamsahu/niva) React/ESP32 dashboard, redesigned around Apple Health's visual language: grouped cards, three concentric "activity rings" for the headline metrics, procedurally-drawn plantar pressure map, and spring-eased animations throughout.

This isn't a wrapper around the web app - it's a native rebuild that keeps the same **explainable, rule-based biomechanics engine** (every score traces to an explicit threshold, no black-box model) and the same ESP32 firmware, but replaces the UI and app shell entirely.

## Status - please read before running

This project was built and reasoned through carefully, but **the sandbox it was written in has no Flutter/Dart SDK available**, so none of this has been run through `flutter analyze`, `flutter pub get`, or `flutter test`. Everything below is what you should do first.

## Setup

Flutter's own tooling has to generate the platform folders (`android/`, `ios/`, etc.) - those aren't included here, only `lib/`, `test/`, and the two config files.

```bash
# 1. Scaffold a fresh Flutter project
flutter create --org com.yourcompany --project-name niva niva_app
cd niva_app

# 2. Replace the generated pubspec.yaml, analysis_options.yaml, lib/, and test/
#    with the ones from this folder (back up main.dart first if curious).
rm -rf lib test
cp -r <path-to-this-folder>/lib .
cp -r <path-to-this-folder>/test .
cp <path-to-this-folder>/pubspec.yaml .
cp <path-to-this-folder>/analysis_options.yaml .

# 3. Install packages
flutter pub get

# 4. Sanity-check before doing anything else
flutter analyze
flutter test

# 5. Run it
flutter run
```

If `flutter analyze` flags anything, it's most likely one of:
- an `fl_chart` API name that shifted between minor versions (pin the exact version in `pubspec.yaml` if so),
- a `share_plus`/`XFile` export path change,
- Android/iOS permission entries you'll need to add manually (see below).

## Platform permissions you'll need to add

- **Network / cleartext HTTP:** connecting to a `ws://` (not `wss://`) ESP32 on your LAN requires:
  - Android: `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`, plus the `INTERNET` permission.
  - iOS: an `NSAppTransportSecurity` exception for local networking, plus `NSLocalNetworkUsageDescription` in `Info.plist` (iOS 14+ prompts the user for local network access the first time you connect).
- **Sharing (Export CSV):** `share_plus` needs no extra manifest entries on modern Android/iOS, but iPad requires a popover anchor for the share sheet if you see a crash there - see the `share_plus` README.

## What changed vs. the web app, and why

| Web app | This app | Why |
|---|---|---|
| Web Serial (USB) | Not included | No mobile equivalent to Web Serial. WebSocket-over-WiFi is the only transport here; see BETTERMENTS.md for the BLE/USB-OTG path. |
| WebSocket + `wss://` relay for mixed-content | WebSocket only, relay still supported | Native apps aren't subject to browser mixed-content policy, so the relay dance is optional here, kept only for people routing through a gateway. |
| IndexedDB dataset store | Hive (schema-less boxes) | Same flexibility, no generated adapters, so no build_runner step is required to build the project. |
| Recharts (radial bar, area, line) | `fl_chart` + hand-rolled `CustomPainter` rings | Apple Health's rings aren't a stock chart type in any charting library, so they're custom-painted; trend lines use `fl_chart` since a stock line chart is exactly what's needed there. |
| Foot heatmap over an uploaded photo (`feet.png` + `simpleheat`) | Procedurally drawn foot outline + radial-gradient pressure zones | Zero image assets to ship, and the outline recolors per theme for free. Visually simpler than the original, intentionally - see BETTERMENTS.md if you want the photographic look back. |
| One `MainDashboard.tsx` doing everything (~1000 lines) | `TelemetryController` (Riverpod `StateNotifier`) + four thin screens | Trends and Insights need the same live metrics Dashboard has; centralizing state means they read the same provider instead of re-deriving it. |
| 3D foot views, anatomy/heatmap legends, clinician PDF export, detailed symmetry report | Not ported | These are additional presentational variants of the same underlying data. Left out of this pass to keep the core experience polished rather than spreading thin - all are straightforward to add back using the same `TelemetryController` state. `pdf` package + `printing` package would cover the clinician PDF export directly. |

## Architecture

```
lib/
  core/
    models/           Pure data classes (RawSensorPacket, ProcessedBiomechanicsMetrics, TelemetrySample, ...)
    engine/            BiomechanicsEngine + SimulationEngine - pure Dart, no Flutter import, unit-testable
    connectivity/       Esp32SocketService - WebSocket client with auto-reconnect
    data/              SettingsRepository (SharedPreferences), TelemetryRepository (Hive), ResearchUploadService (http)
    providers/         Riverpod wiring - TelemetryController is the single source of truth every screen reads
  features/
    dashboard/         "Today" screen - rings, foot pressure map, live metrics grid
    trends/            Sparkline trend cards sourced from the engine's rolling history buffer
    insights/          Plain-English clinical summary + explainability panel
    device/            Connection settings, session metadata, dataset export/upload
    shell/             Bottom tab shell (IndexedStack, keeps all four tabs alive)
  theme/               Apple Health-inspired color/type tokens
  shared/widgets/       RoundedCard, MetricTile, SegmentedToggle, ConnectionBadge - the small reusable pieces
```

The firmware in the original repo (`firmware/esp32_gaitguard_wifi_manager/esp32_gaitguard_wifi_manager.ino`) needs **no changes** - this app speaks the same JSON-over-WebSocket protocol.

## Configuration

The web app used `.env.local` (`VITE_ESP32_WS_URL`, `VITE_DATASET_UPLOAD_URL`, etc.). This app has no build-time env file - all of that is a **runtime setting on the Device tab**, persisted with `shared_preferences`, so you (or a clinician) can point the app at a different insole or upload endpoint without a rebuild.

See `BETTERMENTS.md` for the full list of suggested next steps (BLE, HealthKit/Health Connect, Watch companion, background logging, and more).
