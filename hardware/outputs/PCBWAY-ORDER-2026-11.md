# PCBWay order, November 2026: Niva ankle-hub set (Rev C.2)

One PCBWay order for a complete ankle-hub set: three bare PCBs and the printed parts. It replaces the Rev C.1 pod quote **W1032027AS1M1**. Shubham asks PCBWay to move the sponsorship (and the $30 credit) to this quote. Nothing has been ordered or paid.

**Not in this order:**
- the insole L/R flex boards (FSR/PVDF materials and flex rules not chosen);
- PCB assembly. The boards are bare and are populated by hand from each board's BOM;
- the bought-in parts (section 4).

Status words used below:
- **Ready**: the files exist, KiCad DRC shows 0 errors and 0 unconnected, and the board's blockers that could be closed from datasheets are closed.
- **Not verified**: still true of everything here. Nothing has been built, powered or measured, and no board has had an independent review or a PCBWay DFM reply.

## 1. PCBs

| # | Item | Upload | Qty | Layers | Size (mm) | Thickness | Finish | Min track / space | Min hole | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | Pod Rev C.2 | `NIVA-RevC2-protected-steps/electronics-C2-working/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod-C2/NIVA-pod-C2-PCBWay-gerbers.zip` | 5 | 4 | 34 × 48 | 1.0 | ENIG | 5/5 mil (0.15 mm track, 0.127 mm space) | 0.2 mm (126 vias, 0.5 mm pad) | Ready |
| P2 | Battery cartridge strip, Rev C.2 | `NIVA-3D-engineering-prototype/electronics/cartridge/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-cartridge/NIVA-cartridge-PCBWay-gerbers.zip` | 5 | 2 | 3.4 × 30 | 0.8 | ENIG (dock contact pads) | 5/5 mil (0.2 mm track, 0.15 mm space) | 0.3 mm (3 vias, 0.6 mm pad) | Ready |
| P3 | Charging dock, Rev C.2 | `NIVA-3D-engineering-prototype/electronics/dock/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-dock/NIVA-dock-PCBWay-gerbers.zip` | 5 | 2 | 58 × 56 | 1.6 | ENIG (flat pads for the J2 pins) | 5/5 mil (0.2 mm track, 0.15 mm space) | 0.3 mm (10 vias, 0.6 mm pad) | Ready |

