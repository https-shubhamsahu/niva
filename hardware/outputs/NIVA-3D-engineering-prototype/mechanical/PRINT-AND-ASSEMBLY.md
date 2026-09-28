# NIVA pod Rev C and charging dock Rev C.1 — printing, fasteners, clearances and assembly

Engineering prototype for fit and handling trials. **Not a released medical device**. Watertight meshes and a clean CAD interference check do not establish manufacturability, sealing or wearable safety.

Units: mm. Pod frame: x = width (0–42), y = height (0 = cable end, 60 = top), z = depth (0 = back against the cradle, 20 = front face). Left-side parts are identical to right-side parts except for keys and markings; the assembly shows the left pod 80 mm to the left of the right pod.
Dock frame: x 0–64, y 0–62, z up from the desk. It is the pod frame shifted by (11, 5) mm, so the cartridge's dock pads and the dock's spring pins share x/y without mirroring. The dock is a separate assembly: `NIVA-dock-assembly.FCStd` / `.step`.

## 1. Printable parts

The STLs in `STL-print-parts/` are **already rotated into the recommended print orientation** and sit on z = 0. The STEPs in `STEP-parts/` are in the assembly (pod) frame.

| File | Material | Rigid / flexible | Recommended orientation | Notes |
|---|---|---|---|---|
| `01_RearHousing_R/L` | PETG or ASA, navy | rigid | rear face on bed (as modelled); no supports | The ledge gussets and groove chamfers are 45° self-supporting. The bay ceiling bridges 28.8 mm (check bridging). Use ≥ 4 perimeters around the screw pilots. |
| `02_FrontCover_R/L` | PETG or ASA, pale grey-blue | rigid | cosmetic face on bed (flipped); no supports | The debossed NIVA and R/L marks print on the bed face. |
| `03_BatteryCartridgeCup` | PETG, navy | rigid | rear face on bed; no supports | Printed cups are for fit trials with an **inert dummy cell block**. A live-cell cartridge needs the moulded, welded cup and the checks in `../VERIFICATION-PLAN.md`. Three Ø2.4 windows in the floor expose the strip PCB's dock pads. |
| `04_BatteryCartridgeLid` | PETG, navy | rigid | contact face on bed (flipped); no supports | Has four contact-plate pockets. Bond it to the cup; a live-cell cartridge must not be user-openable. |
| `05_Cradle_R/L` | PETG, navy | rigid | back (leg side) on bed; no supports | The latch arm is thinned from the top so it prints flat. PLA is not recommended for the latch (creep). |
| `06_SoftCradlePad_TPU` | TPU 85A–95A, teal | flexible | flat | Skin contact: material suitability not assessed. |
| `07_Button_TPU` | TPU 85A–95A, teal | flexible | crown on bed (flipped) | The flange overhangs 1.5 mm; add support if your profile needs it. Moulded silicone is the production intent. |
| `08_LightWindow_Clear` | clear SLA resin (preferred) or clear PETG | rigid | window face on bed (flipped) | The flange needs support in FDM. |
| `09_SeamGasket_TPU` | 0.5 mm silicone/EPDM sheet, **die-cut** (TPU print for fit trial only) | flexible | flat | 0.5 mm free thickness, 0.35 mm installed. |
| `10_DockBase` | PETG, navy | rigid | bottom on bed; no supports | Four M2 standoffs with counterbored screw entries from below, 8 mm bumper recesses, debossed label (reads correctly from below). |
| `11_DockTop` | PETG, pale grey-blue | rigid | top face on bed (flipped); no supports | The well floor is a 29 mm bridge in this orientation: enable bridging. Keyed well, tab slot under the far ledge, cantilever snap latch (8 × 1.0 × 10.4 mm arm), finger notches, spring-pin holes, USB-C opening, light-pipe tube. |
| `12_DockLightPipe_Clear` | clear SLA resin or clear PETG | rigid | flange on bed (flipped) | Ø2.3 rod, 0.25 mm above the amber charge LED. |

`geometry-validation.json` (pod) and `dock-geometry-validation.json` (dock) record for every part: one valid solid, closed mesh, no non-manifold edges, volume and print bounding box.

## 2. Bought-in parts per pod

