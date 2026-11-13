# Niva: Protected Steps firmware

One firmware, two roles (`ankle` hub, `insole` node) and two boards. The device contract is PROTOCOL v1 (`protected-steps/PROTOCOL.md` in the `niva` startup tree): ESP-NOW between insole and hub, BLE GATT to the app, a LittleFS stride log, and the P / U / X stride classes.

**Origin:** this folder was copied on 9 November 2026 from the untracked `startup/niva arduino/niva_protected_steps/` of the main `niva` checkout (written 3 November). It was then ported to the Rev C.2 pod. Keep one copy: delete or merge the old one.

**Status:**
- It compiles for both boards and its host tests pass.
- **It has not run on a pod**, because no Rev C.2 board has been built yet.
- Nothing here is a clinical measurement.

## Boards

`niva_board.h` picks the hardware from the build target. Everything above it is shared: stride detector, matcher, contact detector, log, ESP-NOW and BLE.

| | DevKit prototypes | Niva pod Rev C.2 |
|---|---|---|
| Target | `esp32:esp32:esp32:PartitionScheme=huge_app` | `esp32:esp32:esp32c3:PartitionScheme=huge_app,CDCOnBoot=cdc` |
| Insole channels | internal ADC, GPIO32-36 | MCP3208 on SPI (CS GPIO7): heel CH4, inner CH1, outer CH2, toe CH0, piezo CH5 |
| IMU | MPU6050, I2C 21/22 | LSM6DSO32, same SPI bus (CS GPIO10), ODR 104 Hz |
| Battery | MAX17048 if fitted | MAX17048, I2C GPIO0/GPIO2 at 100 kHz, VRESET lowered to 2.68 V |
| LEDs | GPIO2 | green GPIO21 (status), red GPIO20 (IMU not VALID on the hub) |
| Button | GPIO0 (BOOT) | GPIO3 |
| Serial | UART | USB-CDC through the service pads; logs never block |
| Tail check | none | CH6 (tail short) and CH7 (insert ID); a bad tail makes the insole INVALID |

### Pod-specific handling
- **IMU starts in I2C mode.** The LSM6DSO32 powers up with I2C enabled on the shared SPI wires. `nivaBoardBegin()` sends I2C_disable to it before any ADC traffic (review A17).
- **Chip selects in sleep.** Both chip selects are held high through deep sleep (review A2).
- **Single core.** Tasks run on core 0, because the ESP32-C3 has one core. On the classic ESP32 they stay pinned to core 1.
- **Serial must be USB-CDC.** UART0's pins drive the LEDs, so a pod build without `CDCOnBoot=cdc` stops with an `#error`.
- **Low battery.** Two checks in `niva_board_logic.h` decide when the pod goes into deep sleep; the button wakes it.
  - **At boot**, before any radio starts, one gauge reading near rest (`nivaPowerSleepAtBoot`). Sleep below 3.50 V; below 3.80 V after a brown-out reset, because a cell that low browns out while the radios start and never reaches the running check; below 3.60 V after a low-battery sleep, so a button press on a flat cell does not start the radios again.
  - **While running**, every 10 s with the radios on: three readings in a row below 3.50 V (`NivaPowerPolicy`).
  - Before sleeping, the IMU is powered down. The analog front end cannot be (no switch on Rev C.2), so sleep draws roughly 0.3-0.5 mA and delays the PCM's 3.0 V cut-off by about a day rather than preventing it (review A9, Rev C.3).
  - A press already held at boot is ignored until release, so the wake press never tares an insole or opens pairing.
  - On the pod, a gauge that does not answer is retried every 10 s and reported once on serial. Until it answers, nothing guards the cell but its PCM.
  
  All thresholds are design choices, not measurements.
- **Register sources.** Read on 9 Nov 2026:
  - LSM6DSO32: ST's `lsm6dso32-pid` driver;
  - MAX17048: the SparkFun MAX1704x library;
  - MCP3208: DS21298E figure 6-1.

## Build and test

