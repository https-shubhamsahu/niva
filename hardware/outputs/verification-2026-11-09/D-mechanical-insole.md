# Review D: mechanical parts and the insole flex (Niva Rev C.2, PCBWay order 2026-11)

Scope: pod enclosure (01, 02, 07, 08, 09), cartridge (03, 04), cradles and mounts (05, 06, 13, 15, 16; 14 noted only), dock (10, 11, 12), insole sensing flex R/L.
Repo state reviewed: branch `pcbway-silk-logo` @ 2c67426. No repo file was modified (FCStd md5 checked before/after; `git status` unchanged).

How things were verified:
- **FC** = measured in FreeCAD 1.1 on the committed STEP parts / FCStd assemblies (line sections, booleans, translation tests). Scripts: `scratchpad/review/fc_measure.py`, `fc_measure2.py`, `fc_slide.py`, `fc_head.py`.
- **STL** = thin-wall (ray cast along -normal per facet) and overhang (down-facing > 45 deg) scan of the print-orientation STLs, `scratchpad/review/stl_check.py`; output `stl_scan_pod.txt`, `stl_scan_dock.txt`.
- **MC** = tolerance stack, worst case plus 1e6-sample Monte Carlo (symmetric tolerances normal, 3 sigma = tolerance; one-sided effects uniform), `scratchpad/review/stack_mc.py`.
- **KiCad** = `kicad-cli pcb drc` 10.0.7 on a scratch copy of `NIVA-insole-R.kicad_pcb` (0 errors, 0 unconnected; 1 library-path warning from the copy).
- **Read** = from generator source or docs.
- External data: Mill-Max 0900-0 drawing (free 3.49 = 2.49 + 1.0; spring 76: mid stroke 0.5, max 1.0, 60 g at mid stroke, 25 g preload; lengths +/-0.15, diameters +/-0.051; domed plunger), datasheet PDF via ftcelectronics mirror of the Mill-Max catalogue page. PCBWay FDM page: min wall **1.5 mm**, accuracy +/-0.2 mm (<100 mm), layer height **100-300 um**, TPU offered as 95A HF only (pcbway.com/rapid-prototyping/3D-Printing/3D-Printing-FDM.html). PCBWay flex page: max board 8.668 x 27.5 in (220.2 x 698.5 mm), 2/2 mil, min coverlay bridge 8 mil, bend guide 3-6x (1 layer) / 7-10x (2 layer) thickness, finishes incl. ENIG and carbon; copper type (RA/ED), PI and coverlay thickness, stiffener specs not published (pcbway.com/FPC-Rigid-Flex-PCB.html).

Severity: BLOCKER = will not fit/work or unsafe as ordered; MAJOR = likely failure or a safety gap that must be closed before wear; MINOR = fix when convenient; NOTE = information. BENCH = only a print/build settles it.

---

## BLOCKERS

### D1 BLOCKER: the pod cannot be mounted on the cradle with the cartridge screw fitted, and without it nothing stops the pod sliding off toward the foot
Parts: `01_RearHousing_R/L`, `05_Cradle_R/L`, `13_AnkleCradle_R/L` (same interface core), `03_BatteryCartridgeCup` tab screw.
Evidence:
- Rear-housing rail grooves are cut `prism_xz(..., 11.8, 50)`: y 11.8 to 61.8, i.e. **open at the top (y 60) and closed at the cable end**. Cradle lips run y 12..58. The groove end therefore stops the pod moving **+y** (0.2 mm). The latch hook (`prism_yz` y 60.3..62.6) also faces the pod top face and stops **+y**. Nothing stops **-y**.
- FC translation test (pod = rear housing + front cover vs cradle): overlap volume 0 for every dy from -0.5 to **-65 mm** (fully off), 0.042 mm3 at +0.25, 2.8 mm3 at +0.5. Identical for `13_AnkleCradle_R`. The pod comes off toward its cable end with zero interference.
- ROLE-DESIGN-NOTE.md: ankle hub is worn **cable end (-y) down, toward the foot**. Gravity and heel-strike deceleration act along -y: the pod slides off.
- The only possible insertion is therefore from the cable end moving +y, and then the hook never deflects. PRINT-AND-ASSEMBLY.md section 4 step 9 ("slide the pod down ... latch hook snaps over the top face") and step 10 ("press the latch tab ... slide the pod up and off") describe motions the geometry does not allow.
- The M2 x 6 cartridge screw head (ISO 7045 pan, dk 4.0, k 1.6) sits under the tab, whose underside is the pod back face (z 0, FC: cup ZMin 0.0). It protrudes 1.6 mm. The cradle only has a local relief pocket (cyl r 2.4, z -2.0..-0.3 at 31, 44.3). FC: head vs cradle overlap 0.22 mm3 at dy = +/-0.5, 2.4 mm3 at +/-1, 15 mm3 beyond 3 mm. **With the screw in, the pod cannot slide on or off in either direction.** (Seated, the head in the relief is the only thing that would stop -y sliding; it cannot get there.)
Verified: FC (`fc_slide.py`, `fc_head.py`), Read.
Fix (build_niva_cad_revC.py `rear_housing()` / `cradle()`; the ankle cradle inherits via `interface_core`):
1. Make the pod slide on from the top, as documented: groove open at the cable end and closed at the top: `prism_xz(<same profile>, -1.0, 49.2)` (y -1..48.2). Trim the cradle lips to y 12..48: `prism_xz(<lip>, 12.0, 36)` on both sides, so the lip top end stops -y at 0.2 mm.
2. Key slot open at the cable end: `box(KEY_X[side]-1.6, -1, -0.1, 3.2, 13, 1.1)`; key post to y 6..10: `box(KEY_X[side]-1.3, 6, -0.4, 2.6, 4, 1.2)`.
3. Screw-head channel in the cradle from the relief to the top end: `s = s.cut(box(28.6, 44.3, -2.0, 4.8, 20, 1.7))` (clears the latch slots at x <= 25.8).
4. Re-run a translation test like `fc_slide.py` (pod + screw head) in the audit: expect free travel only in +y (until the hook) and a hard stop at -0.2.

