# Closing the STATUS.txt blockers (pod PCB), Rev C.2 working copy

**Update 9 November 2026:** the J2 contact gap is closed in CAD (lid plates recessed 0.37 mm, gap 2.97 mm, re-audited), and C.2 PCBWay Gerbers exist in `electronics-C2-working/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod-C2/`. What is still open is in that folder's `STATUS.txt` and in `../PCBWAY-ORDER-2026-11.md`. The text below is the 3 November record.

3 November 2026. Covers the three hardware blockers listed in `../NIVA-3D-engineering-prototype/electronics/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod/STATUS.txt`.

**Nothing inside `fab-PROTOTYPE-PCBWAY/` or the Rev C.1 KiCad files was changed.** The changes are in `electronics-C2-working/`, which is a copy.

**Not built, powered or measured.**

**Sources:**
- Mill-Max data are from the datasheet PDF, read directly.
- ADI and Espressif figures were read by a research pass on 3 November 2026. My own downloads of the ADI land-pattern PDF timed out, so re-read 90-0065 before ordering a stencil.

| Blocker | State after this pass |
|---|---|
| J2 spring-contact part not selected | **Part selected**, land pattern replaced in C.2 (DRC clean). **Open:** the Rev C.1 contact gap is too small for the part; a mechanical change is needed (§1). |
| U6 MAX17048 land pattern unconfirmed | **Compared** with ADI 90-0065; C.2 uses the ADI land (DRC clean); pin use matches the datasheet. **Open:** stencil, 3D model, re-read of the drawing (§2). |
| Antenna keep-out / placement | **Compared** with Espressif's Hardware Design Guidelines. Rev C.1 misses the preferred placement. C.2 cuts the board away under the antenna (DRC clean). **Open:** 15 mm clearances cannot be met in this pod; radiated test required (§3). |
| Independent review, PCBWay DFM | **Open**; not addressable here. |

## 1. J2 cartridge spring contacts

### Selected part

**4 × Mill-Max 0900-0-15-20-76-14-11-0**, surface-mount spring-loaded pins at 2.54 mm pitch. Datasheet: www.mill-max.com/products/datasheet/0900-0-15-20-76-14-11-0, pages 1–2, read 3 November 2026.

- **Mounting:** "Surface mount on .082 Dia. min. solder pad", i.e. a 2.08 mm minimum pad.
- **Height and travel:**
  - Initial (free) height 3.480 mm.
  - Max stroke 0.991 mm.
  - Rated travel (mid-stroke) 0.508 mm. The drawing table gives .0195 in (0.495 mm) for 0900-0.
- **Spring force:** 15 g initial, 60 g at mid-stroke.
- **Electrical:** 8 A at 30 °C rise; 6.40 A derated. Contact resistance 20 mΩ max.
- **Plating:** 20 µin gold over nickel on body and plunger; 10 µin gold on the spring.
- **Life:** 100,000 to 1,000,000 cycles at mid-stroke.
- **Shock and vibration:** no discontinuity > 1 µs at 50 g shock; 10–2000 Hz, 20 G vibration.
- **Price and stock:** DigiKey ED9000-ND, USD 0.77 / 0.657 / 0.5584 at 1 / 10 / 100 pieces, 80,370 in stock. These figures are from the research pass (3 November 2026) and were not re-fetched by me.

### Alternatives found

- **Mill-Max 811-22-004-30-000101:** the same pin in a 4-way moulded strip, which gives better alignment. Its price was not confirmed; DigiKey no longer carries it, and Mill-Max's check-stock page showed 1,638 at Mouser.
- **Harwin S1761-42R:** a leaf contact with 2.50 mm working height, 4 A rating and 1,500 cycles. It fits the Rev C.1 gap, but its 3.00 × 4.50 mm pads cannot sit at 2.54 mm pitch.

### Why the Rev C.1 geometry does not suit the part

The board underside is at z = 11.8 and the lid plate tops are at z = 9.2 (`niva_layout.py`, `niva_cad_lib.py`), so the gap is 2.6 mm.

- The 0900-0 at its rated travel works at 3.480 − 0.508 = **2.972 mm**.
- In a 2.6 mm gap it is compressed 0.88 mm of its 0.991 mm maximum, which is 89 % and close to bottoming. That is outside the travel at which the rated life is given.
- **Change needed (C.2 mechanical, not yet modelled):** increase the gap by about 0.37 mm. One way is to recess the four lid plates 0.37 mm deeper in `04_BatteryCartridgeLid`, so the PCB and pod stack are unchanged. Then re-run the pod interference audit; the intended preload changes from 0.4 mm to about 0.5 mm.

### Land pattern

- **Rev C.1:** the placeholder pads are 1.6 × 2.4 mm rectangles, narrower than the 2.08 mm minimum pad. **A 0900 pin fitted to the Rev C.1 first-article boards would sit on a pad below the datasheet minimum.** That is acceptable for bench handling at most.
- **C.2:** four Ø2.08 mm round pads at the same centres. One GND fan-out via was moved by 0.04 mm to clear pad 1: (123.935, 79.1454) → (123.9005, 79.1631) in KiCad coordinates, together with its track end.
- **Result:** DRC 0 errors, 0 unconnected.
- **Still to do:** replace the envelope 3D model with a supplier model, and check solder-paste volume and pin verticality during reflow (bench).

