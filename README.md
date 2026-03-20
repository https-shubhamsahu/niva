# GaitGuard Nexus (NIVA)

<p align="center">
  <img src="public/niva_logo.jpeg" alt="NIVA Logo" width="220" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/build-tsc%20%2B%20vite-0ea5e9?style=for-the-badge" alt="Build badge" />
  <img src="https://img.shields.io/badge/lint-eslint-22c55e?style=for-the-badge" alt="Lint badge" />
  <img src="https://img.shields.io/badge/license-not%20specified-94a3b8?style=for-the-badge" alt="License badge" />
  <img src="https://img.shields.io/badge/version-0.0.0-f59e0b?style=for-the-badge" alt="Version badge" />
</p>

Deterministic, explainable gait analytics platform for ESP32 smart insole telemetry.

This project focuses on transparent biomechanics logic rather than black-box prediction. Every score and alert can be traced to explicit sensor rules.

## What This Project Does

- Streams plantar + IMU telemetry from ESP32 over USB Serial and WiFi WebSocket.
- Runs a real-time biomechanics engine for gait phase, cadence, COP, stability, and anomaly detection.
- Stores samples locally in IndexedDB with disease/session/trial metadata.
- Exports datasets as CSV and supports one-click backend upload for research pipelines.
- Supports disease-mode simulation for demos and algorithm walkthroughs.

## Explainability First

This is an explainable rule-based system. Core decisions are derived from explicit thresholds and state transitions:

- Contact detection from total normalized plantar pressure.
- Heel-strike events from impact + heel-rise transition constraints.
- Gait phase classification using interpretable phase rules.
- Cadence from heel-strike intervals.
- Stability from pitch/roll sway and impact penalties.
- Risk flags from sustained pressure and kinematic instability conditions.

Primary implementation file:

- src/utils/biomechanicsEngine.ts

## Data Pipeline

End-to-end flow:

ESP32 packet -> transport parsing -> biomechanics engine -> dashboard state -> dataset store -> CSV/export/upload

Coordinator file:

- src/pages/MainDashboard.tsx

## Architecture Diagram

<p align="center">
  <img src="public/architecture-diagram.svg" alt="GaitGuard Nexus Architecture Diagram" width="960" />
</p>

## Supported Input Formats

### USB Serial (CSV)

Expected line format:

```text
H,I,O,T,Piezo,Pitch,Roll,AccZ
```

Example:

```text
45,70,25,20,160,-2.1,1.4,9.78
```

### WiFi WebSocket (JSON)

Example payload:

```json
{"heel":42,"inner":68,"outer":31,"toe":27,"pitch":-2.4,"roll":1.3,"piezo":176,"accZ":9.72}
```

## Dataset Schema

Samples are persisted in browser IndexedDB.

- Database: gaitguard-nexus-datasets
- Store: esp32_samples

Per sample fields:

- timestampMs
- source (usb | ws | sim)
- sessionId
- trialId
- diseaseLabel (Unknown | Normal | Parkinson | Stroke | Neuropathy | Foot Drop | Ataxia)
- mode (live | simulation)
- heel
- inner
- outer
- toe
- impact
- pitch
- roll
- accZ

Disease labeling behavior:

- Live USB/WiFi packets use operator-selected disease label.
- Simulation packets auto-tag from active simulation mode.

## Backend Upload Contract

One-click upload sends multipart form-data with:

- file (CSV)
- sampleCount
- generatedAt
- datasetType (esp32-biomechanics)
- sessionId
- trialId
- diseaseLabel

Upload helper:

- src/utils/researchUpload.ts

## Quick Start

1. Install dependencies:

```bash
npm install
```

2. If peer dependency conflicts appear, use:

```bash
npm install --legacy-peer-deps
```

3. Start development server:

```bash
npm run dev
```

4. Open the app URL shown by Vite.

## Environment Variables

Create .env.local in project root if needed:

```bash
VITE_ESP32_WS_URL=ws://<esp32-ip>:81
VITE_ESP32_WS_RELAY_URL=wss://<your-relay-domain>/ws
VITE_ESP32_WS_RELAY_TARGET_KEY=target
VITE_DATASET_UPLOAD_URL=https://your-api.example.com/upload
VITE_DATASET_UPLOAD_TOKEN=your_optional_bearer_token
```

