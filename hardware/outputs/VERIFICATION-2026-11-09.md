# Niva design verification, 9 November 2026

What was checked, what was wrong, what is fixed on this branch, and what is still open before Niva can be called production ready.

## Bottom line

**Niva is not production ready, and no desk review can make it so.** For a wearable that protects diabetic feet, production needs four things this repo does not have yet:
- built and measured first articles;
- firmware proven on a Rev C.2 pod (written on 12 Nov, not yet run on hardware);
- battery and EMC test reports (IEC 62133-2 / UN 38.3 for the cell, IEC 60601-1-2 style EMC);
- biocompatibility evidence and a medical-device risk file (ISO 14971, IEC 62304, CDSCO).

What this pass did:
- **Desk checks:** checked every part against its maker's datasheet, every board against PCBWay's published limits, every printed part against the CAD, and the software against the hardware.
- **Fixes:** fixed the design flaws that could be fixed on paper, keeping the bare-board order for C.2 first articles.
- **Unfixed findings:** every finding not fixed is listed below with its next step.

| Area | Findings (BLOCKER / MAJOR / MINOR / NOTE) | Fixed today |
|---|---|---|
| A. Pod schematic vs datasheets | 0 / 4 / 10 / 13 | A1, A14 (BOM), A27 |
| B. Pod layout and PCBWay DFM | 0 / 3 / 10 / 11 | B1 (J2, U4), B2, B7 |
| C. Cartridge, dock, battery safety | 0 / 8 / 12 / 6 | C1 (TVS), C3 (claim), C4, C6, C9, C11, C12, C15, C17, C18 |
| D. Mechanics and insole flex | 2 / 14 / 12 / 6 | D1, D2, D3, D4 (partly), D5, D9, D11, D25 |
| E. Firmware, app, web | 7 / 11 / 11 / 2 | E2, E3, E4, E5, E8, E9, E18 |

Detailed findings with evidence (datasheet page, coordinates, file:line) are in [`verification-2026-11-09/`](verification-2026-11-09/), one file per area.

## 1. How it was checked

**Reviewers:** five independent reviews ran in parallel, one per area. Each had the files and the datasheets but not the earlier conclusions, so they could not simply confirm them.

**Tools:**
- KiCad 10.0.7 (`kicad-cli`, `pcbnew` python) for netlists, ERC/DRC, probe DRC at PCBWay limits, and renders;
- FreeCAD 1.1 for interference audits, sections, tolerance stacks and a Monte Carlo run of the pin compression;
- a Dart harness for the app engine.

**Primary sources read:**
- Espressif ESP32-C3-MINI-1 v2.2 and the ESP32-C3 hardware design guidelines;
- Microchip MCP3208, MCP6001 and MCP73831 (DS20001984H);
- TI TLV755P and LM393; ADI MAX17048 Rev 7; Nexperia BAV199;
- Mill-Max 0900-0-15-20-76-14-11-0; Bourns MF-PSMF;
- the EEMB LP502030-PCM-LD spec ZJQM-RD-SPC-A03249;
- the JST GH and Tag-Connect TC2030-NL drawings;
- the PCBWay PCB, FDM and flex capability pages.

**Sources not reached** (st.com, analog.com and C&K timed out or refused): the LSM6DSO32 datasheet, ADI land pattern 90-0065 and the KMR2 drawing. Those footprints are marked "not independently verified".

**Spot checks:** I re-checked the findings that changed the plan myself. All held:
- the module MPN in the BOM;
- the vias inside J2 pad 3 and U4 pad 2 (measured);
- the cradle slide direction (read from the generator code);
- the pressure conversion jump in both app engines (read);
- the plated-slot count in the dock drill file.

## 2. What is correct (selected)

**Pod schematic:**
- Every IC pin, strapping pin and rail in the exported netlist matches its datasheet: ESP32-C3 GPIO2/8/9 and EN RC, SPI and I2C wiring, MAX17048 pin use, TLV755P DBV pinout, BAV199 pinning, MCP6001 pinout.
- ERC: 0 errors, one reviewed warning.

**Pod layout:**
- The Gerbers match the board and every measured minimum is inside PCBWay's limits: clearance 0.127 mm, track 0.15 mm, annular ring 0.150 mm, hole to hole 0.457 mm, copper to edge 0.30 mm.
- In1 is a continuous GND plane.
- Placement CSV rows match the board.

**Cartridge and dock:**
- The dock pins and cartridge pads line up with no mirroring.
- A floating PROG does disable the MCP73831 (datasheet §3.5, §5.2.2).

