# NIVA 3D engineering prototype — Revision C.1

Bilateral gait-sensing research/screening kit with four parts:

- **Insole:** a five-region force insole with a heel PVDF film and a protected flat tail.
- **Pod:** worn on the lower shin (ESP32-C3, MCP3208, LSM6DSO32, removable battery cartridge, one button, one light) and controlled offline from a phone over Bluetooth.
- **Cartridge:** a removable battery cartridge.
- **Dock:** a desk dock that charges bare cartridges.

> **Status: engineering prototype for fit, handling and bench work. Not a released medical device. Not released for fabrication.**
> - Every KiCad board is routed and passes KiCad ERC and DRC. That is an automated check, **not a design review**.
> - Gerbers exist only in `fab-REVIEW-ONLY-NOT-RELEASED/` folders, each with a list of open blockers.
> - Nothing has been built, powered or measured. Nothing here establishes clinical performance.
> - The sensing concept does **not** measure medial knee contact force.
> - Sealing, skin contact and cleaning are **unverified**: see `VERIFICATION-PLAN.md`.

## What changed in Rev C.1 (this update)

| Open item in Rev C | Rev C.1 resolution | Still open |
|---|---|---|
| Pod PCB unrouted. Freerouting stalled at about 40 open connections, no Gerbers. | GND fan-out first: every GND pad gets its own via to the solid In1 plane. Signals are then autorouted, followed by pours and stitching. **0 DRC errors, 0 unconnected, parity clean.** Review-only Gerbers/drill/placement files. | Independent review, fab DFM, return-path and RF review |
| R33 = 220 Ω made every force reading depend on VEXC, so firmware had to normalise it. | The MCP3208 VREF is now VEXC, so readings are ratiometric in hardware and need **no firmware normalisation**. CH6 becomes a tail-fault monitor. | Bench confirmation |
| Dual clamp diodes not used (contradictory KiCad symbol). | One **BAV199** series pair (SOT-23) on a project symbol that states the data-sheet pinning (1 A1, 2 K2, 3 K1/A2). | Check the reel marking; the PDF host was unreachable, so the pinning comes from two search sources quoting the Nexperia data sheet |
| Battery cell not selected; 300 mAh fit unproven. | EEMB **LP502030** class (230 mAh min, 20.5 × 32 × 5.3 mm max, PCM + NTC). The cartridge is resized around its maximum size plus 8 % swell. **300 mAh does not fit and is not claimed.** | A purchased lot, swelling under cycling, and cell safety evidence |
| Cartridge electronics not designed. | `electronics/cartridge/`: interconnect strip PCB with a series polyfuse and gold dock pads. No active parts. The cell PCM is protection layer 1. | Polyfuse part number, pad wear |
| Charging dock not designed. | `electronics/dock/`: USB-C, MCP73831 at 100 mA, and a **hardware NTC window** (LM393 → PROG gate). `mechanical/` has a printable dock with a keyed well, tab ledge, snap latch, spring-pin holes and a light pipe. | Spring-pin part not selected; thresholds and termination unmeasured |
| Insole tail could not reach the big toe (A201 tails too short, hold H1). | `electronics/insole/`: an **integrated sensing flex** (R and L). Five printed shunt-mode electrodes and PVDF bond pads, with copper lanes to the heel tab. Only F.Cu and no parts underfoot. A 115 mm tail runs to a stiffened above-collar transition that carries the insert ID resistor. | FSR ink film selection and characterisation, fatigue, lamination |
| No sealing, skin-contact or cleaning claims. | Still **none claimed**. `VERIFICATION-PLAN.md` gives materials, test methods and proposed acceptance criteria. | Every test in that plan |
| Blender PCB close-up read too light green. | Root cause: KiCad 9's GLB writer stores sRGB colours as linear glTF factors. The import now linearises them, and the close-up lights no longer mirror into the glossy mask. | — |

## Contents

```
NIVA-3D-engineering-prototype/
├── README.md                          this file
├── VERIFICATION-PLAN.md               sealing / skin contact / cleaning (and dependent) tests - plan only, no claims
├── mechanical/
│   ├── NIVA-RevC-assembly.FCStd/.step pod assembly: groups Pod_R and Pod_L (left pod at x - 80 mm), incl. routed PCBA
│   ├── NIVA-dock-assembly.FCStd/.step dock assembly with dock PCBA and a seated cartridge
│   ├── STEP-parts/, STL-print-parts/  12 printable parts (01-09 pod, 10-12 dock); STLs in print orientation
│   ├── PRINT-AND-ASSEMBLY.md          materials, orientation, fasteners, clearances, pod/cartridge/dock assembly, open items
│   ├── geometry-validation.json, dock-geometry-validation.json     per-part solid/mesh checks
│   └── interference-report.json, dock-interference-report.json     pairwise interference + functional gaps
├── electronics/
│   ├── NIVA-pod.kicad_pro/.kicad_sch/.kicad_pcb + 2 sub-sheets     pod: 4-layer 34 x 48 mm, ROUTED
│   ├── ELECTRICAL-REVIEW.md           findings, ERC, pin/boot review, analog values, power, PCB, open items
│   ├── exports/                       pod schematic PDF/SVG, ERC, BOM, netlist; pcb/ DRC, assembly PDFs, PCBA STEP+GLB,
│   │                                  fab-REVIEW-ONLY-NOT-RELEASED/ (Gerber, drill, placement, STATUS.txt)
│   ├── cartridge/  NIVA-cartridge.*   interconnect strip (hand-routed) + exports/ (same structure)
│   ├── dock/       NIVA-dock.*        charging dock (autorouted) + exports/
│   ├── insole/     NIVA-insole-R.*, NIVA-insole-L.*   sensing flex, right/left medium + exports/
│   ├── 3dmodels/                      STEP models (KiCad library, Espressif, *_ENVELOPE stand-ins)
│   └── work-routing/                  Specctra DSN/SES + Freerouting logs (the sessions actually imported)
├── renders/                           11 captioned images: 01-07 Blender scenes, pcb_* KiCad raytraces; raw/, pcb-raw/ originals
└── blender/
    ├── NIVA-RevC-scenes.blend         editable Blender 4.5 file: 7 scenes + hidden library collections
    └── 01..07_*.glb                   glTF binary of each scene
```