### D2 BLOCKER: the cartridge strip PCB is not located or held down, so the dock pins lift it or miss its pads
Parts: `03_BatteryCartridgeCup`, strip PCB, dock J2.
Evidence:
- FC: strip bbox x 29.85..33.25, y 8.0..38.0, z 1.0..1.8 (polyfuse to 2.8). Cup cavity y 6.5..41.0, x 8.5..33.5. **Strip-to-lid gap 4.4 mm**; strip-to-cell 0.55 mm. The strip can slide **-1.5 / +3.0 mm in y** and about 0.8 mm in x, and lift 4.4 mm.
- PRINT-AND-ASSEMBLY section 4a step 3 only says "lay the strip PCB on the cup floor". No adhesive, no locating feature.
- In the dock the three pins push **up** on the strip's B.Cu pads (Ø2.0, `ContactPads_1x03_P6.0mm`) through Ø2.4 cup windows. Pin preload is 25 g each (Mill-Max). An unbonded strip held only by soldered AWG28 leads lifts until the plungers reach free length, so contact force falls to roughly the strip's weight share. A y shift of 1.5 mm moves the Ø2.0 pad wholly off the plunger tip (pad radius 1.0).
- The dock audit's "0.50 mm compression" assumes the strip lies flat on the floor.
Verified: FC, Read (cartridge kicad_pcb pad sizes).
Fix (niva_cad_lib `cartridge_cup()` / `cartridge_lid()`):
- Two end stops on the cup floor 0.1 mm from the strip ends: `box(29.6, 7.5, 1.0, 3.9, 0.4, 0.8)` and `box(29.6, 38.1, 1.0, 3.9, 0.4, 0.8)`.
- Two hold-down posts on the lid plug underside over the strip centreline, clear of F1 (y 11..13.2) and the wire pads (y 25..36): `box(30.8, 17.25, 1.85, 1.5, 1.5, 5.35)` and the same at y 21.25. Check the post height against the strip thickness tolerance (0.8 +/-0.08); TPU-tipped or 0.1 mm undersize is safer.
- Specify the bond: 0.05 mm acrylic PSA (e.g. 3M 467MP) under the strip, outside the pad windows. Add it to section 4a and to the dock stack (it raises the pads 0.05).

---

## MAJOR

### D3 MAJOR: pod J2 lateral capture: the full stack exceeds the 0.37 mm pocket clearance, and a miss lands all four plungers on the lid face (no power and 0.965 mm compression, at the 1.0 mm max stroke)
Parts: `04_BatteryCartridgeLid`, `01_RearHousing`, pod PCB J2 (Mill-Max 0900-0, plunger Ø1.07, domed tip).
Evidence (FC): pockets x 24.29..26.09, 26.83..28.63, 29.37..31.17, 31.91..33.71 (1.8 wide) at y 19.9..23.1; plates 1.6 wide; plate top 8.83; lid face 9.2; plunger tip 8.235.
- Allowed x offset before the plunger rests on the pocket edge: 0.9 - 0.533 = 0.367 (flat tip); about 0.39 for a hemispherical tip (dome height must reach 0.37 at the edge).
- Shift budget (x, at the pin row y 21.5):
  - cartridge rotation about the screw: 0.274, deterministic toward a side (bay 28.8 vs cup 28.0, +/-0.4 at the far end; tab hole Ø2.2 on M2, +/-0.1);
  - lid on cup at bonding: +/-0.2 (cavity 25.0 vs plug 24.6);
  - pocket printed on the bed face (first-layer squish): -0.1 per side;
  - pin float on the Ø2.08 pad (flange Ø1.83): +/-0.125;
  - PCB on M2 screws in Ø2.2 holes: +/-0.1;
  - housing feature position: +/-0.1.
  - **Worst case 0.90 mm; RSS 0.44 mm; both exceed 0.37.**
- All four pins shift together, so the redundant P-/P+ pairs do not help. On the lid face the compression is 9.2 - 8.235 = 0.965 mm, which is the max stroke before any other tolerance.
Verified: FC, computed. BENCH confirms it.
Fix:
- Best: rotate pod J2 90 deg (a 1 x 4 column along y at x 29). The pockets become 3.2 mm in x, giving 1.07 mm capture in the dominant direction; the y budget RSS is about 0.27 < 0.37. This is a pod-PCB change; coordinate with the electronics reviewer.
- Mechanical-only alternative:
  - locate the lid on the cup (plug clearance 0.2 -> 0.05 per side, or two Ø1.5 pins);
  - add 0.3 mm crush ribs at the bay far end (y 5..8) to cut the 0.274 rotation to under 0.1;
  - print the lid at 0.1 mm layers or in SLA and measure the pocket.

