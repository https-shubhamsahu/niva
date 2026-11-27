# Review C: battery cartridge, charging dock, battery safety (Niva Rev C.2)

Reviewer scope: cartridge strip, charging dock, and the battery safety architecture. Pod board, mechanics and software are covered by other reviewers; where a finding touches them it says so.
Repo: `/home/shubh/_Active_Projects/niva-pcbway` at `2c67426` (branch `pcbway-silk-logo`). No repo files were changed.

**Result: 0 BLOCKER, 8 MAJOR, 12 MINOR, 6 NOTE.**

Neither bare board has an error that stops the PCBWay order: pinouts, nets and contact mapping are correct, and DRC/ERC are clean. The MAJOR items are about the safety architecture and parts choices. They need to be closed before a **live cell** is charged or worn, which the docs already gate behind F4, and some need copper changes in a later revision.

## How this was checked

- **Connectivity truth.** Netlists re-exported with kicad-cli 10.0.7 from both `.kicad_sch` files (`scratchpad/crev/cart.net`, `dock.net`) and parsed into net lists.
- **Layout.** Both `.kicad_pcb` files dumped with `pcbnew`: footprints, pad positions and sizes, layers, nets, track widths and lengths, vias, zones.
- **DRC/ERC re-run** with `kicad-cli pcb drc --severity-all --schematic-parity` and `sch erc --severity-all`:
  - cartridge: 0 violations, 0 unconnected, 4 field-mismatch warnings; ERC 0/0;
  - dock: 1 `lib_footprint_mismatch` (USB-C), 0 unconnected, 3 MPN-field warnings; ERC 0 errors, 1 warning.
  - These match the STATUS files.
- **Datasheets read** (text extracted with pdftotext):
  - Microchip MCP73831 DS20001984H: https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP73831-Family-Data-Sheet-DS20001984H.pdf
  - TI LM393 SLCS005AH: https://www.ti.com/lit/ds/symlink/lm393.pdf
  - EEMB LP502030-PCM-LD ZJQM-RD-SPC-A03249 v0.0 (scratch copy)
  - Bourns MF-PSMF (scratch copy): https://www.bourns.com/docs/product-datasheets/mf-psmf.pdf
  - Bourns MF-NSMF: https://www.bourns.com/docs/product-datasheets/mf-nsmf.pdf
  - Mill-Max 0900-0-15-20-76-14-11-0 (scratch copy)
  - GCT USB4125 drawing Rev A6: https://gct.co/files/drawings/usb4125.pdf
  - PCBWay capabilities: https://www.pcbway.com/capabilities.html
  - TI BQ25170 / BQ21040 product pages
- **Calculations:**
  - NTC window, tolerance corners and wrong-NTC cases: script `scratchpad/crev/ntc.py`;
  - hot-plug ringing, IPC-2221 trace current, copper resistance, sag budget: inline Python. All numbers below come from those runs.

---

## MAJOR

### C1 (MAJOR): No input overvoltage or transient protection on dock VBUS, which the MCP73831 datasheet requires for USB

- **Evidence.**
  - Dock net `VBUS_IN` (J1.A9/B9) → F1 → `VBUS` → U1.4 (VDD), U2.8, C1 only. There is no TVS or OVP anywhere (dock netlist).
  - MCP73831 DS20001984H §6.1.1.2, pdf p.18: input overvoltage protection *must be used when the input power source is hot-pluggable. This includes USB cables*. Fig. 6-1 shows an SMAJ5.0A from VDD to VSS.
  - Absolute maximum VDD is 7.0 V (p.3).
- **How verified.** Read the datasheet; computed hot-plug ringing as a series RLC.
  - Assumed values: cable L 0.5–1 µH; C1 4.7 µF 0603, about 2.2 µF effective at 5 V; R = PTC + cable, 0.25–0.6 Ω.
  - Peak VDD is **5.3–7.8 V**. At low R it exceeds 7.0 V (for example L = 1 µH, C = 2.2 µF, R = 0.25 Ω gives 7.76 V).
- **Why it matters.** The charger's pass element is the first safety layer. A damaged U1 that fails short leaves only the cell PCM (4.28 ± 0.05 V) between 5 V and the cell.
- **Fix.**
  - Rev C.3 dock: add a 5 V TVS from `VBUS` to `GND` beside C1, downstream of F1, as the datasheet shows: SMAJ5.0A, or SMF5.0A in SOD-123FL to save space. A sustained overvoltage then trips F1 through the TVS.
  - Make F1 a real 13.2 V+ part (C18).
  - Production: replace U1 with a 30 V-tolerant charger with built-in OVP. TI BQ25170 lists 30 V tolerant input, 6.6 V input OVP, ±0.5 % VBAT, a TS/NTC input and a safety timer, so it also closes C2 and C10. It is WSON-8 2 × 2 mm, so it needs hot-air or reflow assembly.
- **BENCH.** Scope VDD at U1 during 20 hot plugs with a 1 m and a 2 m cable.

### C2 (MAJOR): No charge safety timer, although the cell maker requires one

- **Evidence.**
  - MCP73831: the feature list (p.1) and charge flowchart Fig. 4-1 (p.13) have no timer state. The word "timer" does not appear anywhere in the 29-page datasheet text.
  - EEMB LP502030 spec p.9, Warning: *Stop charging the Cell if charging is not completed within the specified time.*
