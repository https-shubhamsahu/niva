# B. Pod Rev C.2: PCB layout, land patterns, PCBWay manufacturability

Reviewer B, 9 Nov 2026. Board: `hardware/outputs/NIVA-RevC2-protected-steps/electronics-C2-working/NIVA-pod.kicad_pcb` (KiCad 10.0.7). Nothing in the repo was changed; all work was on a copy in the scratch folder.

**Verdict:** No BLOCKER for the bare-board PCBWay order. The Gerbers match the board exactly and meet PCBWay's published standard limits. Several items sit exactly at a limit (annular ring 0.150 mm, clearance 0.127 mm, mask dams 0.150 mm). Three MAJOR items affect assembly: unfilled vias in pads, 100 % paste on the module EPAD, and the J2 pin centroid and process for PCBA. Fix those before the stencil and PCBA order. They do not block the bare-board order.

Counts: BLOCKER 0, MAJOR 3, MINOR 10, NOTE 11.

## How it was checked (all run in this session)

- **Baseline DRC.** `kicad-cli pcb drc --severity-all` on a copy reproduces the committed report: 3 violations (2 silk-at-edge, 1 LGA lib mismatch), 0 unconnected.
- **Probe DRC.** I set rules just above PCBWay's limits so DRC lists every near-limit item with its measured value. The rules file is `scratchpad/bwork/NIVA-pod.kicad_dru`, deleted after the run. The report is `scratchpad/bwork/probe-drc.rpt`.
  - `clearance 0.16`
  - `annular_width 0.16`
  - `hole_clearance 0.30`
  - `hole_to_hole 0.45`
  - `edge_clearance 0.50`
  - `silk_clearance 0.15`
  - `text_height 0.8`
  - `text_thickness 0.15`
  - `connection_width 0.20`
- **pcbnew scripts** (`scratchpad/bscripts/*.py`) measured:
  - pad geometry
  - via-in-pad
  - mask web per footprint
  - hole-to-hole distances
  - track widths per net
  - shortest +3V3 and VBAT copper paths
  - decoupling distances
  - courtyard to edge
  - Tag-Connect keep-out
  - placement CSV against the board
- **Gerber parity.** I re-exported Gerbers and drills from the board with STATUS.txt's flags (`--no-x2 --no-netlist --subtract-soldermask`, separate PTH/NPTH). All 14 files are identical to the committed set, ignoring date lines. The zip contents are byte-identical to `gerber/`.
- **Renders.** F, B, In1 and In2 SVG and PNG, plus zoomed crops of the U1 top row and U4/U6, are in `scratchpad/bwork/img/`. I looked at all of them.
- **Datasheets read:**
  - Espressif ESP32-C3-MINI-1 datasheet v2.2
  - Espressif ESP32-C3 Hardware Design Guidelines (PCB layout page)
  - Microchip MCP3208 (21298E) and MCP6001 (DS20001733L)
  - TI TLV755P
  - Nexperia BAV199 (2020)
  - JST GH (eGH)
  - Mill-Max 0900-0-15-20-76-14-11-0 (PDF dated 11/8/26)
  - Tag-Connect TC2030-IDC-NL footprint Rev B
  - PCBWay capabilities page
- **Datasheets not reachable:**
  - st.com timed out.
  - analog.com timed out (MAX17048 / 90-0065).
  - Littelfuse/C&K KMR2 returned 403.
  - The Kento LED datasheet was not tried.

  The footprints for those parts are marked "not independently verified" below.

PCBWay figures used, all from https://www.pcbway.com/capabilities.html:

| Item | Value |
|---|---|
| Min trace / spacing (Standard) | 4 mil (0.1 mm) |
| Min annular ring | 0.15 mm (6 mil), "For pads with vias in the middle" |
| Drill | "smaller than 0.2mm will be subject to extra charges" |
| Outline tolerance | ±0.2 mm CNC |
| Legend characters | "less than 0.15mm wide will be too narrow"; < 0.8 mm high too small; 1:5 ratio |
| Line to board edge (Advanced, CNC) | 0.25 mm normal |
| Hole spacing | via (≤ 0.45 mm) to hole ≥ 11 mil; component hole to hole ≥ 16 mil |
| Inner isolation ring, 4 layers | ≥ 7 mil |
| Green mask bridge | 4 mil normal "ICs spaced 8 mil"; 3–4 mil medium "ICs spaced 7–8 mil" |
| Trace/space for 35 µm outer (Advanced table) | ≥ 5/6 mil |
| 4-layer thickness | 1.0 mm offered; 4L minimum 0.6 mm normal |