### D4 MAJOR: pod J2 compression stack: the real nominal is 0.60 mm, not 0.51, and the cartridge is held in z at one end only, so worn compression can fall to zero
Evidence:
- FC: pin solids z 8.235..11.715 (pad copper 11.76..11.80 plus 0.045 solder modelled). Plate top 8.83, so **nominal 0.595 mm**. The 11.8 - 8.83 = 2.97 design arithmetic ignores pad copper and solder. The bond line (lid on cup, 0..0.1) and plate adhesive (0.02..0.1) add more.
- z datum chain, five FDM features:
  - boss top 11.8 vs tab-recess ceiling 1.6 (RH);
  - the recess ceiling is a 4.8 x 8.8 mm bridge (STL: down-facing at z 1.60), so it sags;
  - tab 1.6;
  - cup 8.0;
  - lid floor 0.43.
- The cartridge is clamped only at the tab (y 44.3). The four pins (4 x 0.25-0.59 N) push it out of the rear. When worn, the far end (y 5) can drop 0.4 mm to the cradle plate plus 0.2 mm rail play, which is **up to 0.35 mm at the pins** depending on screw preload, and PETG relaxes it.
- MC (`stack_mc.py`, FDM +/-0.2):
  - clamped flat: mean 0.58, 99.8 % within 0.10..1.06; P(bottomed >= 1.0) 0.35 %;
  - **worn and tilted: mean 0.23, P(open) 7.1 %, P(< 0.15 mm, i.e. < 35 g) 30 %**;
  - worst case -0.98..+1.80 mm.
- Layer quantisation: PCBWay prints 0.1-0.3 mm layers. At 0.3 mm the 0.77 pocket depth becomes 0.6 or 0.9 and the 0.37 recess becomes about 0.2 or 0.5 (-0.13 / +0.17 mm on compression).
Verified: FC, MC, Read.
Fix:
- Capture the cartridge far end in z: a second tab and M2 screw at y about 3, or a lip under a bay ledge with far-end-first insertion. Then re-centre the nominal: `CART['plate_recess']` 0.37 -> 0.45 (about 0.50 mm nominal including pad and solder).
- Order the lid with "0.1 mm layer height" or in SLA.
- For the two prototypes, shim plates with 0.05 mm Kapton after measuring each lid.
- BENCH: measure the plunger heights with a depth gauge through the J2 window before closing.
- If FDM cannot hold it, a wider-stroke pin opens the window. The 0900 family with spring 75 has 0.7 mid and 1.4 max stroke (Mill-Max drawing) but a different free height, so `PCB_Z0`/`plate_recess` and the dock floor must be re-derived.

### D5 MAJOR: the cartridge retention-screw pilot has a 0.6 mm wall toward the bay (0.4 mm after a thread-forming M2)
Part: `01_RearHousing_R/L` retention post.
Evidence: FC y-section at x 31, z 5: material 42.9..43.5, pilot 43.5..45.1, material 45.1..46.3. The post is `box(27, py0+pl = 42.9, ...)` and the screw is at y 44.3, so the wall between the pilot and the cartridge pocket is 0.6 mm. A thread-forming M2 (major Ø2.0) leaves 0.4 mm and will split or bulge into the bay. FDM pilots also print undersize (PCBWay: oversize holes by 0.1-0.3), which raises the hoop stress. This screw carries the full pin reaction (D4) and is the charging-exclusion feature.
Verified: FC, Read.
Fix: `CART_TAB = dict(x0=27.0, y0=41.5, w=8.0, l=5.3, t=1.6, screw=(31.0, 45.1))`. That puts 1.4 mm to the bay and 1.2 mm to the post end (post to y 47.1, merging with the H2 boss at y >= 46.6). The cradle relief follows `CART_TAB['screw']`. Drill pilots to Ø1.6 after printing.

### D6 MAJOR: the pod interior is open to the cartridge bay, so the sealing concept fails its own S2/S4 tests by design
Parts: `01_RearHousing`, `09_SeamGasket`, `07_Button`, tail aperture.
Evidence:
- FC: a z-line at the J2 window (29, 21.5) and at the service window (21, 28) meets **no material** from the rear face to the board. Windows: J2 x 22.8..35.2 / y 19.3..23.7; service y 25..31. The bay is open to the rear and the cartridge has 0.4 mm gaps all round. Sweat in the bay reaches the PCB underside and the interior (1.0 mm gap ceiling-to-board).
- VERIFICATION-PLAN says "the bay ceiling ... keeps the PCB out of reach". It does keep fingers out; it does not keep water out.
- Gasket: 0.5 mm flat, 1.2 mm wide, compressed to 0.35 by a 0.35 mm stop step (RH rim 14.0, stop 14.35, FC). At 0.2/0.3 mm layers that step prints as 0.2 or 0.4, i.e. 20-60 % compression. FDM flatness over 60 mm is about +/-0.1-0.2, which a 0.5 mm gasket cannot absorb.
- The button flange touches the face (z 18.2) with no squeeze (FC: flange z 17.2..18.2). The gasket is cut at the tail aperture. The boot and tail blank have 0.2 mm clearance (FC: 17.2 x 5.0 in 17.6 x 5.4).
Verified: FC, Read. No IP claim is made (correctly).
Fix:
- 1.3 mm closed-cell silicone foam frame on the ceiling top (z 10.8) around both windows, compressed to 1.0 by the board. Conformal-coat the board except the J2/J3 pads.
- Replace the 0.5 mm flat gasket with a Ø1.2 silicone cord in a 0.9 deep x 1.5 wide groove in the RH rim (25 % squeeze) or a 1.0 mm PORON gasket.
- Give the button flange 0.2 mm interference against the face.
- Do S2 only after these.

