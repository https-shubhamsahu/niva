# One pod, two roles: ankle hub and shoe node (Protected Steps, Rev C.2)

Design note, 3 November 2026. **Nothing here has been built, powered or measured.** The roles and the role flag come from `protected-steps/PROTOCOL.md` (v1, draft). Pin and net names are in `PINMAP.md`.

The same Rev C.1 pod PCB and enclosure serve both roles. What differs is the mount, which connectors are used, the firmware role, and possibly a cheaper set of parts on the ankle hub.

| | **Ankle hub** | **Shoe node** |
|---|---|---|
| PROTOCOL.md role | `ankle`: counts every stride, receives the insole's ESP-NOW events, classifies strides P / U / X, logs offline, serves BLE | `insole`: detects contacts and sends them, plus a heartbeat every 30 s, to the paired hub over ESP-NOW |
| Worn | strap on the lower shin of the instrumented leg | clipped at the collar of the prescribed shoe, same leg |
| Mount (new CAD, `mechanical/`) | `13_AnkleCradle` + `16_AnkleSaddlePad_TPU` | `14_CollarClip` |
| Pod orientation | cable end (pod −y) down, toward the foot | cable end up at the collar; the pod hangs upside down on the heel counter |
| J1 insole tail (JST GH 10) | fitted but unused; opening closed by `15_TailBlank_TPU` | insole tail connected through the keyed boot |
| Analog front end (MCP3208, dividers, PVDF buffer) | not needed; see "ankle-lean build" below | needed |
| IMU (LSM6DSO32) | primary sensor: stride detection | optional for contacts; useful for a shoe-on/off motion check (research question, not designed) |
| Radio | BLE to the phone, ESP-NOW receive, a Wi-Fi scan every `home_scan_s` (default 300 s) for the home flag | ESP-NOW transmit per contact and per heartbeat |
| Cartridge, dock, button, lights | same | same |
| BLE name (PROTOCOL.md) | `Niva-Ankle-XXXX` | `Niva-Insole-XXXX` |

## Firmware role flag

- **Role:** stored in NVS as `role` = `ankle` | `insole` and set with `role ankle` on serial or over BLE (PROTOCOL.md). Nothing in the hardware sets it; the same board runs either role.
- **Proposed second key, `mount`** (= `ankle_up` | `collar_inverted`): tells the firmware how to remap the IMU axes. In the collar clip the pod is mounted upside down, so its y axis points down the leg and its x axis is mirrored relative to the ankle mount. It can stay internal to the firmware (derived from `role`, or its own NVS key); it only enters PROTOCOL.md if the app must set it, as an optional field, which the protocol allows without a `proto` bump.
- **Hardware cross-check, already on the board:**
  - CH7 INSERT_ID reads 4095 with no tail fitted and an insert-specific code with one (right medium 4.7 kΩ → 1310, left medium 47 kΩ → 3378; ELECTRICAL-REVIEW §4).
  - CH6 flags a shorted tail.
  - With `role = insole` and CH7 ≈ 4095, the firmware should report validity `INVALID` ("tail missing") instead of sending contacts.
  - With `role = ankle` and a valid insert code, it should warn that a tail is plugged into the hub.
  - The R/L insert code can also confirm that the shoe node sits on the same leg as its hub.
- **Physical marking:** the cradle carries a debossed **A**, and the clip an **S** on its shoe side, next to the R/L letter, so the parts are not mixed up.

## Ankle-lean build (optional, ankle hub only)

**Default:** populate the full Rev C.1 BOM for both roles. Any pod can then take either role, and only one assembly has to be kept in stock.

**Lean option:** if ankle hubs are built separately, leave out the parts that only serve the insole, so they draw no standby current. These are **calculations from part values or datasheet typicals, not measurements**:

| Do not populate (ankle hub) | Why | Continuous current saved |
|---|---|---|
| R31, R32 (CH6 divider, +3V3 to GND) | tail-fault monitor, no tail | 3.3 V / 20 kΩ = 165 µA (Ohm's law) |
| R40, R41, C40 (VMID divider from VEXC) | PVDF bias, no film | about 3.3 V / 200.2 kΩ ≈ 16.5 µA (Ohm's law, R33 included) |
| U4 MCP6001, R42–R44, C41, C42, D2 | PVDF buffer, no film | 100 µA typical quiescent at 5.5 V (Microchip DS20001733L, p. 3; no 3.3 V figure listed) |
| R11–R15, R21–R25, C11–C15, R30, R34, C16, C17 | force and ID channels | ~0 with no tail fitted: the FSR dividers carry no current when open |
| U2 MCP3208, C4, C19 (optional) | no analog channels left | 0.5 µA typ standby (Microchip DS21298E, p. 3) |

**Keep J1.** It closes the CH7 cross-check, and it lets an ankle hub be reflashed as a shoe node. If U2 is left out, CH6 and CH7 are gone, so keep U2 if the role check above is wanted.

## Battery-life budget: to be measured

**Cell:** EEMB LP502030 class, 230 mAh minimum / 250 mAh typical, per the EEMB listing cited in the Rev C.1 README; no lot has been bought.

**Life per role: to be measured.** No hours are estimated here, because the radio duty cycle, which dominates, is set by the firmware and has not been measured.

The datasheet typicals below are only for planning the bench measurement (bench item P1 and RQ2):

| Load | Datasheet typical (conditions) | Source | Ankle hub: measured | Shoe node: measured |
|---|---|---|---|---|
| ESP32-C3 Wi-Fi / BLE TX | 290–350 mA Wi-Fi TX; BLE TX 100 mA at −15 dBm to 340 mA at 20 dBm (3.3 V, 25 °C, 100 % duty) | ESP32-C3-MINI-1 datasheet v2.2, Tables 6-4, 6-5 | to be measured | to be measured |
| ESP32-C3 RX | 82–86 mA | Tables 6-4, 6-5 | to be measured (ESP-NOW listen duty: firmware choice) | to be measured |
| ESP32-C3 modem-sleep | 13–28 mA depending on CPU clock and peripherals | Table 6-6 | to be measured | to be measured |
| ESP32-C3 light / deep sleep | 130 µA / 5 µA | Table 6-7 | to be measured | to be measured |
| LSM6DSO32 | 0.55 mA accel + gyro high-performance; 4.4–4.5 µA accel low-power at 1.6 Hz; 3 µA power-down (1.8 V; "not guaranteed") | ST DocID032891 Rev 1, Table 4 | to be measured at the chosen ODR | to be measured |
| MCP3208 | 225 µA active at 2.7 V; 0.5 µA standby | DS21298E p. 3 | — (lean: not fitted) | to be measured |
| TLV75533 | 25 µA ground current, no load, 25 °C | TI SBVS320D §5.5 | to be measured | to be measured |
| MAX17048 | 23 µA active; 3 µA hibernate | ADI MAX17048 datasheet p. 2 | to be measured | to be measured |
| Dividers and PVDF buffer | see the table above | calculation | — | to be measured |
| **Battery life** | — | — | **to be measured** (RQ2 three-day wear) | **to be measured** |

These figures were read from the datasheets by a research pass on 3 November 2026. Re-read them before quoting them.

## Mechanical notes per role

- **Ankle hub:**
  - Uses the Rev C rail, key and latch interface unchanged; the audit shows the same 0.2 mm rail clearance as the Rev C cradle.
  - The 35 mm strap width is the Rev C cradle's; no strap has been bought.
  - The saddle pad's concave radius (`SHIN_R` = 60 mm) is a **placeholder to be measured**. Its 2 mm centre thickness copies the Rev C pad.
  - Wear all day with a sari or lungi, and pressure under the strap: unassessed (README "Still to check").
- **Shoe node:**
  - **The clip's inner tongue sits inside the shoe collar, against the sock. For people with diabetic foot disease this is a potential pressure point, so a clinician must approve it before any wear by at-risk participants.**
  - The tongue is designed short (14 mm), rounded and thin (1.8 mm), but its skin-side pressure has not been assessed.
  - Collar thickness (`COLLAR_T`, placeholder 5 mm) and tail thickness (`TAIL_T`, placeholder 1.2 mm) **must be measured** on the prescribed shoe before printing.
  - The pod hangs on the outside of the heel counter, where it can catch on furniture and stairs.
  - Retention under heel-strike acceleration is untested. In this orientation the latch, not the groove end stop, carries the pod's weight.
- **Radio between the two:** the hub and node are on the same leg, roughly ankle to collar apart, with the leg and shoe in the path. The ESP-NOW link margin is not measured. Espressif's antenna guidance is not met inside this enclosure (`STATUS-CLOSURE.md` §3).