## ESP32 on Any Device (WiFi and Hotspot)

Use Settings -> ESP32 WebSocket Raw Stream to set endpoint at runtime.

Examples:

- `ws://192.168.4.1:81` (ESP32 AP mode)
- `ws://<hotspot-assigned-esp32-ip>:81`
- `wss://<your-secure-relay-domain>/ws` (recommended for deployed HTTPS pages)

Important browser rule:

- GitHub Pages runs on HTTPS.
- Browsers block `ws://` from HTTPS pages (mixed-content restriction).
- For deployed usage on any device, configure `VITE_ESP32_WS_RELAY_URL` (wss) so the app automatically switches to relay mode.
- If relay is not configured, open the app locally over HTTP for direct `ws://` testing.

Automatic seamless fallback:

- App attempts direct mode when allowed.
- On HTTPS + `ws://` endpoint, app auto-routes through relay when `VITE_ESP32_WS_RELAY_URL` is set.
- Relay query parameter name defaults to `target`, configurable via `VITE_ESP32_WS_RELAY_TARGET_KEY`.

Sharing endpoint to another device:

- Use `Copy Share Link` in Settings.
- The generated URL includes `?esp32ws=<endpoint>` and auto-applies endpoint on open.

## Beginner WiFi Setup for ESP32

This section is for first-time users with no networking background.

Ready-to-flash firmware in this repo:

- firmware/esp32_gaitguard_wifi_manager/esp32_gaitguard_wifi_manager.ino

Required Arduino libraries:

- WiFiManager (by tzapu)
- WebSockets (by Markus Sattler)

### What you are configuring

Your ESP32 needs to do two things:

1. Join a WiFi network (home WiFi or phone hotspot).
2. Expose a WebSocket stream so the dashboard can read live packets.

### Method 1: Hardcode hotspot or WiFi in firmware (easiest)

Use this when starting out.

```cpp
#include <WiFi.h>
#include <WebSocketsServer.h>

const char* ssid = "ShubhamHotspot";
const char* password = "12345678";

WebSocketsServer wsServer(81);

void setup() {
  Serial.begin(115200);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print('.');
  }

  Serial.println("\nWiFi Connected");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());

  wsServer.begin();
}

void loop() {
  wsServer.loop();

  const String packet =
    "{\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"pitch\":0,\"roll\":0,\"piezo\":0,\"accZ\":0}";

  wsServer.broadcastTXT(packet);
  delay(100);
}
```

After upload, open Serial Monitor. You should see:

- `WiFi Connected`
- `ESP32 IP: 10.x.x.x` or `192.168.x.x`

Then in app Settings:

- Connection Endpoint: `ws://<ESP32_IP>:81/`

If using deployed HTTPS app, also set Relay Endpoint.

### Method 2: WiFiManager (pro move)

If you do not want to hardcode WiFi every time:

- ESP32 creates its own setup WiFi.
- You connect once, enter credentials, and ESP32 saves them.

```cpp
#include <WiFi.h>
#include <WiFiManager.h>

WiFiManager wm;

void setup() {
  Serial.begin(115200);

  bool connected = wm.autoConnect("ESP32_Setup");
  if (!connected) {
    Serial.println("Failed to connect");
    return;
  }

  Serial.println("WiFi Connected");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

void loop() {}
```

How it works:

1. ESP32 starts temporary AP: `ESP32_Setup`.
2. Connect your phone to it.
3. Open `192.168.4.1` in browser.
4. Enter hotspot SSID/password.
5. ESP32 saves and reconnects automatically next boot.

### Common mistakes (do not ignore)

- Wrong hotspot name/password.
- WiFi names are case-sensitive (`ShubhamHotspot` is not `shubhamhotspot`).
- Weak hotspot signal (keep phone close to ESP32).
- 5 GHz hotspot only (ESP32 needs 2.4 GHz).
- Forgot to reboot ESP32 after changing WiFi.

### Pro tips

- Always print IP after connect:

```cpp
Serial.println(WiFi.localIP());
```