- **Why it matters.**
  - A cell with an internal soft short never reaches V_REG or I_TERM, so the dock supplies 100 mA (about 0.4 W) indefinitely.
  - Below V_PTH (2.79 V for -2ACI) the 10 mA preconditioning also has no time-out.
  - The only remaining bound is the NTC window opening at about 45 °C, which is a single channel (C3, C9).
- **Fix.**
  - Production: a charger with precharge and fast-charge timers (BQ25170; or MCP73833/4 from the same Microchip family; confirm its timer and THERM thresholds in its datasheet).
  - Prototype: charge only attended, and add "charge stops by 5 h" to F4.

### C3 (MAJOR): The NTC window is only safe for one NTC value, and the claim that a wrong NTC shows up on the first test is untrue for most wrong values

- **Evidence.**
  - Dock STATUS.txt and PCBWAY-ORDER §1 say: *A 100 k NTC reads as cold at room temperature and the dock never charges, so a wrong NTC shows up on the first test.*
  - The only cell spec in hand is the no-NTC variant (EEMB LP502030-PCM-LD, 2 leads, p.8). The -PCM-NTC-LD NTC value, B constant and wiring are unknown (cartridge STATUS).
- **How verified.** `ntc.py`, using the dock's R5 22k and R6/R7/R8 43k/39k/18k. Charge-allowed window per NTC:

  | NTC fitted | Charges between | Revealed at a 25 °C first test? |
  |---|---|---|
  | 10k B3435 (design) | −0.3 … 45.1 °C |: |
  | 10k B3950 | 2.7 … 42.3 °C |: (safe) |
  | 6.8k B3435 | **−8.5 … 34.1 °C** | **No**: charges normally, also below 0 °C |
  | 15k B3950 | **10.8 … 52.9 °C** | **No** |
  | 22k B3950 | **18.8 … 63.5 °C** | **No** |
  | 47k B4050 | **35.9 … 85.0 °C** | yes (no charge at 25 °C), but charges a hot cell |
  | 100k B4250 | **53.2 … 105.5 °C** | yes, but **charges a cell that is 53–105 °C** |
  | 4.7k B3435 | −15.8 … 24.3 °C | marginal: charges in a 22 °C room |

- **Fix.**
  - Obtain the -PCM-NTC-LD spec and its IEC 62133-2 report (C8).
  - Incoming inspection: measure every pack's NTC between the NTC and − leads at 25 °C before soldering (accept 10 k ± 3 %), and record the lot.
  - Correct the STATUS and order-sheet sentence.
  - F4: chamber test with the real pack at −5, +2, 43 and 48 °C.
  - A TS-pin charger (C1/C2) has the same NTC dependency, so the inspection step stays either way.

### C4 (MAJOR): Live P+ and P− lid plates 0.94 mm apart on a removable cartridge

- **Evidence.**
  - Pod J2 (`NIVA-RevC2-protected-steps/electronics-C2-working/NIVA-pod.kicad_pcb`) pads sit at pod x = 25.19 / 27.73 (VBAT) and 30.27 / 32.81 (GND), y = 21.5. The lid plates mirror these.
  - `niva_cad_lib.contact_plates()` gives plates 1.6 × 3.0 mm at 2.54 mm pitch, so the **P+ to P− edge gap is 0.94 mm**. The pockets are 1.8 mm wide, so the plastic wall between them is 0.74 mm.
  - The plates sit 0.37 mm below the lid face (`CART['plate_recess']`).
  - The cartridge travels to and from the dock bare, and sits lid-up in the dock while charging.
  - The pod bay is open by design (VERIFICATION-PLAN §2), so sweat can reach the plates while the pod is worn.
  - EEMB spec p.9: *Strictly prohibit put batteries in your pockets or a bag together with metal objects such as necklaces, hairpins, coins, or screws.*
  - IEC 62133-2:2017 §5, terminal-contacts clause: terminal contacts shall be arranged to minimize the risk of short circuits.
  - The rear dock pads are lower risk: P+ to P− is 12 mm, each pad sits 1.0 mm deep in a Ø2.4 window, and a flat coin cannot reach them.
- **How verified.** Coordinates read from the pod PCB and the CAD code; the gap was computed.
- **Consequences.**
  - Any key, chain, foil, or wet film across 0.94 mm under 4.2 V causes discharge, electrolytic corrosion of the plates and pod pins, and a hard or soft short handled only by the PCM and F1. See C5 for what a soft short does.
- **Fix (pod and mechanics owners).**
  - Regroup the four pins as 2 + 2 with at least 5 mm between the P+ pair and the P− pair, for example VBAT at x 23.9 / 26.4 and GND at x 31.6 / 34.1.
  - Recess the plates at least 1.0 mm with a raised rib between the groups. This also needs a pin with more free height, or a lid boss.
  - Add a snap-on travel cap for the bare cartridge, and a user instruction.

### C5 (MAJOR): A tripped F1 becomes a sustained ~0.5 W heat source about 1 mm from the pouch cell

