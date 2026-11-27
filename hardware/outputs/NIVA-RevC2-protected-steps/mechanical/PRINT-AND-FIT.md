# Rev C.2 mounting variants for the Rev C.1 pod: print and fit

The generator is `../work/build_ps_mounts.py` (FreeCAD 1.1). It executes only the definitions of the unchanged Rev C.1 generator (`hardware/work/build_niva_cad_revC.py`), so these parts mate with the pod geometry that was audited for Rev C.1. No Rev C.1 file was written.

**Status:** CAD only. Not printed, not fitted, not worn.

## Parts

STEPs in `STEP-parts/` are in the pod frame. STLs in `STL-print-parts/` are in print orientation.

| Part | Material | Print orientation | Role |
|---|---|---|---|
| `13_AnkleCradle_R/L` | PETG | back (leg side) on the bed, as the Rev C cradle; no supports | ankle hub |
| `16_AnkleSaddlePad_TPU` | TPU 85A–95A | flat (cradle) face on the bed, concave face up; no supports | ankle hub, bonded under the cradle |
| `15_TailBlank_TPU_R/L` | TPU 95A | flange face on the bed; no supports | ankle hub: closes the unused tail opening |
| `14_CollarClip_R/L` | PETG | standing on its −x rail wall, so the hook profile lies in the layer plane; use a brim; no supports expected (check in the slicer) | shoe node |

**Assemblies:** `NIVA-RevC2-ProtectedSteps-mounts.FCStd` / `.step` contain two groups:
- `AnkleHub_R`: pod, cradle, pad and plug.
- `ShoeNode_R`: pod, tail boot, clip, and reference collar and tail slabs (`REF_*`, never printed).

## Parameters (top of `build_ps_mounts.py`)

| Name | Value | Kind |
|---|---|---|
| `STRAP_W` | 35 mm | design: the Rev C cradle's strap (PRINT-AND-ASSEMBLY.md §2); no strap bought |
| `WING_SPAN` | 69 mm | design: Rev C is 63 mm, plus room for the A/R marks |
| `SHIN_R` | 60 mm | **placeholder: measure** the lower-shin radius at the strap line |
| `PAD_MIN` | 2.0 mm | design (Rev C pad thickness) |
| `COLLAR_T` | 5.0 mm | **placeholder: measure** the prescribed shoe's collar wall |
| `TAIL_T` | 1.2 mm | **placeholder: measure** the insole tail where it crosses the collar |
| `HOOK_W`, `BRIDGE_T`, `TONGUE_T`, `TONGUE_L`, `GRIP`, `TAIL_SLOT_W` | 30, 2.4, 1.8, 14, 0.8, 9 mm | design; tune on prints |

## Checks run (`mounts-validation.json`, 3 November 2026)

**Solids and meshes:** each of the 7 printable parts is one valid solid. The exported STEP re-reads as one solid with the same volume, and the STL re-reads as a closed mesh with no non-manifold edges.

**Interface:** the new cradle core minus the Rev C cradle 05 is 0.0000 mm³. The rails, rail lips, key post, latch and screw relief are therefore the Rev C ones, unchanged.

**Interference:** checked pairwise against the rear housing, front cover, PCB substrate and the KiCad component bodies from `NIVA-pod-PCBA.step`. The only intersection is the intended one: clip tongue × reference tail band, 55.6 mm³ (the `GRIP` preload).

**Gaps:**

| Pair | Gap |
|---|---|
| Ankle cradle to rear housing | 0.2 mm (same as Rev C) |
| Collar clip to rear housing | 0.2 mm |
| Tail blank to rear housing and to front cover | 0.2 mm each |
| Tail blank to PCB components | 3.9 mm |
| Saddle pad to cradle | 0 (bonded face) |
| Clip to tail boot | 11.6 mm |

**Collar clip opening**, measured on the solid at x = 8 mm:
- 6.03 mm near the root;
- 5.45 mm near the tip.

These are against a design gap of `COLLAR_T` + `TAIL_T` = 6.2 mm with 0.8 mm grip at the tip.

**Saddle pad sagitta:** 5.46 mm over 50 mm at `SHIN_R` = 60 mm (calculated).

## Fit and open items

- **Cradle:** the pod slides onto the ankle cradle exactly as onto the Rev C cradle (PRINT-AND-ASSEMBLY.md §4 step 9). The latch strain estimate there applies unchanged.
- **Collar clip:**
  - The pod goes on cable end up. The tail runs up between the collar lining and the tongue, through the bridge slot, and over into the boot.
  - In this orientation the latch carries the pod's weight, and retention at heel strike is **untested**.
  - **The tongue touches the sock or skin inside the collar. A clinician must approve it before any wear by people at risk of foot ulcers; pressure is unassessed.**
- **Tail blank:** it uses the same key as the Rev C tail boot, so R and L plugs only fit their own side. Remove it with a fingernail under the 1 mm flange lip.
- **Not assessed:** printing tolerances (FDM ±0.1–0.2 mm, PRINT-AND-ASSEMBLY.md §3), TPU bonding, skin contact, cleaning and sealing.
