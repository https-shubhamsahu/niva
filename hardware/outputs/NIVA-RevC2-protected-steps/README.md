# NIVA Rev C.2 working copy: Niva Protected Steps hardware

The Rev C.1 pod (`../NIVA-3D-engineering-prototype/`), adapted for Protected Steps. One pod design serves two roles:
- the **ankle hub**, strapped on the lower shin with no insole tail;
- the **shoe node**, clipped at the shoe collar with the insole tail connected.

There is also an interim printable cabinet for the current ESP32 perfboard prototype.

> **Status: working copy for review.**
> - Nothing here, and nothing in Rev C.1, has been printed, built, powered or measured.
> - KiCad ERC/DRC and the FreeCAD geometry checks are automated checks, not a design review.
> - Not a medical device; no clinical claim.
> - Every placeholder dimension says so where it is defined.

## Where things are

| Path | What |
|---|---|
| `CHANGELOG.md` | every change from Rev C.1 |
| `BASELINE-ERC-DRC.md`, `baseline-erc-drc/` | ERC/DRC of all five Rev C.1 boards (KiCad 10.0.7) |
| `STATUS-CLOSURE.md` | the STATUS.txt blockers: J2 part, MAX17048 land pattern, antenna keep-out, with sources |
| `ROLE-DESIGN-NOTE.md` | what changes per role: firmware flag, connectors, lean build, battery budget (to be measured) |
| `PINMAP.md` | every ESP32-C3-MINI-1 pin, net and function, plus the port table from the classic ESP32 prototype |
| `bom/` | costed pod BOM at 1 / 10 / 100 boards (LCSC and DigiKey, with links, checked 3 November 2026) |
| `electronics-C2-working/` | KiCad pod copy with the C.2 J2 / U6 land patterns and the antenna notch, plus `reports/` |
| `electronics-C2-working/exports/` | C.2 PCBWay Gerbers (`pcb/fab-PROTOTYPE-PCBWAY/NIVA-pod-C2/`, with `STATUS.txt`), DRC/ERC, PCBA STEP (9 Nov 2026); order sheet `../PCBWAY-ORDER-2026-11.md` |
| `mechanical/` | ankle cradle, saddle pad, tail blank, collar clip: STEP, STL, FCStd, `mounts-validation.json`, `PRINT-AND-FIT.md` |
| `interim-cabinet/` | parametric box, `cabinet-params.json`, STEP, STL, FCStd, `cabinet-validation.json`, `PRINT-SETTINGS.md` |
| `work/` | generators: `build_ps_mounts.py`, `render_protected_steps.py`, `caption_ps_renders.py`; render meshes |
| `renders-work/` | raw renders and the `.blend` file |
| `../renders-protected-steps/` | captioned 3D renders for the deck and website, also copied to `niva/media/cad/outputs/renders-protected-steps/` |

## Regenerate

```sh
cd hardware/outputs/NIVA-RevC2-protected-steps
freecadcmd work/build_ps_mounts.py                                  # mounts + audit
(cd interim-cabinet && freecadcmd build_interim_cabinet.py)          # cabinet + audit (edit cabinet-params.json first)
blender -b --factory-startup -P work/render_protected_steps.py       # 4 scenes, 80 samples, 1800 px wide
python3 work/caption_ps_renders.py                                   # captions -> ../renders-protected-steps/
```

**KiCad checks:** use a `KICAD_CONFIG_HOME` that contains the stock `sym-lib-table` and `fp-lib-table` (see `BASELINE-ERC-DRC.md`).

**Before heavy jobs:** run `free -h` and keep at least 3 GB available.

## Renders

All four images are 3D renders of CAD, not photos.

| File | Shows |
|---|---|
| `PS01_ankle-hub-on-strap_3D-render.png` | pod on the ankle cradle and strap, on a neutral mannequin leg |
| `PS02_shoe-collar-node_3D-render.png` | the same pod on the collar clip of a stand-in shoe form, tail into the shoe |
| `PS03_pod-exploded_3D-render.png` | exploded pod, ankle-hub build |
| `PS04_interim-cabinet_3D-render.png` | interim cabinet with the lid lifted and labelled DUMMY board blocks |
