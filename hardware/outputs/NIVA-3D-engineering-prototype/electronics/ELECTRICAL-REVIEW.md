# NIVA pod — electrical design review, Revision C

**Status:** engineering prototype. The schematic is one connected KiCad 9 hierarchy that passes ERC with 0 errors. The PCB is an **unrouted placement prototype**: the ratsnest is shown, but no copper tracks have been designed. Nothing here has been built, powered or measured. **Not for fabrication.**

## 1. What was wrong with Rev B, and what changed

| # | Rev B finding | Rev C resolution |
|---|---|---|
| E1 | Neither `.kicad_sch` file could be parsed by KiCad: every placed symbol was left unclosed (42 and 15 unbalanced parentheses). | The generator writes a closed record per symbol. All three sheets load in KiCad 9.0.9, with 66 components (64 electrical + 2 mounting holes). |
| E2 | Two separate projects were "merged by matching local net labels". This meant +3V3/GND and the four interface signals were **not** connected across the files. | One hierarchy: root `NIVA-pod.kicad_sch` → `Controller` and `Heel and indicator`. Rails use global power symbols; `PVDF_RAW`, `PIEZO_ADC`, `LED_R` and `LED_G` use hierarchical labels and sheet pins. |
| E3 | The official Espressif symbol library (github.com/espressif/kicad-libraries, 2026-07 snapshot) is saved in **KiCad 10** format (`20251024`), so KiCad 9.0.9 rejects it. | The ESP32-C3-MINI-1 symbol is down-converted by stripping four presentation-only tokens (`show_name`, `do_not_autoplace`, `in_pos_files`, `duplicate_pin_numbers_are_jumpers`). Pins and electrical types are unchanged. The official footprint (KiCad 7 format) is used unmodified. |
| E4 | VEXC was hard-wired to +3V3 at J1 pin 1. A short in the tail pulls down the MCU rail, and the "VEXC sense" divider measured +3V3, so it could never detect that fault. | VEXC is fed through R33 = 220 Ω with C18 = 1 µF, and CH6 senses VEXC/2 **after** R33. A tail short now draws 15 mA (0.05 W in R33), and the rail stays up. |
| E5 | The ID line went straight to ADC CH7 with no filtering. | R34 3.3 kΩ + C17 1 µF, the same RC as the force channels. |
| E6 | Piezo clamps were left as "D_Small / select". | D2 and D3 are BAS416 low-leakage diodes (SOD-323), with pin 1 as cathode on both symbol and footprint. BAV199DW/BAV99 dual parts were rejected: KiCad's symbol pin names contradict its unit grouping, and the manufacturer datasheets could not be retrieved from this environment to resolve it. |
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
- **VEXC is load-dependent.** Through R33 = 220 Ω it sags to about 2.94 V at full load, and one channel's load change moves the others by up to about 2 %. Every channel is proportional to VEXC, so **firmware must normalise each block by that block's CH6 reading.** This is mandatory, not optional.
- Excitation is continuous (the Rev B decision is kept). Switching it every 5 ms cannot settle a 3.3 ms RC.

**Insert ID (CH7):** a 10 kΩ pull-up to +3V3 and an ID resistor to GND in the protected tail assembly. V = 3.3·R_ID/(10k + R_ID). Choose E12 codes with at least 3 ADC-bin separation after tolerance and temperature, for example 1k / 2.2k / 4.7k / 10k / 22k / 47k.

**ESD at J1:** no TVS is fitted. Each force and ID line reaches the ADC through 3.3 kΩ into 1 µF, so an 8 kV HBM event (100 pF → 0.8 µC) raises the reservoir about 0.8 V. The PVDF line is protected by the 100 kΩ series resistor and the BAS416 clamps. **System-level IEC 61000-4-2 testing is still required.**

**Heel PVDF buffer:**
- Film capacitance of about 1.4 nF (LDT0-028K class; confirm on the chosen part) with R43 = 10 MΩ bias gives a high-pass near 11 Hz.
- Clamp current is limited by R42 = 100 kΩ (a 70 V spike gives 0.7 mA).
- Offset budget: diode leakage × 10 MΩ. Verify the BAS416 leakage figure against its datasheet.
- MCP6001 unity-gain follower: 1 pA bias current, isolated from the 470 nF load by 1 kΩ.
- Output filter 339 Hz, single pole, for 2 kHz sampling: about 10 dB at Nyquist. Treat as exploratory. Decide the final filter and sample rate after experiment E3 (cable-motion noise).