- **Evidence.**
  - Cartridge F1 sits on the strip at pod (30.95, 12.1), alongside the cell body. The cell spans y 6.8–38.8, max-size envelope x ≤ 29.3.
  - The strip is 0.55 mm from the cell (PRINT-AND-ASSEMBLY §3), and the F1 body is about 0.9–1.0 mm from the cell envelope (`niva_layout` CART/STRIP, `niva_cad_lib.strip_pcb`).
  - Bourns MF-PSMF table p.1: tripped power dissipation **0.5 W typ.** for MF-PSMF035X. A tripped polymer PTC holds itself near its switching temperature for as long as voltage is applied.
  - The EEMB spec gives the PCM load limits (0.3 A constant, 0.8 A for 3 s, §6.1 p.7) but **no over-current detection current or delay**.
- **Scenario.**
  - A soft short between the PTC trip current (0.75 A) and the PCM over-current threshold trips F1 but not the PCM. The PCM threshold is unknown; a DW01-class PCM at about 150 mV across ≤ 70 mΩ is about 2 A (assumption).
  - Examples: a poor-contact key across the C4 plates, or chafed lead insulation inside the cup.
  - The cell then feeds about 0.12 A (0.5 W / 4 V) into the hot PTC until the PCM over-discharge cut-off at 3.0 V. That is up to about 2 h of local heating next to the pouch.
