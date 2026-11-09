# CHANGELOG: Rev C.1 → Rev C.2 working copy (Niva: Protected Steps)

## 2026-11-09 (evening): design review fixes

Five independent reviews (pod schematic, pod layout and DFM, cartridge/dock/battery, mechanics and insole, software) are in `../verification-2026-11-09/`, summarised in `../VERIFICATION-2026-11-09.md`.

Fixed here:
- **J2 regrouped:** footprint `NIVA:SpringContact_2x2pairs_MillMax0900_SMD`. Pads 1-2 VBAT stay at pod y 21.5; pads 3-4 GND move to y 13.0 and tie to adjacent GND vias. The cartridge lid plates are now 5.5 mm apart (were 0.94 mm).
- **In-pad vias:** the via that sat in old J2 pad 3 is clear of all pads, and the stub via inside U4 pad 2 is deleted.
- **U1:** EPAD paste reduced to about half (margin ratio -0.15). U1 is now the ESP32-C3-MINI-1-N4X, since the N4 is NRND.
- **Parts and silk:** C4 is 1 µF. The bottom silk reads NIVA REV C.2.
- **Checks:** DRC 0 errors, 0 unconnected; ERC 0 errors. Gerbers, drills, placement and PCBA STEP re-exported.
- **Mounts:** `build_ps_mounts.py` audits against the C.2 board. `ankle_cradle()` no longer refills the screw-head relief or the latch arm slots with its wings.

## 2026-11-09: PCBWay order set

**Status:** fab outputs made; still not built, powered or measured. Order sheet: `../PCBWAY-ORDER-2026-11.md`.

- **Pod C.2 Gerbers:** `electronics-C2-working/exports/pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod-C2/` (zip, Gerbers, drills, placement, `STATUS.txt`). Same export flags as the C.1 PCBWay set, checked by re-exporting C.1 and diffing (identical apart from dates). KiCad 10.0.7, stock libraries, parity on: DRC 0 errors, 0 unconnected; ERC 0 errors.
- **C.2 PCBA STEP:** `electronics-C2-working/exports/pcb/NIVA-pod-PCBA.step`. `electronics-C2-working/3dmodels` is a symlink to the Rev C.1 model folder.
- **J2 mechanics closed in CAD:** the shared generators now carry Rev C.2. `niva_layout.CART['plate_recess'] = 0.37` lowers the four lid plates, so the board-to-plate gap is 2.97 mm. `04_BatteryCartridgeLid` STL/STEP and `NIVA-RevC-assembly.FCStd/.step` in `../NIVA-3D-engineering-prototype/mechanical/` were regenerated, and the audit now imports the C.2 board.
- **Spring-pin envelopes:** `build_niva_envelopes.py` draws both J2 models from the Mill-Max 0900-0 datasheet key dimensions.
- **Dock and cartridge:** see their `fab-PROTOTYPE-PCBWAY/*/STATUS.txt` in `../NIVA-3D-engineering-prototype/electronics/`. Dock J2 = 3 × Mill-Max 0900-0 on Ø2.08 mm pads, dock well floor 0.83 mm lower; cartridge F1 = Bourns MF-PSMF035X-2.
- **Rev C.1 PCBWay set** marked superseded in its `STATUS.txt`; its files are unchanged.

## 2026-11-03

**Status:** a working copy for review. Nothing has been printed, built, powered or measured.

**Rev C.1 is untouched:**
- `../NIVA-3D-engineering-prototype/` (including `fab-PROTOTYPE-PCBWAY/`, the Rev C.1 Gerbers, and the KiCad and FreeCAD sources) has not been modified.
- The Rev C.1 generators in `hardware/work/` were only read and executed for their definitions.
- `git status` shows only new, untracked folders.

### Electronics (`electronics-C2-working/`, a copy of the Rev C.1 pod project)