**Mechanics:**
- Screw engagement in the case bosses is adequate.
- The cell fits with 0.9 mm (17 %) swell room.
- Button, light-pipe and L/R keying clearances are fine.
- The dock well floor is 1.2 mm thick over its 29 mm span.

**Insole flex:** DRC is clean and the flex fits PCBWay's maximum size, with 2.6 mm to spare.

## 3. Fixed on this branch today

Each fix was re-checked with the tool named.

| Finding | Fix | Checked by |
|---|---|---|
| **C4 / D3 / D25** live P+ and P- plates 0.94 mm apart; plungers could miss the 1.8 mm pockets | **Pod J2 regrouped**: P+ pins stay at y 21.5, the P- pair moves to y 13.0. One plate per polarity on the lid, 5.5 mm apart, each with 0.92 mm of plate around every pin (was 0.37). New footprint `NIVA:SpringContact_2x2pairs_MillMax0900_SMD`, debossed + and - on the lid, + and - silk on the board | KiCad DRC 0 errors / 0 unconnected; render; FreeCAD audit (§5) |
| **B1** open vias in J2 pad 3 and U4 pad 2 | The J2 pads moved off the via; the stub via inside U4 pad 2 is deleted (U4 keeps its other GND via) | pcbnew pad hit-test, DRC |
| **B2** U1 EPAD 100 % paste | Paste margin ratio -0.15 on the eight EPAD sub-pads (about 49 % area) | board file |
| **B7** boards marked only "NIVA REV C" | Bottom silk now reads NIVA REV C.2 | render |
| **A1** ESP32-C3-MINI-1-N4 is NRND | U1 is ESP32-C3-MINI-1-N4X (same footprint, chip v1.1); costed BOM noted, N4X price to re-quote | ERC, BOM export |
| **A14** MCP3208 bypass 100 nF | C4 = 1 µF (DS21298E §6.4) | BOM export |
| **C6** no polarity marks on the cartridge strip; lead order written two ways | Silk + T - beside J1 and - - + + beside J2; footprint text corrected to pad 1 +, pad 2 NTC, pad 3 - | DRC, render |
| **D1** pod could not be mounted; nothing stopped it sliding toward the foot | Grooves now open at the cable end and closed at y 58.2, so the pod slides down onto the cradle as documented; the key slot opens at the cable end and the cradle post moves to y 12-16; a slot in the cradle for the cartridge screw head | FreeCAD audit (§5) |
| **D11** 65° latch lead-in jams | 28° lead-in ramp | CAD |
| **D2 / C15** strip PCB not located or held down | End stops in the cup locate it to 0.15 mm in y; two Ø1.6 posts on the lid hold it 0.05 mm above its top face; epoxy in the assembly steps | FreeCAD audit (§5) |
| **D4** cartridge held in z at one end only | Two 0.3 mm bumps on the cradle under the cartridge far end limit outward travel to 0.1 mm when worn | FreeCAD audit (§5) |
| **D5** 0.6 mm wall around the cartridge screw pilot | Screw moved 0.5 mm (wall 1.1 mm), tab 0.8 mm longer, dock tab slot 0.8 mm longer | FreeCAD audit (§5) |
| **D9** dock USB-C opening only fits slim plugs | Opening 13 × 9 mm | dock audit (§5) |
| **C1 / C12 / C9 / C11 / C17 / C18 / C3** dock | Bourns SMAJ5.0A TVS on VBUS after F1. C1/C2 = 10 µF 16 V X5R 0805. NTC divider R6/R7/R8 = 46.4k/31.6k/19.6k 1 %: window 3.7-41.2 °C nominal, 2.2-43.0 °C worst case for a 10k B3435 NTC (was -1.9 to 47.1). MPNs added for J1 (GCT USB4125-GF-A-0190, 1.9 mm stakes for the 1.6 mm board) and F1 (Bourns MF-NSMF050/24X-2). STATUS corrected: four plated USB-C slots, not two, and a list of the wrong-NTC values a room-temperature test does not reveal | ERC 0 errors; DRC 0 errors, 0 unconnected, 0 parity issues; window re-derived independently (same 3.7 / 41.2 °C); dock audit (§5) |
| **C10** hysteresis | **Not fitted, on purpose.** The proposed 4.7 MΩ moves the hot edge the wrong way, because VTH_LO shares the divider, so TEMP_OK would oscillate near 41 °C. A correct version needs a separate VTH_LO divider; the C.3 charger makes it moot | analysis in the dock STATUS |
| **E2 / E3 / E4 / E5 / E8 / E9 / E18** apps | Pressure is one linear ADC-count mapping in both engines. Removed: the fake patient PDF, random-walk pressures, fixed battery and storage tiles, the "Ischemic > 50 mmHg" alert and the unwired threshold sliders (mock pages now show "No device data yet"). Packets are stamped on receipt and show Stale or Disconnected after 2 s; old packets are no longer replayed. Steps = 2 × heel strikes. Tare rejects a loaded foot, and a second tap no longer opens a second socket. Notice: "Uncalibrated sensor readings. Not a medical device." | Dart and TS harnesses (100 / 101 counts give 2.442 / 2.466 %, identical in both); 9 Flutter engine tests pass; `flutter analyze` and `tsc` show no new issues; web UI run in a browser against a fake device (goes Stale after 2 s, nothing replayed). Flutter UI not run on a device |

