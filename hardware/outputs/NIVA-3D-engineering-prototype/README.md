# NIVA 3D engineering prototype — Revision C

Bilateral gait-sensing research/screening kit: a passive five-region force insole with heel PVDF film, a protected flat tail, and a lower-shin pod (ESP32-C3, MCP3208, LSM6DSO32, removable battery cartridge, one button, one light) controlled offline from a phone over Bluetooth.

> **Status: engineering prototype for fit, handling and bench work. Not a released medical device. Not for fabrication.**
> - The PCB is an **unrouted placement prototype**.
> - The battery cell is **not selected**, and no charging electronics exist.
> - Nothing here establishes clinical performance.
> - The sensing concept does **not** measure medial knee contact force.

## Contents

```
NIVA-3D-engineering-prototype/
├── README.md                          this file
├── mechanical/
│   ├── NIVA-RevC-assembly.FCStd       native FreeCAD 1.1 assembly: groups Pod_R and Pod_L (left pod at x - 80 mm)
│   ├── NIVA-RevC-assembly.step        STEP AP214 of the same assembly (includes the KiCad PCBA solids)
│   ├── STEP-parts/                    9 printable parts in the pod frame (_R/_L where sided)
│   ├── STL-print-parts/               the same parts, rotated to the recommended print orientation
│   ├── PRINT-AND-ASSEMBLY.md          materials, orientation, fasteners, clearances, sequence, unverified fits
│   ├── geometry-validation.json       per-part solid/mesh checks and print bounding boxes
│   └── interference-report.json       pairwise interference + functional gaps against the real PCBA model
├── electronics/
│   ├── NIVA-pod.kicad_pro/.kicad_sch  KiCad 9 project: root sheet
│   ├── NIVA-controller.kicad_sch      sub-sheet: MCU, ADC, IMU, power, insert connector
│   ├── NIVA-heel-and-indicator.kicad_sch   sub-sheet: PVDF buffer, status emitters
│   ├── NIVA-pod.kicad_pcb             4-layer 34 x 48 mm UNROUTED PLACEMENT PROTOTYPE
│   ├── NIVA.kicad_sym, Espressif.kicad_sym, NIVA.pretty/, sym-lib-table, fp-lib-table   project libraries
│   ├── 3dmodels/                      STEP models used by the board (KiCad library, Espressif, *_ENVELOPE)
│   ├── ELECTRICAL-REVIEW.md           Rev B findings, ERC, pin/boot review, analog values, open items
│   ├── component-net-map.json, pin-map.csv
│   ├── exports/                       schematic PDF + SVG, ERC report, BOM, netlist
│   │   └── pcb/                       DRC report, assembly drawings (PDF), PCBA STEP + GLB
│   └── work-routing/                  Specctra DSN + Freerouting log (autoroute attempt, NOT adopted)
├── renders/                           9 captioned images: 01..05 Blender scenes, pcb_* KiCad raytraces (colour reference for the PCB)
│                                      raw/ and pcb-raw/ hold the uncaptioned originals
└── blender/
    ├── NIVA-RevC-scenes.blend         editable Blender 4.5 file: 5 scenes + hidden library collections
    └── 01..05_*.glb                   glTF binary of each scene
```

## Opening the files

- **FreeCAD 1.1:** open `mechanical/NIVA-RevC-assembly.FCStd`; it was saved with FreeCAD 1.1.3. Each object carries `Material`, `Kind` and `Note` properties. The model is a solid assembly, not a parametric feature tree. Change dimensions in the generator and re-run it (see *Regenerating*).
- **KiCad 9:** open `electronics/NIVA-pod.kicad_pro`.
  - Project libraries resolve through `${KIPRJMOD}`, and 3D models through `${KIPRJMOD}/3dmodels`.
  - The Espressif symbol has been converted from KiCad 10 to KiCad 9 format; see the review.
  - The PCB shows a ratsnest by design.
- **Blender 4.5:** open `blender/NIVA-RevC-scenes.blend`.
  - Scenes `01_Pod_Assembled` … `05_Bilateral_Kit` each have their own camera, lights and studio floor.
  - The `LIB_*` collections in `NIVA_library` hold the source meshes (render-hidden).
  - Pod parts, the PCBA root and the insoles record their source file in a `source` custom property.
- **Any glTF viewer:** `blender/*.glb`, `electronics/exports/pcb/NIVA-pod-PCBA.glb`.

## Revision changes (Rev B → Rev C)