**Settings common to all three PCBs:**
- Board type: single pieces. Material: FR-4, TG150 (default).
- Copper: 1 oz outer. Inner copper (pod only): default.
- Mask and silk: green mask, white silk.
- Vias: tented. The Gerbers have no mask openings on vias.
- Gold thickness: default (1 µ").
- Edge connector: no.

**PCBWay order number:** PCBWay prints one on the silkscreen unless told otherwise. The pod and the 3.4 mm strip have no free area for it, so choose "remove" for those. The dock's bottom side has room if you prefer "specify a location".

**"PCBWay" mark:**
- All three boards carry "PCBWay" on B.Silkscreen, 1 mm high with a 0.15 mm stroke, for the Future Innovators Program.
- The pod mark dates from 25 October. The cartridge and dock marks were added on 9 November; DRC reports no silkscreen warnings for them.

**5/5 mil:**
- The pod's 0.127 mm minimum space is 5 mil.
- The cartridge and dock rule minimum is 0.15 mm, which is 0.002 mm under 6 mil.
- Picking 5/5 mil for all three avoids a DFM query.

**Each board's open items are in the `STATUS.txt` next to its zip.** Summary:

| # | Closed on 9 Nov | Still open |
|---|---|---|
| P1 | J2 pads Ø2.08 mm for Mill-Max 0900-0 (from 3 Nov); lid recessed so the pins work at their rated 0.508 mm travel (2.97 mm gap, re-audited in FreeCAD); C.2 Gerbers exported. KiCad 10.0.7: DRC 0 errors, 0 unconnected; ERC 0 errors. | J2 plunger has 0.37 mm side clearance in the lid pocket against an estimated 0.27 mm cartridge shift: measure the first printed lid. Re-read ADI land 90-0065 (T822-3C flag). Antenna range test in the closed pod. Web between H1 and the antenna notch is about 2.4 mm. |
| P2 | F1 = Bourns MF-PSMF035X-2. The cell PCM (EEMB spec) allows 0.3 A constant and 0.8 A for 3 s; F1 holds 0.30 A at 40 °C and trips by 0.75 A. Lead gauge AWG28 per the EEMB spec, and the pads fit it. DRC 0 errors; ERC 0 errors, 0 warnings. | F1 adds 0.25–1.2 Ω, which is 88–420 mV at a 0.35 A radio burst: measure VBAT sag; MF-PSMF050X-2 is the fallback. The spec read is for the no-NTC cell variant. ENIG wear under the dock pins. PCBWay may want the 3.4 mm strip panelised. |
| P3 | J2 = 3 × Mill-Max 0900-0 on Ø2.08 mm pads (DRC 0 errors). Dock well floor lowered 0.83 mm so the pins reach the cartridge pads at rated travel (they were 0.32 mm short). NTC assumption stated: 10 kΩ, B 3435 K. | With 1 % resistors the charge window is −1.0…46.0 °C, against the cell's 0–45 °C charge range. Trim R6–R8 once the purchased cell's NTC is known (BOM change, no copper change). A 100 kΩ NTC would not charge at room temperature. |

**Rev C.1 pod set:** `NIVA-3D-engineering-prototype/electronics/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod/` is marked superseded. Do not order it.

## 2. 3D-printed parts

Upload the STLs; they are already in print orientation.

**Paths:**
- `NIVA-3D-engineering-prototype/mechanical/STL-print-parts/` (materials from `PRINT-AND-ASSEMBLY.md`);
- `NIVA-RevC2-protected-steps/mechanical/STL-print-parts/` for the ankle mounts (`PRINT-AND-FIT.md`).

**PCBWay process names:** FDM PETG, FDM ASA, FDM TPU, SLA "UTR-8100 (transparent)". PCBWay states ±0.2 mm for both FDM and SLA at this size.

**Colours:** the design calls for navy and pale grey-blue. Pick the nearest colour PCBWay stocks; colour does not affect fit.

**Quantities:** one right pod and one left pod, two cartridges plus a spare lid, and one dock.

| # | File | PCBWay process / material | Qty | Print box (mm) | Notes |
|---|---|---|---|---|---|
| M1 | `01_RearHousing_R`, `01_RearHousing_L` | FDM PETG (ASA also fine) | 1 + 1 | 42 × 60 × 14.4 | no supports; bay ceiling bridges 28.8 mm |
| M2 | `02_FrontCover_R`, `02_FrontCover_L` | FDM PETG (or ASA) | 1 + 1 | 42 × 60 × 7.2 | cosmetic face on the bed |
| M3 | `03_BatteryCartridgeCup` | FDM PETG | 2 | 28 × 41 × 8 | fit trials with a dummy cell only (a live cell needs a moulded cup) |
| M4 | `04_BatteryCartridgeLid` (**Rev C.2**, plates 0.37 mm deeper) | FDM PETG | 3 | 27.6 × 37.1 × 2.0 | one spare: measure the 1.8 mm pocket width on the first print |
| M5 | `13_AnkleCradle_R`, `13_AnkleCradle_L` (ankle hub) | FDM PETG | 1 + 1 | 69 × 63 × 6.6 | `SHIN_R` = 60 mm is a placeholder; Rev C `05_Cradle_R/L` (63 × 63 × 6.6, PETG) has the same pod interface if you want the plain cradle instead |
| M6 | `16_AnkleSaddlePad_TPU` | FDM TPU | 2 | 50 × 60 × 7.5 | bonded under the ankle cradle; with `05_Cradle`, use `06_SoftCradlePad_TPU` (50 × 60 × 2) instead |
| M7 | `15_TailBlank_TPU_R`, `15_TailBlank_TPU_L` | FDM TPU | 1 + 1 | 19.6 × 7.4 × 4.2 | closes the tail opening on an ankle hub |
| M8 | `07_Button_TPU` | FDM TPU | 2 | 13 × 13 × 5.3 | 1.5 mm flange overhang may need support |
| M9 | `08_LightWindow_Clear` | SLA UTR-8100 (transparent) | 2 | 9.6 × 3.6 × 6.0 | |
| M10 | `09_SeamGasket_TPU` | FDM TPU, fit trial only | 2 | 41.4 × 59.4 × 0.5 | the real gasket is die-cut 0.5 mm silicone/EPDM sheet; skip if PCBWay rejects a 0.5 mm print |
| M11 | `10_DockBase` (**Rev C.2** label) | FDM PETG | 1 | 64 × 62 × 8 | no supports |
| M12 | `11_DockTop` (**Rev C.2**, well floor 0.83 mm lower) | FDM PETG | 1 | 64 × 62 × 12.4 | well floor is a 29 mm bridge printed top-down |
| M13 | `12_DockLightPipe_Clear` | SLA UTR-8100 (transparent) | 1 | 3.4 × 3.4 × 11.0 | |

The shoe-node collar clip (`14_CollarClip_R/L`) is left out: it belongs to the shoe-node role, and its collar and tail thicknesses are placeholders.

## 3. What changed in the CAD for this order

- **Pod lid:** `hardware/work/niva_layout.py` has `CART['plate_recess'] = 0.37`, and `niva_cad_lib.py` cuts the four pockets that much deeper.
  - The pod audit now imports the C.2 board.
  - Its only intersection is J2 on the plates: 1.27 mm³, the intended 0.51 mm preload.
  - J2 no longer intersects the lid.
- **Dock well:** `DOCK['floor_z']` is now set from the pin working height (2.972 mm) instead of a fixed 2.8 mm headroom. The dock audit gives 0.50 mm pin compression seated and 0.40 mm on the latch hook; the only intersection is pins on pads. The dock is now 20.4 mm tall (was 21.2).
- **Spring-pin envelopes:** both J2 STEP envelopes are drawn from the Mill-Max 0900-0 key dimensions: flange Ø1.829, body Ø1.499 to 2.083, plunger Ø1.067 to 3.480.
- **Unchanged parts:** pod parts other than the lid were regenerated, checked to have the committed volumes, and restored from git so the diff only shows real changes.

## 4. Bought-in parts the set needs (not PCBWay)

Per set of 5 boards, from the BOMs in each `exports/` folder:

| Part | Qty | Where |
|---|---|---|
| Mill-Max 0900-0-15-20-76-14-11-0 | 4 per pod + 3 per dock (35 for 5 + 5) | DigiKey ED9000-ND (3 Nov research pass: USD 0.657 at 10) |
| Bourns MF-PSMF035X-2 | 1 per cartridge | DigiKey / LCSC, not priced here |
| EEMB LP502030-PCM-NTC-LD (or a confirmed equivalent) | 1 per cartridge | ask EEMB for the NTC variant's spec before buying |
| Brass contact plates 1.6 × 3.0 × 0.4, gold flash | 4 per cartridge | not selected |
| Pod parts | per `NIVA-RevC2-protected-steps/bom/NIVA-pod-BOM-costed.csv` | LCSC / DigiKey |
| Dock parts | per `NIVA-3D-engineering-prototype/electronics/dock/exports/NIVA-dock-BOM.csv` | LCSC / DigiKey, not priced here |
| M2 thread-forming screws, bumpers, strap | per `PRINT-AND-ASSEMBLY.md` §2 | not selected |

## 5. Before paying

1. Upload all three zips. Read PCBWay's DFM reply, especially:
   - the pod's antenna notch corners and the 2.4 mm web;
   - the 3.4 mm cartridge strip;
   - the 0.2 mm pod vias;
   - the dock's two 0.6 × 1.2 mm plated USB-C slots.
2. Get an independent schematic and layout review of the pod. None has been done.
3. Ask PCBWay to move the sponsorship from W1032027AS1M1 to the new quote (Shubham).