- **J2 cartridge contacts:** the placeholder 1.6 × 2.4 mm rectangles became Ø2.08 mm round pads at the same centres, for 4 × Mill-Max 0900-0-15-20-76-14-11-0. The datasheet's minimum pad is 0.082 in (2.08 mm). One GND fan-out via moved 0.04 mm to clear pad 1. Footprint and description updated in `NIVA.pretty`.
- **U6 MAX17048:** new project footprint `NIVA:TDFN-8-1EP_2x2mm_P0.5mm_ADI-90-0065`. Signal pads 0.30 × 0.70 mm at ±0.99 mm; EP land 0.80 × 1.38 mm, per ADI land pattern 90-0065 as read by the research pass. The schematic and symbol footprint fields were updated.
- **Antenna:** the board outline is notched under the ESP32-C3-MINI-1 antenna area (pod frame x 12.5–29.5 mm, to y 48.5 mm), so the antenna overhangs, as Espressif's guidelines prefer. The notch floor sits 0.15 mm inside the antenna area to keep 0.3 mm edge clearance to five GND stitching vias.
- **Zones** refilled by KiCad DRC (`--refill-zones --save-board`, on the copy only).
- **Result:**
  - ERC: 0 errors, 1 warning (as in C.1).
  - DRC: 0 errors, 0 unconnected, 12 warnings.
- **Not regenerated:** Gerbers, drill files, placement, the PCBA STEP/GLB.
- **Not changed:** the schematic connectivity and the pin map.

### Mechanical (`mechanical/`, new parts; the Rev C.1 pod body is unchanged)

- `13_AnkleCradle_R/L`: the Rev C cradle interface with parametric strap slots and A/R role marks.
- `16_AnkleSaddlePad_TPU`: a concave leg-side pad. `SHIN_R` is a placeholder.
- `15_TailBlank_TPU_R/L`: keyed plug for the tail opening when no insole is connected (ankle hub).
- `14_CollarClip_R/L`: the same interface plus a hook, an inner tongue and a tail slot, for the shoe collar. `COLLAR_T` and `TAIL_T` are placeholders.
- Validation (`mounts-validation.json`): single solids, closed manifold meshes and re-read exports. The interface is identical to the Rev C cradle (0.0000 mm³ difference). The only interference is the intended tongue preload.

### Interim cabinet (`interim-cabinet/`, new)

- A parametric two-part printable box for the current ESP32 + MPU6050 + OLED perfboard prototype. Every board dimension is a "MEASURE" parameter in `cabinet-params.json`.
- **Features:**
  - USB opening with an outside recess;
  - OLED window with a recess for a clear acrylic pane;
  - insole-cable U-notch closed by a lid tongue (strain relief) and an outside cable-tie lug;
  - corner pads and clamp posts for the perfboard;
  - 4 × M3 bosses;
  - strap wings with slots (ankle-hub use);
  - UP arrow on the lid.
- Validation (`cabinet-validation.json`): both parts are single solids with closed meshes; the USB plug path is clear; the only interference is the intended cable squeeze.

### Documents

- `BASELINE-ERC-DRC.md`
- `STATUS-CLOSURE.md`
- `ROLE-DESIGN-NOTE.md`
- `PINMAP.md`
- `bom/` (costed BOM)
- `mechanical/PRINT-AND-FIT.md`
- `interim-cabinet/PRINT-SETTINGS.md`

### Renders

- Four Blender 3D renders: `PS01`–`PS04`, all `*_3D-render.png`.
- Each is captioned and corner-tagged "3D RENDER - NOT A PHOTO".
- Saved in `hardware/outputs/renders-protected-steps/` and copied to `niva/media/cad/outputs/renders-protected-steps/`.
- Scenes: `renders-work/NIVA-RevC2-ProtectedSteps-scenes.blend`.

### Still open (selected; full lists in each document)

- **J2 contact gap:** 2.6 mm today vs the 2.97 mm the pin needs. Lid plates to be recessed about 0.37 mm; not modelled.
- **Antenna:** 15 mm clearances not achievable in this pod; radiated test needed.
- **Review and DFM:** independent review and PCBWay DFM; C.2 fab outputs not made.
- **Placeholders:** every shoe, leg and board placeholder must be measured.
- **Skin-side pressure:** the collar-clip tongue needs clinician approval before any at-risk wearer.
- **Battery life per role:** to be measured.