Rev B inputs came from the earlier session and were committed as received. They are retrievable from git history (commit `b7eb80f`, `hardware/`).

**Mechanical.** In Rev B, a limited clash check passed, but a full audit showed parts that could not assemble. Rev C findings and fixes:

- **M1 Gasket:** it sat in the parting plane with no groove or stop (42 and 31 mm³ overlaps). It is now a continuous rim gasket, 0.5 → 0.35 mm, with boss hard stops.
- **M2 Cover screws:** each head bore on 0.6 mm of plastic over a 4.2 mm unsupported span. Rev C adds full-height bosses and Ø4.5 counterbores.
- **M3 PCB mounting:** the board had no standoffs, and two of its holes were over the open battery pocket. Rev C has two bosses outside the bay, self-supporting side ledges, bottom ledges and front clamp ribs. The board is notched around the case bosses.
- **M4 Cable path:** the aperture was below the connector, and the strain relief ran into the bay wall. Rev C moves the aperture to J1 height, split on the parting line, with an overmoulded boot that carries the L/R key.
- **M5 Light window:** it ended 3.5 mm above the LED. The light pipe now reaches 0.3 mm above the two emitters.
- **M6 Battery connection:** a JST cable connector on the top side could not reach a rear-removable cartridge. Rev C uses underside spring contacts through a bay-ceiling window onto flush lid plates. The cartridge lid is bonded.
- **M7 Cradle retention:** there was no undercut, no latch and no L/R key. Rev C adds chamfered rails, a bottom stop, a flat-printing cantilever latch, and an L/R key post and slot, plus debossed marks and tactile dots.
- **M8 Bay ceiling:** new. Fingers and debris stay off the board when the cartridge is out, and the windows give access to the contacts and service pads only.

**Electronics.**

- The Rev B schematics never parsed in KiCad (every symbol record was unclosed), and they were two unconnected projects.
- Rev C is one connected hierarchy with ERC at 0 errors.
- It adds VEXC current limiting and sensing, ID filtering, low-leakage piezo clamps, retuned anti-aliasing, per-device decoupling, the spring-contact battery interface, and a service pad set with no charge path.

Details: `electronics/ELECTRICAL-REVIEW.md`.

**New shared source of truth:** `work/niva_layout.py`. The KiCad board outline, mounting holes and every placement are generated from it, and so are the matching enclosure features.

## Printing and assembly

See `mechanical/PRINT-AND-ASSEMBLY.md`:
- rigid vs flexible material assignment and print orientation for all 9 parts;
- fastener list (4 × M2×10, 2 × M2×5, 1 × M2×6 per pod) and nominal clearances;
- the assembly and charging-removal sequence;
- the list of unverified fits and safety mechanisms.

## Electrical verification status

| Check | Result |
|---|---|
| KiCad 9.0.9 parses all sheets | yes: 66 symbols, 3 sheets |
| ERC (all severities, default rules, no exclusions) | 0 errors, 1 reviewed warning (unused IMU hub pins tied to GND) |
| Schematic ↔ PCB parity (DRC) | 0 issues |
| DRC placement / clearance / footprint | 0 errors; 4 warnings (isolated inner GND before vias, module silk at the antenna edge) |
| Routing | **not done**: 183 unconnected items; Freerouting stalled at about 40 unrouted, not adopted |
| Built, powered, measured | **no** |
| Gerbers / drill / pick-and-place | **not produced** (not fabrication-ready) |

## Complete vs provisional

| Area | Complete in this package | Provisional / open |
|---|---|---|
| Enclosure | Rev C solids and printable STL/STEP for R and L, full interference audit vs the real PCBA, fastener list, orientation | Every 0.2 mm fit, sealing, latch and screw durability, skin contact, cleaning — see §5 of the assembly doc |
| Battery | Cartridge cup/lid/contact geometry and the charging-exclusion concept | Cell not selected; 300 mAh fit not established; cartridge electronics and dock not designed |
| Schematic | Connected hierarchy, reviewed values, ERC-clean, PDF/SVG/BOM/netlist | Bench validation of the analog front end, spring-contact part, datasheet re-checks listed in the review |
| PCB | Placement, outline, mounting, keepouts, 3D models, DRC-clean placement | Routing, RF/return-path review, fab rules — **unrouted** |
| Insole / tail | Visual model from the 1:1 fit template (outline, toe slot, tail tab) | Sensor laminate and tail routing to the toe (A201 length, hold H1); no rigid joints underfoot |
| Renders | 5 Blender scenes + 4 KiCad raytraces, captioned with status | Soft goods (strap, tail) are parametric bands, not CAD parts |

