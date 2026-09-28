# NIVA pod — electrical design review, Revision C

**Status:** engineering prototype, Rev C.1.
- The schematic is one connected KiCad 9 hierarchy that passes ERC with 0 errors.
- The PCB is **routed**. KiCad DRC reports 0 errors and 0 unconnected items with schematic parity on.
- The cartridge strip, charging dock and insole flex (right and left) are separate KiCad projects. Each passes ERC and DRC.
- Nothing here has been independently reviewed, built, powered or measured. **Not released for fabrication:** Gerbers exist for review only.

## 1. What was wrong with Rev B, and what changed

| # | Rev B finding | Rev C resolution |
|---|---|---|
| E1 | Neither `.kicad_sch` file could be parsed by KiCad: every placed symbol was left unclosed (42 and 15 unbalanced parentheses). | The generator writes a closed record per symbol. All three sheets load in KiCad 9.0.9, with 65 components in Rev C.1 (63 electrical + 2 mounting holes; the two BAS416 became one BAV199). |
| E2 | Two separate projects were "merged by matching local net labels". This meant +3V3/GND and the four interface signals were **not** connected across the files. | One hierarchy: root `NIVA-pod.kicad_sch` → `Controller` and `Heel and indicator`. Rails use global power symbols; `PVDF_RAW`, `PIEZO_ADC`, `LED_R` and `LED_G` use hierarchical labels and sheet pins. |
| E3 | The official Espressif symbol library (github.com/espressif/kicad-libraries, 2026-07 snapshot) is saved in **KiCad 10** format (`20251024`), so KiCad 9.0.9 rejects it. | The ESP32-C3-MINI-1 symbol is down-converted by stripping four presentation-only tokens (`show_name`, `do_not_autoplace`, `in_pos_files`, `duplicate_pin_numbers_are_jumpers`). Pins and electrical types are unchanged. The official footprint (KiCad 7 format) is used unmodified. |
| E4 | VEXC was hard-wired to +3V3 at J1 pin 1. A short in the tail pulls down the MCU rail, and the "VEXC sense" divider measured +3V3, so it could never detect that fault. | VEXC is fed through R33 = 220 Ω with C18 = 1 µF, so a tail short draws 15 mA (0.05 W in R33) and the rail stays up. **Rev C.1:** VEXC is also the MCP3208 VREF (C19 1 µF at the pin), so every channel is ratiometric in hardware. CH6 now reads +3V3/2 (R31/R32, C16) against VEXC as a tail-fault monitor. |
| E5 | The ID line went straight to ADC CH7 with no filtering. | R34 3.3 kΩ + C17 1 µF, the same RC as the force channels. |
| E6 | Piezo clamps were left as "D_Small / select". | **Rev C.1:** D2 is one BAV199 (Nexperia low-leakage series pair, SOT-23, 3 pA typical), replacing the two BAS416 singles. KiCad's stock dual-diode symbols disagree with their own unit grouping, so D2 uses a project symbol whose pins state the datasheet pinning explicitly: 1 = A1 → GND, 3 = K1/A2 → PZ_BIAS, 2 = K2 → +3V3. The pinning is from the Nexperia BAV199 data sheet (April 2023), as quoted by two independent search results; the PDF host itself was blocked here. **Check the part marking against the purchased reel.** |
| E7 | The PVDF output filter was 1 kΩ/220 nF (723 Hz) for 2 kHz sampling, which is almost no anti-aliasing. | 1 kΩ/470 nF (339 Hz). It is still single-pole; see §4. |
| E8 | Decoupling was generic "C3–C5 100n on +3V3". | Assigned per pin: module 22 µF + 100 nF; ADC VDD 100 nF, VREF 1 µF; IMU VDD and VDDIO 100 nF each; LDO 4.7 µF in, 10 µF + 100 nF out; gauge 100 nF. |
| E9 | The battery was on a JST GH cable connector on top of the board, which is incompatible with a cartridge removed from the rear. | J2 is a 4-position spring-contact block on the board underside (2 × VBAT, 2 × GND). It reaches brass plates in the cartridge lid through a window in the bay ceiling. **The part is still to be selected**; the footprint is a labelled placeholder. |
| E10 | Service pads were a 2.54 mm pin header (too tall for the pod). | A Tag-Connect TC2030-NL footprint on the underside, reached through the empty cartridge bay. It has no charge path. |
| E11 | The button was a TL3342 with no height basis. | C&K KMR2 (KMR221G). Its 1.9 mm height comes from the KiCad library model and was used in the enclosure stack-up. |