| Qty | Item | Where | Notes |
|---|---|---|---|
| 4 | M2 × 10 pan head, thread-forming for plastics (head Ø4.0 × 1.6, DIN 7985 / ISO 7045 style) | front cover → rear housing | 1.6 mm pilot, about 6 mm engagement, Ø4.5 × 1.7 counterbore. |
| 2 | M2 × 5 pan head, thread-forming | PCB (H1, H2) → rear housing bosses | 1.6 mm pilot, 6.8 mm deep. |
| 1 | M2 × 6 pan head, thread-forming | cartridge tab → rear screw post | Hidden by the cradle when worn: this is the charging-exclusion feature. |
| 4 | Brass contact plate 1.6 × 3.0 × 0.4, gold flash (to select) | cartridge lid pockets | Wired to the strip PCB's J2 pads (2 × P−, 2 × P+) through Ø0.8 holes. |
| 1 | Cell: EEMB LP502030 class with protection module and NTC lead (230 mAh min / 250 mAh typ, 20.5 × 32 × 5.3 mm max) | cartridge cup | The part class is selected, not a purchased lot. Confirm the lot datasheet and the NTC value before use. |
| 1 | Cartridge strip PCB (`../electronics/cartridge`), 3.4 × 30 × 0.8 mm, with an 0805 polyfuse | cartridge cup floor, beside the cell | Its gold dock pads face the floor windows. |
| 1 | Pod PCBA (see `../electronics`) | — | A routed prototype that passes KiCad ERC and DRC. It is **not reviewed or released** for fabrication. |
| 1 | Insert (sensing flex laminated inside, `../electronics/insole`) with cable and overmoulded, keyed JST GH 10 boot | J1 | The boot is modelled as `TailBoot_R/L` (not printed). |
| 1 | 35 mm smooth silicone ladder strap | cradle slots | Not modelled in CAD; shown in the renders. |

**Per dock:** 4 × M2 × 12 pan head, thread-forming (base → PCB → top bosses; 1.7 mm pilots, about 5.8 mm engagement); 4 × Ø8 × 2 mm adhesive bumpers; 1 dock PCBA (`../electronics/dock`, spring pins **not selected**); a USB-C 5 V supply and cable.

**Torque:** not specified. Thread-forming M2 in PETG strips easily. Start at about 0.1 N·m, set the value by test, and expect a limited number of service cycles. Heat-set inserts do not fit the 4.4 mm bosses.

## 3. Nominal clearances

These are measured in the Rev C CAD (`interference-report.json`) against the real KiCad PCBA model.

| Interface | Nominal |
|---|---|
| Cartridge cup in bay pocket | 0.4 per side |
| Cartridge lid to bay ceiling | ≥ 0.6 |
| Spring plungers to lid plates | **0.4 preload** (the only intended overlap in the audit) |
| Front-cover locating lip in rear cavity | 0.2 per side |
| Gasket | 0.5 free → 0.35 installed (30 % compression), set by boss-to-boss hard stops at z = 14.35 |
| Cradle rail lips in housing grooves | 0.2 on each face; cradle plate to pod back 0.4 |
| Latch hook to pod top face | 0.3; key post in key slot 0.2 (depth) |
| Button crown in Ø10.3 hole | 0.2 radial; plunger to KMR2 switch 0.2 pre-travel |
| Light pipe in window | 0.2 per side; 0.3 above the emitters |
| PCB components to front cover / rear housing | min 1.16 (J1) / 0.6 |
| Tail boot in aperture | 0.2; boot to J1 face 0.4 |
| PCB notches to enclosure bosses | 0.4 |
| PCB on ledges and clamp ribs | 0 nominal. Board thickness tolerance (±0.1) is not yet absorbed: tune the rib height. |
| Cell (published maximum size) in the cartridge | 0.9 to the lid plug; 0.55 to the strip PCB (`interference-report.json`) |
| Cartridge in the dock well | 0.5 per side; tab in its slot 0.5 per side, 0.2 above |
| Dock latch hook over the cartridge lid | 0.1 free play, 0.5 overlap on the lid edge |
| Dock spring pins on the cartridge pads | 0.70 compression seated, 0.60 when pushed up onto the hook (envelope pin, 4.5 mm free height) |
| Dock PCB clamp | standoff tops 0.06 below the board underside; top bosses bear on the board's top face. Tallest component to the top housing is 0.53 |

FDM accuracy is typically ±0.1–0.2 mm, so every 0.2 mm fit above must be checked on real prints.

## 4. Assembly sequence (one pod)

1. **Rear housing:** check that all pilots are clear. Optionally run each screw in once to form the threads.
2. **PCB:** lower it onto the side and bottom ledges so J2 and the service pads pass the bay-ceiling windows and the notches clear the four bosses. Fit 2 × M2 × 5 at H1/H2.
3. **Front cover sub-assembly:**
   - Push the light pipe into the window from inside and retain it with a small bead of UV adhesive on the flange.
   - Drop the TPU button into its hole from inside.