- **Fix.**
  - Get the PCM OC detection current and delay from EEMB for the NTC variant.
  - Bench test: dummy-then-live cartridge, thermocouple on the pouch at F1, 3 Ω load across the lid plates, at 25 °C and 40 °C ambient. Accept a pouch surface below 60 °C (the cell's discharge maximum, EEMB §2.9).
  - If it fails: add a thermal barrier (polyimide tape plus an air gap), or move F1 off the cell flank (extend the strip past the PCM end), or use a one-time chip fuse sized at about 1 A, so a fault leaves no latched hot element.
- **BENCH.**

### C6 (MAJOR): Cartridge strip has no polarity marks, and the lead order is documented two ways

- **Evidence.**
  - Netlist: J1.1 = CELL_P (+), J1.2 = NTC, J1.3 = PACK_N (−).
  - The footprint description says *three 30 AWG leads (cell +, -, NTC)*. `niva_layout.CART_PLACE` says *cell leads (+, -, NTC)*. PRINT-AND-ASSEMBLY §4a says only "+, − and NTC". Three sources, two orders.
  - The F.Silkscreen Gerber holds only the F1 outline (4 draw operations). B.Silkscreen holds "PCBWay". Reference designators are on Fab layers. J2's P−/P−/P+/P+ order and the lid plates are also unmarked.
- **Consequences of a swap during hand assembly with a live pack.**
  - **+/− swapped:**
    - The pod receives reversed polarity. It has no reverse protection (ELECTRICAL-REVIEW §5).
    - In the dock, BAT (U1.3) is forced about 4 V below VSS. MCP73831 absolute maximum on inputs and outputs is −0.3 V (p.3).
    - Fault current is limited only by F1 and the PCM.
  - **+/NTC swapped:** the cell + goes unfused to the dock NTC pad.
- **Fix.**
  - Add F.Silk marks: "+", "T", "−" beside J1 pads and "− − + +" beside J2. They fit in the 1.5 mm free strip width at PCBWay's 0.8 mm minimum text height.
  - Fix the footprint description to "(cell +, NTC, −), AWG28" and add a table to §4a.
  - Add a post-assembly check before the lid is bonded: J3.1 to the cell + lead reads 0.25–1.2 Ω (F1); J3.2 to J3.3 reads about 10 kΩ at 25 °C.

### C7 (MAJOR): Supply-path resistance at a 350 mA pod burst can drop the 3V3 rail below the ESP32-C3 minimum over much of the discharge

- **Evidence and calculation.** Series path from the cell to pod J2:
  - pack (cell + PCM) ≤ 0.30 Ω at 1 kHz (EEMB p.8; DC IR is higher);
  - F1 0.25–1.2 Ω (Bourns Rmin / R1max);
  - strip copper about 0.083 Ω, computed for 1 oz copper: CELL_P 28.9 mm × 0.3 mm = 0.047 Ω, PACK_P 15.7 mm = 0.026 Ω, PACK_N 5.9 mm = 0.010 Ω;
  - spring contacts ≤ 2 × 10 mΩ (Mill-Max 20 mΩ max each, two in parallel per pole);
  - total **0.62–1.61 Ω**, so **ΔV = 0.22–0.56 V at 0.35 A**.
  - TLV75533 dropout is about 0.17 V at 0.35 A (238 mV max at 500 mA, scaled; ELECTRICAL-REVIEW §5).
  - Result: 3V3 stays in regulation only above a cell voltage of **3.69–4.03 V**, and stays ≥ 3.0 V only above **3.39–3.73 V**. In the worst case, a large share of the cell's capacity cannot be used with the radio on.
  - CELL_P runs the full strip length to F1 at y = 11.2 and PACK_P comes back to J2 at y ≈ 25: about 25 mm of avoidable detour.
- **Fix.**
  - Measure first (bench item P1).
  - Then: F1 → MF-PSMF050X-2 (0.15–0.9 Ω, same land). It trips at 1.0 A, above the PCM's 0.8 A peak, so record that tradeoff.
  - Widen CELL_P/PACK_P to at least 0.8 mm (the strip is 3.4 mm wide) or duplicate them on B.Cu, and move F1 next to J1/J2 at y ≈ 31.
  - Pod side: bulk capacitance on VBAT (pod reviewer).
- **BENCH.**

### C8 (MAJOR): No cell safety evidence or spec for the part actually designed in

- **Evidence.**
  - The spec in hand is EEMB LP502030-PCM-LD, ZJQM-RD-SPC-A03249 **v0.0, 2017-12-15**, 2-lead, no NTC.
  - The design names -PCM-NTC-LD (`niva_layout.CELL`).
  - There is no IEC 62133-2 test report, UN 38.3 test summary or SDS for either variant; F4 lists them as open.
  - The PCM over-current threshold and the NTC value, B constant and return point (B− or P−) are unspecified. C3, C5 and C20 depend on them.
- **Also missing for a 1-cell wearable.**
  - IEC 62133-2:2017 battery-level tests on the **cartridge** as built: 7.2.2 case stress at 70 °C for 7 h (the printed PETG cup, Tg about 80 °C, needs checking), 7.3.2 external short at 55 °C, 7.3.3 free fall, 7.3.6 overcharge of battery.
  - IEC 60601-1 (A2:2020) points secondary lithium batteries to IEC 62133-2.
  - UN 38.3 coverage of the cartridge as shipped (casing and added PTC). Air shipment of standalone Li-ion at ≤ 30 % SoC (IATA PI 965).
- **Fix.** Request from EEMB, for the exact NTC part number: the current spec, IEC 62133-2 report, UN 38.3 summary, PCM OC and short thresholds and delays, and the NTC value, B constant and wiring. Until then, the "live cells only after F4" gate in PRINT-AND-ASSEMBLY §4a must hold.

---

## MINOR

### C9 (MINOR): NTC window tolerance stack lets charging start up to 46.8 °C or down to −1.6 °C

- **Evidence.** `ntc.py` corners: R5–R8 ±1 %, NTC R25 ±1 %, B ±1 %, LM393 V_IO ±9 mV full range and I_IB 250 nA (SLCS005AH §5.8, pdf p.8).
  - With 10k B3435: cold trip **−1.6 … +0.9 °C**, hot trip **43.3 … 46.8 °C**.
  - Resistors alone: −1.0 … +0.3 / 44.2 … 46.0 °C, as STATUS says.
  - The cell charge range is 0–45 °C (EEMB §2.9). Thermal lag from the cell to the NTC adds more.
- **Fix (BOM only).** R6 / R7 / R8 = **46.4k / 33.2k / 19.6k 1 %**, keeping R5 = 22k.
  - Computed nominal window: 3.0–41.8 °C.
  - Worst case: **1.7–43.4 °C** (B3435) and **4.6–40.9 °C** (B3950).

### C10 (MINOR): No hysteresis, and the charge current pushes the cold edge into a limit cycle

- **Evidence.**
  - The generator comment calls toggling at a threshold benign.
  - Charge current returns through the P− pin (≤ 20 mΩ), the PCM FETs (≤ 70 mΩ, if the NTC is tied to B−) and the strip copper. That lifts the NTC's ground by about 2–11 mV at 100 mA, which raises NTC_S.
  - At the **cold** edge a higher NTC_S means "colder", so switching the charger on pushes NTC_S back across the threshold: negative feedback, a sustained on/off cycle.
  - At the hot edge the same shift adds hysteresis (positive feedback).
  - Each PROG re-enable restarts the MCP73831 charge cycle, so D1 flickers.
- **How verified.** Reasoned from the netlist current paths; slopes from `ntc.py`: 56.5 mV/°C at 0 °C, 25.1 mV/°C at 45 °C.
- **Fix.** 4.7 MΩ from TEMP_OK to VTH_HI. Computed Thevenin 24.5 kΩ gives 26 mV, about 0.46 °C of hysteresis on the cold edge. Re-centre R6–R8 afterwards. A TS-pin charger (C1) makes this moot.

### C11 (MINOR): LM393 common-mode margin is thin at low VBUS

- **Evidence.** VTH_HI = 0.57 × VBUS. LM393 V_ICR upper limit is VCC − 1.5 V at 25 °C and VCC − 2 V over full range (SLCS005AH §5.8, p.8).
  - VBUS 4.75 V: VTH_HI 2.71 V against a 2.75 V full-range limit.
  - VBUS 4.5 V: 2.57 V against 2.50 V, which is outside.
  - Fine at 25 °C. Per TI note (2), the inputs at VBUS with no cartridge are correctly handled, because the other input stays in range.
- **Fix.** Raise R5 to 33.2k and retune R6–R8, or use a rail-to-rail-input, open-collector dual comparator in the same SOIC-8 pinout (for example TI TLV1702; confirm output type and pinout).

### C12 (MINOR): C1/C2 fall below the MCP73831 minimum 4.7 µF after DC bias

- **Evidence.**
  - C1 and C2 are "4.7u 10V", 0603, with no dielectric stated (dock BOM).
  - Datasheet §3.1/§3.2 (p.11) and §6.1.1.4 (p.18): bypass VDD and VBAT with a minimum of 4.7 µF. The VBAT capacitor is the loop compensation when no battery is present, and the spring-pin and cell path is inductive.
  - A 10 V 0603 X5R part typically keeps only about half its capacitance at 4–5 V (typical DC-bias curves; not measured).
- **Fix.** 10 µF 0805 X5R 16 V, for example Murata GRM21BR61C106KE15, for C1 and C2. The 0603 pads need re-landing to 0805.

### C13 (MINOR): Exposed dock pins drive the LM393 inputs directly, and a half-seated cartridge pulls them below −0.3 V

- **Evidence.**
  - NTC_S runs **62.7 mm** from J2.2 to U2.2/U2.5, with C3 (100 nF) at the far end by R5. There is no ESD part on J2.
  - The pins are finger-reachable in an empty well.
  - Half-seated case: P+ and NTC touching without P−, while C2 is discharged.
    - Computed NTC_S = (5·Rn − 3.7·22k)/(22k + Rn) = **−0.98 V** for Rn = 10k, and −2.1 V at 45 °C.
    - TI note (1), p.6–8: an input more than 0.3 V below ground can give a wrong output and excessive input current.
    - Here the current is below 0.5 mA, and charge current is limited to about 0.1 mA by the NTC path, so it is harmless but out of spec.
  - The normal tab-first pivot mates P− first, then NTC, then P+ (P− is nearest the tab pivot at pod y = 24), and removal breaks P+ first. So this only happens on a straight drop or a wrong-way tilt.
- **Fix.** At J2: a low-capacitance ESD diode (for example a 5 V unidirectional TVS) on NTC_S and on BAT, plus a BAT54 (anode to GND) on NTC_S to clamp negative excursions. BAT54 leakage times about 12 kΩ is under 2 mV. Alternatively, move C3 to J2.
- **BENCH.** Run an IEC 61000-4-2 contact discharge on the pins.

### C14 (MINOR): One amber LED cannot tell "full" from "not charging"

- **Evidence.**
  - D1 runs VBUS → R4 → D1 → STAT and lights only on STAT = L.
  - Charge complete (H), shutdown with PROG floating (temperature or NTC fault, no contact) and no battery (Hi-Z) all show **off** (MCP73831 Table 5-1, p.15).
  - A patient can take a too-hot or badly seated cartridge for a full one.
- **Fix.**
  - Add a second LED from STAT to GND through 1 kΩ (lit at charge complete), as §5.2.1 allows ("one, two or tri-color LEDs").
  - Choose LEDs so Vf(amber) + Vf(second) exceeds VBUS max, or neither glows when STAT is Hi-Z.
  - Or use the PG/STAT outputs of the C1 replacement charger.

### C15 (MINOR): Strip PCB is not located in the cup, so dock contact alignment is uncontrolled

- **Evidence.**
  - Cup cavity: x 8.5–33.5, y 6.5–41.0. Strip: x 29.85–33.25, y 8–38.
  - The strip can move 0.25 mm in x and −1.5 / +3.0 mm in y. Nothing pins it, and §4a step 3 only says "lay".
  - Floor windows are Ø2.4 and pads Ø2.0 (`niva_cad_lib.cartridge_cup`). The Mill-Max plunger is Ø1.067.
  - Radial budget before the plunger hits the window wall is 0.67 mm. Before the plunger tip leaves the pad it is 1.0 mm.
  - These stack with the 0.5 mm well clearance and print tolerance.
- **Fix (mechanics owner).** Add two NPTH holes in the strip with cup pegs, or a floor pocket, or bond the strip in a fixture before the cell goes in.
- **BENCH.** Measure the pad-centre offset on the first prints.

### C16 (MINOR): Default ENIG gold is thin for a daily-mated contact pad

- **Evidence.**
  - Cartridge J3 pads are the wear surface under 60 g, gold-plated Mill-Max plungers (Mill-Max p.2).
  - The order sheet says gold thickness "default (1 µ")". PCBWay normal ENIG is 1–8 µin; PCBWay also offers ENEPIG and hard gold.