**Status emitters:** red (Vf ≈ 2.0 V) through 1 kΩ gives about 1.3 mA; 570 nm yellow-green (Vf ≈ 2.1 V) through 680 Ω gives about 1.8 mA. Red and green together read as amber. Brightness and colour separation through the printed light pipe are untested. The colours signal recording quality only, never a clinical result.

## 5. Power integrity

- There is **no charger in the wearable**. The cartridge supplies VBAT through J2; cell protection (e.g. BQ2970) belongs in the cartridge, and charging, NTC and pack ID belong in a separate dock. **Neither the cartridge electronics nor the dock is designed here.**
- TLV75533 dropout: 238 mV maximum at 500 mA (TI datasheet), scaling roughly with load. ESP-NOW/Wi-Fi TX bursts can reach a few hundred mA, so cell internal resistance, protection FETs, the two spring contacts and the dropout together set the usable cut-off. Measure the sag on the bench, then set a gauge-based firmware cut-off (bench item P1).
- MAX17048: about 23 µA continuous from VBAT; include it in the deep-sleep budget.
- Reverse insertion: the cartridge tab is asymmetric, so the cartridge only seats one way, and contacts only mate lid-inwards. There is no electrical reverse-polarity protection.

## 6. PCB — placement prototype

`NIVA-pod.kicad_pcb`: 4 layers, 34 × 48 × 1.0 mm, generated from the netlist by `work/build_niva_pcb.py`. Placement comes from `work/niva_layout.py`, which also drives the FreeCAD enclosure.

- **Board, enclosure and mounting:** the outline is notched around the four enclosure screw bosses with 0.4 mm clearance. Two M2 holes (H1, H2) go to bosses outside the battery bay. The other edges sit on housing ledges and are clamped by front-cover ribs.
- **Component height:** taken from the actual 3D models. The tallest part is J1 at 4.25 mm, leaving 1.16 mm to the front cover. The complete PCBA STEP was checked against every enclosure part; see `../mechanical/interference-report.json`.
- **Battery clearance:** the board underside carries only J2 and the J3 pads, both reached through windows in a 0.8 mm bay ceiling.
- **Antenna:**
  - The module's antenna end is at the top board edge, away from the cell, with Espressif's footprint keepout plus a board-level all-layer keepout (x 11–31, y 48.4–55 in the pod frame).
  - The M2 screws and bosses nearest the antenna are about 6–8 mm away.
  - **RF performance, detuning by the housing and body, and the keepout's adequacy are not verified.**
- **Sensor connector access:** J1's entry faces the pod bottom, with its front 0.5 mm inboard of the board edge. The keyed tail boot passes the enclosure aperture on the parting line.
- **IMU rigidity and orientation:** the LSM6DSO32 is placed beside screw H2. Axis arrows are on the silk; confirm them against the package marking during placement review.
- **Button and indicator alignment:** SW1 is centred under the actuator (0.2 mm pre-travel). D4/D5 are under the light pipe (0.3 mm gap), which is checked in CAD.
- **Grounding, analog noise and RF:**
  - In1 is a solid GND plane under the whole board.
  - The analog rows sit between J1 and the ADC, away from the module.
  - The rest is **not done**, because routing is not done: return-path review, SPI clock routing, shielding of the PVDF input and RF coexistence.
- **Autorouting attempt:** Freerouting 2.1.0 on F.Cu/In2.Cu/B.Cu stalled at about 40 of 151 connections unrouted after 160+ passes. It was **not adopted**; the DSN and log are kept in `work-routing/`. The dense 0603 rows at 1.8 mm pitch are the main constraint. Hand routing, or relaxing the rows, is the next step.
- **DRC** (`exports/pcb/NIVA-pod-DRC.rpt`, with schematic parity): 0 placement or clearance errors, 0 footprint errors, 0 parity issues, and 183 unconnected items (expected: unrouted). There are 4 warnings: the In1 GND plane is isolated (no vias yet), and the module silk is clipped at the antenna edge.
- **No Gerbers, drill files or pick-and-place files were produced.**

## 7. Open electrical items before any fabrication release

1. Route the board, then re-run DRC with fab-house rules and review the return paths and RF.
2. Select the spring-contact part and replace the J2 placeholder footprint and envelope model.
3. Confirm the MAX17048 land pattern (TDFN-8 2 × 2) against the ADI package drawing. The 3D model is a simplified envelope because KiCad has no model for it.
4. Confirm the BAS416 leakage, the LSM6DSO32 unused-pin handling, and the KMR2 travel and force.
5. Bench-measure regulator sag during radio bursts, deep-sleep current, ADC noise, and CH6 normalisation.
6. Run the E3 cable-motion test before fixing the PVDF filter and sample rate.
7. Design the cartridge protection board and the charging dock separately, with a selected cell and temperature protection.