4. **Gasket:** lay it on the rear rim, clear of the bosses, with the gap at the tail aperture.
5. **Close:** fit the front cover, with the lip inside the rear cavity and the aperture halves aligned. Drive 4 × M2 × 10 in a cross pattern to the boss hard stop. Do not over-torque.
6. **Cartridge (dummy):** bond the lid to the cup with the contact plates fitted. Insert it from the rear, tab first into its recess, and fit the M2 × 6 screw.
7. **Tail:** insert the keyed boot through the aperture until the GH latch engages. The boot key tab only fits the matching side.
8. **Cradle:** bond the TPU pad under the cradle (adhesive to be chosen) and thread the strap through both slots.
9. **Mount:** slide the pod down the cradle rails, key post into the rear slot, until it stops at the groove end and the latch hook snaps over the top face. Confirm that the other side's pod cannot be inserted.
10. **Removal (for charging):** press the latch tab away from the pod, slide the pod up and off, remove the M2 × 6, and withdraw the cartridge. Charging happens only in the separate dock (§4b).

## 4a. Cartridge assembly (bench; live cells only after the verification plan's F4 items)

1. Solder the cell's +, − and NTC leads to strip PCB J1 (pads offset to −x, toward the cell).
2. Solder four leads from strip J2 to the lid plates (P−, P−, P+, P+), and fit the plates into the lid pockets.
3. Lay the strip PCB on the cup floor, gold pads down over the three windows. Seat the cell against the −x wall with its PCM at the +y end.
4. Bond (production intent: weld) the lid. The cartridge must not be user-openable.

## 4b. Dock assembly and use

1. Fit the light pipe into the top from above; its flange sits in the counterbore.
2. Place the dock PCBA on the base standoffs (USB-C toward the +x wall opening), lower the top onto it, and drive 4 × M2 × 12 up through the base.
3. Stick the bumpers into the four base recesses.
4. **Use:** tilt the bare cartridge rear face down, slide its tab into the slot under the far ledge (the top face says TAB END IN FIRST), then press the near end down until the latch clicks. Amber light = charging (MCP73831 STAT). To remove it, push the latch arm back and lift the near end using the side finger notches.

## 5. Unverified fits and safety mechanisms

- **Charging exclusion:** the pod has no port, coil or charger. The cartridge screw is hidden under the cradle, and only a bare cartridge fits the dock well (the pod is far too large for it). This is a mechanical intent; it is untested, including against deliberate defeat.
- **Battery:**
  - The cell *class* is selected: EEMB LP502030, 230 mAh minimum. The original 300 mAh target does **not** fit, and none is claimed.
  - The cartridge layout is designed around the published maximum size plus an 8 % swelling allowance.
  - Not yet done: a purchased lot, swelling under cycling, the lid welding process, and cell safety evidence (see `../VERIFICATION-PLAN.md` F4).
- **Spring contacts:** neither the pod J2 nor the dock J2 part is selected, so preload, contact resistance, wear and vibration performance are all unverified. Both 3D models are envelopes.
- **Dock:**
  - The latch strain estimate (≈ 1.7 %), the 29 mm bridged well floor and the USB-C plug overmould clearance (13 × 7 mm opening) need checking on prints.
  - The charger's NTC window thresholds are designed, not measured.
- **Sealing:** the gasket path, boot seal and button seal are not validated. **No IP rating is claimed.**
- **Screws and bosses:** strip-out, boss cracking, service life and torque are untested.
- **Cradle latch:** the hand calculation (ε ≈ 1.5·t·δ/L², t = 1.6, δ = 1.8, L ≈ 14.5) gives about 2 % peak strain, within the short-term range of PETG but with little margin. Release force, creep, fatigue, accidental release and retention under strap load are all untested; lengthen or thin the arm if prints crack.
- **L/R keys:**
  - The cradle key post (1.2 mm) and boot key tab (0.5 mm) are small and could be forced.
  - A complete matched set on the wrong leg is **not** prevented; the app's side check and fitting check remain required.
- **Button:** KMR2 travel and force through TPU, flange retention and feel are untested.
- **Light pipe:** coupling, amber mixing and light bleed are untested.
- **PCB clamping:** board thickness tolerance is not yet absorbed by the ribs.
- **Antenna:** metal screws sit 6–8 mm from the antenna region, with housing and body detuning on top. Not measured.
- **Skin contact and pressure:** TPU pad and silicone strap materials, pressure under the strap and cradle, and sweat and heat are not assessed.
- **Cleaning:** disinfectant compatibility of all printed and soft materials is untested.
- **Underfoot:**
  - The discrete-sensor tail problem (hold H1) is addressed by the integrated sensing flex in `../electronics/insole`, which has no sensor tails and uses one copper layer and no parts underfoot.
  - The flex, its FSR ink film, the lamination and the tail fold are all **untested** (verification plan S7, S8, F2, F3).
  - The CAD insole is still the passive visual insert from the 1:1 fit template.
- **Sealing, skin contact, cleaning:** see `../VERIFICATION-PLAN.md`. Nothing is claimed.