- **Fix.** ENEPIG, or hard gold of at least 30 µin, on the cartridge strip only.
- **BENCH.** Verification item C6 (contact resistance after cycling).

### C17 (MINOR): USB-C receptacle stake length versus 1.6 mm board; STATUS slot count is wrong

- **Evidence.**
  - GCT USB4125 drawing A6: shell stake length "S" is blank = 1.00 mm, or "0190" = 1.90 mm. The recommended layout matches the footprint used: pads 0.70 / 0.76 / 0.80 × 1.20 mm, slots 0.60 × 1.20 in 1.10 × 1.70 pads at 8.64 × 3.80 mm.
  - The dock is 1.6 mm thick and the BOM says only "GCT USB4125 class". A 1.00 mm stake does not reach the bottom side.
  - Dock STATUS says "Two plated slots". The PTH drill file has **four** G85 slots (x 154.2–154.8 and 158.0–158.6 at y −45.68 and −54.32).
  - Slot 0.6 × 1.2 mm is a 2.0 length-to-width ratio, exactly PCBWay's minimum (≥ 0.5 mm wide, L/W ≥ 2).
  - The DRC `lib_footprint_mismatch` is only the shell pad name, S1 versus library SH; all copper is identical (compared pad by pad).
- **Fix.** Order USB4125-GF-A-0190 and check that KiCad's `..._USB4125-xx-x-0190_6P` footprint keeps the same slots. Correct STATUS to "four plated slots".