## Measured board minimums (worst cases, KiCad coordinates in mm)

| Parameter | Board worst case | Where | PCBWay | Status |
|---|---|---|---|---|
| Track width | 0.150 (342 segments); power nets 0.30, one 0.25 VBAT stub | everywhere | 0.1 mm std | OK |
| Copper clearance | **0.1273** | U6 pad 5 (ALRT, NC) to GND track at (132.87, 70.85) | 0.1 mm std, 6 mil default | B4 |
| Clearance ≤ 0.1287 | 35 locations | e.g. USB_DM to U1 pad 25 (126.99, 60.45); SPI_SCK to U1 EPAD (121.0, 60.96); F1/F2/F3_RAW at J1 (115.8, 90.5) | | B4 |
| Via | 126 × 0.50 / 0.20, annular **0.150** (all 126) | | 0.15 mm | at limit (B15) |
| Hole to hole (edge to edge) | 0.457 | GND via (110.80, 80.40) to F4_ADC via (110.154, 80.519) | 11 mil = 0.28 | OK |
| Via to NPTH | 0.492 | GND via (122.537, 73.435) to J3 NPTH (123.54, 73.016) | 0.28 | OK |
| Via hole to other-net copper | ≥ 0.30 (none flagged at 0.30 probe) | | 7 mil inner | OK |
| NPTH to copper | **0.2005** | H1, H2 and the three J3 holes to GND pours on all 4 layers | 7 mil inner | OK, see B15 |
| Copper to routed edge | **0.300** | J1 MP pads (113.525 and 128.475, 92.35) to bottom edge y = 94; all pours 0.3005 | 0.25 normal | OK |
| Copper to antenna notch | 0.380 | GND via (121.821, 52.130) | 0.25 | OK |
| | 0.45 | U1 pads 36–48, 50, 53 | | OK |
| Mask web (pad to pad, 1:1 openings) | **0.150** | U3 (LGA) pads 1–2 | needs ≥ 8 mil IC spacing for a 4 mil dam | B5 |
| | 0.200 | U6 (TDFN) | | B5 |
| | 0.35 | U4 and U5 | | OK |
| Silk line width | 0.12 (all footprint silk) | | 0.15 min character width | B6 |
| Silk text | 0.8 / 0.12 (6 board texts); 1.0 / 0.15 (refs, "PCBWay") | | ≥ 0.8 high, ≥ 0.15 wide | B6 |
| Board-edge hole web | 2.4 (H1 to notch wall x = 112.5); 2.25 (H1 to boss arc) | | | NOTE |

## Findings

### B1. MAJOR: 23 SMD pads have unfilled through-vias in them; 3 more vias overlap pad edges

**Evidence** (`viainpad.py`, confirmed visually in `img/u1top.png`). All vias are 0.5/0.2, tented outside pads but open inside the pad openings:

- **U1 top-row GND pads 36, 37, 38, 39, 40, 41, 44, 45, 46, 47, 48** (0.4 × 0.8 mm) and **corner pads 50 and 53** (0.7 × 0.7). Vias sit at y 52.13–52.28. The 0.5 mm via copper is wider than the 0.4 mm pad.
- **U1 EPAD 49:** 8 of the 9 sub-pads have a via at the sub-pad centre, for example (121.000, 57.250).
- **U4 pad 2** (GND of the MCP6001): via at (131.699, 77.675).
- **J2 pad 3** (B side, Mill-Max GND pin): via at (130.750, 77.800). It is 0.85 mm from the pad centre, which is under the 1.83 mm pin flange.
- **Vias overlapping pad edges:**
  - D2 pad 1 at (130.600, 83.900); the drill edge is only 0.025 mm outside the mask opening.
  - U1 pad 52 at (114.538, 61.888).
  - U1 EPAD corner at (118.227, 55.568).