### D7 MAJOR: the dock latch bends across print layers and can let go of the lid
Part: `11_DockTop` (printed flipped, top face on bed).
Evidence (FC):
- Arm y 8.5..9.5 (1.0 thick) x 28..36, from the floor (9.972) to the top (20.372); slots 0.8 wide; hook reach 1.2 at z 19.272; lid top 19.172.
- The arm's length lies along the print z axis, so bending tension crosses the layer interfaces.
- Strain 1.5*t*d/L^2 with L 9.5: 1.2 % at 0.7 mm deflection, 2.0 % at 1.2 mm, with a sharp root at the floor (no fillet). That is too high across PETG layers for the 2000-cycle F1 target.
- Well y 9.5..48.0 vs cup body 10.0..47.5: the cartridge can sit 0.5 mm toward the tab end, and the 45 deg hook ramp pushes it there on insertion. Overlap on the lid edge = 10.7 - (10.2 + 0.5) = **0.0 mm**; with +0.2 FDM on the well it is negative. The pins (3 x >= 25 g) then lift the near end.
Verified: FC, computed. BENCH.
Fix:
- `DOCK['well_clear']` 0.5 -> 0.2 in y (keep 0.3-0.5 in x if wanted, via separate x/y clearances).
- Hook 1.2 -> 1.4 engaging a 0.6 mm notch in the cup's near wall rather than the lid edge.
- Move the flexure into the print plane: a separate latch part printed flat, or a horizontal cantilever in the top face.
- Or replace the snap with 2 x Ø4 x 2 mm magnets in the well floor plus a steel disc in the cup floor. Pins push 0.7-1.8 N, so size for >= 3 N.

### D8 MAJOR: dock pin stack and pin-to-pad capture (after D2 is fixed)
Evidence:
- FC: pins z 7.995..11.475 on pads 7.91..7.95; pad face 10.972; nominal 0.50 (0.55 if the board seats on the top bosses at 8.0).
- Barrel (Ø1.5, top at 10.078) **protrudes 0.106 mm above the well floor** (9.972) into the Ø2.4 cup window: 0.45 mm radial clearance.
- Plunger in the window: 0.667 mm radial clearance.
- PCB clamp: base standoffs top 6.34, top bosses 8.0, so the space is 1.66 mm for a 1.6 +/-10 % board. A thin board (1.44) floats 0.22 mm and the pins push it onto the standoffs, losing that compression.
- MC (strip bonded, FDM +/-0.2): on the floor mean 0.42, P(< 0.15) 3 %; **lifted onto the hook mean 0.32, P(open) 1.35 %, P(< 0.15) 10.9 %**.
- Lateral budget: well clearance +/-0.5, window position +/-0.1, PCB-to-top +/-0.1 (Ø2.2 holes), pin float +/-0.125. That is 0.83 against 0.667, so the plunger can ride the window edge.
Verified: FC, MC.
Fix:
- Cup windows Ø2.4 -> Ø3.0. Strip pads Ø2.0 -> Ø2.4 (the strip is 3.4 wide).
- `well_clear` 0.5 -> 0.25 (also D7).
- Base standoffs to `pcb_z + 0.1` (6.5) and the base/top wall seam 0.2 mm open, so the screws always clamp the PCB between standoff and boss rather than closing the walls.

### D9 MAJOR: the USB-C opening only admits slim plugs, and the receptacle sits 3.1 mm behind the wall
Parts: `10_DockBase`, `11_DockTop`.
Evidence:
- FC: opening y 43.5..56.5 x z 6.12..13.12 = **13.0 x 7.0** at x 63.
- Receptacle (KiCad PCBA STEP) mating face at x 60.9; outer wall face at 64.0, so a **3.1 mm recess**. The plug overmould must enter the opening about 2.5 mm to mate.
- The USB-C recommended overmould envelope is 12.35 x 6.5 (USB-IF recommendation; not re-verified here). Common retail cables are about 12.3 x 8.3 and will not enter 7.0, so they will not fully mate.
- FDM holes print undersize: 12.8 x 6.8 likely.
Verified: FC, Read.
Fix: `USB = dict(y=50.0, z=pcb_z+3.22, w=14.0, h=9.5)` (z 4.87..14.37 stays inside the 2.5 floor and 18.77 roof). Or thin the wall locally to 1.0 mm around the port to cut the recess to 1.6. Name a known-good cable in the BOM.

### D10 MAJOR: the order contains many features below PCBWay's FDM rules, and the z-critical features depend on an unspecified layer height
Evidence: PCBWay FDM min wall is 1.5 mm, accuracy +/-0.2, layers 0.1-0.3 mm. Measured features below 1.5 mm (FC / STL):