### C18 (MINOR): Dock BOM not orderable as written; real part proposed for the VBUS PTC

- **Evidence.**
  - Dock F1 is "PTC 1206 hold 0.5 A" with no MPN.
  - U2 "LM393", Q1 "2N7002" and D1 "AMBER 0805" have no MPN.
  - C3/C4 "100n" and C1/C2 "4.7u 10V" have no dielectric or voltage.
- **Fix.**
  - F1 = **Bourns MF-NSMF050-2** (1206; Vmax 13.2 V, Imax 100 A, Ihold 0.50 A, Itrip 1.00 A, R 0.15–0.70 Ω; MF-NSMF table, LCSC C75464). For more source-fault margin use MF-NSMF050/24X-2 (24 V). Bourns' recommended land (1.0 × 1.6 mm, 2.0 mm gap) is compatible with the KiCad 1206 land (1.25 × 1.75 mm, 1.55 mm gap).
  - U2 = LM393DR (TI SOIC-8). Q1 = any 2N7002 (V_GS(th) 1.0–2.5 V, R_DS(on) ≤ 7.5 Ω at 5 V).
  - Name the D1 part so its Vf is known for C14.

### C19 (MINOR): F4 acceptance is looser than the cell spec, and the charger and PCM tolerance bands overlap

- **Evidence.**
  - F4 accepts "4.20 V ± 1 %", i.e. 4.158–4.242 V.
  - The cell limit is 4.200 ± 0.020 V (EEMB §2.7). MCP73831-2 V_REG is 4.168–4.232 V (p.3, at −5 to +55 °C).
  - The PCM over-charge detect is 4.28 ± 0.05 V, minimum **4.23 V**, which is below the charger maximum of 4.232 V. Worst case, the PCM can trip at end of charge.
  - F4 covers neither the timer, input OVP, hot-plug, the wrong-NTC case, the half-seated case nor ESD.
- **Fix.**
  - F4: accept 4.18–4.22 V at the cartridge P+ after termination.
  - Add tests for C1, C3, C13 and C20, plus "charge with VBUS at 4.75 V".
  - The MCP73831 DC table is specified at VDD = V_REG + 1 V = 5.2 V to 6 V (p.3); USB minimum through F1 is about 4.7 V.

### C20 (MINOR): If the pack NTC returns to B−, the hot trip moves to about 66 °C or more while the PCM's discharge FET is off

- **Evidence and calculation.**
  - In over-discharge lockout (release at 3.5 ± 0.05 V, EEMB §6.1) the dock charges through the discharge FET's body diode.
  - A NTC tied to B− then sits about 0.5–0.7 V above dock GND.
  - Solving 0.5 + 4.5 × Rn / (22k + Rn) = 0.9 V gives Rn = 2.15 kΩ, which is about 66 °C for 10k B3435. It is higher at 0.7 V.
- **Fix.** Confirm the NTC wiring in the -NTC spec (C8). Prefer an NTC referenced to P−.
- **BENCH.** Recovery-charge an over-discharged pack in the chamber at 50 °C.

---

## NOTE

### C21 (NOTE): Trickle into a full cell left in a powered dock

- **Evidence.** MCP73831 I_DISCHARGE "Charge Complete" is **−5.5 µA typ / −15 µA max** (sourced into the battery, p.4). The PCM draws 3–7 µA (EEMB §6.1).
- **Why it matters.** With two cartridges, one sits in the dock for days.
- **BENCH.** Log cell voltage over 7 days in a powered dock; flag creep above 4.20 V.

### C22 (NOTE): No over-temperature sensing during discharge

- **Evidence.** The NTC goes only to the dock (cartridge netlist: NTC = J1.2, J3.2 only), and the PCM has no temperature input.
- **Why it matters.** Cell discharge limit is −20 to 60 °C. Sun on an ankle in summer can approach this.
- **Fix.** Pod firmware cut-off using the LSM6DSO32 or ESP32-C3 temperature sensor as a proxy (pod/software owners), or a fifth contact later.

### C23 (NOTE): Dock "Power" netclass patterns do not match hierarchical net names

- **Evidence.** Patterns `BAT` and `VBUS_IN` do not match `/BAT` and `/VBUS_IN`, so those tracks are 0.2 mm (the pcbnew dump confirms it).
- **Impact.** Electrically fine: IPC-2221 external, 1 oz, gives 0.74 A at 10 °C rise against 0.11 A. But the intended 0.4 mm was not applied. The cartridge's `*PACK_P` wildcard patterns work.

### C24 (NOTE): Wire-pad details on the cartridge strip

- EEMB leads are AWG28, tinned 3.0 ± 0.5 mm (p.8). The pads are 1.5 mm long, so trim the tinned end to about 1.3 mm or bare wire overhangs the 0.7 mm pad gap.
- The footprint description still says 30 AWG.
- Hand-soldering a live pack needs a temperature-limited iron and ESD and short precautions in §4a.

