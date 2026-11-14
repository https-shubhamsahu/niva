# Review A: NIVA pod Rev C.2 schematic and components vs manufacturer datasheets

Reviewer scope: pod Rev C.2 schematic (`hardware/outputs/NIVA-RevC2-protected-steps/electronics-C2-working/`), every part on it, checked against primary datasheets. Layout, cartridge/dock/battery, mechanics and firmware are other reviewers' areas; where a finding depends on them it says so.
Read-only: no repo file was changed. Nothing here was built or measured; items that need hardware are marked **BENCH**.

## 0. Method and ground truth

- **Netlist (ground truth):** `kicad-cli sch export netlist --format kicadsexpr` (KiCad 10.0.7, stock library tables) on `NIVA-pod.kicad_sch`, parsed to a component and net list. 65 symbols (62 BOM parts plus J3, H1, H2 with `bom=False`), 59 nets: 40 connected nets and 19 declared no-connects; no other single-node nets.
- **ERC (re-run):** `kicad-cli sch erc --severity-all`: 0 errors, 1 warning (`pin_to_pin`, U3 SDx tied to GND/PWR_FLAG). Matches `ELECTRICAL-REVIEW.md` §2.
- **Pad check:** `pcbnew` dump of U1, U2, U3, U4, U5, U6, D2, J1, J2, J3, SW1 pads with nets in `NIVA-pod.kicad_pcb`, to confirm symbol pin numbers land on the intended pads (numbering/orientation only; land dimensions are the layout reviewer's).
- **Datasheets actually read** (PDF text extracted with `pdftotext` from the fetched manufacturer file):

| Part | Document | URL |
|---|---|---|
| ESP32-C3-MINI-1 | ESP32-C3-MINI-1 & MINI-1U Datasheet **v2.2** | https://documentation.espressif.com/esp32-c3-mini-1_datasheet_en.pdf |
| ESP32-C3 (chip) | ESP32-C3 Series Datasheet **v2.4** | https://documentation.espressif.com/esp32-c3_datasheet_en.pdf |
| ESP32-C3 design rules | ESP Hardware Design Guidelines, ESP32-C3 schematic checklist (latest, read 9 Nov 2026) | https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32c3/schematic-checklist.html |
| TLV75533 | TI TLV755P **SBVS320D** (Sep 2024) | https://www.ti.com/lit/ds/symlink/tlv755p.pdf |
| MCP3208 | Microchip **DS21298E** | https://ww1.microchip.com/downloads/en/DeviceDoc/21298e.pdf |
| MCP6001 | Microchip **DS20001733L** | https://ww1.microchip.com/downloads/en/DeviceDoc/MCP6001-1R-1U-2-4-1-MHz-Low-Power-Op-Amp-DS20001733L.pdf |
| MAX17048 | Maxim/ADI **19-6171 Rev 7 (11/16)** (analog.com timed out 4×; same document via SparkFun's CDN copy) | https://www.analog.com/media/en/technical-documentation/data-sheets/MAX17048-MAX17049.pdf (copy read: https://cdn.sparkfun.com/assets/b/b/2/c/b/MAX17048.pdf) |
| BAV199 | Nexperia product data sheet, 1 Sep 2020 (assets.nexperia.com returned 403; same Nexperia PDF via mirror) | https://assets.nexperia.com/documents/data-sheet/BAV199.pdf (copy read: https://cdn.components.ru/media/PDF/1264335.pdf) |
| LSM6DSO32 | **Not reachable** (st.com timed out 4×). Pin table checked against ST **AN5192 Rev 5** (LSM6DSO, the pin-compatible ±16 g family member), Table 1 | https://www.st.com/resource/en/datasheet/lsm6dso32.pdf (AN5192 read via https://cdn.sparkfun.com/assets/c/b/2/e/f/dm00517282-lsm6dso-alwayson-3d-accelerometer-and-3d-gyroscope-stmicroelectronics.pdf) |
| JST GH | JST GH connector catalogue (eGH) | https://www.jst-mfg.com/product/pdf/eng/eGH.pdf |
| KMR2 | **Not reachable** (ckswitches.com → littelfuse.com 403, Mouser timed out). Figures from distributor listings only | https://www.ckswitches.com/media/1479/kmr2.pdf |
| ADI 21-0168 / 90-0065 | **Not reachable** (analog.com timed out) | https://www.analog.com/media/en/package-pcb-resources/package/21-0168.pdf |

Severity: BLOCKER (will not work / unsafe), MAJOR (likely field failure, out of spec, or blocks production), MINOR, NOTE. "Copper" = needs a PCB change; "BOM" = can be applied to the C.2 boards being hand-built; "FW" = firmware or production-programming step.

**No BLOCKER found.** Every IC pin, strap and rail on the netlist matches its datasheet; the C.2 bare boards ordered for bench bring-up should power up and program. The MAJOR findings are about production: brown-out margin, standby current, an NRND module, and unprotected service pads that users can reach.

---

## 1. U1 ESP32-C3-MINI-1-N4: pins, straps, reset, programming

### A1 MAJOR: the specified module is NRND
- **Evidence:** schematic/BOM `U1 = ESP32-C3-MINI-1-N4` (`MPN` field; `bom/NIVA-pod-BOM-costed.csv`). Espressif datasheet v2.2, Table 1-1 (p. 3) lists **"ESP32-C3-MINI-1-N4 (NRND)"**, chip revision v0.4; the current part is **ESP32-C3-MINI-1-N4X** (chip v1.1, same 4 MB flash, same package and pinout per Table 3-1). The BOM README already notes DigiKey shows "Not For New Designs".
- **Verified:** read (datasheet ordering table).
- **Fix (BOM):** specify ESP32-C3-MINI-1-N4X. Footprint and pin map unchanged. Firmware must use an ESP-IDF / Arduino-ESP32 version that supports chip v1.1 (datasheet note 6 points to the "Compatibility Advisory for ESP32-C3 Chip Revision v1.1"); FW reviewer to pin the version.

### A2 MINOR: CS_ADC (GPIO7) and CS_IMU (GPIO10) have no pull-ups
- **Evidence:** nets `/Controller/CS_ADC` (U1.21 to U2.10 only) and `/Controller/CS_IMU` (U1.16 to U3.12 only). ESP32-C3 datasheet v2.4 Table 2-1 (p. 16): MTDO (GPIO7) and GPIO10 reset to input with no pull. MCP3208 DS21298E p. 3: standby current 0.5 µA is specified with **CS = VDD**; a floating CS can leave it out of shutdown. LSM6DSO AN5192 Table 1: CS has an internal pull-up that is **disabled when I2C_disable = 1**, which A17 asks firmware to set.
- **Consequence:** during reset, boot, and deep sleep (ESP-IDF isolates non-held digital pads), both chip selects float. MCP3208 standby current becomes undefined (up to its 225 µA active figure plus shoot-through); the IMU can see spurious selects.
- **Verified:** read + reasoning; current impact **BENCH**.
- **Fix:** Copper: 100 kΩ from each CS net to +3V3 (no static current while deselected). C.2 workaround (FW): `gpio_hold_en()` on GPIO7/GPIO10 (driven high) plus `gpio_deep_sleep_hold_en()` before deep sleep.

### A3 NOTE: green LED on U0TXD is lit through boot and flickers with logs
- **Evidence:** `/Controller/LED_G` = U1.31 (GPIO21/U0TXD) → R46 680 Ω → D5. Datasheet v2.4 Table 2-1: U0TXD after reset is an **output with pull-up** (UART idles high), so D5 is on (~1.9 mA) for the whole ROM + bootloader time and blinks with every UART0 log line. ELECTRICAL-REVIEW §3 calls it a flicker only.
- **Fix (FW/production):** burn `EFUSE_UART_PRINT_CONTROL` = 1 (disables ROM UART0 printing while GPIO8 = 1, which R2 guarantees) or 3 (always disabled), MINI-1 datasheet Table 4-4 (p. 14); set the bootloader log level to none and the console to USB-Serial-JTAG (`CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG`, Arduino "USB CDC On Boot"). The 680 Ω also satisfies Espressif's "series resistor on U0TXD" advice. GPIO20 (LED_R) has a 45 kΩ pull-up at reset (Table 2-1), so D4 gets about 37 µA during boot, which is not visible.

### A4 NOTE: no UART0 recovery path
- **Evidence:** J3 carries only USB D+/D-, EN, GPIO9, +3V3, GND. UART0 (GPIO20/21) goes only to the LEDs. If USB-Serial-JTAG is ever disabled by eFuse (`EFUSE_DIS_USB_SERIAL_JTAG`, Table 4-5) or GPIO18/19 are damaged (see A22), the board cannot be reflashed.
- **Fix (copper, cheap):** two 1 mm test pads on the LED_R/LED_G nets (U0RXD/U0TXD side of R45/R46) on the underside next to J3.

### A5 NOTE: EN RC is correct; no supervisor
- **Computed:** R1 10 kΩ, C1 1 µF; EN reaches VIH_nRST = 0.75 × VDD (MINI-1 datasheet Table 6-3) after τ·ln 4 = **13.9 ms**, well above tSTBL = 50 µs (Table 4-6). Values match the datasheet §9 recommendation (10 kΩ / 1 µF). The Espressif checklist ("Chip Power-up and Reset Timing") recommends a ~3.0 V supervisor when the supply can sag or bounce; here the on-chip brownout detector is the only guard. Acceptable if the A7 firmware cut-off exists; otherwise add an open-drain supervisor (2.9-3.0 V) on CHIP_EN.

### A6 NOTE: 4 MB flash and OTA
- **Evidence:** PINMAP §3 says the classic-ESP32 prototype already needed the "Huge APP" (no-OTA) scheme for BLE + Wi-Fi. With 4 MB and two OTA slots each app is about 1.9 MB. If OTA is wanted and the image is > 1.9 MB, the only MINI-1 8 MB variant is H8X (105 °C). FW reviewer to size.

**Checked and correct on U1:** every module pin in Table 3-1 (p. 11) matches the symbol and the net (pins 1, 2, 11, 14, 36-53 GND; 3 = 3V3; 4, 7, 9, 10, 15, 17, 24, 25, 28, 29, 32-35 NC; IO2 = 5, IO3 = 6, EN = 8, IO0 = 12, IO1 = 13, IO10 = 16, IO4-IO9 = 18-23, IO18 = 26, IO19 = 27, RXD0 = 30, TXD0 = 31); footprint pad numbers carry the same nets (pcbnew dump), EPAD (pad 49, 9 squares) and corner pads 50-53 to GND. Strapping (Table 4-3, p. 13): GPIO2 = 1 via R4 4.7 kΩ (MAX17048 SCL only adds a 0.2 µA pull-down, MAX17048 p. 2 IPD), GPIO8 = 1 via R2, GPIO9 = 1 via R3 with J3.5 to pull low → SPI boot by default, Joint Download Boot (USB-Serial-JTAG or UART) with J3.5 low at reset; no capacitor on GPIO9 (checklist warning respected). Flash pins GPIO11-17 are internal to the module and not exposed. Power-up glitches (chip datasheet Table 2-2, p. 18): 5 ns low on GPIO6 (MOSI), GPIO7 (CS_ADC), GPIO10 (CS_IMU), GPIO20 (LED_R); 50 µs high on GPIO18 (USB D-): all harmless here. Deep-sleep wake sources: BUTTON (GPIO3) and IMU_INT1 (GPIO1) are both in the VDD3P3_RTC domain (Table 2-1), so both can wake from deep sleep. Decoupling: C2 22 µF 0805 + C3 100 nF on pin 3 vs datasheet Fig. 9-1 10 µF + 0.1 µF; C2 at 3.3 V bias still gives ≈ 9-11 µF. Supply capability: TLV755P 500 mA rated, current limit 560 mA min (SBVS320D §5.5) vs Espressif's "≥ 0.5 A" (Table 6-2).

---

## 2. Power: J2, U5 TLV75533, rails, standby

### A7 MAJOR: brown-out during radio TX leaves a large part of the cell unusable
- **Evidence:** Load: Wi-Fi TX 802.11b @ 20.5 dBm **350 mA** peak, BLE @ 20 dBm 340 mA, BLE @ 0 dBm 170 mA (MINI-1 Table 6-4/6-5, p. 22); ESP-NOW uses the Wi-Fi PHY. Supply minimum **3.0 V** (Table 6-2). LDO dropout, DBV, 3.3 V, 500 mA: 150 mV typ, **215 mV max (-40..85 °C)**, 238 mV max to 125 °C (SBVS320D §5.5, p. 6); the PMOS behaves as a resistor in dropout (§7.1.2), so 0.30 Ω typ / 0.43 Ω max. Path from the cell: cell IR (assumed 0.15-0.40 Ω for a 230 mAh pouch, **BENCH**), PCM 70 mΩ, cartridge polyfuse 0.25-1.2 Ω (brief), J2 2 × Mill-Max 0900 per rail at 20 mΩ max each (STATUS-CLOSURE §1).
- **Computed** (355 mA = radio + ~5 mA board):

| Path R (cell + PCM + fuse + contacts) | Cell OCV needed to keep 3V3 ≥ 3.0 V, LDO typ / max |
|---|---|
| 0.49 Ω (0.15 + 0.07 + 0.25 + 0.02) | 3.28 V / 3.33 V |
| 0.85 Ω (0.25 + 0.07 + 0.50 + 0.03) | 3.41 V / 3.45 V |
| 1.71 Ω (0.40 + 0.07 + 1.20 + 0.04) | **3.71 V / 3.76 V** |

  On a typical LiCoO2 OCV curve, 3.71-3.76 V is roughly 30-40 % state of charge, so in the worst case about a third of the cell is stranded or the pod reboots on every ESP-NOW frame (shoe node transmits per contact, ankle hub scans Wi-Fi every 300 s). Bulk capacitance cannot fix this: holding 0.1 V for a 1 ms, 350 mA frame needs C = I·t/ΔV = 3.5 mF.
- ELECTRICAL-REVIEW §5 treats this as a bench calibration (P1). I disagree that calibration alone is enough: with the stated polyfuse range the cut-off itself may have to sit near 3.7 V.
- **Fix:** (1) cartridge reviewer: bring the series fuse resistance down (a lower-R PTC, or rely on the PCM's over-current protection) and measure the total path R (**BENCH**); (2) FW: cap TX power (`esp_wifi_set_max_tx_power`, BLE ≤ 0 dBm where the link allows) and stop radio use below a gauge voltage set from the measured sag; (3) production revision: replace U5 with a 3.3 V buck-boost rated ≥ 1 A (e.g. TI TPS63802 class), which regulates down to ~2.3 V input and also cuts battery current at high VBAT. Option 3 is a copper change.

### A8 MINOR: LDO overshoot when leaving dropout (BENCH)
- **Evidence:** SBVS320D §6.4.2 (p. 14): in steady dropout the pass device is driven fully on, and "VOUT overshoots VOUT(NOM) during fast transients" on recovery. At the end of a TX burst VBAT jumps back by I × R_path (up to 0.6 V, A7), while U5 is in dropout. ESP32-C3 absolute maximum is **3.6 V** (MINI-1 Table 6-1). EN is tied to VBAT, so TI's advice to use EN to avoid start-up overshoot (§7.1.3) cannot be applied.
- **Fix:** **BENCH:** scope +3V3 at the end of 350 mA bursts with VBAT at 3.4-3.8 V. If it exceeds 3.6 V, the A7 regulator change removes the problem.

### A9 MAJOR: always-on analog load dominates standby and keeps DC on the insole 24/7
- **Evidence:** U5 EN = VBAT (always on); VEXC = +3V3 through R33 220 Ω with no switch; R31/R32 (10k/10k) from +3V3; MCP6001 on +3V3. Currents (datasheet typicals): R31/R32 **165 µA**; R40/R41 16.5 µA; MCP6001 IQ **100 µA typ / 170 µA max** (DS20001733L p. 3, at 5.5 V); INSERT_ID R30 + R_ID: **224 µA** with the right-medium 4.7 kΩ, 58 µA with 47 kΩ; TLV755P IGND 25 µA typ (§5.5); MAX17048 hibernate 4 µA with the reset comparator enabled (p. 2); LSM6DSO32 power-down 3 µA; MCP3208 0.5 µA (only with CS high, see A2); ESP32-C3 deep sleep 5 µA (Table 6-7). Each loaded FSR adds up to 0.3 mA continuously while the shoe is worn (1.5 mA for five at 1 kΩ).
- **Computed floor (no foot load):** ankle hub (no tail) **319 µA**; shoe node with right-medium insert **544 µA**, left-medium 377 µA. That is 64-109 × the ESP32's own deep-sleep figure. 230 mAh lasts 30 days (ankle) / 18 days (shoe) parked with the cartridge in; over the RQ2 72 h wear the floor alone uses 23 / 39 mAh (10-17 % of the cell), before radio and FSR load. The ROLE-DESIGN-NOTE per-part figures agree with these; the total was not added up there.
- **Second consequence:** VEXC (up to 3.26 V, 220 Ω source) sits on the insole combs continuously, including when the shoe is off. See A25.
- **Fix:**
  - BOM (C.2 boards now): R31/R32 → 100 kΩ/100 kΩ (16.5 µA; ADC leakage ±1 µA max × 50 kΩ = 50 mV worst case, fine for a fault flag; C16 can stay 100 nF, τ = 5 ms). MCP6001 → a ≤ 5 µA unity-gain-stable RRIO CMOS op-amp in the same SOT-23-5 pinout (candidates: MCP6041T-I/OT, OPA379AIDBVR; confirm pinout, input bias and slew against the 339 Hz band). Floor drops to ≈ 72 µA (ankle).
  - Copper (production): switch the analog supply with a PMOS (e.g. DMG2305UX) whose gate is **GPIO8**, the spare strap pin. R2 already pulls GPIO8 high at reset, in download mode and when IDF isolates the pad in deep sleep, so the switch is **off** in every boot/sleep state and on only when firmware drives GPIO8 low; no strap conflict. Put R33/VEXC, R31, R40 and the MCP6001 supply (with D2's K2 clamp) behind it. Settling after switch-on: FSR RC 5τ = 17 ms, VMID 5τ = 250 ms, PVDF bias 14 ms, so use it for sleep/idle, not per-sample duty cycling.

### A10 MINOR: no reverse-polarity protection on J2
- **Evidence:** J2.1/2 = VBAT, J2.3/4 = GND straight to U5 IN, U6 VDD/CELL, C6, C9. TLV755P VIN min -0.3 V (§5.1), MAX17048 "all other pins" -0.3 V (p. 2). A reversed cartridge (180° rotation puts VBAT on pads 3/4) destroys U5/U6, limited only by the cartridge PCM/fuse. ELECTRICAL-REVIEW §5 relies on the asymmetric tab.
- **Fix:** mechanics reviewer to confirm the key cannot be defeated. Electrical option (copper): PMOS reverse-protection (e.g. DMG2305UX, ~50 mΩ at VGS = -3 V → 18 mV at 355 mA), which costs a little of the A7 margin.

### A11 MINOR: J3 pin 1 is +3V3, and a jig that sources it back-feeds the LDO
- **Evidence:** J3.1 = +3V3 directly. TLV755P abs max VOUT ≤ VIN + 0.3 V and §7.1.4 (p. 17): reverse current through the body diode when "the output is biased when the input supply is not established". The schematic text says "J3 pin 1 is sense-only for the jig. The jig must NOT back-feed", but nothing enforces it, and Tag-Connect programming adapters commonly supply 3.3 V.
- **Fix (copper):** 1 kΩ in series between +3V3 and J3.1 so it is physically sense-only; write the production fixture spec so the board is powered through J2 (3.7-4.2 V on the spring pins, both on the underside next to J3).

**Checked and correct on power:** U5 pinout DBV (IN 1, GND 2, EN 3, NC 4, OUT 5) = symbol = pads; EN = VBAT is allowed ("If shutdown capability is not required, connect EN to IN", §6.3.2); VIN 3.0-4.28 V within 1.45-5.5 V; input cap C6 4.7 µF (BOM part is 16 V X5R, ≈ 2.8 µF effective at 4.2 V) + C9 100 nF ≥ 1 µF; output C7 10 µF 0603 + C2 22 µF 0805 + 4 × 100 nF, ≈ 13-15 µF effective, inside 0.47 µF min / 200 µF max effective (Table 4-1 note, §5.3, §7.1.1), ceramic X5R/X7R as TI asks; peak dissipation (4.28 - 3.3) × 0.355 = 0.35 W for the duration of a burst only; worst-case board current ≈ 357 mA < 500 mA rating. Hot-plug of the cartridge into C6: with ~50 nH lead inductance, Z0 = √(L/C) = 0.13 Ω, and the path R ≥ 0.35 Ω gives ζ ≥ 1.3, so no ringing overshoot. J2 Mill-Max 0900: 6.4 A derated vs 0.36 A.

---

## 3. U6 MAX17048 fuel gauge

### A12 MINOR: gauge sees the cell through PCM + fuse + contacts; VRESET default can fire under TX sag
- **Evidence:** MAX17048 p. 6 pin table: for MAX17048, **VDD is the voltage-sense input** ("Connect to positive battery terminal"); CELL is not internally connected. Here VDD is on the pod side of PCM + polyfuse + J2 (A7 path, up to ~1.3 Ω excluding the cell), so at 355 mA the sensed voltage can read up to ~0.46 V low. p. 13: VRESET defaults to 3.0 V with a fast comparator; "For removable batteries, set to at least 300mV below the application's empty voltage"; on reset the IC quick-starts, and p. 8 says a quick-start on an unrelaxed cell gives an initial SOC error. A TX sag at low charge can cross 3.0 V at VDD and trigger a spurious quick-start under load. The gauge also resets on every cartridge swap and estimates SOC from the max of 16 samples in the first 17 ms (p. 8); the ESP32 is still in reset then (A5: 13.9 ms + boot), so that first estimate is clean, but a cartridge fresh off the dock is not relaxed (error heals over time, p. 8 Fig. 5).
- **Fix (FW):** write VRESET ≤ 2.7 V (or set `Dis` and rely on POR at swap, which also saves 0.5 µA); take the voltage reading for any cut-off decision when the radio is idle; ask ADI for a custom ModelGauge model for the purchased LP502030 lot. ALRT stays unused (allowed, Table 3, p. 15).

### A13 NOTE: land pattern T822-3 vs T822-3C, still open (agree with STATUS-CLOSURE §2)
- **Evidence:** datasheet p. 18 confirms 8 TDFN-EP, package code **T822+3**, outline **21-0168**, land pattern **90-0065**, and that "+/#/-" suffixes are RoHS-only; it says nothing about a "C" suffix. 21-0168 and 90-0065 could not be opened (analog.com timed out), so I could not settle it. The C.2 footprint (pcbnew dump): pins 1-4 on the left top to bottom, 5-8 on the right bottom to top (counter-clockwise, pin 1 at (-0.99, -0.75)), pads 0.70 × 0.30 at ±0.99 mm, EP 0.80 × 1.38 mm, 4 paste windows 0.32 × 0.48 mm (56 % of the EP land). Nets per pad are correct.
- **Fix:** download 21-0168 and 90-0065 on a network that reaches analog.com before ordering a stencil.

**Checked and correct on U6:** CTG pin 1 → GND ("Connect to Ground"); CELL pin 2 → VBAT ("Connect to the Positive Battery Terminal"); VDD pin 3 → VBAT with C9 0.1 µF ("Bypass with 0.1µF"); GND pin 4, EP → GND; ALRT pin 5 NC (allowed); QSTRT pin 6 → GND ("Connect to GND if not used"); SCL/SDA pins 7/8 with external pull-ups (they have internal pull-downs, p. 6). VDD 3.0-4.28 V within 2.5-4.5 V; data pins abs max 6 V, VIH 1.4 V, so 3.3 V pull-ups are fine. Address **0x36** (7-bit; 0x6C/0x6D, p. 16): no conflict, it is the only I2C device. Bus-low shutdown after 2.5 s (p. 3 note 6) cannot occur because the pull-ups sit on the always-on +3V3.

---

## 4. U2 MCP3208, VEXC/VREF, force, ID and CH6 channels

### A14 MINOR: MCP3208 VDD bypass is 100 nF; datasheet asks for 1 µF
- **Evidence:** C4 100 nF on U2.16 (generator text "C4 at VDD pin 16"). DS21298E §6.4 (p. 23): "A bypass capacitor value of 1 µF is recommended."
- **Fix (BOM):** C4 → 1 µF X7R 0603 (e.g. the C11-C15 part), or add 1 µF next to it.

### A15 NOTE: CH6 "normal" window is wider than documented
- **Computed:** full analog load (5 saturated FSRs to 10 kΩ, ID 4.7 kΩ, R40/R41, IREF 150 µA): R_load = 1745 Ω, VEXC = 3.3 × 1745/1965 - 150 µA × 195 Ω = **2.90 V** (docs: 2.94 V, they omit the ID and IREF loads). CH6 = 4096 × 1.65/2.90 = **2329**, and up to **2353** with the 1 % R31/R32 ratio error. The reading is independent of the absolute +3V3 value. PINMAP gives 2048-2299 and ELECTRICAL-REVIEW §4 sets the fault threshold at "about 2400", leaving ~47 counts.
- **Fix (FW):** set the upper threshold from this calculation (e.g. 2450), or use 0.1 % parts for R31/R32. If A9 changes R31/R32 to 100 kΩ, add ±1 µA × 50 kΩ leakage to the window.

### A16 NOTE: SPI clock limits
- DS21298E p. 3: fCLK max 1.0 MHz at 2.7 V, 2.0 MHz at 5 V (≈ 1.2 MHz by interpolation at 3.3 V); below 10 kHz linearity degrades (note 3). LSM6DSO32 runs at up to 10 MHz on the same bus, so FW must set the clock per device (ESP-IDF `spi_bus_add_device` does). MCP3208 supports modes 0,0 and 1,1, LSM6DSO32 mode 3 (1,1); one mode for both works.

**Checked and correct on the acquisition chain:** U2 SOIC-16 pinout (CH0-7 = 1-8, DGND 9, CS 10, DIN 11, DOUT 12, CLK 13, AGND 14, VREF 15, VDD 16) = symbol = pads. VREF = VEXC 2.90-3.26 V within 0.25 V..VDD (p. 2) and always ≤ VDD because it is derived from +3V3 through R33. All channel inputs stay within VSS..VREF in normal use and within the -0.6 V..VDD + 0.6 V abs max (p. 2) everywhere: the piezo buffer can exceed VREF (it runs from +3V3), which only saturates the code. Power-down: the 1 µF caps behind 3.3 kΩ and C41 behind 1 kΩ limit back-current into pins to ≤ 1 mA; C19 at the VREF pin can push ~2.5 mA into the VREF ESD diode while +3V3 collapses faster than VEXC (τ 0.44 ms), which is far below latch-up levels. Ratiometric claim: FSR code = 4096 × 10k/(10k + R_FSR), independent of VEXC (the FSR top and VREF are the same node; J1 contact 30-50 mΩ × 1.65 mA = 82 µV, negligible; flex lane resistance adds ≈ 0.1 % at full load, absorbed by calibration). VREF source: datasheet's own application figure uses 1 µF on VREF; C19 1 µF at the pin plus C18 1 µF at R33; IREF 100-150 µA × 220 Ω = 22-33 mV static drop, ratiometric so it cancels for the FSR and ID channels. Source impedance: the 1 µF input reservoirs are 50,000 × the 20 pF sample capacitor (p. 3), so the 1.5-clock acquisition sees a stiff source. Filters re-derived: FSR 3.3 kΩ/1 µF = 48.2 Hz, ID same, CH6 5 kΩ/100 nF = 318 Hz. ID codes re-derived: 4.7 kΩ → 1310, 47 kΩ → 3377, open → 4095. R33 into a tail short: 3.3 V/220 Ω = 15 mA, 50 mW in a 100 mW 0603.

---

## 5. U3 LSM6DSO32 IMU on the shared SPI bus

### A17 MINOR: the IMU starts in I2C mode on the SPI wires
- **Evidence:** AN5192 Table 1 (p. 2-3): CS "1: SPI idle mode / I²C ... communication enabled", **default input with pull-up**; pins 13/14 are I2C SCL/SDA when CS is high. Here pin 13 = SPI_SCK and pin 14 = SPI_MOSI, shared with U2. While CS_IMU is high, MCP3208 traffic is seen by the IMU's I2C slave; a MOSI edge while SCK is high is an I2C START/STOP, and a matching 0x6A/0x6B address (SA0 = the MISO line) makes the IMU ACK by pulling MOSI low against the ESP32's driver.
- **Fix (FW):** first SPI transaction after every power-up or IMU reset is to the IMU: set CTRL4_C (13h) bit `I2C_disable` = 1 (and `I3C_disable` in CTRL9_XL), before any MCP3208 access. Note this also disables the CS pull-up (A2).

### A18 NOTE: INT1 must be low at power-on
- AN5192 Table 1 note 2: "INT1 must be set to '0' or left unconnected during power-on if the I²C/SPI interfaces are used." INT1 has an internal pull-down by default, and GPIO1 resets with no pull (ESP32-C3 Table 2-1), so the circuit is correct. FW must not enable a pull-up on GPIO1 (for example in deep-sleep wake setup); wake on high level, INT1 is push-pull active-high by default.

### A19 NOTE: LSM6DSO32 datasheet itself not read
- st.com timed out. The pin table was checked against AN5192 (LSM6DSO, same LGA-14 pinout). Re-read DS of the LSM6DSO32 for the decoupling figure and supply ranges before release. The ST reference circuit decoupling as quoted in the repo (100 nF on VDD and on VDDIO) matches C5 and C20.

**Checked and correct on U3:** pinout from AN5192 Table 1: 1 SDO/SA0 → MISO, 2 SDx → GND and 3 SCx → GND ("Connect to VDDIO or GND"), 4 INT1 → GPIO1, 5 VDDIO and 8 VDD → +3V3, 6/7 GND, 9 INT2 open ("can be left unconnected"; default output forced to ground), 10 OCS_Aux and 11 SDO_Aux open ("Connect to VDDIO or leave unconnected"; default pull-up), 12 CS → GPIO10, 13 SCL/SPC → SCK, 14 SDA/SDI → MOSI. ERC warning on SDx is the intended GND tie. Footprint pads 1-14 run counter-clockwise from top-left with the same nets (pcbnew dump). No exposed pad. In SPI mode, MISO is shared with the MCP3208 DOUT, which is high-Z when its CS is high (p. 3 tDIS).

---

## 6. U4 MCP6001 / D2 BAV199 PVDF heel front end

### A20 NOTE: input-stage crossover sits inside the signal swing
- DS20001733L §4.1.3 (p. 13): the two input stages hand over at VCM = VDD - 1.1 V = **2.2 V**. VMID = VEXC/2 = 1.45-1.63 V and heel strikes swing about ±1.5 V, so large positive strikes cross it with a small gain step. Acceptable for event detection; avoid if amplitudes are later used quantitatively.

### A21 NOTE: DC leakage budget on the 10 MΩ bias node
- JST GH insulation resistance is **100 MΩ min** (eGH spec table). J1.7 (PVDF_RAW) is next to J1.8 (GND): at that limit, the R42 + R43 bias divider shifts PZ_BIAS by ≈ VMID × 10/110 ≈ 0.14 V; sweat makes it worse. BAV199 IR max 5 nA at 75 V, 25 °C (Table 7) → ≤ 50 mV through 10 MΩ (the doc's 30 µV uses the 3 pA typical). MCP6001 IB 19 pA at 85 °C (p. 3) → 0.2 mV. The signal is AC-coupled (11 Hz), so offsets this size only move the midpoint. Optional: R43 → 4.7 MΩ (fc 24 Hz with 1.4 nF) halves the sensitivity to leakage.

**Checked and correct on the PVDF chain:** U4 SOT-23-5 "OT" pinout (VOUT 1, VSS 2, VIN+ 3, VIN- 4, VDD 5; the R/U variants differ) = netlist = pads. D2 BAV199 pinning (Nexperia Table 2): **1 = A1, 2 = K2, 3 = K1/A2**; schematic 1 → GND, 3 → PZ_BIAS, 2 → +3V3 is correct: diode 1 clamps PZ_BIAS below GND, diode 2 clamps above +3V3. Marking code "JY%" (Table 4) for incoming inspection. Clamp current: 70 V / 100 kΩ = 0.7 mA; BAV199 VF ≤ 900 mV at 1 mA keeps the op-amp input within VSS - 1.0 V / VDD + 1.0 V and below the ±2 mA input-current limit (p. 3); the op-amp stays clear of the 2 mA limit up to ~200 V of film output. Injected charge into +3V3 per strike (~26 nC for a 1.4 nF film at ~20 V) is negligible against ~15 µF. Stability: above fz = 1/(2π·1 kΩ·470 nF) = 339 Hz the 470 nF is a short at the 1 MHz GBW, so the op-amp sees 1 kΩ resistive (datasheet §4.3 R_ISO method; Fig. 4-4 only goes to 10 nF, where the needed R_ISO is far below 1 kΩ). Output current into 1 kΩ on a full step ≤ 1.65 mA vs 6 mA short-circuit at 1.8 V. Bypass: C42 100 nF local + C2/C7 bulk ≤ 100 mm away (§4.4). Corner frequencies re-derived: 11.4 Hz (10 MΩ, 1.4 nF), 339 Hz output pole.

---

## 7. Connectors, button, ESD

### A22 MAJOR: J3 service pads are user-reachable through the bay and have no ESD protection
- **Evidence:** `work/build_niva_cad_revC.py` line 57 cuts a **9.0 × 6.0 mm window** in the bay ceiling over J3, and line 56 a 12.4 × 4.4 mm window over J2; `niva_layout.py` line 56: "cartridge spring contacts and the service pads, both reached through the bay". The CAD comment (line 18) says the windows keep fingers off the board; a 6 mm wide opening does keep a fingertip off the copper, but an 8 kV air discharge jumps several mm, and a pen or key used to free a stuck cartridge reaches the pads. The cartridge comes out for every charge, so these openings are exposed every day. J3 nets: USB_DP/USB_DM (GPIO19/18), BOOT9 (GPIO9, 10 kΩ only), CHIP_EN (C1 1 µF), +3V3. Module ESD rating is **±2 kV HBM** (MINI-1 §12.2, p. 40); the Espressif checklist (USB section) asks for series resistors (22/33 Ω) and capacitors on D+/D- close to the chip; there are none. ELECTRICAL-REVIEW §3 and PINMAP accept "no ESD protection: jig-only access", which does not hold for a bay the user opens daily. VERIFICATION-PLAN has no ESD test at all.
- **Fix (copper):** a 4-channel low-capacitance TVS array at J3 on USB_DP, USB_DM, BOOT9, CHIP_EN (e.g. TI TPD4E05U06 class, < 1 pF, 5.5 V working); 22 Ω series resistors on D+/D- (Espressif); optionally a non-conductive plug or label over the J3 window. J2 is already well buffered (C6 + 32 µF downstream; a 150 pF/8 kV IEC pulse is 1.2 µC → ~0.25 V on ~5 µF), as is CHIP_EN (1 µF). **BENCH:** add IEC 61000-4-2 contact (±4 kV) and air (±8 kV) discharge to J2 pins and J3 pads with the cartridge removed, and to the closed pod, to VERIFICATION-PLAN.

### A23 MINOR: J1 insole tail has no TVS; the resistors take the full pulse
- **Evidence:** J1.1 VEXC goes straight to U2 VREF (C18/C19 only); J1.2-J1.6 meet R11-R15 (10 kΩ 0.1 % thin film, ERA-3A) to GND and R21-R25 (3.3 kΩ thick film) into 1 µF; J1.9 meets R30 (thin film) and R34. ELECTRICAL-REVIEW §4 checks only the charge into the 1 µF reservoirs (0.8 µC → 0.8 V); at the first nanoseconds the whole discharge voltage appears across R11-R15 and R21-R25 (the 1 µF is behind 3.3 kΩ), and thin-film precision resistors are the ESD-sensitive kind. The insole is under a foot in a shoe, a classic charge source.
- **Fix (copper):** low-leakage TVS array (≤ 100 nA, ≤ 5 pF; leakage × the ≤ 10 kΩ node impedance must stay < 1 LSB ≈ 0.7 mV) at J1 on VEXC, F1-F5_RAW and INSERT_ID_RAW; keep the BAV199 + 100 kΩ for PVDF. **BENCH:** IEC 61000-4-2 on the tail with the insole fitted; re-measure R11-R15 afterwards.

### A24 MINOR: button input has no series resistor, filter or clamp
- **Evidence:** `/Controller/BUTTON` = R6 10 kΩ pull-up, SW1 to GND, U1.6 (GPIO3) direct. The button sits under a TPU actuator in the front cover (`07_Button_TPU`), a likely air-discharge entry point; the module is rated ±2 kV HBM. KMR2 data could not be opened (A0 table); distributor listings give 2 N, 0.25 mm travel, 50 mA 32 VDC, which suits 0.33 mA.
- **Fix (copper):** 1 kΩ in series to GPIO3 plus 100 nF from the GPIO side to GND (also a 1 ms hardware debounce, and harmless for deep-sleep wake).

### A25 MINOR: continuous DC excitation on a sweat-exposed flex (BENCH)
- **Evidence:** VEXC is DC and never switched (A9). The insole exposes VEXC and Fn_RAW comb electrodes under one coverlay opening (ELECTRICAL-REVIEW §6, "Other boards"); VERIFICATION-PLAN S7 soaks the insole in 40 °C artificial sweat **without bias**. DC bias in an electrolyte drives copper migration and dendrites (FSR baseline drift, eventual shorts), and in a breached laminate it is a DC path toward skin; IEC 60601-1 patient leakage limits for DC are in the tens of µA, while VEXC can source 15 mA.
- **Fix:** run S7/S8 with 3.3 V applied through 220 Ω, as in the pod; adopt the A9 VEXC switch so bias is applied only while measuring; insole reviewer to confirm the insulation concept. Not a medical claim; this is for the risk file.

**Checked and correct on connectors:** J1 SM10B-GHS-TB: 1.0 A, 50 V, 30 mΩ initial contact resistance (eGH); pads 1-10 at 1.25 mm carry VEXC, F1-F5, PVDF, GND, ID, GND as documented; GND pins 8 and 10 flank the ID line, and the FSR returns do not pass through J1 (R11-R15 return to pod GND), so contact resistance does not enter the ratio. J2: 2 × VBAT (pads 1-2) and 2 × GND (pads 3-4), Ø2.08 mm pads per Mill-Max minimum; partial contact during insertion creates no path. J3 TC2030-NL: pads 1-6 at 1.27 mm with three alignment holes, on B.Cu (the jig sees it mirrored); pinout is project-specific (1 +3V3, 2 EN, 3 D+, 4 D-, 5 GPIO9, 6 GND), so the jig must be built to it. Production programming path: USB-Serial-JTAG download works by holding J3.5 low and pulsing J3.2 (MINI-1 Table 4-3 note 3), or by esptool's USB-JTAG reset without the strap; the board must be powered through J2 (see A11).

---

## 8. I2C bus

### A26 NOTE: 400 kHz rise time is marginal; run at 100 kHz
- MAX17048 SDA/SCL input capacitance up to **60 pF** (p. 3, CB,IN). With ~10 pF of pin + trace, tr = 0.8473 × 4.7 kΩ × 70 pF = **279 ns** vs the 300 ns Fast-mode limit. The gauge needs little bandwidth: run at 100 kHz (FW), or use 2.2 kΩ (130 ns, 1.5 mA sink) if 400 kHz is wanted.

---

## 9. Documentation and BOM consistency

### A27 NOTE: schematic fields lag the C.2 decisions
- J2 Value is still "CARTRIDGE SPRING CONTACTS (part to select)" with no MPN (`NIVA-controller.kicad_sch`); a BOM exported from the schematic would omit the 4 × Mill-Max 0900-0-15-20-76-14-11-0. C6 Value says "10V" while the BOM part (CL10A475KO8NNNC) is 16 V. Passives carry no MPN in the schematic (only in the costed CSV). Sheet text still says "NOT FOR FABRICATION" on the set being ordered. ELECTRICAL-REVIEW §4 "ESD at J1" still refers to "BAS416 clamps" (now BAV199). ROLE-DESIGN-NOTE gives MAX17048 hibernate as 3 µA; with the default VRESET comparator enabled it is 4 µA (p. 2).
- **Fix:** set J2 Value/MPN (or four single-pin symbols J2A-D), C6 "4.7u 16V X5R", MPN fields on all lines, update the sheet banner.

---

## 10. Open items from the design notes: my position

| Open item (STATUS-CLOSURE / ELECTRICAL-REVIEW §7) | Position |
|---|---|
| MAX17048 land pattern T822-3 vs T822-3C | Still open; I could not reach analog.com (A13). Pin use and footprint pin order are correct. |
| Antenna clearance | Not in this review's scope (layout/mechanics). No schematic dependency. |
| J2 contact geometry | Mechanics. Electrically: 20 mΩ max per contact, 2 per rail, is fine; the series path that matters is the fuse (A7). Reverse insertion relies on the key (A10). |
| Independent review | This document covers the schematic. |
| "Confirm LSM6DSO32 unused-pin handling" | Correct per AN5192 Table 1; re-read against the LSM6DSO32 DS when st.com is reachable (A19). |
| "BAV199 marking and pinning on the purchased reel" | Pinning confirmed from the Nexperia data sheet itself (Table 2); marking code JY% for incoming inspection. |
| Bench P1 (regulator sag) | Necessary but not sufficient: the worst-case calculation already puts the cut-off near 3.7 V (A7). |

## 11. Summary table: what was checked and found correct

| Item | Check | Result |
|---|---|---|
| Netlist connectivity | 40 connected nets + 19 NC, 65 symbols; every IC pin to the intended net; no stray single-node nets | OK |
| ERC | re-run, all severities | 0 errors, 1 intended warning |
| Symbol ↔ footprint pad numbering | U1, U2, U3, U4, U5, U6, D2, J1, J2, J3, SW1 (pcbnew) | OK |
| ESP32-C3 pin functions | MINI-1 Table 3-1 | OK |
| Strapping GPIO2/8/9 | MINI-1 Table 4-3; no cap on GPIO9 | OK |
| EN timing | 13.9 ms to VIH_nRST vs tSTBL 50 µs | OK |
| USB-JTAG pins / download mode | GPIO18/19 on J3; J3.5 = GPIO9 | OK (ESD: A22) |
| Flash pins | internal to module | OK |
| Boot glitches | chip Table 2-2 | harmless |
| Deep-sleep wake pins | GPIO1, GPIO3 in RTC domain | OK |
| Module decoupling | 22 µF + 100 nF vs 10 µF + 0.1 µF | OK |
| LDO pinout, VIN, EN, caps min/max, ESR type | SBVS320D | OK |
| LDO current rating vs load | 357 mA vs 500 mA, ICL ≥ 560 mA | OK |
| LDO dropout / brown-out | computed | **A7** |
| MAX17048 CTG/CELL/VDD/QSTRT/EP/ALRT | datasheet p. 6, Table 3 | OK |
| I2C address map | MAX17048 0x36 only | OK |
| I2C pull-ups / timing | 4.7 kΩ, 0.7 mA sink | OK at 100 kHz (A26) |
| MCP3208 pinout, VREF range, input range, abs max | DS21298E | OK |
| MCP3208 VDD bypass | 1 µF recommended | **A14** |
| Ratiometric FSR/ID math | re-derived codes 1310 / 3377 / 4095 | OK |
| CH6 window | re-derived 2329-2353 | A15 |
| LSM6DSO32 pinout, unused pins, CS mode, INT1 | AN5192 Table 1 | OK (A17, A18 firmware) |
| MCP6001 pinout, input limits, stability with 1 kΩ/470 nF | DS20001733L | OK |
| BAV199 pinning, orientation, leakage, current | Nexperia Tables 2, 5, 7 | OK |
| PVDF corner frequencies, clamp current | re-derived 11.4 Hz, 339 Hz, 0.7 mA | OK |
| Exposed/thermal pads | U6 EP and U1 EPAD to GND; no other EP | OK |
| LEDs | 1.45 mA red, 1.9 mA green; KiCad pad 1 = cathode = GND | OK (boot glow: A3) |
| J2 hot-plug ringing | ζ ≥ 1.3 | OK |
| Power-down back-currents into U2 | ≤ 2.5 mA transient | OK |
| BOM vs netlist | every netlist ref has a BOM line (J3, H1, H2 excluded by design) | OK (field lag: A27) |

## 12. Counts

BLOCKER 0, MAJOR 4 (A1, A7, A9, A22), MINOR 10 (A2, A8, A10, A11, A12, A14, A17, A23, A24, A25), NOTE 13 (A3, A4, A5, A6, A13, A15, A16, A18, A19, A20, A21, A26, A27).

Fixes that can go on the C.2 boards now (BOM/FW only): A1 (module), A3, A9 partial (R31/R32 100 kΩ, low-Iq op-amp), A12, A14, A15, A17, A18, A26, and the A2 firmware hold. Fixes that need copper (next revision): A2 pull-ups, A4 pads, A7 regulator, A9 VEXC switch, A10, A11, A22, A23, A24.