- Add LED indicator for connected/disconnected state.
- Use WiFiManager for real deployments with changing hotspots.
- Add auto-reconnect logic in `loop()`.

### Reality check

ESP32 does not behave like a phone that auto-discovers everything.

You must provide:

- WiFi network name
- WiFi password

Or implement logic (WiFiManager/fallback) that collects and stores this for you.

### Switching to another phone hotspot

When you change hotspot, ESP32 usually gets a new IP.

Do this every time:

1. Connect ESP32 and your relay laptop to the new hotspot.
2. Reboot ESP32.
3. Read new IP from Serial Monitor.
4. Update app Connection Endpoint to `ws://<new_ip>:81/`.
5. Keep same relay URL if still active, otherwise generate a new tunnel URL.

### Connection pitfalls in this project

- Relay URL expired (quick tunnel links are temporary).
- ESP32 got a new hotspot IP and app still points to old IP.

### Make it less fragile (recommended)

For better real-world behavior, implement:

- Auto reconnect when `WiFi.status() != WL_CONNECTED`.
- Fallback list of known SSIDs.
- Periodic `Serial.println(WiFi.localIP())` after reconnect.
- Status LED for connected/disconnected state.

## Main Routes

- /main: live telemetry dashboard + simulation + dataset controls
- /settings: Nexus console, hardware matrix, raw WebSocket monitor
- /insights: clinical insights views
- /trends: trend analytics

Router definition:

- src/App.tsx

## Key Files

- src/pages/MainDashboard.tsx: transport integration, engine binding, dataset actions
- src/utils/biomechanicsEngine.ts: explainable gait algorithms
- src/utils/esp32Telemetry.ts: USB CSV parser
- src/hooks/useSensorData.ts: WebSocket hook with reconnect
- src/utils/telemetryDatasetStore.ts: IndexedDB and CSV export
- src/utils/researchUpload.ts: backend upload utility
- src/utils/simulationEngine.ts: synthetic disease-mode frame generator
- JUDGES_WALKTHROUGH.md: algorithm and data presentation script

## Scripts

- npm run dev: start local dev server
- npm run build: type-check and production build
- npm run preview: preview production build
- npm run lint: run ESLint

## Deploy to GitHub Pages

This repo is configured for Pages deployment through GitHub Actions.

Workflow file:

- .github/workflows/deploy-pages.yml

How it works:

1. On push to main (or manual run), GitHub Actions installs dependencies and builds the Vite app.
2. Build base path is set automatically to /<repo>/ in CI using GITHUB_REPOSITORY.
3. The workflow copies dist/index.html to dist/404.html for SPA route fallback.
4. The generated dist artifact is deployed to GitHub Pages.

One-time GitHub setup:

1. Open repository Settings -> Pages.
2. Under Build and deployment, set Source to GitHub Actions.
3. Push your latest code to main.
4. Wait for Deploy to GitHub Pages workflow to complete.

Expected URL format:

- https://<your-username>.github.io/<your-repo>/

### Configure Relay Variables for Pages Build

For seamless ESP32 connectivity on deployed HTTPS pages, set repository variables:

1. Open GitHub repository Settings -> Secrets and variables -> Actions -> Variables.
2. Add variable VITE_ESP32_WS_RELAY_URL with your secure relay endpoint (example: wss://relay.yourdomain.com/ws).
3. Optional: add variable VITE_ESP32_WS_RELAY_TARGET_KEY if your relay expects a key other than target.
4. Optional: add variable VITE_ESP32_WS_URL for your default direct endpoint.
5. Push a new commit to main (or re-run the deploy workflow) so Vite rebuilds with updated variables.

This workflow reads these variables in:

- .github/workflows/deploy-pages.yml

## Troubleshooting

- Web Serial requires Chromium-based browser and localhost/https context.
- Ensure ESP32 serial baud rate is 115200.
- If no live data appears, check cable quality and COM port permissions.
- If WiFi stream fails, verify VITE_ESP32_WS_URL and ESP32 WebSocket server port.

## Research and Clinical Notes

This repository currently provides an engineering prototype for explainable screening support and data collection. It is not a medical diagnosis device.

For judging and deep algorithm mapping, see:

- JUDGES_WALKTHROUGH.md