### C25 (NOTE): Cartridge F1 land differs from Bourns

- **Evidence.**
  - KiCad `Fuse_0805_2012Metric`: 0.975 × 1.4 mm pads, **0.9 mm gap**.
  - Bourns MF-PSMF recommended: 1.0 × 1.5 mm, **1.2 mm gap** (p.2).
  - The pad extends 0.3 mm further under the polymer body; the terminal band D is ≥ 0.20 mm.
- **Impact.** Acceptable for hand soldering. Use the Bourns land at the next copper revision.

### C26 (NOTE): Mill-Max 0900-0-15-… is bulk packed

- **Evidence.** Packaging code 15 = bulk (Mill-Max p.3).
- **Impact.** Fine for the hand-populated prototype (order sheet). PCBA needs a tape-and-reel variant or manual placement. Check pin verticality after reflow (STATUS lists it).

---

## Checked and found correct

| Item | Evidence | How verified |
|---|---|---|
| MCP73831 pinout | SOT-23-5 pins 1 STAT, 2 VSS, 3 VBAT, 4 VDD, 5 PROG (Table 3-1, p.11) match U1 nets STAT/GND/BAT/VBUS/PROG and pad geometry (pin 4 opposite 3, pin 5 opposite 1) | netlist + pcbnew pads |
| Floating PROG disables the charger | §3.5 p.11 ("disabled by allowing the PROG input to float"), §4.3 p.13 ("open or floating … disabled … reverse discharge < 2 µA"), §5.2.2 p.15, Fig. 4-1 shutdown when PROG > 200 kΩ, minimum shutdown impedance 70–200 kΩ (p.4). Q1 off leaves R3 + 2N7002 off-state (I_DSS ≤ 1 µA at 60 V, 25 °C), far above 200 kΩ. The generator's claim is correct. | read |
| Charge current | I_REG = 1000 V / R_PROG; 90/100/110 mA at 10 kΩ (p.3); Q1 R_DS(on) ≤ 7.5 Ω adds 0.08 %. 0.1 A is 0.4 C of 250 mAh, below the cell's 0.25 A maximum. Pre-charge 10 mA below 2.79 V; termination 5.6–9.4 mA, at or above the cell's 5 mA end current, so it ends slightly early (safe side); recharge at 4.05 V (-2ACI = AC: 10 / 66.5 / 7.5 / 96.5 %, p.26) | read + computed |
| STAT and D1 | Tri-state: L while charging, H at complete, Hi-Z in shutdown or no battery (Table 5-1). D1 anode to R4/VBUS, cathode to STAT, so it lights only while charging; about 2.6 mA, against 25 mA sink capability. LED footprint pad 1 = K = STAT. | netlist + read |
| Reverse drain into an unpowered dock | BAT net = U1.3, C2, J2.1 only. I_DISCHARGE ≤ 2 µA with VDD floating, below VSTOP, or PROG floating (p.4). The NTC is passive, so there is no other path. | netlist + read |
| Thermal | Worst case (5.25 − 0.64 × 4.2) × 0.11 A = 0.28 W; 65 °C rise at 230 °C/W (minimum copper, p.5); below the 150 °C thermal shutdown; the pour helps | computed |
| LM393 pinout and logic | SOIC-8: 1 OUT1, 2 IN1−, 3 IN1+, 4 GND, 5 IN2+, 6 IN2−, 7 OUT2, 8 VCC. Unit A pulls TEMP_OK low when NTC_S > VTH_HI (cold or open); unit B when NTC_S < VTH_LO (hot or short); wired-AND with R9 100k. | netlist |
| Q1 drive | TEMP_OK high ≈ VBUS − I_OH × 100k (≤ 50 nA, so ≤ 5 mV), so V_GS ≈ 5 V against V_GS(th) 1.0–2.5 V; R_DS(on) ≤ 7.5 Ω at 0.1 mA is negligible. LM393 V_OL at 50 µA sink is far below 1.0 V. SOT-23 pins 1 G, 2 S, 3 D match nets. | read + computed |
| No cartridge, NTC open, NTC shorted | Open: NTC_S = VBUS, unit A low, no charge (one input inside the CMR is enough, TI note (2)). Shorted: NTC_S = 0, unit B low. Both inhibit. | computed |
| Nominal window | 0.570 / 0.180 of VBUS give −0.34 °C / 45.11 °C (10k B3435); ratiometric, so VBUS-independent; NTC self-heating 0.17–0.28 mW | `ntc.py` |
| VBUS ramp | NTC_S lags VBUS (τ = 2.2 ms), and with no cartridge passes through the window for about 1.4 ms. MCP73831 UVLO is 3.3–3.6 V with up to 5 ms start delay; worst case is a brief enable with no battery (harmless). The LM393 works from 2 V. | read + computed |
| Mating order | Tab-first pivot: P− (y 24, nearest the tab), then NTC, then P+. Removal reverses. C2 inrush at P+ contact is 4.7 µF × ≤ 1.2 V, a few µC. | geometry + computed |
| Dock-to-cartridge pin mapping | Dock J2.1 BAT at dock (42.55, 17) = pod (31.55, 12) = cartridge J3.1 PACK_P (B.Cu). J2.3 GND matches J3.3 PACK_N at y 24. No mirroring: both frames are right-handed with z up; checked pad by pad. | pcbnew on both boards |
| Reverse insertion | Rotated 180° the pads go to x 10.45; flipped lid-down the plates go to x 9–17, or y 24.5–27.5 with the pin at y 24 between plates. No orientation puts a dock pin on a pad or plate, and the tab blocks seating. | computed from coordinates |
| Pod in the dock | Pod 42 × 60 against a 29 × 38.5 well; the pod has no charge input | geometry |
| USB-C sink | Separate 5.1 kΩ Rd on CC1 and on CC2 (correct for a sink; CC lines reach only resistors, so no ESD part is needed there); 6P pin map matches GCT A5/B5/A9/B9/A12/B12; footprint copper matches the GCT recommended layout and the KiCad library | netlist + drawing + pad compare |
| F1 position (cartridge) | CELL_P = F1.1 and J1.1 only; PACK_P = F1.2, J2.3, J2.4, J3.1. Both lid P+ plates and the dock P+ pad are behind F1, in copper too (pad nets and track nets). An unfused P− does not matter: every external short loop passes through P+, and NTC-to-P± is limited by the 10 kΩ NTC. | netlist + pcbnew |
| F1 ratings (cartridge) | Vmax 6 V ≥ 4.33 V (PCM over-charge maximum); Imax 40 A ≥ about 7.6 A prospective short (4.2 V / (0.3 + 0.25 Ω)); I_hold 0.30 A at 40 °C ≥ 0.1 A charge and the pod RMS (bench-confirm); typical trip about 0.5–1 s at 0.8 A (curve p.3), inside the PCM's 0.8 A / 3 s | read + computed |
| Trace widths | IPC-2221 external, 1 oz: 0.3 mm carries 1.0 A at 10 °C rise; 0.2 mm carries 0.74 A. Onderdonk fusing for 0.3 mm is about 96 A at 1 ms, so a short pulse before the PCM trips is safe. | computed |
| Wire pads | 1.5 × 1.1 mm at 1.8 mm pitch suit AWG28 (EEMB p.8) | read |
| Mill-Max land | 2.08 mm round pad = datasheet .082" (2.083 mm) circular SMT pad; 20 mΩ maximum contact resistance; 60 g at mid stroke | read |
| Package lands | MCP73831 SOT-23-5, LM393 SOIC-8, 2N7002 SOT-23, LED 0805, 1206 PTC: stock KiCad lands with standard JEDEC pinouts | read |
| PCBWay rules | Minimum track 0.2 mm (≥ 0.1); spacing 0.15 mm; via annular ring 0.15 mm (= 0.15 minimum); plated slot 0.6 × 1.2 mm (≥ 0.5, L/W = 2); copper to edge ≥ 0.25 mm (DRC rule; cartridge NTC trace at exactly 0.25 mm); silk 1.0 mm / 0.15 mm (≥ 0.8 / 0.15); 0.8 and 1.6 mm thickness offered; 3.4 mm strip above the 3 × 3 mm minimum | pcbnew + PCBWay page |
| DRC / ERC | Re-run, matches the STATUS files | kicad-cli |
| Creepage | 5 V only. The USB shell goes straight to GND, which is acceptable in a plastic desk dock. | layout |
| Hazard coverage that exists | Overcharge: charger CV + PCM 4.28 V. Over-discharge: PCM 3.0 V + pod gauge. Over-current / short: PCM + F1. Charge temperature: NTC window. Reverse insertion and pod-in-dock: mechanical. | architecture review |