## 4. Still open: what has to happen before production

### Rev C.3 board changes (need copper, decided to wait for bench data)
- **A7 / C7 power path.** The 3.3 V rail falls below the ESP32-C3's 3.0 V during radio bursts once the cell is under about 3.3-3.8 V, depending on the polyfuse resistance. Measure first (bench P1). Then, in order of effort:
  1. MF-PSMF050X-2;
  2. shorter and wider VBAT copper;
  3. a buck-boost regulator.
- **A9 standby load.** About 320-540 µA flows all the time through the analog front end and insole excitation. Add a PMOS switch on the analog supply, driven by GPIO8 (its pull-up keeps it off at reset).
- **A22 / A23 / A24 ESD.** The J3 service pads are reachable through the bay window, and the insole connector J1 and the button have no protection. Add 22-33 Ω on USB D+/D-, a low-capacitance TVS array on J3 and J1, and an RC on the button.
- **A2.** 100 kΩ pull-ups on CS_ADC and CS_IMU.
- **B11.** A Kelvin trace from J2 to the MAX17048 CELL pin.
- **B9 / B10.** Move C6, C9 and U4's bypass closer to their pins; widen +3V3 to at least 0.635 mm (Espressif).
- **B1 rest.** 21 open vias remain in U1 GND pads and EPAD sub-pads. Order with plugged vias, or fill and cap them, before any PCBA.
- **B3.** For PCBA, J2 needs four single-pin placements and a second reflow. Hand-solder J2 for first articles.
- **C2 dock charger.** The MCP73831 has no safety timer, and the cell maker asks for one. Use a charger with a timer and input over-voltage cut-off, such as TI BQ25170 class.

### Mechanics still open
- **D6 sealing.** The bay ceiling windows open the PCB to the bay, which is open to the leg. The sealing concept therefore fails its own splash and sweat tests. It needs a sealed contact feedthrough, or a gasket around each pin pair, in C.3.
- **D7 dock latch.** The 1.0 mm arm bends across print layers. Reorient it or make it a separate spring part.
- **D8.** Dock pin capture: the PCB clamp has play, and the plunger can ride the window edge.
- **D10 printing.** About 18 features are under PCBWay's 1.5 mm FDM minimum wall. The order sheet now asks for 0.1 mm layers and a DFM check.
- **D12 / D13 / D14 safety.**
  - Pressure on a neuropathic shin has not been assessed, and the flat pad makes a line contact on the tibial crest.
  - The cell has no vent path, so it would vent toward the leg.
  - There is no ISO 10993 data, and printed parts cannot be reliably disinfected.
  - These need a clinician and materials work, not CAD.
- **D18-D24, D26-D28.** Minor items, listed in the D file.

### Insole flex (not ordered)
- **D15.** Every lane turns exactly on the heel-tab fold line.
- **D16.** The comb electrodes are exposed with no finish, under DC bias in sweat.
- **D17.** The flex rules and stack-up are not defined.
- Ten decisions are needed before a flex order: FSR ink film, PVDF film and bond, coverlay, stiffener, RA copper and others. They are listed at the end of `D-mechanical-insole.md`.

### Battery evidence
- **C8.** The only cell spec in hand is the 2017 v0.0 no-NTC variant. Before any live cell is worn, get from EEMB:
  - the spec for the NTC variant;
  - the PCM over-current threshold;
  - the IEC 62133-2 report and UN 38.3 summary.
- **C5.** A tripped F1 runs at about 0.5 W, 1 mm from the pouch. Bench-test it with a thermocouple on the cell.
- **C19.** The verification-plan F4 acceptance band is looser than the cell spec.

