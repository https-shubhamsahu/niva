# Niva Arduino / ESP32 firmware

Embedded firmware for the Niva smart insole. This directory contains the ESP32 sketches that acquire FSR, piezo, and IMU data and stream telemetry to the Flutter app and web dashboard.

## Technology stack

- ESP32 + Arduino core
- WebSockets (Markus Sattler)
- WiFiManager (tzapu) in the active sketch
- U8g2 (olikraus) for the SH1106 OLED in the active sketch
- MPU6050 over raw I2C (address `0x68`) in the active sketch

There is no PlatformIO `platformio.ini` in this repository. Flash with Arduino IDE (or another Arduino-compatible ESP32 toolchain).

## Sketches

### Active: `niva_hardware/niva_hardware.ino`

This is the complete hardware sketch currently used on the insole:

- WiFiManager captive portal (`NIVA-GaitGuard-AP`)
- MPU6050 pitch / roll / accZ
- SH1106 128x64 OLED status display on the shared I2C bus
- 16x ADC oversampling
- Zero-load tare calibration with NVS persistence
- mDNS names `niva.local` / `gaitguard.local`
- WebSocket JSON on port 81 and USB CSV on Serial

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
{"heel":42.00,"inner":68.00,"outer":31.00,"toe":27.00,"piezo":176.00,"pitch":-2.40,"roll":1.30,"accZ":9.72}
```

USB Serial CSV at 115200 baud:

```text
H,I,O,T,Piezo,Pitch,Roll,AccZ
```

Gait-phase classification and EMA smoothing are applied in `niva web` and `niva flutter`, not in these sketches.

## Setup / flash

1. Install Arduino IDE and ESP32 board support.
2. Install the libraries listed for the sketch you are flashing.
3. For the simpler sketch, edit `WIFI_SSID` and `WIFI_PASS` before upload.
4. Select your ESP32 board and port.
5. Open the `.ino` and upload.
6. Open Serial Monitor at **115200** baud and note the printed IP address.
7. Point the Flutter Device tab or the web Settings page at `ws://<ESP32_IP>:81`.

Runtime tare on the active sketch: send `calibrate` or `tare` over WebSocket or Serial.

## Connection to other Niva components

- `niva flutter` connects over WebSocket using the same JSON packet.
- `niva web` connects over WebSocket or USB Web Serial using the same JSON/CSV packet.
- `niva web/relay` can bridge `wss://` (HTTPS GitHub Pages) to the ESP32 `ws://` endpoint.

## Implementation notes

- IMU in firmware is **MPU6050**, not BMI270.
- Production ideas such as ESP32-C3, FPC insole, or screen-printed layers are not implemented in these sketches.
- BLE is not implemented in firmware.