## 2. ERC

`exports/NIVA-pod-ERC.rpt` (kicad-cli 9.0.9, all severities, KiCad default rule severities, **no exclusions**): **0 errors, 1 warning.**

- `pin_to_pin` — LSM6DSO32 SDx (bidirectional) is tied to GND, whose PWR_FLAG is a power output. The unused sensor-hub pins are tied to GND intentionally, following the ST pin table. This is left visible rather than suppressed. Confirm against the current ST datasheet (DS13210) before release.

## 3. Pin and boot review (ESP32-C3-MINI-1)

| GPIO | Net | Review |
|---|---|---|
| IO0 / IO1 | I2C_SDA / IMU_INT1 | Also XTAL_32K pins. That is acceptable because no 32 kHz crystal is fitted. |
| IO2 | I2C_SCL | Strapping pin that must be high at reset. The 4.7 kΩ I²C pull-up does this, and the MAX17048 (powered from VBAT) does not pull it low. |
| IO3 | BUTTON | Not a strapping pin. 10 kΩ pull-up; KMR2 to GND. |
| IO4/5/6 | SPI SCK/MISO/MOSI | Shared by the MCP3208 and IMU. The MCP3208 is limited to about 1 MHz SCLK at 2.7 V (2 MHz at 5 V), so firmware must switch clock rate per chip select. |
| IO7 / IO10 | CS_ADC / CS_IMU | — |
| IO8 | BOOT8 (pull-up only) | Must be high for UART download mode. Otherwise spare. |
| IO9 | BOOT9 | Strap: 10 kΩ pull-up; the service jig pulls it low for download. |
| IO18/19 | USB D−/D+ | Service pads only. There is no ESD protection: internal, jig-only access. |
| IO20 | LED_R | U0RXD; it is an input at boot, so the LED load is harmless. |
| IO21 | LED_G | U0TXD: **the ROM boot log will flicker the green emitter at reset.** Accepted for the prototype; firmware logs over USB. |
| EN | CHIP_EN | 10 kΩ / 1 µF RC reset delay (τ = 10 ms). |

All 15 exposed GPIOs are assigned (IO8 as a strap-only spare). Any new function needs an I/O expander.

## 4. Analog values (calculations, not measurements)