```sh
arduino-cli compile --fqbn "esp32:esp32:esp32c3:PartitionScheme=huge_app,CDCOnBoot=cdc" --warnings all "niva arduino/niva_protected_steps"
arduino-cli compile --fqbn "esp32:esp32:esp32:PartitionScheme=huge_app" --warnings all "niva arduino/niva_protected_steps"
bash "niva arduino/tests/run_host_tests.sh"
```

Libraries: NimBLE-Arduino 2.5.2, WiFiManager 2.0.17, WebSockets 2.7.2, ESP32 core 3.3.12.

Results on 13 Nov 2026:

| Build | Size | RAM | Warnings in this sketch |
|---|---|---|---|
| Pod | 1,526,251 bytes (48 % of 3 MB) | 59,688 bytes | 0 |
| DevKit | 1,442,627 bytes (45 %) | 73,036 bytes | 0 |

The 21 warnings in each build are in WiFiManager.

The host tests cover:
- `ps_logic_test`: 259 checks;
- the contact detector and frame tests;
- `board_logic_test`: MCP3208 frames, LSM6DSO32 settings and byte order, MAX17048 conversions, the tail classifier, the low-battery boot and running checks (51 checks).

**Flashing the pod:**
- Use the TC2030 service jig on J3 (USB D+/D-, GPIO9, EN, 3V3, GND).
- Hold GPIO9 low at reset for download mode.

## Not verified until a pod is built

- **Every driver against real chips:**
  - LSM6DSO32 WHO_AM_I = 0x6C read back over SPI;
  - MCP3208 codes on all eight channels;
  - MAX17048 VRESET read back.
- **Sampling rates on one core.** The piezo runs at 500 Hz, FSR + IMU at 100 Hz, and each FSR burst is 64 MCP3208 frames. Wi-Fi and BLE share the core. `status` on serial prints the achieved rates and overruns. Lower `kOversample` if the burst does not fit.
- **FSR and contact thresholds.** `niva_signal.h` was tuned on the DevKit divider; the pod's MCP3208 codes are ratiometric to VEXC through a different circuit. Re-derive the thresholds with recorded traces (PINMAP section 3, verification plan F3).
- **Hub stride axis.** The default `axis` is +z, chosen for the DevKit mounting. On the pod, find the axis of shank rotation on a wearer and set it over serial (`axis`).
- **Tail check limits** (CH6 1950-2450, insert IDs ±80 counts) against real inserts and a deliberately shorted tail.
- **Low-battery shutdown.**
  - Measure the cell voltage at which the rail browns out during a burst, with a fresh F1 and with a tripped and recovered F1 (review A7, C7). Then set `NIVA_POWER_LOW_MV`, `NIVA_POWER_LOW_MV_AFTER_BROWNOUT` and `NIVA_POWER_RESUME_MV` from those measurements. Review A7 says the cut-off may have to sit near 3.7 V; 3.50 V assumes a fresh F1.
  - Check that a brown-out really reports `ESP_RST_BROWNOUT` on the ESP32-C3, rather than a plain power-on reset. If it does not, a pod that browns out while starting its radios at a rest voltage between 3.50 and 3.80 V reboots in a loop until the PCM opens.
  - Check how long the gauge's first VCELL reading takes after a cartridge is inserted (the boot check waits about 0.3 s).
  - Measure the deep-sleep current, and check that the LEDs (GPIO20/21, not held) stay off.
  - Check that the button wakes the pod from deep sleep.

## Open

- **OTA.** No over-the-air update yet. A 4 MB pod needs two app slots for OTA. The image is 1.53 MB, so a custom table such as 2 × 1.6 MB app + about 0.7 MB LittleFS would fit, but it shrinks the offline log. Not done.
- **BLE security.** Protected Steps' GATT service has no pairing or bonding. Any phone in range can read the log and send commands (review E6). That needs a protocol and app change.
- **Ankle-hub IMU on the pod.** The ankle hub uses the pod's IMU only; the MCP3208 is idle. The analog front end still draws its standby current (review A9, a Rev C.3 copper item).
