# Niva Arduino / ESP32 firmware

Embedded firmware for the Niva sensorised insole. The firmware acquires FSR, piezo, and IMU observations and streams them to the Flutter app and web dashboard. It is an instrument transport, not a diagnostic or classifier.

## Technology stack

- ESP32 + Arduino core
- WebSockets (Markus Sattler)
- WiFiManager (tzapu) in the active sketch
- U8g2 (olikraus) for the SH1106 OLED in the active sketch
- MPU6050 over raw I2C (address `0x68`) in the active sketch
- ESP32 Arduino core BLE library for direct phone-to-insole transport

There is no PlatformIO `platformio.ini` in this repository. Flash with Arduino IDE (or another Arduino-compatible ESP32 toolchain).

## Sketches

### Active: `niva_hardware/niva_hardware.ino`

This is the complete hardware sketch currently used on the insole:

- WiFiManager captive portal (`NIVA-GaitGuard-AP`)
- MPU6050 pitch / roll / accZ
- SH1106 128x64 OLED status display on the shared I2C bus
- `100 Hz` FSR + IMU acquisition and `500 Hz` piezo peak-hold sampling
- Explicit unloaded tare; no baseline is reused across a reboot
- MPU6050 configured to its ±16 g range, with clipping reported per frame
- mDNS name `niva.local`
- Wi-Fi WebSocket JSON on port `81`, USB JSON on Serial, and BLE GATT notifications
- A `validity` value on every frame. Only `"valid"` frames may be recorded or used for derived metrics.

`niva.ino` is intentionally a comment-only compatibility file: Arduino compiles every `.ino` in one directory, so the implementation is kept in exactly one entry-point file.

Required libraries:

- WiFiManager by tzapu
- WebSockets by Markus Sattler
- U8g2 by olikraus

### Simpler variant: `esp32_gaitguard_wifi_manager/esp32_gaitguard_wifi_manager.ino`

Earlier GitHub sketch kept because it is still a valid, smaller firmware:

- Hardcoded SSID / password (`YOUR_HOTSPOT_NAME` / `YOUR_HOTSPOT_PASSWORD`)
- Zero-load calibration (40 samples, not stored in NVS)
- WebSocket JSON + USB CSV
- `pitch` / `roll` / `accZ` are sent as `0.0` (no IMU)

Required libraries:

- WebSockets by Markus Sattler

## Pin map (both sketches)

| Signal | GPIO |
|---|---|
| FSR heel | 32 |
| FSR inner | 33 |
| FSR outer | 34 |
| FSR toe | 35 |
| Piezo | 36 |
| I2C SDA (MPU6050 + OLED) | 21 |
| I2C SCL | 22 |
| Status LED | 2 |

## Telemetry

JSON over WebSocket (`ws://<esp32-ip>:81`):

```json
{"deviceTimestampMs":12345,"heel":42.00,"inner":68.00,"outer":31.00,"toe":27.00,"piezo":176.00,"impact":176.00,"pitch":-2.40,"roll":1.30,"accZ":9.72,"validity":"valid","sampleHz":100,"imuClipped":false,"contact":9,"events":["h+@12290","F+h@12290","t+@12330"],"eventsDropped":0}
```

USB Serial JSON at `115200` baud uses the same packet.

`deviceTimestampMs` is milliseconds since boot from the 64-bit `esp_timer`. It does not wrap. Earlier builds used `micros()`, which wraps after about 71.6 minutes.

### Contact events

Contact edges are detected on the ESP32 at the `100 Hz` acquisition rate (`NivaContactDetector`, `niva_signal.h` section 9). Clients should time edges from these events, not from the `20 Hz` frames.

- `contact`: the sensors in contact now, as a bit mask (1 heel, 2 inner, 4 outer, 8 toe).
- `events`: edges since the previous frame. Each one is `<code>@<deviceMs>`, stamped at the first sample that crossed the threshold:
  - `h+` `h-` `i+` `i-` `o+` `o-` `t+` `t-`: one sensor (heel, inner, outer, toe) loads or unloads.
  - `F+x`: the foot loads. `x` is the sensor that loaded first, or `*` when two sensors crossed on the same `10 ms` sample, which cannot be ordered.
  - `F-`: the last loaded sensor unloads.
- `eventsDropped`: events lost to a full queue since the last tare. Anything above zero means some steps are incomplete.

At most 16 events go in one frame; any extra wait for the next frame. Older clients ignore the three new fields.

The detector's thresholds, debounce and noise floor are starting values, not validated ones. Checks F1–F4 of the SIH26213 plan compare its edges against a trained tester and slow-motion video, and the constants should be revised from those results. After each tare, the serial log prints the noise floor of every channel.

BLE advertises as **Niva Insole**, with service UUID
`c4f00001-dc50-4c44-a4d8-f0164e510001`. The app subscribes to TX
`c4f00003-dc50-4c44-a4d8-f0164e510001` and sends commands to RX
`c4f00002-dc50-4c44-a4d8-f0164e510001`. BLE packets carry an internal two-byte
fragment header because JSON frames are larger than the default BLE payload;
the Flutter service reassembles them before decoding.

Start a tare only while the insole is unloaded:

```text
{"cmd":"tare"}
```

The firmware provides sensor observations and their acquisition validity. Any downstream analysis must treat the sparse FSR values as relative load indices, not force or pressure measurements.

## Setup / flash

1. Install Arduino IDE and ESP32 board support.
2. Install the libraries listed for the sketch you are flashing.
3. For the simpler sketch, edit `WIFI_SSID` and `WIFI_PASS` before upload.
4. Select your ESP32 board and port.
5. For `niva_hardware`, set **Tools → Partition Scheme → Huge APP (3MB No OTA/1MB SPIFFS)**. BLE plus Wi-Fi does not fit the default 1.2 MB app partition: the build stops with "text section exceeds available space in board". From the command line, use the FQBN `esp32:esp32:esp32:PartitionScheme=huge_app`.
6. Open the `.ino` and upload.
7. In the Flutter Device tab, either choose **Find Niva Insole** for BLE or use `ws://<ESP32_IP>:81` for Wi-Fi.
8. Connect, leave the insole unloaded, then select **Tare unloaded insole**. Wait until the validity state reads `valid` before a recording.

## Off-target tests

`tests/contact_detector_test.cpp` checks the contact detector on a PC, with no ESP32 attached. It uses a minimal `Arduino.h` stand-in from `tests/stub/`. Run it from the repository root:

```bash
g++ -std=gnu++17 -Wall -Wextra -Werror -I"startup/niva arduino/tests/stub" -I"startup/niva arduino/niva_hardware" "startup/niva arduino/tests/contact_detector_test.cpp" -o contact_detector_test && ./contact_detector_test
```

Runtime tare accepts `tare`, `calibrate`, or `{"cmd":"tare"}` over WebSocket, BLE, or Serial.

## Connection to other Niva components

- `niva flutter` connects over WebSocket or BLE using the same reassembled JSON packet and suppresses non-valid frames from its dataset.
- `niva web` connects over WebSocket or USB Web Serial using the same JSON/CSV packet.
- `niva web/relay` can bridge `wss://` (HTTPS GitHub Pages) to the ESP32 `ws://` endpoint.

## Implementation notes

- IMU in firmware is **MPU6050**, not BMI270.
- Production ideas such as ESP32-C3, FPC insole, or screen-printed layers are not implemented in these sketches.
- BLE framing is part of the active firmware/app contract.