## Regenerating

Everything is script-generated. Run from `hardware/work/`:

```powershell
# enclosure (FreeCAD 1.1 python). Reads niva_layout.py and, if present, electronics/exports/pcb/NIVA-pod-PCBA.step
& 'C:\Program Files\FreeCAD 1.1\bin\python.exe' build_niva_cad_revC.py
# schematic (plain python 3; set KICAD9_SYMBOL_DIR if the portable KiCad is not under work\tools3d)
python build_niva_schematic_revC.py
# then, with KiCad 9: ERC + netlist, PCB placement, finalize, DRC
kicad-cli sch export netlist --format kicadsexpr -o ..\outputs\NIVA-3D-engineering-prototype\electronics\exports\NIVA-pod.net ..\outputs\NIVA-3D-engineering-prototype\electronics\NIVA-pod.kicad_sch
.\tools3d\kicad\bin\python.exe build_niva_pcb.py place
.\tools3d\kicad\bin\python.exe build_niva_pcb.py finalize "UNROUTED PLACEMENT PROTOTYPE - RATSNEST ONLY - NOT FOR FABRICATION"
# scenes (Blender 4.5), then captions (python + Pillow)
blender -b --factory-startup -P build_niva_scenes.py
python caption_renders.py
```

The schematic generator uses deterministic UUIDs, so re-running it keeps the schematic and PCB linked. Re-run the netlist, `place` and `finalize` after any schematic change.

## Sources and third-party assets

- **Engineering brief:** "Niva prototype blueprint: from bench insole to health-camp kit", draft v0.1 (`hardware/brief/engineering-brief.txt`). Its component choices were reviewed, not assumed validated. Its prices, literature figures and unpublished study results are not adopted here.
- **Rev A vector blueprints:** `outputs/niva-vector-blueprints/`. The 1:1 fit template provides the insole geometry used in the renders.
- **Espressif KiCad libraries** (ESP32-C3-MINI-1 symbol, footprint and STEP model): github.com/espressif/kicad-libraries, commit `dd76561` (2026-07-28). CC-BY-SA 4.0 with the KiCad library design-use exception. The symbol was converted to KiCad 9 format; the footprint and model are unmodified.
- **KiCad 9 libraries:**
  - Symbols and footprints: KiCad 9.0.9, official `kicad/kicad:9.0` image.
  - 3D models: gitlab.com/kicad/libraries/kicad-packages3D, tag 9.0.0; the KMR2 model is from `master`, since it is absent in 9.0.0.
  - License: CC-BY-SA 4.0 with the design-use exception.
- **Simplified envelopes (not supplier models):**
  - `TDFN-8-2x2mm_ENVELOPE.step` (MAX17048; KiCad has no model);
  - `NIVA_SpringContact_1x04_ENVELOPE.step` (part not selected);
  - cell and cell-protection envelopes in the enclosure model. These are orange in the renders.
- **Tools:**
  - FreeCAD 1.1.3 (conda-forge).
  - KiCad 9.0.9 (Docker).
  - Blender 4.5.14 LTS (`bpy` from PyPI; `.blend` saved in 4.5 format).
  - CadQuery 2.7 (envelope models).
  - Freerouting 2.1.0 (attempt only).
  - DejaVu Sans font for the debossed CAD lettering.
- **Datasheets cited in the review:** Espressif ESP32-C3 and ESP32-C3-MINI-1, Microchip MCP3208 and MCP6001, ST LSM6DSO32, TI TLV755P, ADI MAX17048, Tekscan A201. They are cited as in the brief. Where a figure matters it is marked "verify": several manufacturer sites were unreachable from the build environment.

## Checks actually completed

- KiCad CLI: parse, ERC, netlist, BOM, PDF/SVG export; PCB DRC with schematic parity; STEP/GLB export; raytraced renders.
- FreeCAD: every printable part is one valid solid with a closed, manifold mesh. A pairwise interference check covered every part of the right pod, including the KiCad PCBA solids. The only intersections are the intentional 0.4 mm spring-contact preload. Functional gaps are listed in `interference-report.json`.
- Blender: every scene was rendered and visually inspected for clipping, floating parts and wrong geometry. Issues found and fixed included:
  - edge-on bands;
  - pods overlapping insoles;
  - tails dipping below the floor;
  - uncoloured KiCad GLB components.
- **Not done:** any physical print, electrical build, measurement, routing, RF test, sealing test, skin or pressure assessment, or cleaning test.
