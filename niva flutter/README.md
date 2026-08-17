# Niva Flutter

Patient/user-facing mobile application for Niva (GaitGuard Nexus). This is a native Flutter rebuild of the web dashboard: Apple Health-inspired cards and activity rings, a procedurally drawn plantar pressure map, and the same explainable biomechanics engine.

It is not a WebView wrapper. It speaks the same ESP32 JSON-over-WebSocket protocol as `niva web`.

## Technology stack

- Flutter / Dart 3.3+
- Riverpod
- Hive + `shared_preferences`
- `web_socket_channel`
- `fl_chart`, `google_fonts`, `share_plus`, `http`

Platform folders already in this project: `android/`, `ios/`, `windows/`, `web/`.

## Directory structure

```text
lib/
  core/
    models/            Packet and metric types
    engine/            BiomechanicsEngine + SimulationEngine
    connectivity/      Esp32SocketService (WebSocket + reconnect)
    data/              Hive dataset store, settings, optional CSV upload
    providers/         TelemetryController is the source of truth
  features/
    dashboard/         Today: rings, foot map, live metrics
    trends/            Cadence / stability / impact charts
    insights/          Clinical summary + AI coach card
    device/            Connection, session metadata, export/upload
    shell/             Bottom tab shell
  theme/
  shared/widgets/
test/
  biomechanics_engine_test.dart
assets/
  images/feet.png
  icon/
```

## Setup

```bash
cd "niva flutter"
flutter pub get
flutter analyze
flutter test
flutter run
```

Android already enables `INTERNET` and `usesCleartextTraffic` so `ws://` ESP32 endpoints on the LAN can connect. iOS still needs a local-network usage description if you ship to a device (see `ios/Runner/Info.plist`).

## Configuration

There is no `.env` file. WebSocket URL, optional relay URL, session/trial IDs, and upload endpoint are runtime settings on the Device tab, persisted with `shared_preferences`.

## Connection to other Niva components

- Firmware: `niva arduino/niva_hardware/niva_hardware.ino` (active) or the simpler `esp32_gaitguard_wifi_manager` sketch. Packet shape is the same.
- Web: `niva web` is the clinician dashboard with USB Serial plus extra visualization pages that were not ported here (3D foot views, clinician PDF).
- BLE / USB-OTG are not implemented in this app. See `BETTERMENTS.md` and `CONNECTIVITY_PLAN.md`.

## Additional docs in this folder

- `DESIGN.md` — visual language
- `BACKEND_LOGIC.md` — data contract and storage
- `SIMULATION_LOGIC.md` — disease-mode simulator
- `BETTERMENTS.md` — follow-up ideas (BLE, HealthKit, etc.)
