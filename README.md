# Niva

**Every step, understood.**

Niva is an explainable gait-analytics platform for a smart insole. Plantar pressure, impact, and IMU telemetry are acquired on an ESP32, streamed to software, then scored with explicit biomechanics rules rather than a black-box model.

This repository is a monorepo for the three implemented Niva applications.

## Architecture

```text
Smart Insole (FSR + piezo + MPU6050)
    ↓
ESP32 firmware  (niva arduino)
    ↓
BLE is not implemented. Live transport is USB Serial and Wi-Fi WebSocket.
    ↓
Web dashboard / optional WS relay  (niva web)
    ↓
Clinician / analytics UI

Flutter app  (niva flutter)
    ↓
Patient/user-facing mobile experience (same JSON telemetry protocol)
```

What is actually in the code:

- Firmware reads four FSR channels, a piezoelectric channel, and an MPU6050 IMU (in the active sketch).
- Telemetry is JSON over WebSocket (`:81`) and CSV over USB Serial at 115200 baud.
- The web app is a React + Vite clinician/research dashboard with IndexedDB storage.
- The Flutter app is a native rebuild of that dashboard for mobile, using Hive instead of IndexedDB.
- EMA filtering and gait-phase logic live in the software biomechanics engines, not as a separate firmware filter stage.
- The implemented IMU is **MPU6050**. This repo does not contain BMI270 firmware.

## Repository structure

```text
Niva/
├── niva flutter/     Mobile application (Flutter)
├── niva arduino/     ESP32 / Arduino firmware
├── niva web/         Clinician dashboard, Vite app, and WS relay
├── docs/brand/       Logo source assets
├── README.md
└── .github/          GitHub Pages deploy workflow
```

| Directory | Responsibility |
|---|---|
| `niva flutter/` | Patient/user-facing Flutter app: dashboard, device pairing over WebSocket, insights, trends, CSV export |
| `niva arduino/` | ESP32 firmware: ADC acquisition, calibration, IMU, telemetry, Wi-Fi / WebSocket |
| `niva web/` | Clinician dashboard, biomechanics visualization, dataset export/upload, optional WebSocket relay |

## Development prerequisites

Install only what you need for the component you are running:

- **Web:** Node.js 22+ and npm
- **Flutter:** Flutter SDK (Dart 3.3+)
- **Firmware:** Arduino IDE (or compatible ESP32 toolchain) with ESP32 board support

## How to run each component

### Web dashboard (`niva web`)

```bash
cd "niva web"
npm install
# if peer dependency conflicts appear:
npm install --legacy-peer-deps
npm run dev
```

Other supported scripts:

```bash
npm run build
npm run preview
npm run lint
```

Optional environment file: create `niva web/.env.local`

```bash
VITE_ESP32_WS_URL=ws://<esp32-ip>:81
VITE_ESP32_WS_RELAY_URL=wss://<your-relay-domain>/ws
VITE_ESP32_WS_RELAY_TARGET_KEY=target
VITE_DATASET_UPLOAD_URL=https://your-api.example.com/upload
VITE_DATASET_UPLOAD_TOKEN=your_optional_bearer_token
```

Optional local WebSocket relay (needed when a HTTPS dashboard must reach a `ws://` ESP32):

```bash
cd "niva web/relay"
npm install
npm start
```

### Flutter app (`niva flutter`)

```bash
cd "niva flutter"
flutter pub get
flutter analyze
flutter test
flutter run
```

ESP32 endpoint, relay URL, and upload URL are runtime settings on the Device tab (not build-time env files).

### Firmware (`niva arduino`)

Open one of these sketches in Arduino IDE, install the libraries listed in `niva arduino/README.md`, select an ESP32 board, and upload:

- **Active hardware sketch:** `niva arduino/niva_hardware/niva_hardware.ino`
- **Simpler hardcoded-WiFi sketch:** `niva arduino/esp32_gaitguard_wifi_manager/esp32_gaitguard_wifi_manager.ino`

Serial Monitor baud rate: **115200**.

## Hardware / firmware overview

Implemented on ESP32:

- FSR heel / inner / outer / toe on ADC pins 32, 33, 34, 35
- Piezoelectric heel disc on pin 36
- MPU6050 on I2C (SDA 21, SCL 22) in the active `niva_hardware` sketch
- Optional SH1106 OLED on the same I2C bus (address 0x3C)
- Oversampled ADC reads and zero-load tare calibration (NVS-persisted in the active sketch)
- WebSocket telemetry on port 81, USB CSV telemetry on Serial

The simpler `esp32_gaitguard_wifi_manager` sketch uses hardcoded Wi-Fi credentials and does not drive the IMU or OLED.

## Software overview

- **Web:** React 19, TypeScript, Vite, Tailwind, Recharts, IndexedDB
- **Flutter:** Flutter, Riverpod, Hive, `web_socket_channel`, `fl_chart`
- **Relay:** Node.js + `ws`
- **Deploy:** GitHub Pages via `.github/workflows/deploy-pages.yml` (builds `niva web`)

There is no application server or database in this repository. Dataset persistence is browser-local (IndexedDB) or on-device (Hive). CSV upload to an external research API is optional.

## Documentation

| Location | Contents |
|---|---|
| `niva flutter/README.md` | Flutter setup, architecture, and run commands |
| `niva arduino/README.md` | Firmware sketches, pin map, libraries |
| `niva web/README.md` | Dashboard setup, telemetry formats, Pages deploy |
| `niva web/JUDGES_WALKTHROUGH.md` | Algorithm and data walkthrough |
| `niva flutter/DESIGN.md` | Flutter visual/design notes |
| `niva flutter/BACKEND_LOGIC.md` | Data contract and storage |
| `docs/brand/` | Logo source assets |

This prototype is an engineering / research screening tool. It is not a medical diagnosis device.