## 2. U6 MAX17048, TDFN-8 2 × 2 mm

### Package

ADI MAX17048/MAX17049 datasheet Rev 7, p. 18: 8 TDFN-EP, package code T822+3, outline 21-0168, land pattern 90-0065.

Outline 21-0168 Rev M, row T822-3:

| Dimension | Value |
|---|---|
| Body (D, E) | 2.00 mm |
| Height (A) | 0.75 mm |
| Pitch (e) | 0.50 mm |
| Lead width (b) | 0.25 ± 0.05 mm |
| Lead length (L) | 0.30 mm |
| Exposed pad (D2 × E2) | 0.80 × 1.20 ± 0.10 mm |

### Land pattern comparison

| | Rev C.1 (KiCad stock footprint) | ADI 90-0065 Rev E | C.2 working copy |
|---|---|---|---|
| Signal pad (w × l) | 0.25 × 0.775 | 0.30 × 0.70 | 0.30 × 0.70 |
| Pad centres (x) | ±0.9875 (span 1.975) | span 1.98 | ±0.99 |
| Exposed-pad land | 0.80 × 1.20 | 0.80 × 1.38 (±0.02) | 0.80 × 1.38 |
| Paste on the EP | 4 × 0.32 × 0.48 | not given | unchanged; review with the stencil |

The Rev C.1 pads are workable: 0.05 mm narrower and 0.075 mm longer than ADI's.

**Flag:** the 90-0065 code box lists T822-3C, not T822-3. The research pass found the two codes dimensionally identical in 21-0168. Confirm this.

C.2 uses the ADI land through a project footprint, `NIVA:TDFN-8-1EP_2x2mm_P0.5mm_ADI-90-0065`, with the schematic and library footprint fields updated. **Result:** DRC 0 errors, 0 unconnected; ERC back to the Rev C.1 single warning.

### Pin use against the datasheet

Datasheet p. 6, Table 3, Fig. 14:

| Pin | Datasheet | Schematic | Match |
|---|---|---|---|
| 1 CTG | connect to GND | GND | yes |
| 2 CELL, 3 VDD | battery +; 0.1 µF bypass on VDD | VBAT; C9 100 nF | yes |
| 4 GND, EP | GND | GND | yes |
| 5 ALRT | optional, may be left unconnected | unconnected | yes |
| 6 QSTRT | connect to GND if not used | GND | yes |
| 7 SCL, 8 SDA | internal pull-downs; system provides pull-ups | R4/R5 4.7 kΩ to +3V3 | yes |

**Still open:** a supplier 3D model (the current one is an envelope), the stencil, and the purchased package.

## 3. Antenna keep-out (ESP32-C3-MINI-1)

**Sources:**
- ESP32-C3-MINI-1 datasheet v2.2, §11.2 and Fig. 3-1 note A. It points to the Hardware Design Guidelines.
- ESP32-C3 Hardware Design Guidelines §1.4.7, docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32c3/pcb-layout-design.html, Figs. 19–21.

| Guideline | Rev C.1 | C.2 working copy |
|---|---|---|
| Place the module's PCB antenna outside the base board, feed point near the edge | **Miss:** the module top is 0.25 mm inside the board edge | **Improved:** the board is cut away under the antenna area (pod frame x 12.5–29.5 mm, from the edge to y 48.5 mm), so the antenna overhangs free air. The module pads stay on the board (top pad edge at about y 46.95). |
| Otherwise cut the board on both sides of and below the antenna; Fig. 21 shows a 15 mm minimum left, right and beyond | **Miss:** 3.4 mm copper keep-out each side, board material left in place | **Still a miss:** the cut-out is 1.9 mm wider than the module on each side (module x 14.4–27.6 mm). 15 mm is impossible in a 42 mm wide pod. |
| No copper under the antenna | Meets (keep-out on all layers) | Meets (no board) |
| Enough ground copper and dense ground vias near the antenna | Stitching vias run along the keep-out edge | Unchanged; the notch floor was set at y 48.5 so that five stitching vias keep 0.3 mm edge clearance |
| At least 15 mm clearance in all directions from the enclosure | Likely miss: the housing wall is about 4 mm beyond the board edge (`niva_layout.py`: pod 60 mm, board top at 54 mm) | Same |
| Metal near the antenna (M2 screws 6–8 mm away; LiPo cell about 6 mm away) | Not covered explicitly by the C3 guide; both are inside the 15 mm zone | Same |
| Test throughput and range on the finished product | Not done | Not done: **required**, in the closed pod, on the body, in both roles |

The C.2 notch passes DRC with 0 errors and 0 unconnected (silk-at-edge warnings drop from 3 to 2). It does not touch the enclosure, because it only removes board material.

Mechanically, the web between the H1 hole and the notch is about 2.4 mm. Check it with PCBWay. Inner corners will take the fab's router radius.

## What this means for the PCBWay order

The Rev C.1 Gerbers are unchanged and still match `STATUS.txt`. If they are ordered as they are, the boards are fine for bench bring-up of everything except J2:
- The J2 pads are below Mill-Max's minimum pad.
- The U6 land is workable but not ADI's.
- The antenna placement is the Rev C.1 one.

Whether to hold the order for a C.2 board is the team's decision. A C.2 board would also need fresh fab outputs, a DFM reply and an independent review. **No C.2 Gerbers have been made.**