### Firmware and software
- **E1 (BLOCKER, partly done 12 Nov 2026).** Rev C.2 firmware now exists: Protected Steps ported to the pod, in [`niva arduino/niva_protected_steps/`](../../niva%20arduino/niva_protected_steps/README.md). It compiles and its host tests pass. It has not run on a board.
  - **Done:**
    - MCP3208 over SPI;
    - LSM6DSO32, with `I2C_disable` sent first (A17, E17);
    - the MAX17048 with VRESET at 2.68 V (A12);
    - the CH6 tail-fault check with the A15 window, plus the CH7 insert ID;
    - CS lines held high in sleep (A2);
    - USB-CDC only, since UART0 drives the LEDs;
    - the ESP-NOW and BLE roles;
    - a low-battery deep sleep (A7, C7).
  - **Still open:**
    - OTA with rollback, which needs a custom partition table;
    - factory provisioning through the TC2030 jig;
    - BLE pairing (E6);
    - bring-up on a built pod.
- **E6 (BLOCKER).** The current Wi-Fi sketch has no authentication on the health stream or the re-tare command, and its setup portal accepts firmware uploads. The C.2 firmware must not copy this.
- **E7 (BLOCKER).** No IEC 62304 / ISO 14971 process exists. Write the intended use first. A wellness claim and a medical claim lead to very different work.
- **E10-E16, E19-E29.** IMU timing and ranges, data contract and timestamps, BLE permissions, health data unencrypted at rest and in transit, the relay as an open proxy, and the hardcoded credentials in a public repo (E23). Details are in the E file.

## 5. Re-run results after the fixes

| Check | Result |
|---|---|
| Pod C.2 (KiCad 10.0.7, stock libs, parity) | DRC 0 errors, 0 unconnected; 3 warnings (2 silk at the antenna notch, LGA-14 library copy); ERC 0 errors, 1 reviewed warning |
| Cartridge | DRC 0 errors, 0 unconnected; ERC 0 errors, 0 warnings |
| Dock | DRC 0 errors, 0 unconnected, 0 parity issues, 1 warning (USB-C library copy); ERC 0 errors, 1 warning (same) |
| Pod enclosure audit (`mechanical/interference-report.json`) | One intersection: J2 plungers on the lid plates, 1.27 mm³, the intended preload. Cradle to cartridge 0.1 mm (bumps); lid posts to strip PCB 0.05 mm; cradle to housing 0.2 mm |
| Slide check, pod onto 05 cradle, 13 ankle cradle and 14 collar clip (`verification-2026-11-09/scripts/slide_check.py`) | 0 mm³ overlap from 65 mm above to seated for the rigid cradle; stops 0.25 mm further down (groove ends) and 0.5 mm back up (latch). The hook overlaps the pod while passing, so the arm must flex: the intended snap |
| Mounts audit (`NIVA-RevC2-protected-steps/mechanical/mounts-validation.json`), now against the C.2 board | One intersection: the collar-clip tongue preload (intended). All 7 parts single solids with closed meshes |
| Dock audit (`mechanical/dock-interference-report.json`) | One intersection: dock pins on the cartridge pads (intended). Compression 0.50 mm seated, 0.40 mm on the latch hook; components to dock top 0.53 mm; dock 20.4 mm tall |
| Unchanged printed parts | Regenerated, volumes equal to the committed files, then restored from git so the diff shows only real changes (01, 03, 04, 05, 10, 11, 12 changed) |

## 6. Bench checks for the first articles

These can only be settled on built units. The verification plan's IDs are in brackets.
- VBAT sag at the pod during TX bursts at 3.4-4.2 V cell (P1). The 3.3 V rail overshoot at the end of a burst, against the 3.6 V maximum (A8).
- Deep-sleep current, ankle-hub and shoe-node builds (A9).
- J2 contact resistance and force across the cartridge's play, on the cradle and off it (D3, D4). The plunger landing on the plate on a printed lid.
- Dock: charge termination at 4.20 V, NTC trip points with the purchased cell, the hysteresis, and TVS clamping on a USB hot-plug (F4, C1, C9, C10).
- Polyfuse surface temperature when tripped, on the pouch (C5).
- ESD on J3, J1, the button and the cartridge contacts (A22, A23).
- Antenna range and throughput in the closed pod, on the body, in both roles.
- Drop, sweat soak with bias, strap pressure on volunteers with a clinician (S-series, D12, A25).