| Part | Feature | Size |
|---|---|---|
| RH | bay ceiling, bridging 28.8 mm (x 6.6..35.4) | 0.8 |
| RH | strip under each rail groove | 0.8 x 1.2 |
| RH | retention post wall | 0.6 (D5) |
| RH | key-slot breakout sliver (y 57: outer 1.755, slot 1.9) | 0.145 |
| RH | tab-recess skin (y 46.3..46.4) | 0.2 |
| Lid | outer pocket floor (x 33.3..33.71) | 0.43 |
| Lid | outer wire hole to plug face (x 33.21 vs 33.3) | 0.09 |
| Cup | floor | 1.0 |
| Cup | finger-groove floor | 0.5 |
| FC | locating lip | 0.8 |
| FC | flange carrying the lip, with a 1.0 mm unsupported overhang (STL: 140 mm2 down-facing at z' 5.25) | 0.4 |
| FC | lip tips at the boss cut-outs | 0.06 |
| Dock top | well floor, a 29.0 mm bridge (x 17.5..46.5) | 1.2 |
| Dock top | latch arm | 1.0 |
| Dock top | light-pipe tube wall (Ø4.0 / Ø2.5) | 0.75 |
| Gasket (TPU) | thickness | 0.5 |
| Button (TPU) | flange | 1.0 |
| Tail blank (TPU) | key | 0.5 |
| Cradle | latch slots (gaps) | 0.8 |

Z-critical steps 0.35 (gasket stop), 0.37 (plate recess) and 0.43 (lid floor) are each smaller than one 0.3 mm layer plus tolerance.
Verified: FC, STL, PCBWay page.
Fix:
- In the order notes, specify **0.1 mm layer height, 3 perimeters, 100 % infill for 03/04/07/08/15**, and ask DFM to confirm the sub-1.5 mm features.
- Move `04_BatteryCartridgeLid` and `03_BatteryCartridgeCup` to SLA (or MJF PA12) if PCBWay declines.
- Drop the 0.5 mm TPU gasket print (use die-cut sheet).
- Fix the RH key-slot breakout by moving `KEY_X` to 4.0/38.0 (or by the D1 change, which moves the slot to the cable end).

### D11 MAJOR: the cradle latch lead-in is 65 deg, so the pod jams instead of snapping (matters once D1 is fixed)
Evidence: FC hook top flat y 60.3..61.0 at z 1.6; ramp (61.0, 1.6) -> (62.6, -1.8), i.e. 65 deg to the slide direction. The push-to-deflect ratio is tan(65 + phi). With PETG-on-PETG mu 0.4 it is about 18x; with mu 0.5 it self-locks. The arm needs about 9 N at 1.6 mm (k = 3EI/L^3, E 2 GPa, L 14.25, t 1.6), so 150 N or more of push.
Verified: FC, computed. BENCH.
Fix: `prism_yz([(60.3,-1.8),(60.3,1.6),(61.0,1.6),(63.8,0.0),(64.0,-1.8)], 17, 8)` (30 deg over the 0..1.6 rise). Also chamfer the RH back/bottom edge 0.8 x 45 deg outside x 12..30.

### D12 MAJOR (safety): pressure on a neuropathic shin is unassessed, and the parts as drawn concentrate it
Parts: `05_Cradle` + `06_SoftCradlePad_TPU`, `13_AnkleCradle` + `16_AnkleSaddlePad_TPU`, strap.
Evidence:
- `06` is a flat 2 mm pad. On a convex shin of R 60 the sagitta over its 50 mm width is 5.46 mm (build_ps_mounts note), so it makes a line contact along the tibial crest.
- PCBWay stocks TPU 95A HF only (not the 85A in the docs).
- Laplace estimate under a 35 mm strap: P = T/(w R). At T 10 N, R 40 mm that is about 7 kPa (54 mmHg) on average, already above about 4.3 kPa (32 mmHg) capillary closing. A rigid plate with line contact multiplies the peak.
- Diabetic users often also have PAD, where sustained compression is contraindicated.
- No edge is filleted. STL: saddle pad corner lands 0.02-0.04 mm thick. Cradle wing and strap-slot edges are square (FC). `SHIN_R` is a placeholder.
Verified: computed, FC, STL, Read. BENCH (B6 pressure mapping).
Fix:
- Before any wear: a conforming >= 5 mm medical PU or silicone-gel liner, an elastic strap with a tension indicator (target set with a clinician), 1 mm fillets/chamfers on every leg-side and slot edge, and a placement rule off the tibial crest.
- Run B6 before B-trial sign-off.
- Exclude PAD (ABPI < 0.8) from wear trials until B6 passes.

### D13 MAJOR (safety): cell venting has no path and would vent toward the leg
Evidence:
- The cartridge is closed: lid bonded, Ø0.8 wire holes under bonded plates, floor windows under the strip.
- The only leak path is the floor windows on the **rear face, which faces the cradle and the shin** (cradle plate 3.0 + pad 2.0).
- PETG and TPU are not flame-rated (HB class).
- The cell is about 0.9 Wh; a thermal event releases several kJ about 6 mm from skin that a neuropathic user may not feel.
Verified: Read, FC (geometry).
Fix:
- Define a vent away from the skin: a 0.3 mm burst-thin window in the lid at the +y lead end, ducted through the bay to the pod's top edge.
- Add a ceramic-paper or mica layer between the cell and the cup floor.
- Use PC/ABS V-0 for production.
- Make IEC 62133-2 / UN 38.3 for the exact cell (F4) a hard gate before any live-cell cartridge is worn.

### D14 MAJOR (safety/process): skin contact, flex edges and cleaning
Evidence:
- No ISO 10993 data for any printed part (FDM PETG/TPU industrial grades). VERIFICATION-PLAN B1-B4 not done (stated).
- The insole tail (14 mm wide polyimide, cut edges) runs up the lateral heel counter. The stiffened 22 x 23 mm transition with R1, 10 solder joints and the cable sits above the collar, next to the lateral malleolus, inside the sock line. Neither is covered by B8, which only covers underfoot pressure.
- FDM layer lines are porous and cannot be reliably disinfected, yet the kit is described as a "health-camp kit" (shared use).
Verified: Read, insole layout JSON (tail y 13..27, transition x 206..228).
Fix:
- A barrier (sleeve/sock) for all printed parts in any wear.
- The tail laminated inside a textile sleeve with >= 1 mm overlap past the PI edges.
- The transition potted in silicone and routed outside the collar.
- Single-patient use for printed parts.
- Add B-tests for tail and transition pressure at the malleolus.

### D15 MAJOR (insole): the heel-tab fold has the lane corners on the fold line
Evidence (layout JSON + insole outline):
- Insole lateral edge at y 22..34 is x 71.5..74.5.
- Every lane turns at x **72.44..72.56** (F1..F5, PVDF, VEXC), exactly on the fold, and then crosses the tab at 18.9 deg to the fold normal ((72.5, y) -> (93, y-7)).
- Corners and oblique crossings in a bend zone are the classic copper-crack sites.
- The fold radius is not specified anywhere in the fab data. F2 plans 5 mm.
- The collar crossing (about x 170, fab note "fit check") is a dynamic bend every step.
- PCBWay's bend guidance is static: 3-6x thickness single layer, 7-10x double. IPC-2223 dynamic practice is about 100x, i.e. >= 15-20 mm for a 0.15-0.2 mm build.
Verified: Read/computed from `insole-layout-R.json`.
Fix (build_niva_insole_flex.py):
- End every lane's last bend at x <= 69 (>= 3 mm before the fold).
- Run all lanes parallel and perpendicular through the fold band x 69..77 (make the tab a straight 14 mm strip at the fold).
- Put a "BEND ZONE R >= 5, NO CORNERS, NO VIAS" outline on a user layer.
- Bond the fold to the heel counter (static), and design the collar crossing for R >= 15 mm with a strain-relief loop.

### D16 MAJOR (insole): exposed comb electrodes have no finish and sit under DC bias in a sweat environment
Evidence:
- Gerber job `"Finish": "None"`. FSR combs are exposed under a coverlay opening Ø12.6 (F.Mask r 6.3) with 0.3 mm finger gaps between VEXC and Fn_RAW.
- Bare copper oxidises (FSR baseline drift). Any sweat film across a 0.3 mm gap under a few volts DC grows copper dendrites (electrochemical migration), giving false force.
- The coverlay also acts as the de-facto FSR spacer (copper about 18 um recessed under about 40-50 um coverlay), and that thickness is not specified.
Verified: Read (gbrjob, footprint generator).
Fix:
- ENIG (or carbon ink over ENIG) on the combs and wire pads.
- A sealed FSR spacer with a vent channel to the tail side, not to the sole.
- Drive VEXC only during the ADC sample window (firmware, duty < 1 %).
- Specify coverlay thickness as part of the FSR stack (F3).

---

## MINOR

### D17 MINOR (insole): flex rules and stack-up are not defined, and the panel barely fits PCBWay's maximum
Evidence:
- Board 217.6 x 234.1 mm vs PCBWay max 220.2 mm width (2.6 mm margin, no room for rails); area use 5288 / 50 940 mm2 = 10 %.
- `general (thickness 0.12)` with 2 copper layers is not a buildable 2-layer coverlay flex (typically 0.15-0.22).
- Stiffener exists only as F.Fab text ("0.2 FR4 ON BACK"); no layer or drawing.
- Copper type (RA) and weight are unspecified; vias are 0.25/0.5 (0.125 ring, thin for flex registration).
- KiCad DRC passes (0 errors).
Fix: see the "decide before a flex order" list at the end; via pad 0.6; stiffener as a user-layer outline plus fab drawing; or split into a 1-layer underfoot flex plus a small rigid transition board to avoid 2-layer flex cost.

### D18 MINOR: two plate leads run over the cell inside its swell gap
Evidence: wire holes are at the plate centres x 25.19 and 27.73, both over the cell (x 8.8..29.3; FC). Their leads must cross the 0.9 mm cell-to-plug gap to the strip at x about 31. The gap is the swelling allowance, and an aluminium-laminate pouch pinched against wire insulation is a short risk.
Fix: a 0.6 x 0.8 mm groove in the plug underside from each hole to x 30, wires bonded in it; or a 0.1 mm flex jumper.

### D19 MINOR: the cell is not retained
Evidence (FC): cell z 1.0..6.3 under a plug at 7.2 (0.9 free), x 0.3 / 0.55, y 0.3 / 2.2. It rattles at every heel strike and works the PCM leads.
Fix: 0.8 mm PORON pad on the plug underside (compresses under swelling), plus lead strain relief.

### D20 MINOR: cradle latch root
Evidence (FC): arm 1.6 thick from a 3.0 to 1.6 square step at y 46.5, to the hook at 60.3. Strain 1.5*t*d/L^2 = 1.9 % at d 1.6, L 14.25, and Kt about 2 at the square step, so about 4 % peak. In-plane print (good). Snag retention by tip moment is about 25 N (E 2 GPa).
Fix: 1.0 mm fillet or a 3 mm taper at the step. BENCH (F1).

### D21 MINOR: rail-lip underside is an unsupported overhang that sets the 0.2 mm pull-off clearance
Evidence: STL: 73.6 mm2 down-facing at z' 4.8 (lip underside z 1.4, 0.8 mm deep, x -0.2..0.6). Droop eats the 0.2 mm z-clearance (FC: dz +0.25 interferes).
Fix: 45 deg chamfer under the lip (profile `[(-0.2,0.6),(0.6,1.4),(0.6,1.8),(-0.2,2.6)]`) with a matching groove floor.

### D22 MINOR: small-hole and slot fits in FDM/SLA

| Feature | Nominal | Likely as printed |
|---|---|---|
| Dock light pipe Ø2.3 in Ø2.5 hole | 0.1 radial | interference, FDM holes print small |
| Dock pipe flange Ø3.4 in Ø3.6 counterbore | 0.1 radial | tight |
| Pod light window 1.8 in a 2.2 slot | slot on the bed face | elephant foot gives about 2.0 |
| TPU button Ø9.9 in Ø10.3 | 0.2 radial | tight |
| Lid pockets 1.8 on the bed face | 1.8 | about 1.6 |
| Latch slots | 0.8 | may bridge |

Fix: hole/slot +0.2 on these, or ream; latch slots 1.2.

### D23 MINOR: the tail blank is not retained
Evidence (FC): 17.2 x 5.0 body in a 17.6 x 5.4 aperture (0.2 per side), no detent; the 0.5 mm TPU key is easily deformed. It will fall out.
Fix: 0.15 mm interference ribs on the body, or a 0.3 mm barb behind the wall.

### D24 MINOR: heat and creep
PETG Tg about 80 C, HDT lower. A car dashboard (70-90 C) warps the parts and relaxes the screw preload that D4 depends on. Constant pin load on the 0.43 mm lid floor and constant gasket squeeze creep at 32-35 C skin temperature.
Fix: ASA for the housings (already allowed), a "not in a car / above 45 C" label (the cell needs it anyway), and re-measure preload after a 48 h 40 C soak (BENCH).

### D25 MINOR: lid plates are a short-circuit target
The plates are recessed 0.37 mm with P- and P+ pockets (2 and 3) 0.74 mm apart. A paperclip or key-ring wire bridges them. F1 and the PCM limit the current, but the cartridge is carried loose.
Fix: do not interleave the nets (P-, P+, P-, P+ would create three bridgeable gaps instead of one). Prefer a 1.0 mm recess, which needs a longer-stroke pin such as a 0900-X-15-20-75 (spring 75: 0.7 mid, 1.4 max stroke; different free height, so redo D4), or a sliding shutter. At minimum, ship a storage cap.

### D26 MINOR: the dock floor bridge moves the datum
The 29 mm, 1.2 mm well floor sags in the flipped print and bulges up into the well in use. The cartridge then seats on the bulge and the hook sets the compression (0.40 nominal), not the floor.
Fix: stiffening ribs under the floor do not fit (0.77 mm to the PCB). Instead add four 0.3 mm landing pads on the floor within 3 mm of the well walls, where sag is small, so the cup rests on them and not on the mid-span bulge. Re-run D8 with the pads as the datum. BENCH.

### D27 MINOR: saddle pad `16`
Edges are 0.5 mm lands with 0.02-0.04 mm knife corners (STL). The concave face prints as 0.1-0.3 mm stair steps on the skin side. Fillet the edges, or cast it in silicone.

### D28 MINOR: lid bond unspecified
PETG bonds poorly with cyanoacrylate. Specify the adhesive (e.g. a methacrylate for low-energy plastics, or a DCM solvent weld for prototypes), its bond-line thickness (it enters D4), and a peel/pull test.

---

## NOTES
- **D29 NOTE:** build_ps_mounts.py audits the mounts against the Rev C.1 PCBA STEP (`electronics/exports/pcb/NIVA-pod-PCBA.step`), not the C.2 board; the pod generator uses C.2. Harmless for the mounts, but switch it.
- **D30 NOTE:** cell swelling allowance is adequate for ageing. Cell-to-plug is 0.9 mm (17 % of 5.3) against the 8 % (0.42 mm) design allowance and typical 8-10 % end-of-life specs. Gassing from abuse can exceed it. The dock hook (0.1 mm above the lid) can double as a go/no-go: a cartridge whose lid has bulged will not latch, which means retire it. Write that into the instructions.
- **D31 NOTE:** drop test (1.5 m onto concrete) is BENCH. Pod mass is about 35 g. The likely first failures are the 0.4 mm lip flange (D10), the 0.6 mm screw-post wall (D5), the cradle latch, and the bay ceiling.
- **D32 NOTE:** JST GH is a low-mating-cycle wire-to-board family. Check its rated cycles against daily insole connect/disconnect, and plan the boot as the wear part.
- **D33 NOTE:** P2 (24, 193) and P3 (80, 180) sit on the metatarsophalangeal flex line, so expect bending artefacts at toe-off in F3.
- **D34 NOTE:** dock stability is fine: 64 x 62 footprint, 20.4 mm tall, about 35 g PETG plus PCB. The light pipe needs a drop of adhesive (it falls out when the dock is inverted). The M2 x 12 engagement is 5.8 mm (good).

---

## Counts

BLOCKER 2 (D1, D2), MAJOR 14 (D3-D16), MINOR 12 (D17-D28), NOTE 6 (D29-D34).

## Checked and found correct

| Item | Result | How |
|---|---|---|
| Front-cover screws M2 x 10: engagement 6.05 mm in Ø1.6 pilot; boss Ø4.4 merged into wall (pilot-to-outside 2.8, inside 1.4); counterbore Ø4.5 x 1.7 for a 1.6 head | OK | FC, Read |
| PCB screws M2 x 5 (H1/H2): Ø4.8 bosses, 4.0 mm engagement, clear of the bay frame | OK | Read |
| Dock M2 x 12: Ø5.2 bosses, Ø1.7 pilots, 5.8 mm engagement; PCB holes Ø2.2 | OK | FC, Read |
| Dock well floor thickness | 1.2 mm (z 8.772..9.972) | FC |
| Dock well bridge span | 29.0 mm | FC |
| Dock pins vs floor holes | 0.25 radial | FC |
| Dock pin nominal compression | 0.50 (CAD) | FC |
| Pod bay ceiling 0.8 mm; lid-to-ceiling 0.8 mm; J2 barrels clear the window (x 22.8..35.2) | OK | FC |
| Cartridge cup in bay 0.4 per side; lid plug 0.2 per side | OK (but see D3) | FC |
| Cell (published max 20.5 x 32 x 5.3) fits; 0.9 mm to lid | OK | FC |
| Button pre-travel 0.2; light pipe 0.3 above emitters; dock pipe 0.255 above LED | OK | report + FC |
| Cradle-to-pod pull-off play | 0.2 mm (dz +0.25 interferes, +0.1 free) | FC |
| L/R exclusion: R cradle post (x 2.2..4.8, 1.2 tall) blocks an L pod | OK (keep in the D1 redesign) | Read/FC |
| Cradle latch arm 1.6 mm prints in plane (bending along rasters) | OK orientation | FC/STL |
| Rear-housing ledge gussets and groove chamfers self-supporting (45 deg) | OK | STL |
| Bay-ceiling bridge 28.8 mm; tab-recess bridge 4.8 mm; key-slot bridge 3.2 mm | bridgeable; sag noted in D4 | STL |
| All print STLs: closed, manifold, single solid (their JSON) | consistent with re-read | STL scan ran on all |
| Mill-Max 0900-0 data in repo (3.48 free, 0.508/0.991) vs drawing (3.49, 0.5/1.0, lengths +/-0.15) | consistent | datasheet |
| Insole flex DRC (KiCad 10.0.7) | 0 errors, 0 unconnected | KiCad |
| Insole track/space 0.25/0.45 in pairs, 0.75 between pairs, >= 2.2 mm copper-to-edge in the tail; comb 0.3/0.3 | well inside PCBWay 2/2 mil | Read/computed |
| Insole underfoot single copper layer, no vias/parts underfoot; vias only at the stiffened transition | as stated | Read |
| STATUS.txt (insole): FSR ink, spacer, lamination, PVDF film and bond, and flex rules all "not selected" | confirmed | Read |
| Insole size fits PCBWay max | yes, 217.6 <= 220.2 (tight, D17) | PCBWay page |

---

## Decide before ordering the insole flex (open items, confirmed)

1. FSR material: ink or film (vendor, part), resistance-force curve range for 0.5-1 MPa heel pressure, spacer thickness and adhesive, vent path (F3, D16).
2. PVDF film part, its lead termination (ACF, conductive epoxy or crimp), and bond-pad finish (STATUS).
3. Flex construction:
   - layer count: 2-layer, or 1-layer plus a rigid transition board (D17);
   - PI core thickness (12.5 or 25 um);
   - adhesive or adhesiveless laminate;
   - copper **RA**, 1/3 or 1/2 oz;
   - coverlay thickness and colour;
   - finished thickness callout (replace 0.12).
4. Surface finish: ENIG on combs and pads; carbon overprint yes/no (D16).
5. Stiffener: material and thickness (0.2 FR4 is thin for soldering 10 wires; 0.3-0.5 FR4 or 0.2 PI), drawn on a layer.
6. Bend spec: heel-tab radius (>= 5 mm static, bonded); collar-crossing radius (>= 15 mm dynamic); bend-zone keep-outs; then fix the lane corners (D15).
7. Lamination stack: top cover, base foam, adhesive, edge seal; and the tail sleeve (D14).
8. Panel/outline: PCBWay max width margin, rails, outline tolerance, and whether to split tail and footbed.
9. Sizes: only medium exists (no grading).
10. Test coupons and acceptance: F2 fold and heel-strike fatigue, S7/S8 soak, B8 pressure, plus an electrical test on the open combs (isolation > 100 MOhm at 5 V before film).