## Opening the files

- **FreeCAD 1.1:** open `mechanical/NIVA-RevC-assembly.FCStd` or `NIVA-dock-assembly.FCStd`. Objects carry `Material`, `Kind` and `Note` properties. The models are solid assemblies generated by script, so change dimensions in `work/niva_layout.py` and re-run the generators.
- **KiCad 9:** open any `.kicad_pro`.
  - Project libraries resolve through `${KIPRJMOD}`; 3D models through `${KIPRJMOD}/3dmodels` (pod) or `${KIPRJMOD}/../3dmodels`.
  - The insole flex boards use negative y coordinates: the insole frame has the heel at y = 100 mm and the toe above it.
- **Blender 4.5:** open `blender/NIVA-RevC-scenes.blend`, which has scenes `01_Pod_Assembled` … `07_Insole_Flex`. The `LIB_*` collections hold the source meshes and GLBs (render-hidden).
- **Any glTF viewer:** `blender/*.glb` and `electronics/**/exports/pcb/*-PCBA.glb`.

## Boards at a glance

| Board | Size / layers | Routing | KiCad ERC / DRC (schematic parity on) |
|---|---|---|---|
| Pod | 34 × 48 × 1.0 mm, 4 layers (In1 = GND plane) | GND fan-out, then Freerouting signals, then pours; 547 segments, 126 vias | 0 errors, 1 reviewed warning / **0 errors, 0 unconnected**, 3 silk warnings (module outline at the antenna edge) |
| Cartridge strip | 3.4 × 30 × 0.8 mm, 2 layers | hand-routed | 0 / 0, 0 unconnected |
| Dock | 58 × 56 × 1.6 mm, 2 layers | Freerouting + GND pours | 0 / 0, 0 unconnected |
| Insole flex R, L | 0.12 mm polyimide; F.Cu only underfoot | generated paired lanes; B.Cu only at the above-collar transition | 0 / 0, 0 unconnected |

## Printing and assembly

See `mechanical/PRINT-AND-ASSEMBLY.md`. It covers:
- material and print orientation for all 12 printed parts;
- fasteners for the pod and dock;
- nominal clearances measured in CAD;
- pod, cartridge and dock assembly sequences;
- the list of unverified fits and safety mechanisms.

## Complete vs provisional

| Area | Complete in this package | Provisional / open |
|---|---|---|
| Pod enclosure | Rev C solids and printable STL/STEP for R and L; interference audit against the routed PCBA (only the intended spring preload overlaps) | Every 0.2 mm fit, sealing, latch and screw durability, skin contact, cleaning |
| Battery | Selected cell class; cartridge cup, lid, strip PCB, pads and windows; charge-only-when-removed concept | Purchased lot, swelling, lid welding, cell safety evidence |
| Dock | Schematic, routed PCB and printable enclosure; audit shows only the intended spring-pin compression | Spring-pin part, measured thresholds and termination, latch life |
| Schematic | Connected hierarchy, ratiometric ADC, reviewed values, ERC-clean | Bench validation of the analog front end, datasheet re-checks listed in the review |
| Pod PCB | Routed, DRC-clean, review-only fab data | Independent review, fab DFM, RF and return-path review |
| Insole | Sensing flex R/L (schematic, routed layout, review-only fab data); visual insert from the 1:1 fit template | FSR film, lamination, fatigue, sweat ingress, other sizes (no automatic grading) |
| Renders | 7 Blender scenes + 4 KiCad raytraces, captioned with status | Soft goods (strap, tail) are parametric bands, not CAD parts |

## Regenerating

Everything is script-generated. From `hardware/work/` (paths below are the Linux build used for this package: KiCad 9.0.9 in Docker via a `kicad9` wrapper, FreeCAD 1.1.3, `bpy` 4.5, Freerouting 2.1.0 via `niva-route`, which is Freerouting headless on `work-routing/<name>.dsn`):