**Force channels (F1–F5), bench divider topology.** The FSR runs from VEXC to Fn_RAW, with 10 kΩ (0.1 %) to GND, then 3.3 kΩ + 1 µF into the ADC.
- Transfer: V = VEXC · 10k / (10k + R_FSR). This is **not** the Tekscan A201 op-amp reference circuit and does not inherit its linearity, drift or repeatability figures. Calibrate the complete insole stack as built.
- Low-pass fc = 1/(2π·3.3 kΩ·1 µF) = 48 Hz. At 200 Hz sampling the Nyquist attenuation is only about 7 dB. Plantar force content is mostly below 20–30 Hz, but impact transients alias. **Recommendation:** oversample (the MCP3208 has large headroom) and decimate in firmware.
- ADC settling: the 1 µF reservoir is about 50,000 × the MCP3208's ~20 pF sample capacitor, so charge-sharing error is below 0.003 %. The ADC's source-impedance limit does not apply at the pin.
- Current: at most 0.33 mA per saturated channel, 1.65 mA for all five (the brief's worst case).
- **VEXC is load-dependent, and that no longer matters to the reading.** Through R33 = 220 Ω, VEXC sags to about 2.94 V at full load, and one channel's load change moves VEXC by up to about 2 %. Rev C.1 drives the MCP3208 VREF from VEXC itself, so code = 4096 · 10k / (10k + R_FSR) whatever VEXC is: the ratio is formed in hardware, and **no firmware normalisation is needed**.
  - VREF range: the MCP3208 accepts VREF from 0.25 V to VDD (DS21298). VEXC is 2.94–3.3 V ≤ VDD, so this is in range.
  - VREF current: 100 µA typ / 150 µA max drawn from VEXC. C19 (1 µF at the VREF pin) supplies the conversion transients.
  - CH6 monitor: in normal operation it reads 4096 · 1.65 / VEXC, which is 2048–2299. On a tail short, VEXC (and so VREF) collapses below the 0.25 V minimum. Conversions are then invalid, but CH6 is driven toward full scale. Firmware treats CH6 outside about 2000–2400 as a tail fault and discards that block.
- Excitation is continuous (the Rev B decision is kept). Switching it every 5 ms cannot settle a 3.3 ms RC.

**Insert ID (CH7):** R30 = 10 kΩ 0.1 % from VEXC, and an ID resistor to GND on the insert's flex transition (above the collar). Code = 4096 · R_ID / (10k + R_ID), which is ratiometric. Assigned codes: **right medium 4.7 kΩ → 0.320 (1310)** and **left medium 47 kΩ → 0.825 (3378)**. Other sizes take further E12 values with at least 3 bins of separation after tolerance, e.g. 1k / 2.2k / 10k / 22k / 100k. An open tail reads 4095, and a short reads 0.

**ESD at J1:** no TVS is fitted. Each force and ID line reaches the ADC through 3.3 kΩ into 1 µF, so an 8 kV HBM event (100 pF → 0.8 µC) raises the reservoir about 0.8 V. The PVDF line is protected by the 100 kΩ series resistor and the BAS416 clamps. **System-level IEC 61000-4-2 testing is still required.**

**Heel PVDF buffer:**
- Film capacitance of about 1.4 nF (LDT0-028K class; confirm on the chosen part) with R43 = 10 MΩ bias gives a high-pass near 11 Hz.
- Clamp current is limited by R42 = 100 kΩ (a 70 V spike gives 0.7 mA).
- Offset budget: diode leakage × 10 MΩ = 3 pA × 10 MΩ = 30 µV typical (BAV199). The maximum leakage over temperature is larger; check the data sheet's maximum at 40 °C.
- MCP6001 unity-gain follower: 1 pA bias current, isolated from the 470 nF load by 1 kΩ.
- Output filter 339 Hz, single pole, for 2 kHz sampling: about 10 dB at Nyquist. Treat as exploratory. Decide the final filter and sample rate after experiment E3 (cable-motion noise).

**Status emitters:** red (Vf ≈ 2.0 V) through 1 kΩ gives about 1.3 mA; 570 nm yellow-green (Vf ≈ 2.1 V) through 680 Ω gives about 1.8 mA. Red and green together read as amber. Brightness and colour separation through the printed light pipe are untested. The colours signal recording quality only, never a clinical result.

## 5. Power integrity

- There is **no charger in the wearable**. The cartridge supplies VBAT through J2. Rev C.1 designs the rest as separate KiCad projects:
  - **Cartridge** (`cartridge/`): an EEMB LP502030-class cell whose integrated PCM is protection layer 1, a series 0805 polyfuse on every external P+ path as layer 2, the NTC routed to the dock only, and gold dock pads on the underside. No active parts.
  - **Dock** (`dock/`):
    - USB-C sink (5.1 k CC pull-downs, 1206 polyfuse) and an MCP73831-2 charger at 4.20 V, with I_REG = 1000 V / 10 kΩ = 100 mA (about 0.43 C of 230 mAh).
    - The charger's PROG pin reaches GND only through Q1. An LM393 window on the pack NTC turns Q1 off outside about 0–45 °C, and also when the NTC is open (no cartridge) or shorted. A floating PROG disables the MCP73831 (datasheet).
    - The temperature window is therefore enforced in hardware, with no firmware.
  - Both boards pass ERC and DRC. **Neither has been built, and the thresholds, charge termination and fault behaviour are unmeasured** (verification plan F4).
- TLV75533 dropout: 238 mV maximum at 500 mA (TI datasheet), scaling roughly with load. ESP-NOW/Wi-Fi TX bursts can reach a few hundred mA, so cell internal resistance, protection FETs, the two spring contacts and the dropout together set the usable cut-off. Measure the sag on the bench, then set a gauge-based firmware cut-off (bench item P1).
- MAX17048: about 23 µA continuous from VBAT; include it in the deep-sleep budget.
- Reverse insertion: the cartridge tab is asymmetric, so the cartridge only seats one way, and contacts only mate lid-inwards. There is no electrical reverse-polarity protection.

## 6. PCB — routed prototype (Rev C.1)

`NIVA-pod.kicad_pcb`: 4 layers (F.Cu signal, **In1.Cu solid GND plane**, In2.Cu signal, B.Cu signal), 34 × 48 × 1.0 mm, generated from the netlist by `work/build_niva_pcb.py`. Placement comes from `work/niva_layout.py`, which also drives the FreeCAD enclosure.

- **Rules:** 0.15 mm tracks with 0.127 mm clearance (0.3 mm for +3V3, VBAT and VEXC), and 0.5 / 0.25 mm through vias. These are inside common small-batch 4-layer capability, but they are not a specific fab's rules: confirm them with the chosen fab.
- **How it was routed:**
  1. Every GND pad (81, including the module's split thermal pad and the Tag-Connect pad) gets its own via to the In1 plane *before* routing, at the nearest spot that clears all other copper, holes, the board edge and the antenna keep-out.
  2. Freerouting 2.1.0 then routes the signal nets. It counts the plane-connected GND pads as unrouted because it does not credit the plane, so its log ends at "8 unrouted"; KiCad's connectivity check is the authority here.
  3. `finalize` imports the session, removes dangling stubs, adds GND pours on F.Cu, In2.Cu and B.Cu with solid pad connections, and fills them.
- **Result:** 547 track segments (F.Cu 665 mm, B.Cu 222 mm, In2.Cu 73 mm) and 126 vias (81 GND). The session in `work-routing/` was routed from the DSN before the Tag-Connect GND pad joined the fan-out; `finalize` adds that one via after import. Re-running Freerouting gives a different result each time (a repeat run left 6 nets open), so the committed session is the one that was checked.
- **DRC** (`exports/pcb/NIVA-pod-DRC.rpt`, KiCad 9.0.9, all severities, schematic parity on): **0 errors, 0 unconnected items, 0 parity issues, 0 footprint errors.** There are 3 warnings, all the ESP32-C3-MINI-1 footprint's own silkscreen clipped at the board edge. The module sits at the edge on purpose (antenna end out).
- **Board, enclosure and mounting:** the outline is notched around the four enclosure screw bosses with 0.4 mm clearance. Two M2 holes (H1, H2) go to bosses outside the battery bay. The other edges sit on housing ledges and are clamped by front-cover ribs. The FreeCAD audit against the routed PCBA shows only the two intended spring-contact preload intersections.
- **Antenna:** the module's antenna end is at the top board edge, with Espressif's footprint keep-out plus a board-level keep-out on all four layers (x 11–31, y 48.4–55 in the pod frame). No copper, via or pour is inside it. **RF performance and detuning by the housing and body are not verified.**
- **Not reviewed:**
  - return paths of the SPI clock and the analog rows over the split F.Cu pour;
  - PVDF input guarding;
  - thermal relief versus hand rework;
  - the fab's DFM check.

  The `fab-REVIEW-ONLY-NOT-RELEASED/` folder holds Gerbers, drill and placement files so that a reviewer can inspect them. It is **not** an order package; its `STATUS.txt` lists the blockers.

### Other boards (Rev C.1)

| Board | Layers / thickness | Routing | ERC / DRC |
|---|---|---|---|
| `cartridge/NIVA-cartridge` — 3.4 × 30 mm interconnect strip | 2 / 0.8 mm | hand-routed from `HAND` in `build_niva_pcb.py`: 17 segments, 3 vias, 0.3 mm power tracks, 0.15 mm gaps | 0 / 0 errors, 0 unconnected |
| `dock/NIVA-dock` — 58 × 56 mm charging dock | 2 / 1.6 mm | Freerouting plus GND pours: 166 segments, 10 vias | 0 / 0 errors, 0 unconnected |
| `insole/NIVA-insole-R`, `-L` — sensing flex (hold H1) | 2 / 0.12 mm polyimide; **F.Cu only underfoot** | generated lanes, 117 segments (3.3 m of 0.25 mm lanes), 8 vias, all above the collar | 0 / 0 errors, 0 unconnected |

The insole flex's FSR windows expose both comb nets under one coverlay opening on purpose, because the FSR film bridges them. The footprint declares `allow_soldermask_bridges`, so DRC reports no mask bridge.

## 7. Open electrical items before any fabrication release

1. Independent schematic and layout review; fab DFM on the pod, dock and flex; return-path and RF review of the pod.
2. Select the pod J2 and dock J2 spring-contact parts, and replace the placeholder land patterns and envelope models.
3. Confirm the MAX17048 TDFN-8 land pattern against the ADI package drawing (its 3D model is an envelope), and the BAV199 marking and pinning on the purchased reel.
4. Confirm the LSM6DSO32 unused-pin handling and the KMR2 travel and force.
5. Bench: regulator sag during radio bursts, deep-sleep current, ADC noise with VREF = VEXC, and the CH6 tail-fault flag.
6. Run the E3 cable-motion test before fixing the PVDF filter and sample rate.
7. Cartridge and dock: a purchased cell lot, the NTC value, the polyfuse part, charge termination and the thermal-window trip points, all measured (`../VERIFICATION-PLAN.md` F4).
8. Insole flex: choose and characterise the FSR ink film; test fatigue, sweat ingress and the ID codes (`../VERIFICATION-PLAN.md` F2, F3, F6, S7).