## Hazard coverage summary

| Hazard | Layer 1 | Layer 2 | Gap |
|---|---|---|---|
| Overcharge | MCP73831 CV, ±0.75 % | PCM 4.28 ± 0.05 V | Charger maximum overlaps PCM minimum (C19); no input OVP (C1) |
| Over-discharge | Pod firmware cut-off (MAX17048) | PCM 3.0 V |: |
| Over-current / short | PCM (thresholds unknown) | F1 PTC | F1 heat beside the cell (C5); exposed plates (C4) |
| Charge over / under temperature | LM393 window | none | Single channel, no diagnostics; wrong NTC unsafe (C3); tolerance (C9); NTC on B− (C20) |
| Discharge over-temperature | none | none | C22 |
| Charge time-out / damaged cell | none | none | C2 |
| Reverse insertion | Keyed well and tab; geometry checked |: | Assembly lead swap (C6) |
| Pod on the dock | Mechanical (does not fit; pod has no input) |: |: |
| Swollen cell | 8 % swell allowance in the cup; the latch may not close |: | No detection (bench) |

## BENCH-only items

- C1: VDD ringing at hot plug.
- C3: chamber trips with the real pack.
- C5: pouch temperature with F1 tripped.
- C7: VBAT and 3V3 sag during TX.
- C10: cold-edge chatter.
- C13: ESD.
- C15: pad alignment.
- C16: contact wear.
- C19: termination voltage at the cartridge.
- C20: hot recovery charge.
- C21: 7-day float in a powered dock.
- Pod RMS current against F1 I_hold at 40 °C.
- Swollen-cell latch behaviour.
