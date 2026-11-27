# E. Software review: firmware, Flutter app, web dashboard, relay vs production hardware

Reviewer: independent production-readiness pass, 9 Nov 2026. Repo `/home/shubh/_Active_Projects/niva-pcbway` at `2c67426` (branch `pcbway-silk-logo`). No repo files were changed.

## Scope and method

- Static review of `niva arduino/` (2 sketches), `niva flutter/lib` (27 files, 4,583 lines), `niva web/src` (5,076 lines incl. relay), and the hardware docs that define what firmware must do (PINMAP, ROLE-DESIGN-NOTE, ELECTRICAL-REVIEW, VERIFICATION-PLAN).
- Library behaviour was checked against the installed sources the sketches build with: WiFiManager 2.0.17 (`~/Arduino/libraries/WiFiManager`), arduinoWebSockets 2.7.2, ESP32 Arduino core 3.3.12 (ESPmDNS).
- **Run checks:** a pure-Dart harness (copies of `biomechanics_engine.dart`, `simulation_engine.dart`, `biomechanics_metrics.dart` in the scratchpad, run with `capped dart run`) fed the engine firmware-shaped packets. Output is quoted in E2, E5, E8, E9.
- `gh` for repo visibility, Pages config and open Dependabot alerts; `curl` for the deployed dashboard headers.
- **Not run:** `flutter analyze` / `dart analyze` (no `.dart_tool`, packages unresolved, `pub get` would download), `tsc`/`eslint` (no `node_modules`). No firmware was compiled or flashed. Nothing was measured on hardware.

## Headline

1. **There is no firmware for the production pod.** Both sketches target a classic-ESP32 perfboard (GPIO32-36 internal ADC, MPU6050 on I2C 21/22, SH1106 OLED, LED on GPIO2). None of those pins or parts exist on the Rev C.2 pod (ESP32-C3-MINI-1, MCP3208 over SPI, LSM6DSO32 over SPI, MAX17048). Confirmed.
2. **The apps in this repo implement a different product.** They are "GaitGuard Nexus", a Wi-Fi WebSocket gait dashboard. The production architecture (ROLE-DESIGN-NOTE: ankle hub + shoe node, ESP-NOW, BLE, offline log, P/U/X stride classes per `protected-steps/PROTOCOL.md`) has no client here. That protocol, its firmware (`startup/niva arduino/niva_protected_steps/`) and its app live in the separate `~/_Active_Projects/niva` repo, which was outside this review. A file listing shows that firmware still uses classic-ESP32 pins too (`ps_device.h:14-22`, GPIO32-36, button on GPIO0).
3. **The pressure numbers shown to users are wrong on real hardware, can be stale or fabricated, and are labelled with clinical meaning nothing supports.** See E2-E5.

Severity counts: **BLOCKER 7, MAJOR 11, MINOR 11, NOTE 2** (31 findings).

---

## BLOCKER

### E1. No firmware exists for the ESP32-C3 Rev C.2 pod
- **Evidence:** `niva arduino/niva_hardware/niva_hardware.ino:29-37` (GPIO32/33/34/35/36 ADC, SDA 21, SCL 22, LED 2), `:212-269` (MPU6050 raw I2C), `:67` (SH1106). `esp32_gaitguard_wifi_manager.ino:7-11`. `niva arduino/README.md` "Production ideas such as ESP32-C3 ... are not implemented" and "BLE is not implemented". Pod pin map: `hardware/outputs/NIVA-RevC2-protected-steps/PINMAP.md` §1-2 and `NIVA-3D-engineering-prototype/electronics/pin-map.csv`. On the C3, GPIO32-36 do not exist and ADC1 is GPIO0-4, which the pod uses for I2C, IMU_INT1, BUTTON and SPI.
- **Verified:** read both sketches, the PINMAP and the netlist CSV. Ran `git ls-files` for any `.ino/.h/.cpp/platformio` file: only the two sketches.
- **Fix:** write the C.2 firmware. Minimum module list, each traceable to a hardware doc:

| # | Module | Must do | Source |
|---|---|---|---|
| 1 | Board/toolchain | ESP32-C3 core 3.x or ESP-IDF 5.x, USB-CDC-on-boot (UART0 pins are LEDs), partition table with two OTA slots in 4 MB (N4) | PINMAP §1, §3 last para |
| 2 | MCP3208 driver (SPI, CS GPIO7) | 8 channels, SCLK ≤ 1 MHz, SPI mode 0, clock switched per CS. F1-F5 at ≥ 200 Hz with oversample + decimation. CH5 PVDF at ≥ 1 kHz peak-hold or per-contact peak. Codes are already ratiometric: no VEXC normalisation | ELECTRICAL-REVIEW:38, :53, :56 |
| 3 | CH6 tail-fault monitor | Discard the block and flag the fault when CH6 is outside ~2000-2400 | ELECTRICAL-REVIEW:59 |
| 4 | CH7 insert ID | Decode the bins (R-M 1310, L-M 3378, 4095 = no tail). Role cross-check (insole role + no tail = INVALID). Report the side so the app can refuse a mismatch | ROLE-DESIGN-NOTE "Hardware cross-check"; VERIFICATION-PLAN F6 |
| 5 | LSM6DSO32 driver (SPI, CS GPIO10, INT1 GPIO1) | Set `CTRL4_C.I2C_disable` first (see E17). WHO_AM_I check. ODR/full scale for gait (≥ ±16 g, ≥ 1000 dps). FIFO + INT1 data-ready/wake. Axis remap per `mount` (ankle_up / collar_inverted) | PINMAP §2; ROLE-DESIGN-NOTE "Firmware role flag" |
| 6 | MAX17048 driver (I2C 0x36, SDA GPIO0, SCL GPIO2) | Poll VCELL/SOC (ALRT is not connected). Settle/QuickStart after a cartridge swap: the gauge is powered from VBAT, so it resets with every cartridge. Hibernate when idle. Feed `batt` | PINMAP §2; ELECTRICAL-REVIEW:84-85 |
| 7 | Low-battery cut-off | Gauge-based cut-off set from bench item P1. Stop radio, then deep sleep before LDO dropout causes brownout reset loops. The TLV75533 EN is tied to VBAT, so only firmware can stop the drain | ELECTRICAL-REVIEW:84 |
| 8 | Power manager | Deep sleep with wake on BUTTON GPIO3 / IMU_INT1 GPIO1 (both in the C3's GPIO0-5 deep-sleep wake range). Radio duty cycle. Measure against RQ2 | ROLE-DESIGN-NOTE battery table |
| 9 | UI | LED_R GPIO20 / LED_G GPIO21, active high, amber = both. Debounced button on GPIO3 (pair, wake, role) | PINMAP §1 |
| 10 | Roles and radio | NVS `role` = ankle / insole. ESP-NOW pairing with encryption (LMK). BLE GATT per PROTOCOL.md (NimBLE to save flash) with LE Secure Connections bonding. Home Wi-Fi scan | ROLE-DESIGN-NOTE |
| 11 | Logging and time | Ring log on flash, boot id + `ms`, sync record, backlog sync | PROTOCOL.md (other repo) |
| 12 | OTA | Signed images (Secure Boot v2), rollback (`CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE`), BLE or Wi-Fi transport. The only other recovery is the TC2030 jig (GPIO9 is not on the button) | PINMAP §1 GPIO9 |
| 13 | Factory provisioning | Serial number, per-insole FSR calibration from F3 stored in NVS, EOL self-test through J3, eFuse burn (secure boot, flash + NVS encryption, USB-JTAG disable or soft-disable) | VERIFICATION-PLAN F3 |
| 14 | Robustness | Task + RTC watchdogs, brownout config, core dump to flash, boot self-test (CH6 sanity, IMU WHO_AM_I, gauge version), firmware version in every status packet | none yet |

### E2. Pressure normalisation is discontinuous: real loads read as near-zero
- **Evidence:** `niva flutter/lib/core/engine/biomechanics_engine.dart:66-73` and `niva web/src/utils/biomechanicsEngine.ts:83-90` both do: `if (v > 100) v = v/4095*100; else v = v` (clamped 0-100). The firmware sends ADC counts minus tare, range 0-4095 (`niva_hardware.ino:474-478, 487-494`). So 0-100 counts are taken as 0-100 %, and 101 counts becomes 2.5 %, which the 2.5 deadband then turns into 0.
- **Verified (harness, 200 frames per level after a clean tare):**
  ```
  heel ADC delta   50 -> filtered heel 50.0 , contact=stance
  heel ADC delta  100 -> filtered heel 100.0 , contact=stance
  heel ADC delta  101 -> filtered heel 0.0 , contact=swing
  heel ADC delta  500 -> filtered heel 12.2 , contact=swing
  heel ADC delta 2000 -> filtered heel 48.8 , contact=stance
  ```
  A light touch reads as full scale, and a moderate load (500 counts) reads as 12 % and "swing". Every downstream output (heatmap, COP, gait phase, contact, MLPI, ischemic integral, flags) inherits this. The existing test (`test/biomechanics_engine_test.dart`) does not cover it.
- **Fix:** one unit contract. The firmware sends counts with an explicit `scale` (or sends calibrated force/pressure once F3 exists). The engine always divides by the declared full scale. Never infer units from magnitude. Add a test for the 100/101 boundary.

### E3. Stale and fabricated data shown and stored as live
- **Evidence (Flutter):**
  - `esp32_socket_service.dart:44`: `latestPacket ?? this.latestPacket` is never cleared.
  - `telemetry_controller.dart:120-147`: every socket state change (connecting, error, onDone, each reconnect attempt) re-processes that last packet with a fresh `DateTime.now()`, feeds it to the engine, and writes it to the dataset as `source: ws, mode: live`. After a disconnect, a phantom "live" sample is written on every reconnect cycle (1.5-30 s) for as long as the app runs.
  - No data-age watchdog. `lastMessageAt` is only printed on the Device tab (`device_screen.dart:472`). No WebSocket ping is configured (`:103`), and the firmware has no heartbeat. If the pod dies (battery), the TCP socket can stay "open", and the dashboard keeps showing **LIVE TELEMETRY** (`dashboard_screen.dart:136-139`) with frozen values.
  - The metrics grid and anomaly card render whatever the last metrics were, with no liveness gate (`dashboard_screen.dart:71, 99-101, 306-336`).
- **Evidence (web):**
  - `MainDashboard.tsx:34` starts with stability score 92. `:77-86` seed the pressure bars (45/70/25/20), MLPI 45, ischemic integral 42 % and random sway/impact traces with spikes of 400-600.
  - `:473-476` re-apply the last `wsData` whenever `isConnected` or `isSimulating` changes. `useSensorData.ts:162-165` never clears `data` on close.
- **Verified:** code trace. The firmware also sends all-zero frames for 3 s during tare (`niva_hardware.ino:466-470`), with nothing to tell them apart from a lifted foot (see E12).
- **Fix:**
  - Process packets only in the message handler, never on state emissions. Clear `latestPacket` on disconnect.
  - Add a staleness rule: no frame for more than 2 × the expected interval means "NO DATA". Blank or grey every value and stop the integrators.
  - Add a WS ping (`IOWebSocketChannel.connect(..., pingInterval:)`) and a firmware heartbeat (`enableHeartbeat`).
  - Remove all seeded values from the web initial state.

### E4. Web UI shows invented clinical values, a fake patient record and fake device health
- **Evidence:**
  - `/insights` (primary nav): `ClinicalInsightsUpdated.tsx:11-31` random-walks "Peak Pressure" between 130 and 160 kPa and "symmetry" between 90 and 100 % with `Math.random`, whether or not a device is connected.
  - `ClinicalInsights3D.tsx:42, 99` (and the heatmap/anatomy variants): hardcoded "142 kPa", "Excessive medial roll detected ... Recommend corrective orthotic adjustment".
  - `/pdf`: `ClinicianPDF.tsx:30-34, 59, 209` shows patient "Johnathan R. Doe, #GG-88291, DOB 05/12/1978", "4.2% improvement", and "CONFIDENTIAL MEDICAL RECORD - GENERATED BY GAITGUARD NEXUS AI".
  - `MainDashboard.tsx:1010-1023`: "Local Cache (LittleFS) 8.4 KB / 2 MB" and "LiPo Reg 3.29V LDO" are constants, drawn in live colours whenever a device is connected. The firmware has no LittleFS and measures no voltage.
  - `:988`: a "Test Piezo Feedback" button injects a 600 impact spike into the live chart.
- **Verified:** read source. Live site: `https://shubham-sahu.me/niva/` returns 200 (curl), so these pages are public.
- **Fix:** delete or clearly watermark every mock page as "DEMO - not patient data" behind a demo flag, and never in the same view as live data. Device-health tiles must show only fields the firmware sends.

### E5. Clinical claims, alerts and controls with nothing behind them
- **Evidence:**
  - Web alert `MainDashboard.tsx:752-753`: "Time-Pressure Integral > 50mmHg capillary occlusion threshold at 1st Metatarsal. Offload immediately." It is triggered at `:275-277` by `ischemicIntegralPct > 50`. That value is a unitless counter: +0.35 per frame while `max(inner, outer) > 50` (in the broken units of E2) and pitch/roll < 6°, −0.08 otherwise (`biomechanics_engine.dart:335-342`, same in TS). It uses inner or outer, not the 1st metatarsal, and has no mmHg anywhere.
  - Harness: the flag fires after 151 frames, which is **15.1 s at 10 Hz, 7.5 s at 20 Hz, 3.0 s at 50 Hz**. The alert timing depends on the sample rate, not on time.
  - Harness: a foot pitch of 15° with roll 2° (normal walking) gives `band=unstable score=0 flags=[Heel-dominant gait trend, High sway instability]`. The "stability" and "ankle instability" rules (`:318-356`) treat ordinary gait kinematics as pathology.
  - Text claims: "Every flag above comes from an explicit, published threshold" (`insights_screen.dart:121-125`), "within its published threshold" (`ai_coach_service.dart:81-83`). The thresholds are not published or validated anywhere in the repo.
  - "AI COACH" (`ai_coach_card.dart:111`) is fixed templated text.
  - "PARKINSON GAIT DETECTED" in simulation mode (`dashboard_screen.dart:207`).
  - Disease labels Parkinson / Stroke / Neuropathy / Foot Drop / Ataxia are written into the research dataset (`telemetry_sample.dart:11`).
  - Dead controls: `DeviceSettings.tsx:140-147, 546-568` show "Ischemic Pressure Threshold ... (mmHg)" and "Static Exposure Window ... Alert when sustained" sliders. Their state is never read (grep finds no consumer) and never persisted. The engine uses hardcoded constants.
  - Project's own rule: VERIFICATION-PLAN F3: "No force or clinical value may be derived from the insole until this exists" (FSR characterisation). It has not been done. The Rev C.2 README says "Not a medical device; no clinical claim".
- **Fix:**
  - Remove mmHg/kPa, "ischemic", "ulcer", disease-detection and "offload immediately" wording until F3 calibration and a clinical validation study exist.
  - Make every threshold time-based (seconds, kPa·s) and sourced to a reference, with a written intended use.
  - Delete the sliders or wire them through to the engine with persistence and an audit trail.
  - Rename "AI" features.

### E6. Device link is open: health stream, remote re-tare, firmware upload
- **Evidence:**
  - `niva_hardware.ino:61, 424, 494`: WebSocket on port 81, no auth, cleartext. It broadcasts every frame to any LAN client, up to 5 (`WebSocketsServer.h:31`).
  - `:355`: any text containing "calibrate" from any client re-tares. A re-tare while loaded zeroes the reading and is saved to NVS (`:304`), so it survives reboots (E9).
  - `:403`: AP password `gaitguard123` is hardcoded, and the repo is **public** (`gh repo view`: `"visibility":"PUBLIC"`).
  - WiFiManager 2.0.17 registers its firmware-upload handler unconditionally (`WiFiManager.cpp:658`, `R_update`), and its default menu includes "update" (`WiFiManager.h:516`). Anyone in range during the 180 s boot portal (which opens whenever saved Wi-Fi is not reachable) can join with the public password and flash arbitrary firmware.
  - `:415-421`: mDNS advertises the device as `_ws._tcp`.
- **Verified:** read the sketch and the installed library sources. `gh` for visibility.
- **Fix:** for anything beyond the bench, drop Wi-Fi streaming in favour of BLE with LE Secure Connections bonding (production plan). If Wi-Fi stays as a lab mode:
  - per-device random AP password printed on a label;
  - `wm.setShowInfoUpdate(false)` and a menu without "update";
  - an authenticated, TLS or encrypted channel;
  - commands require an exact match plus a token;
  - ignore tare while load is present.

### E7. No medical-software lifecycle (IEC 62304 / ISO 14971 / SaMD)
- **Evidence:** the UI makes risk and diagnostic claims (E5). The repo has:
  - no software development plan, requirements (SRS), architecture or risk file;
  - no SOUP list (Arduino core 3.3.12, WiFiManager 2.0.17, WebSockets 2.7.2, U8g2, Riverpod, Hive, web_socket_channel, React 19, recharts, react-router 7, ws);
  - no traceability and no versioned firmware build or version field;
  - 5 unit tests total (`test/biomechanics_engine_test.dart`), none on firmware or web.
  - PR #7 body: "There's no CI on pull requests here."
- **Fix (brief):**
  - Write the intended use first. With ulcer/ischemia alerts it is SaMD: likely CDSCO class B/C under MDR 2017; FDA device software function with 524B cybersecurity (SBOM, threat model, signed updates) as a "cyber device".
  - Then: IEC 62304 software safety class (B at least, because a missed or false offload alert is a foot-injury hazard), ISO 14971 hazards (stale data, wrong scale, missed alarm, wrong side, low battery), IEC 62366-1 usability, IEC 81001-5-1 security, SOUP register, CI with tests, and release records tied to firmware version.
  - If the team does not want that path now, remove every clinical claim (E5) and label the product "research prototype, not for diagnosis or treatment".

---

## MAJOR

### E8. Cadence and steps are half the true value; real steps often not counted
- **Evidence:** one insole sees one heel strike per stride (two steps), but `biomechanics_engine.dart:288-297` counts each as a step and computes `cadence = 60 / strideInterval`. The heel-strike gate requires filtered heel > 80 on the 0-100 scale, i.e. > 3276 ADC counts (E2), plus `impact > 200` and `!_lastContact`. The simulator's normal-gait impact is 80 (`simulation_engine.dart:99`), so simulated walking never registers a step.
- **Verified (harness):**
  ```
  peak ADC 4095, stride 1000 ms (true 120 steps/min): cadence=60 spm, steps=20 for 20 strides
  peak ADC 4095, stride 1100 ms (true 109 steps/min): cadence=55 spm, steps=20 for 20 strides
  peak 3000 counts, 1.0 s stride: cadence=0 spm, steps=0 after 20 strides
  simulation normal 20 s: steps=0 cadence=0.0
  ```
- **Fix:** report strides, or steps = 2 × strides labelled as an estimate (PROTOCOL.md already says this). Detect contacts on per-channel relative thresholds after calibration. Add tests with recorded traces.

### E9. Tare accepts a loaded foot, silently, in both firmware and app
- **Evidence:**
  - Firmware: boot tare averages the first 60 frames with no load or variance check, then persists to NVS forever (`niva_hardware.ino:285-337, 463-471`). If the insole is worn at power-on, standing pressure becomes the zero.
  - App: the "no-load" test allows a mean total up to 55 (of 400) (`biomechanics_engine.dart:44-47, 221-235`). If no clean window appears, it sets `isCalibrated = true` with no baseline (`:236-241`), and the UI cannot tell the two apart.
  - Tapping "LIVE SENSOR" while already live calls `connectLive()` again (`segmented_toggle.dart:45-47` → `dashboard_screen.dart:50-53`). That resets and re-tares the engine (`telemetry_controller.dart:60`) and opens a second socket without cancelling the first (`esp32_socket_service.dart:95-122` overwrites `_subscription`), so every packet is then processed twice.
- **Verified (harness):** 60 frames of heel 1200 + inner 900 counts gives `isCalibrated=true filtered heel=0.0`: a loaded foot was tared to zero.
- **Fix:**
  - Firmware: tare only on explicit command with a stillness and low-load check against factory values; reject and report otherwise. Store tare with a timestamp and expose it.
  - App: one tare authority (firmware). Show calibration state. Make `connect()` idempotent (close the old channel and subscription first). Ignore taps on the active toggle.

### E10. IMU orientation is wrong under motion, and ranges saturate in gait
- **Evidence:**
  - `niva_hardware.ino:227-269`: `updateKinematics()` runs every `loop()` pass, often several times per millisecond. When `dt` computes to 0 it is replaced with 0.01 s (`:261-262`), so the gyro is integrated about 10× too much on fast loops.
  - The MPU6050 is only woken (`:215-218`). It stays at power-on defaults, ±2 g and ±250 °/s (scales at `:248-253`), which saturate at heel strike and in swing.
  - `accZ` is 0 when the IMU is absent (`:231`) and the app substitutes 9.8 when the field is missing (`telemetry_controller.dart:141`).
  - PINMAP.md:71 says the prototype MPU6050 "is set to ±16 g (firmware README)". Neither the README nor this sketch does that, so the docs and the code disagree.
- **Verified:** code read.
- **Fix:** run fusion at a fixed rate from a timer or FIFO with `micros()` dt. Configure full scale (on the LSM6DSO32: ±16/32 g, ≥ 1000 dps). Send raw accel/gyro plus a validity bit.

### E11. Sampling rate and timing cannot capture gait events or support a time base
- **Evidence:**
  - 20 Hz frames (`niva_hardware.ino:42`), 10 Hz in the simple sketch (`:16`). Each frame is one 16-sample burst (about 1 ms window), so the heel-strike piezo transient is mostly missed.
  - ELECTRICAL-REVIEW:53 assumes 200 Hz with oversampling and decimation. PINMAP.md:70 says the piezo used "peak-hold at 500 Hz", which this sketch does not do.
  - The loop can block for long periods:
    - SH1106 full-frame I2C writes (about 1 KB at 400 kHz, roughly 25 ms) inside the stream path (`:500-503`);
    - `broadcastTXT` loops per client for up to `WEBSOCKETS_TCP_TIMEOUT` = 5000 ms when a client's TCP window is full (`WebSockets.h:125`, `WebSockets.cpp:691`), with no heartbeat to evict half-open clients;
    - `Serial.readStringUntil` waits 1 s when there is no newline (`:435-438`).
  - Packets carry no device timestamp or sequence number. The apps stamp receive time (`telemetry_controller.dart:142`, `MainDashboard.tsx:298`), so gaps and Wi-Fi bunching corrupt cadence and stance/swing timing.
  - Engine constants are per frame (EMA α 0.1, 5-frame heel streak, 30-frame tare, 151-frame ischemic), so behaviour changes with the rate.
- **Fix:** timer- or ISR-driven acquisition at the documented rate, a decoupled send task, and `seq` + `t_ms` in every packet. Express every algorithm constant in seconds.

### E12. The data contract is missing what safety logic needs, and two contracts exist
- **Evidence:**
  - Firmware JSON is 8 floats `{heel, inner, outer, toe, piezo, pitch, roll, accZ}` (`niva_hardware.ino:491`).
  - Nothing carries calibration state (tare frames are all zeros, `:467`), battery, firmware version, device id, side, sequence or timestamp, or sensor faults.
  - The C.2 pod has 5 FSR regions (P4 lateral midfoot is new), PVDF, CH6 tail-fault and CH7 insert ID (PINMAP §2 table). The 4-channel schema cannot carry them, and inner/outer map to C.2 channels "by name only" (PINMAP §3).
  - Both apps accept any JSON object: the relay's `{"relay":"connected"}` hello (`relay/server.js:35`) becomes an all-zero live sample in Flutter (`telemetry_controller.dart:130-147`).
  - The production contract (`protected-steps/PROTOCOL.md` v1, other repo: BLE stride records, `batt`, validity VALID/DEGRADED/INVALID) is unrelated to this one.
  - VERIFICATION-PLAN F6 requires "The app refuses a mismatched side". Neither app has a side concept.
- **Fix:**
  - Define one versioned schema with `proto`, `fw`, `seq`, `t_ms`, `cal`, `validity` (+ reason: tail_fault, no_tail, imu_fault, low_batt), `batt`, `side`/`insert_id`, and `channels[]` with declared units/scale.
  - Validate it in both apps and drop unknown or malformed packets.
  - Show validity in the UI.

### E13. The app has no transport or permissions for the production architecture
- **Evidence:**
  - The Flutter app is WebSocket-only (`esp32_socket_service.dart:49-58`; pubspec has no BLE package).
  - `AndroidManifest.xml:2` declares only INTERNET: no `BLUETOOTH_SCAN` (neverForLocation) or `BLUETOOTH_CONNECT` (Android 12+), no location for Android 11 and below, no foreground service for all-day logging.
  - iOS has no `NSBluetoothAlwaysUsageDescription` and no `bluetooth-central` background mode (`Info.plist:29-35` has only the local-network keys).
  - The hub "serves BLE" and logs offline (ROLE-DESIGN-NOTE).
- **Fix:**
  - Implement the PROTOCOL.md BLE client: bonding, MTU 247, backlog sync, time sync.
  - Add the Android 12+ and iOS permissions with purpose strings.
  - Add a foreground service and background BLE handling.
  - Or decide formally that the app in the `niva` repo is the production app and freeze this one as a lab tool.

### E14. Health data is unprotected at rest and in transit
- **Evidence:**
  - Hive box unencrypted (`telemetry_repository.dart:22`, `Hive.openBox` without `encryptionCipher`).
  - Upload bearer token in plain SharedPreferences (`settings_repository.dart:37-38`).
  - Android `allowBackup` not disabled, so the dataset and token go into cloud backup.
  - `usesCleartextTraffic="true"` app-wide (`AndroidManifest.xml:7`), and any `http://` upload URL is accepted (`research_upload_service.dart:36`).
  - CSV export left in the temp dir (`telemetry_repository.dart:75-80`).
  - Web: IndexedDB `gaitguard-nexus-datasets` and localStorage on origin `https://shubham-sahu.me`, **shared with every other page on that domain** (curl: `/` and `/niva/` both 200). Any other project page there can read the dataset.
  - No CSP or HSTS (response headers show only `server: cloudflare`).
  - `VITE_DATASET_UPLOAD_TOKEN` (`researchUpload.ts:23`) would be compiled into the public bundle if set. The workflow does not set it today.
  - Device link cleartext (E6). No consent or privacy notice. India DPDP Act 2023 applies to health data.
- **Fix:**
  - Encrypt Hive with a key in `flutter_secure_storage`, and keep the token there too.
  - Set `allowBackup="false"` or data-extraction rules.
  - Use a network security config that allows cleartext only to the device, and require https uploads.
  - Delete exports after sharing.
  - Host the dashboard on its own origin with CSP and HSTS. Keep upload tokens server-side, never in the bundle.
  - Add a consent screen and retention policy.

### E15. Unbounded storage and synchronous export make the app crash-prone in daily wear
- **Evidence:**
  - Every frame is stored forever: 20 Hz = 72,000 rows/hour, about 1.7 M/day. Hive's normal `Box` keeps all entries in memory and is opened at startup (`main.dart:20`, `telemetry_repository.dart:22`).
  - `exportCsv()` builds the whole dataset as one string on the UI isolate (`:63-71`) for Export and for Upload (`device_screen.dart:326`).
  - The upload sends it in one request with no timeout (`research_upload_service.dart:54`).
  - Export has no try/catch (`device_screen.dart:270-273`). `setState` runs after `await` without a `mounted` check (`:333-336`).
  - Web IndexedDB likewise has no pruning (`telemetryDatasetStore.ts`: only `clear`).
- **Fix:** LazyBox or SQLite with retention and rotation, store decimated or summary data rather than raw frames, streamed export in an isolate, chunked upload with timeout and retry, and error handling with `mounted` checks.

### E16. The relay is an unauthenticated open proxy that a single bad frame can crash
- **Evidence:**
  - `niva web/relay/server.js:16-31` connects to any `ws(s)://` URL from the `target` query param, so anyone can use it to reach internal hosts (SSRF / port probing).
  - No auth, no `Origin` check (cross-site WebSocket hijacking), no TLS of its own, no rate or size limit.
  - Client messages are forwarded upstream (`:57-61`), so remote `calibrate` (E6) works through it.
  - There is no `client.on('error')`. ws emits `'error'` on an invalid frame, and an unhandled `'error'` event kills the Node process.
  - Locked `ws` 8.19.0 (`relay/package-lock.json:15`) has 2 open alerts (memory-exhaustion DoS, high; uninitialised memory disclosure, medium). PR #7 moves it to 8.22.1.
- **Fix:**
  - Allow-list targets (one device id mapped to a LAN address).
  - Require a token and check `Origin`.
  - Set `maxPayload`.
  - Add `client.on('error')`.
  - Terminate TLS in front.
  - Merge PR #7.
  - Better: drop the relay once BLE replaces Wi-Fi streaming.

### E17. ESP32-C3 pin-map traps the new firmware must handle
- **Evidence and fix**, one line each (PINMAP §1-3, ELECTRICAL-REVIEW §3):
  - **Shared SPI with the LSM6DSO32:** it starts in I2C mode while its CS is high, and its SCL/SDA are the SPI SCK/MOSI nets also clocking the MCP3208. Set `CTRL4_C.I2C_disable` (bit 2) immediately after the first SPI access. Use SPI mode 0 for both chips (MCP3208 supports 0,0 / 1,1; the IMU supports 0 and 3). Avoid mode 3 idle-high SCK edges until I2C is disabled. Switch SCLK per CS (≤ 1 MHz for the MCP3208 at 2.7 V).
  - **UART0 TX/RX = LED_G/LED_R (GPIO21/20):** build with USB-CDC-on-boot and never `Serial.begin()` on UART0, or the LEDs become a UART. The ROM boot log flickers LED_G (accepted in ELECTRICAL-REVIEW:44). It can be silenced through the eFuse print control if needed.
  - **No USB socket in service:** USB-CDC writes with no host attached must not block the acquisition loop. Set the HWCDC TX timeout to 0, or compile logging out of release builds.
  - **GPIO2 (I2C SCL) is a strap:** use the I2C peripheral only, never drive it low as GPIO across a reset.
  - **GPIO18/19:** leave them as USB Serial/JTAG. Reassigning them removes the only wired console.
  - **GPIO9 is jig-only:** a field unit cannot be recovered without the TC2030 jig, so OTA must have rollback (E1 #12).
  - **Flash:** the N4 module has 4 MB. PINMAP notes BLE + Wi-Fi needed "Huge APP" on the classic ESP32, a layout with no OTA slot. Use NimBLE, keep each image under about 1.9 MB, and check the size in CI.
  - **Sleep budget:** the CH6 divider R31/R32 draws 165 µA continuously (ROLE-DESIGN-NOTE). Firmware cannot switch it off. Include it in the cut-off and sleep budget, or ask electronics for a switched divider.

### E18. Fault, disconnect and low-battery states have no representation in either app
- **Evidence:**
  - Neither app has any notion of sensor fault, tail missing or shorted, insert mismatch, IMU fault, low or critical battery, or device time.
  - The only connection states are connected/connecting/error (`telemetry_state.dart:8-21`, `useSensorData.ts:16-31`).
  - The web "LiPo Reg 3.29V" tile is fake (E4).
  - PROTOCOL.md's own rule (insole battery < 10 % means class X, unknown) cannot be expressed in this app.
- **Fix:** a single device-status model driven by the E12 fields. Show an explicit "Not monitoring: <reason>" state that suppresses metrics and alerts, plus a low-battery warning with an estimated time left.

---

## MINOR

### E19. The Wi-Fi "offline AP fallback" does not exist, and the app's default URL is unreachable
- **Evidence:**
  - After the 180 s portal timeout, WiFiManager 2.0.17 turns the soft AP off (`WiFiManager.cpp:991` `softAPdisconnect`, then restores STA mode). The sketch never calls `WiFi.softAP`, yet the OLED says "Offline AP mode" (`niva_hardware.ino:146-147, 405-406`).
  - The WS server only starts after `autoConnect` returns (`:424`), so the Flutter default `ws://192.168.4.1:81` (`settings_repository.dart:20`) never works.
  - There is no portal retry without a reboot.
  - The simple sketch calls `WiFi.disconnect(true)` + `begin` every 3 s while disconnected (`esp32_gaitguard_wifi_manager.ino:87-97`), which can cut off attempts that take longer than 3 s.
- **Fix:** keep a real AP plus WS fallback, or default to `ws://niva.local:81`. Add backoff of at least 10 s and do not disconnect mid-attempt.

### E20. Firmware robustness gaps (prototype sketches)
- **Evidence:**
  - No task watchdog on `loop`.
  - `Serial.readStringUntil` 1 s block (`:435-438`).
  - `MDNS.begin` is called twice (`:415-421`). Core 3.3.12 `ESPmDNS.cpp:83-95` calls `mdns_hostname_set` again, so most likely only `gaitguard.local` resolves and `niva.local` (the README default) does not; the ws service is also added twice. Not verified on a device.
  - The 5-client cap lets any LAN host occupy every slot.
  - `String` allocation per command.
- **Fix:** enable the WDT, use non-blocking serial line assembly, one mDNS hostname, and evict idle clients through the heartbeat.

### E21. A crafted link can repoint the web dashboard
- **Evidence:** `useSensorData.ts:124-128, 147-151`: the `?esp32ws=` and `?esp32relay=` query params are written to localStorage with no prompt. A link can permanently send the user's dashboard to an attacker relay that feeds fake data or collects the device address.
- **Fix:** ask for confirmation before saving query-supplied endpoints, or drop the feature.

### E22. Dependency vulnerabilities (PR #7)
- **Evidence:** `gh api .../dependabot/alerts`: 47 open (PR #7 body: 23 high, 21 moderate, 3 low).
  - Locked: vite 8.0.0, react-router(-dom) 7.13.1, styled-components 6.3.11, postcss 8.5.8, relay ws 8.19.0.
  - Most web alerts are dev-server, SSR/RSC or build-tool issues (vite fs.deny, launch-editor, react-router RSC/single-fetch, nanoid, brace-expansion) that do not ship in the static Pages bundle. The client-side react-router open-redirect items are low impact in this SPA.
  - The runtime-relevant ones are the two `ws` alerts in the relay (E16).
  - PR #7 is lockfile-only within current majors, plus a scoped `minimatch` override. Its author reports a clean build, lint parity and route smoke tests.
- **Fix:** merge PR #7, then add Dependabot auto-PRs plus a CI build so future bumps are checked.

### E23. Hardcoded credentials and personal addresses in a public repo
- **Evidence:**
  - `niva web/README.md:229-230` `ssid = "ShubhamHotspot"`, `password = "12345678"`.
  - `niva_hardware.ino:403` `gaitguard123`.
  - `useSensorData.ts:33` default `ws://10.249.106.94:81` (a developer LAN IP).
  - No API keys or tokens found in tracked files or history (`git grep` for key/secret/token/password assignments; `git log --all --name-only` for `.env`, keys and keystores: none).
- **Fix:** rotate the hotspot password if it is real, use placeholders in docs, and default to `niva.local`.

### E24. Third-party content on clinical pages
- **Evidence:** "patient avatar" and logos load from `lh3.googleusercontent.com` (`ClinicianPDF.tsx:30`, `ClinicalInsightsUpdated.tsx:41`, `TrendAnalytics.tsx:15`). Sketchfab iframes (`ClinicalInsights3D.tsx:61`, `ClinicalInsightsUpdated.tsx:105`) send every visit to third parties.
- **Fix:** bundle the assets locally and set a CSP before any real patient data is shown.

### E25. Error-handling gaps in Flutter
- **Evidence:**
  - Export has no try/catch (`device_screen.dart:270-273`).
  - Upload `setState` after `await` without `mounted` (`:333-336`); no HTTP timeout (`research_upload_service.dart:54`).
  - `TelemetrySample.fromMap` casts `timestampMs as int` and throws on a corrupted row (`telemetry_sample.dart:113`).
  - The malformed-JSON branch hides errors once connected (`esp32_socket_service.dart:133-143`), so a firmware that sends garbage after connect is invisible.
- **Fix:** guard the async UI handlers, add timeouts, parse defensively, and count rejected frames in the UI.

### E26. Web frames pass through React state and can be merged or replayed
- **Evidence:** `useSensorData.ts:298-300` stores the latest frame in state. `MainDashboard.tsx:473-476` processes it in an effect, so frames that arrive before a render are dropped, and dependency changes replay the last one (E3).
- **Fix:** run the engine inside `onmessage` and the serial loop, and push only derived values to state.

### E27. CSV formula injection in exports
- **Evidence:** `_escapeCsv` in `telemetry_sample.dart:133-139` quotes commas and quotes only. User-entered `sessionId`/`trialId` starting with `= + - @` will execute in Excel or Sheets.
- **Fix:** prefix those cells with `'`, or reject the leading characters.

### E28. Accessibility and language
- **Evidence:**
  - Zero `Semantics`/`semanticLabel`/`Tooltip` uses in `niva flutter/lib` (grep).
  - The foot heatmap and rings are custom-painted with no screen-reader text. Status relies on colour (red/amber/green).
  - The web uses 9-11 px labels and icon-only buttons (material-symbols spans).
  - No l10n in either app (English only) for an Indian elderly diabetic user base, where retinopathy and low literacy are common.
- **Fix:** add semantics for every metric and alert, check text scaling at 200 %, and add a non-colour status cue. Add `flutter_localizations` + ARB with Hindi and Marathi first.

### E29. Test and release hygiene
- **Evidence:**
  - Only 5 engine unit tests (`test/biomechanics_engine_test.dart:38-108`), none for E2, E8 or E9.
  - No firmware, web or relay tests, and no PR CI.
  - Android release is signed with debug keys (`android/app/build.gradle.kts:29-32`).
  - The product name differs everywhere: "niva" (Android label), "Niva" (iOS), "GaitGuard Nexus" (UI).
- **Fix:** add a CI workflow (Flutter analyze/test, web build/lint, Arduino or IDF compile for C3). Use a release keystore outside the repo. Pick one product name.

---

## NOTE

### E30. Review limits
- Analyzers were not run (packages unresolved). The firmware was not compiled. The out-of-repo Protected Steps firmware and app were only listed, not reviewed.
- Harness results come from copies of the Dart engine. The TS engine has the same constants and normalisation (`biomechanicsEngine.ts:83-90, 128-129`) and was compared by reading, not run.

### E31. Two products share one name
This repo's apps (GaitGuard Nexus gait dashboard, disease simulation, Wi-Fi streaming) and the production hardware plan (Protected Steps: was the prescribed shoe worn, stride classes P/U/X) answer different questions. Decide which app ships with the C.2 pod before investing in fixing E8-E15 here.

---

## Checked and found correct

| Area | What was checked | Result |
|---|---|---|
| C3 pin map | Deep-sleep wake sources: BUTTON GPIO3 and IMU_INT1 GPIO1 are inside the C3's GPIO0-5 deep-sleep-wake range | Correct |
| C3 pin map | Straps: GPIO2 (R4 4.7 kΩ), GPIO8 (R2 10 kΩ), GPIO9 (R3 10 kΩ, jig pulls low) all pulled high. GPIO18/19 kept for USB. GPIO0/1 free because no 32 kHz crystal | Correct (firmware rules in E17) |
| C3 pin map | All analog goes through the MCP3208, so there is no ADC2-vs-Wi-Fi conflict (GPIO5 is SPI_MISO only) | Correct |
| C3 pin map | MAX17048 7-bit address 0x36 | Correct |
| Arithmetic | CH6 normal window 4096×1.65/3.3 = 2048 to 4096×1.65/2.94 = 2299. CH7 codes 4096×4.7/14.7 = 1310, 4096×47/57 = 3377 | Matches PINMAP/ELECTRICAL-REVIEW |
| Firmware | `millis()` deltas are unsigned and wrap-safe (`niva_hardware.ino:441, 261`) | Correct |
| Firmware | Oversample sum: 16 × 4095 fits `uint32_t`; JSON worst case about 110 chars < 256 buffer | No overflow |
| Firmware | Classic-ESP32 prototype uses ADC1 pins only (32-36), so Wi-Fi does not block the ADC | Correct for the prototype |
| Firmware | NVS save/load uses a namespace and a `calibrated` flag, read-only open on load | Mechanically correct (policy issue in E9) |
| Firmware | WebSocket TEXT payload is NUL-terminated by the library before `String((char*)payload)` | Safe |
| Flutter | `channel.ready` rejection is caught, so no unhandled async error (`esp32_socket_service.dart:111-120`) | Correct |
| Flutter | Reconnect backoff 1.5 s to 30 s cap with ±15 % jitter (`:175-186`) | Correct |
| Flutter | Simulation timer cancelled when going live (`telemetry_controller.dart:57-59`); dataset flush re-queues on failure (`:185-199`) | Correct |
| Flutter | iOS `NSLocalNetworkUsageDescription` + `NSAllowsLocalNetworking` present (`Info.plist:29-35`) | Correct for Wi-Fi mode |
| Web | Mixed-content detection: uses the relay or shows a clear hint on HTTPS (`useSensorData.ts:110-113, 174-201`) | Correct |
| Web | Serial CSV parser drops `CALIBRATING`, header and NaN lines (`esp32Telemetry.ts:22-35`) | Correct for `niva_hardware` |
| Deploy | Pages workflow injects only WS/relay URLs, not the upload token (`.github/workflows/deploy-pages.yml:24-26`). http→https 301 is live (curl) | Correct |
| Secrets | No `.env`, keystore or key files tracked now or in history | Clean (credential strings in E23) |
| PR #7 | Lockfile-only, within current majors; clears 47/47 per its body | Safe to merge |