**Why it matters:**

- A 0.2 × 1.0 mm barrel holds about 0.031 mm³. A 0.4 × 0.8 pad with a 0.12 mm stencil leaves about 0.019 mm³ of solder, so the barrel can swallow most of the joint.
- On U4 pin 2 and J2 pin 3 these are single, functional joints. If either fails, the piezo buffer ground is lost or the battery-ground spring pin is weakened (the pin verticality issue STATUS.txt already flags).
- Espressif's HDG says to put EPAD vias in the gaps of a square paste grid "to reduce solder leakage issues when soldering the module EPAD to the substrate" (https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32c3/pcb-layout-design.html, Power Supply > Four-Layer PCB Design).

**How verified:** measured with pcbnew (pad shape collision with via centre) and render.

**Fix:**

- Move the U4 pad-2 and J2 pad-3 vias off the pads. There is room: U4 pin 2 can use the pour, and J2 pad 3 has the B.Cu pour plus pad 4.
- For U1, either:
  - drop the 13 top-row in-pad vias (the GND return is through the EPAD's 9 vias and pads 1, 2, 11, 14, 51, 52), or
  - order "via-in-pad, resin plugged and plated over" for those vias. PCBWay offers it at extra cost.
- Move the EPAD vias into the 0.525 mm gaps between sub-pads (Espressif pattern), or have them plugged and capped.
- Pull the D2 via 0.15 mm away from the pad.

**BENCH:** after the first reflow, check the U4 and J2 joints (continuity, pin tilt) and look for solder balls on the B side under U1.

### B2. MAJOR: U1 EPAD has 100 % paste coverage (18.9 mm²)

**Evidence:**

- All 9 EPAD sub-pads (1.45 × 1.45) carry full F.Paste: 9 × 2.10 = 18.9 mm².
- ESP32-C3-MINI-1 datasheet v2.2, §9 (Peripheral Schematics notes): "Too much soldering paste may increase the gap between the module and the baseboard. As a result, the adhesion between other pins and the baseboard may be poor."
- Combined with B1, paste volume and solder loss both vary from board to board.

**How verified:** read from pad layers (`pads.py`) and the datasheet text.

**Fix:** set the paste on pad 49 to about 45–55 %. Use one 1.0 × 1.0 mm aperture per sub-pad (48 %), or a pad-49 paste margin of −0.2 mm. Do this before ordering a stencil.

**BENCH:** check module standoff and edge-pad joints (side-view inspection or X-ray at PCBWay).

### B3. MAJOR (for PCBA): J2 cannot be machine-assembled as exported, and the board needs two reflows

**Evidence:**

- **One centroid for four pins.** The placement CSV has a single row "J2 … 129.0, −78.5, 0, bottom" for one footprint carrying 4 separate Mill-Max 0900-0 pins (BOM: qty 4, ED9000-ND). A pick-and-place machine cannot place 4 parts from one centroid.
- **Placeholder text.** The J2 value and description still read "part to select" / "Placeholder - part to select". This appears in the CSV, in the DRC field-mismatch warning, and on B.Fab.
- **Bulk packaging.** The Mill-Max datasheet says "Packaging: 15 - Packaged in Bulk, Reel Size: N/A", so the part is not tape-and-reel.
- **Single-reflow limit.** ESP32-C3-MINI-1 datasheet §12.3: "Solder the module in a single reflow". J2 is the only B-side SMT part. If the B side is reflowed after the top, the module sees two reflows.

**How verified:** compared the CSV with the board (`check` script: all 62 rows match position, rotation and side) and read both datasheets.

**Fix:**

- Split J2 into J2A–J2D footprints, one per pin, with MPN fields. Update the value and description.
- In the PCBA notes, either:
  - have J2 hand-soldered after the top reflow, with a fixture for verticality, or
  - reflow the B side first, so the module sees one reflow.
- Ask Mill-Max about a tape-and-reel packaging code if volume assembly is planned.

### B4. MINOR: 0.127 mm clearances need the non-default spacing option on the order

**Evidence:**

- Minimum clearance is 0.1273 mm at U6 pad 5 / GND track (132.87, 70.85).
- 35 locations are at or below 0.1287 mm, among them USB_DM/U1 pad 25, the SPI_SCK/U1 EPAD gaps, the F1/F2/F3_RAW fan-out at J1, I2C_SDA/SCL under U6 and the IMU_INT1/I2C_SDA pair on B.Cu at (124.95, 60.0).
- PCBWay's Standard table allows 4 mil, but its order form defaults to 6/6 mil. Its Advanced table lists 35 µm outer copper as "≥ 5/6 mil" for the normal process, so 5 mil spacing may be classed as medium difficulty.
- STATUS.txt already states 0.127 mm.

**How verified:** probe DRC at 0.16 mm.

**Fix:** select "5/5 mil" (or 4/4) min track/spacing on the form and check the quote line. Optionally widen the gaps around U6 pad 5 and the J1 fan-out to ≥ 0.15 mm, which is easy there.

### B5. MINOR: solder-mask dams on U3 will likely be removed, and U6 is borderline

**Evidence:**

- `pad_to_mask_clearance 0` (1:1 openings).
- The pad-to-pad web is 0.150 mm (5.9 mil) on U3 and 0.200 mm (7.9 mil) on U6.
- PCBWay needs "ICs spaced 8 mil" to keep a 4 mil green dam under the normal process, and 7–8 mil under the medium process. With their mask expansion, U3's dams go (gang relief) and U6 is marginal.

**How verified:** per-footprint mask-opening gap via pcbnew shape collision.

**Fix:** add an order note: "solder mask openings 1:1 as supplied; gang relief acceptable on U3 (LGA-14); keep dams on U6 if possible". The LGA without dams is common practice.

**BENCH:** check U3 SPI pins for bridges by continuity before power-up.

### B6. MINOR: the printed silkscreen is nearly unusable for hand assembly and has sub-spec strokes

**Evidence:**

- Only U2, U3, U4, U6 and SW1 (F side) and J2 (B side) have refdes on silkscreen.
- U1's silk refdes is at (121.0, 45.05), outside the board (top edge y = 46.0). The module's "Antenna Area" text sits in the routed-out notch. Neither will print.
- 57 references are on F.Fab only, at 0.5 mm.
- All footprint silk lines are 0.12 mm.
- The six board texts are 0.8 mm high with a 0.12 mm stroke: "X>" and "Y^" (the IMU axes), "NIVA REV C", "SERVICE", "CARTRIDGE" and J2. PCBWay: "Characters of less than 0.15mm wide will be too narrow to be identifiable".

**How verified:** `silk.py` and probe DRC (text_thickness).

**Fix:**

- Set board texts to ≥ 1.0 mm high with a 0.15–0.2 mm stroke, especially the IMU axis marks.
- For the hand-assembled first article, produce an assembly drawing (F.Fab plot) or an interactive BOM instead of relying on silk.
- Footprint 0.12 mm outlines are acceptable. PCBWay usually prints them, but they may be faint.

### B7. MINOR: the boards cannot be told apart from Rev C.1

**Evidence:**

- The only revision text that prints is "NIVA REV C" on B.Silkscreen. "NIVA POD REV C" on the F side is on a non-plotted layer.
- The job file has `"Revision": "rev?"`.
- STATUS.txt says C.1 boards must not be used for J2 because their pads are undersized, and a C.1 quote exists (W1032027AS1M1).

**How verified:** read the silk texts and the gbrjob.

**Fix:** print "NIVA POD C.2 2026-11" on B silk at 1.0 mm / 0.15 mm, and set the title-block revision.

### B8. MINOR: tracks run inside the Tag-Connect J3 keep-out and too close to its contact pads

**Evidence** (Tag-Connect footprint TC2030-IDC-NL-FP Rev B):

- Note 1: "No tracks or vias in the shaded KEEP OUT AREA".
- Note 2: "No other track or signal within 0.020" of any contact pad".

Measured:

- CHIP_EN runs along x = 120.36, y 70.62–72.00, between pads 1 and 3.
- USB_DP runs along y = 72.01, x 121.64–123.79, between the pad rows.
- USB_DM and BOOT9 also leave between pads.
- Track-to-other-net-pad edge gaps are 0.161–0.172 mm against the 0.508 mm asked for.
- A GND via is 0.200 mm from pad 6 and a +3V3 via 0.254 mm from pad 1 (same nets; tented bumps).

The footprint geometry itself is correct (see the table).

**How verified:** pcbnew segment distances.

**Fix:** escape every J3 pad outward and drop through vias outside the 0.5 mm ring. Route the crossings on In2, not B.Cu.

**BENCH:** check that all 6 pogo contacts read reliably with the plug hand-held.

### B9. MINOR: several bypass capacitors are far from their pins

**Evidence** (pad-to-pad straight-line distance):

| Pin | Nearest bypass | Distance | Guidance |
|---|---|---|---|
| U4 MCP6001 VDD (pin 5) | C42, 100 nF | 8.05 mm | DS20001733L §4.4: "local bypass capacitor (i.e., 0.01 µF to 0.1 µF) within 2 mm" |
| U5 TLV75533 IN (pin 1) | C6, 4.7 µF | 6.32 mm | TI §7.4.1: "Place input and output capacitors as close as possible to the device" |
| U5 OUT (pin 5) | C8 100 nF / C7 10 µF | 2.83 / 5.23 mm | TI §7.4.1 (same) |
| U6 MAX17048 VDD (pin 3) | C9 | 5.09 mm | datasheet: "Bypass with 0.1µF to GND" |
| U2 MCP3208 VDD (pin 16) | C4, 100 nF | 3.14 mm | Microchip §6.4: "A bypass capacitor value of 1 µF is recommended" (value item for the schematic reviewer) |

**How verified:** `decap.py`.

**Fix:**

- Add a 100 nF 0603 at U4 pin 5, on the right of U4 near (135.2, 76.9).
- Move C6 next to U5 pin 1 and C9 next to U6 pins 2–3.
- Consider 1 µF at U2 VDD.

### B10. MINOR: power distribution is long and thin

**Evidence:**

- **+3V3 to the module.** The shortest copper path from U5 pin 5 to U1 pin 3 is **67.9 mm** of 0.30 mm track. It runs down past the LEDs, across to U2 pin 16 (41.1 mm from U5), up the left edge past C4 and C2, then through C3 to the module. That is about 0.11 Ω at 20 °C, so about 40 mV DC drop at 0.35 A Wi-Fi TX. The ADC's VDD and the V33_HALF divider sit on the same trunk and see the module's current steps.
- **Espressif guideline.** The HDG asks that "The width of the main power traces should be no less than 25 mil" (0.635 mm).
- **VBAT path.** J2 to U5 is about 31 mm of 0.30 mm track (about 0.05 Ω) through a **single** 0.2 mm via at (135.236, 80.605). The +3V3 net also has only one via, to J3.

**How verified:** shortest-path script over the track graph.

**Fix:**

- Feed U1 from U5 by the direct route (about 15 mm across the board centre) at ≥ 0.5 mm, and branch the analog loads off it.
- Add a second VBAT via next to (135.236, 80.605).

**BENCH:** scope +3V3 at U1 pin 3 and read MCP3208 CH6 during Wi-Fi TX bursts.

### B11. MINOR: the MAX17048 CELL pin senses VBAT at the LDO, not at the cell

**Evidence:**

- U6 pins 2–3 (CELL, VDD) tap VBAT at U5 pin 3, through the 0.25 mm stub (130.51, 70.75) → (129.29, 70.06) → (129.29, 66.23).
- That point is after the shared J2 contacts, the single via and about 30 mm of 0.3 mm track that carry the full load current.
- ModelGauge reads the drop under load (about 20 mV at 0.4 A on the PCB alone, plus the spring contacts) as a lower cell voltage.

**How verified:** VBAT track listing.

**Fix:** run a separate Kelvin trace from the J2 pad 1/2 junction straight to U6 pin 2.

**BENCH:** compare the SOC reading with radio idle and with radio transmitting.

### B12. MINOR: solid pad connections everywhere (tombstoning and rework)

**Evidence:**

- The GND pours on F.Cu, B.Cu and In2 use solid pad connection (`connect_pads yes`, zone pad connection FULL).
- About 30 0603 parts have one pad flooded with a dedicated plane via and the other pad on a 0.15–0.30 mm track: C1, C3–C9, C11–C20, C40–C42, R12, R13 and others.
- J2 pads 3–4 are flooded into B.Cu and have via-in-pad.

**How verified:** zone settings (`zones.py`) and renders.

**Fix:** use thermal reliefs (0.25 mm gap, 2–4 spokes of 0.3 mm) on SMD pads in pours. Keep the U1 EPAD and U6 EP solid.

**BENCH:** first-article inspection of the C11–C15 and R11–R15 rows for tombstones. For hand rework of J2, use preheat.

### B13. MINOR: no PCBA panel features

**Evidence:**

- No fiducials and no tooling holes on the board.
- MLCCs C11 (courtyard 0.62 mm from the left edge) and C20 (0.53 mm from the right edge), and R1, R3 and R11, are within 0.7 mm of routed edges.
- J1's courtyard overhangs the bottom edge by 0.25 mm (the connector front, by design).
- The board has 0.5 mm pitch LGA and TDFN parts plus the module.

**How verified:** `dump.py` and the courtyard script.

**Fix:** have PCBWay panelise with rails carrying 3 fiducials and tooling holes. Keep breakaway tabs off the C11/C20 edges and off the J1 edge, or add 1 mm copper/2 mm mask fiducials on the board.

### B14. NOTE: copper to edge and the antenna notch

The minimum is 0.300 mm at J1's MP pads and all pours, against PCBWay's 0.25 mm normal.

At the notch:

- GND vias are 0.380 mm from the edge.
- U1 pads 36–48, 50 and 53 are 0.45 mm from the edge.

With ±0.2 mm outline tolerance, a notch-side via ring could end up about 0.18 mm from the cut. That is acceptable, and the vias are GND.

The notch inner corners (112.5, 51.5) and (129.5, 51.5) will take the router radius. C3 is the nearest part, 0.79 mm from the corner, so there is no conflict.

The notch floor is 0.15 mm inside the module keep-out boundary (module-relative y −3.05 vs −2.9). That only matters if PCBWay asks about it.

### B15. NOTE: vias and NPTH

- All 126 vias have a 0.150 mm ring, exactly PCBWay's minimum, with no margin. The drill is 0.2 mm, so there is no "smaller than 0.2 mm" surcharge.
- NPTH-to-copper is 0.2005 mm on all layers (H1, H2, J3). That passes the 4-layer 7 mil isolation figure, with about 0.125 mm left after ±0.075 mm hole position tolerance. Fine; the copper there is GND.
- H1 webs are 2.4 mm to the notch and 2.25 mm to the boss arc. STATUS.txt asks PCBWay to confirm; there is no capability issue.

### B16. NOTE: Gerber and drill set is consistent; small items for the order

- Re-export is identical to the committed set.
- The zip is identical to `gerber/` (14 files).
- PTH: 126 × 0.200. NPTH: 3 × 0.991 + 2 × 2.200. This matches STATUS.txt.
- Edge.Cuts is closed. Two arc endpoints miss line endpoints by 1 nm (Y −94000001 vs −94000000; X 137.685857 vs 137.685857, Y −46000001), which is harmless. Nothing else is on Edge.Cuts.
- The job file says `"Finish": "None"` (order says ENIG). Its stack-up is KiCad's default 3 × 0.28 mm dielectric, not PCBWay's.
- STATUS.txt's order settings name only outer copper. State "inner copper 1 oz", or accept PCBWay's default. No impedance control is needed.

**Doc error:** STATUS-CLOSURE §3 puts the U1 top-pad edge at "about y 46.95" (pod frame). Measured, it is 48.05 pod (51.95 KiCad), 0.45 mm from the notch floor.

### B17. NOTE (positive): In1 is a continuous GND plane

In1 is one outline, 1394 mm², broken only by via antipads. Non-functional via pads are kept on the inner layers. Antipad clusters merge only at a few via triplets of about 2 mm, so there are no slots under F.Cu signals.

In2 is a GND pour cut by about 6 signal tracks (BUTTON diagonal and others). B.Cu signals still have In1 within 0.6 mm.

No SPI or I2C track runs within 0.4 mm of an analog track (F*_ADC, *_RAW, VEXC, PZ_*, V33_HALF).

### B18. NOTE / BENCH: antenna environment (already known)

- The ear pours on all 4 layers start 1.5 mm from the notch walls, so 3.4 mm from the module sides.
- M2 screw heads at H1 and H2 sit about 3.5 mm from the module sides.
- Espressif asks for 15 mm.

The cut-out follows the HDG's "cut off the base board on both sides of the antenna and below it". A range test in the closed pod is required, as STATUS.txt says.

### B19. NOTE: IMU mounting

- A tented CS_IMU via at (133.93, 57.43) sits under the U3 LGA body. Its mask bump can tilt a 0.83 mm-high LGA.
- U3 is 6.5 mm from the H2 screw.

**Fix:** move the via just west of the body.

**BENCH:** check accelerometer and gyro offset before and after screw torque.

### B20. NOTE: placement CSV

All 62 rows match the board in position, rotation and side. H1, H2 and J3 are correctly excluded.

Before PCBA:

- Y values are negative (KiCad page origin). Set the aux origin to the lower-left board corner.
- Values are not MPNs.
- 8 MPN fields are missing on footprints (DRC warnings).
- Ask PCBWay for their placement preview to confirm rotations against the KiCad-zero orientation (SOT-23, SOT-23-5, SOIC-16, LGA, TDFN, LEDs).

### B21. NOTE: bring-up access

| Signal | Access |
|---|---|
| +3V3, EN, USB D±, BOOT9, GND | J3 |
| VBAT | J2 pads (B side) and C6/C9 pads only |
| I2C, SPI, VEXC | no test pads |
| UART0 TX (GPIO21, ROM log) | only at R46 pad 1 |

**Suggestion:** 1 mm test pads on the B side near J3 for VBAT, VEXC, SCL and SDA.

### B22. NOTE: footprints not independently verified because the source would not download

- **SW1 KMR2:** the KiCad stock footprint pairs the two top pads as "1" and the two bottom pads as "2" (0.9 × 1.0 mm at ±2.05 / ±0.8). The Littelfuse/C&K PDF returned 403.
- **D4/D5 KT-0603:** pad 1 = cathode = GND (KiCad convention). The Kento cathode mark was not checked.
- **U3:** checked against KiCad stock and TN0018's rule (see table). st.com timed out.
- **U6:** 90-0065 not re-fetched (analog.com timed out).

**BENCH:** before first power, check SW1 continuity (open at rest, closed when pressed) and diode-test D4/D5.

### B23. NOTE: tracks under the MCP3208

VEXC (0.3 mm), +3V3 (0.3 mm) and a VEXC via at (114.35, 73.30) run under the MCP3208 SOIC body. Microchip §6.4 says "no traces running underneath the device or the bypass capacitor". These are DC nets, so this is acceptable. It is listed for completeness.

### B24. NOTE: J2 pad size has no etch margin

The J2 pads are Ø2.08 mm, which equals Mill-Max's "SMT Pad Size: Circular - .082"" exactly. Outer-layer etch can make them about 0.05 mm smaller.

**Fix:** Ø2.15–2.20 keeps the VBAT–GND gap between pads 2 and 3 ≥ 0.34 mm and gives a full fillet ring around the 1.829 mm flange.

## Footprints checked

| Ref | Footprint | Checked against | Result |
|---|---|---|---|
| U1 | NIVA:ESP32-C3-MINI-1 | Espressif datasheet v2.2 Fig. 11-1 and Table 3-1 | **Correct.** 48 × 0.4 × 0.8 at 0.8 pitch; 4 × 0.7 corner pads; EPAD 9 × 1.45 in a 5.4 mm block; pad-centre spans 11.8, 9.8, 11.9 and 9.9; antenna area 5.4 mm; body 13.2 × 16.6; pin numbers and NC pads match Table 3-1. Paste and vias: B1, B2. |
| U2 | SOIC-16 3.9 × 9.9, P1.27 | BOM MCP3208-CI/SL = 16-lead 150 mil SOIC (21298E); pin 1 and silk mark | **Correct package.** IPC-nominal 0.60 × 1.95 pads; 21298E has no land drawing. |
| U3 | LGA-14 3 × 2.5, P0.5 (LayoutBorder3x4y) | KiCad stock copy (pads identical by pcbnew comparison); TN0018 rule (pin + 0.1 mm) | **Consistent** (0.35 mm-wide lands, KiCad's footprint for LSM6DS3/DSL/DSM LGA-14L). ST datasheet not fetched. Pin-1 silk present. |
| U4 | SOT-23-5 | MCP6001 DS20001733L Table 3-1 (MCP6001, not R or U): 1 VOUT, 2 VSS, 3 VIN+, 4 VIN−, 5 VDD | **Correct.** Nets PZ_BUF / GND / PZ_BIAS / PZ_BUF / +3V3, so a follower. |
| U5 | SOT-23-5 | TLV755P DBV pinout (1 IN, 2 GND, 3 EN, 4 NC, 5 OUT); DBV0005A example land 1.1 × 0.6, 2.6 span | **Correct.** KiCad 1.325 × 0.6 pads at 2.275 span are compatible. |
| U6 | NIVA:TDFN-8-1EP 2 × 2, ADI 90-0065 | Repo's reading of 90-0065 / 21-0168; geometry measured | **Consistent.** 0.30 × 0.70 pads, 1.98 span, EP 0.80 × 1.38, 4 paste windows = 56 % EP. 90-0065 not re-fetched. |
| D2 | SOT-23 | Nexperia BAV199 (2020) pinning: 1 A1, 2 K2, 3 K1/A2 | **Correct.** GND / +3V3 / PZ_BIAS clamps PZ_BIAS to both rails. |
| D4, D5 | LED_0603 | KiCad pad 1 = cathode, on GND | **Correct by convention.** Vendor mark not checked (B22). |
| SW1 | SW_Push_1P1T_NO_CK_KMR2 | KiCad stock | **Not verified** (B22). |
| J1 | JST GH SM10B-GHS-TB, side entry | JST eGH "PC board layout": 0.6 × 1.7 at 1.25; MP 1.0 × 2.7; 5.4 overall; 1.0 gap | **Correct.** Pin 1 at left matches the silk mark. |
| J2 | NIVA:SpringContact 1 × 4, Ø2.08, B side | Mill-Max 0900-0 datasheet: SMT pad Ø.082"; flange Ø1.829 | **Correct size**, at minimum (B24). Placement and CSV: B3. Via-in-pad: B1. |
| J3 | Tag-Connect TC2030-IDC-NL, B side | Tag-Connect TC2030-IDC-NL-FP Rev B | **Correct.** Pads Ø0.787 at 1.27, rows ±0.635; NPTH 3 × Ø0.991 at (−2.54, 0) and (+2.54, ±1.016); no paste; mirrored correctly for the B side. Keep-out: B8. |
| H1, H2 | MountingHole 2.2 mm M2 | NPTH 2.2, no copper ring | **Correct** for M2 clearance. |
| C/R (52 × 0603, C2 0805) | KiCad C/R_0603_1608Metric, C_0805 | IPC nominal | **Correct.** No 0402 parts on the board. |

## Files

- Scratch copy and probe outputs: `/tmp/claude-1000/-home-shubh--config-Claude-2-scratch-workspaces-2595bbd3-486e-4d55-adb3-42bc4a600053-aa6046d8-b7dc-48d9-a636-b816ff0df9d6-scratch-2026-11-09-f3ef21/4f06da30-94b6-435e-9cde-4cf407449d98/scratchpad/bwork/`. It contains `probe-drc.rpt`, `base-drc.rpt`, `regen/`, `zipx2/` and `img/`.
- Scripts: `/tmp/claude-1000/-home-shubh--config-Claude-2-scratch-workspaces-2595bbd3-486e-4d55-adb3-42bc4a600053-aa6046d8-b7dc-48d9-a636-b816ff0df9d6-scratch-2026-11-09-f3ef21/4f06da30-94b6-435e-9cde-4cf407449d98/scratchpad/bscripts/`
- Datasheet text extracts: `.../scratchpad/dsB/` (TC2030-NL, MCP3208, MCP6001, TLV755P, Mill-Max 0900). The shared `.../scratchpad/ds/` holds the Espressif PDF, BAV199 and JST GH text.