```sh
python3 build_niva_schematic_revC.py            # pod schematic + project rules
python3 build_niva_power_schematics.py          # cartridge + dock schematics
python3 build_niva_insole_flex.py               # insole flex schematics, footprints, lane geometry (needs shapely)
# netlists: kicad-cli sch export netlist --format kicadsexpr -o <dir>/exports/<name>.net <name>.kicad_sch
kicad9 python3 build_niva_pcb.py place <pod|cartridge|dock|insole-R|insole-L>
niva-route NIVA-pod 100 900                     # (and NIVA-dock); cartridge and insoles are hand/generated
kicad9 python3 build_niva_pcb.py finalize pod "<status>" ../outputs/.../work-routing/NIVA-pod.ses
kicad9 python3 build_niva_pcb.py finalize cartridge "<status>" hand     # likewise insole-R / insole-L
python3 export_niva_electronics.py              # ERC, DRC, PDFs, BOMs, STEP/GLB, review-only fab data
./render_kicad_pcb.sh                           # KiCad raytraces of the pod
PYTHONPATH=/opt/freecad/lib /opt/freecad/bin/python build_niva_envelopes.py   # spring-pin envelope model
PYTHONPATH=/opt/freecad/lib /opt/freecad/bin/python build_niva_cad_revC.py    # pod enclosure + audit
PYTHONPATH=/opt/freecad/lib /opt/freecad/bin/python build_niva_dock_cad.py    # dock enclosure + audit
/opt/bpyenv/bin/python build_niva_scenes.py && python3 caption_renders.py
```

- **UUIDs:** the schematic generators use deterministic UUIDs, so re-running them keeps each schematic and PCB linked.
- **Autorouting:** Freerouting is not deterministic. The committed `.ses` files are the ones that were imported and DRC-checked; a new routing run must be re-checked.

## Sources and third-party assets

- **Engineering brief:** "Niva prototype blueprint: from bench insole to health-camp kit", draft v0.1 (`hardware/brief/engineering-brief.txt`). Its component choices were reviewed, not assumed validated. Its prices, literature figures and unpublished study results are not adopted here.
- **Rev A vector blueprints:** `outputs/niva-vector-blueprints/`. The 1:1 fit template supplies the insole outline, the sensor-region centres and the heel tab used by the flex and the renders.
- **Espressif KiCad libraries** (ESP32-C3-MINI-1 symbol, footprint and STEP model): github.com/espressif/kicad-libraries, commit `dd76561`. CC-BY-SA 4.0 with the design-use exception. The symbol was converted to KiCad 9 format; the footprint and model are unmodified.
- **KiCad 9 libraries:** symbols and footprints from KiCad 9.0.9. 3D models from gitlab.com/kicad/libraries/kicad-packages3D, tag 9.0.0 (KMR2 from `master`). CC-BY-SA 4.0 with the design-use exception.
- **Simplified envelopes (not supplier models; orange in the renders):**
  - `TDFN-8-2x2mm_ENVELOPE.step` (MAX17048);
  - `NIVA_SpringContact_1x04_ENVELOPE.step` (pod J2);
  - `NIVA_SpringPin_1x03_ENVELOPE.step` (dock J2);
  - the cell, drawn at its published maximum size.
- **Component data used in Rev C.1** (from web search, because manufacturer sites were blocked from the build environment):
  - MCP3208 VREF range 0.25 V–VDD and VREF current (Microchip DS21298);
  - MCP73831 PROG behaviour and I_REG = 1000 V / R_PROG (Microchip);
  - LM393 input common-mode behaviour (TI);
  - EEMB LP502030 size and capacity (EEMB listing);
  - BAV199 pinning and leakage (Nexperia data sheet, as quoted in search results).

  Confirm each against the current PDF before any release.
- **Tools:**
  - FreeCAD 1.1.3.
  - KiCad 9.0.9 (Docker `kicad/kicad:9.0`).
  - Blender 4.5.14 LTS (`bpy`).
  - Freerouting 2.1.0.
  - shapely 2.1 (flex geometry).
  - DejaVu Sans font (CAD lettering).

## Checks actually completed

- **KiCad CLI, every board:**
  - ERC with all severities;
  - DRC with schematic parity;
  - netlist, BOM, PDF, STEP and GLB exports;
  - review-only Gerber, drill and placement exports;
  - raytraced renders of the pod.
- **FreeCAD:**
  - Every printable part is one valid solid with a closed, manifold mesh.
  - Pairwise interference audits cover the right pod, including the routed PCBA and the cartridge internals, and the dock with a seated cartridge.
  - The only intersections are the intended spring-contact and spring-pin compressions.
- **Insole flex:** the lane corridors stay at least 1 mm inside the 1:1 insole outline, except where the lanes intentionally cross the edge into the heel tab. This is checked by the generator.
- **Blender:** all scenes were rendered and visually inspected. The KiCad GLB colour error was diagnosed and fixed at the import.
- **Not done:**
  - any physical print or electrical build;
  - any measurement;
  - RF test;
  - sealing, skin, pressure or cleaning tests;
  - FSR characterisation;
  - independent design review.
