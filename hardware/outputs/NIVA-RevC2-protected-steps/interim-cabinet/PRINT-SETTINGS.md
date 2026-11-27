# Interim cabinet for the current prototype: measure, print, assemble

This box is for the working prototype as it is today: a classic ESP32 dev board, an MPU6050 (GY-521) and an optional SH1106 OLED on perfboard, at present in a clear acrylic box (`media/photos/1.jpg`, a real photo).

The same box can be strapped on as the Protected Steps ankle hub.

**Status:** CAD only. Not printed, not fitted, not worn.

## 1. Measure first (calipers), then regenerate

**Every value under `MEASURE` in `cabinet-params.json` is a placeholder.** Do not print with the defaults. They are round numbers or, where noted, Espressif's ESP32-DevKitC V4 drawing. The board in the photo looks like a 30-pin DOIT-style board, not a DevKitC.

| Parameter | What to measure |
|---|---|
| `PERF_W`, `PERF_L`, `PERF_T` | the outline and thickness of the largest perfboard in the stack |
| `UNDER_H` | the tallest solder joint or wire under the perfboard |
| `STACK_H` | the tallest point above the perfboard (dev board on its headers, OLED, wires) |
| `ESP_*`, `USB_POS_Y`, `USB_Z_ABOVE_PERF` | dev board outline and position, header height, and the USB receptacle centre (measure from the perfboard's −x/−y corner) |
| `USB_OPEN_W`, `USB_OPEN_H` | your USB cable's plug overmould, plus 1 mm |
| `OLED_AA_*`, `OLED_PCB_Z_ABOVE_PERF` | the OLED active-area size (default 29.4 × 14.7 mm, "approx." on one seller page, probots.co.in) and its centre position |
| `CABLE_D`, `CABLE_POS_Y`, `CABLE_Z_ABOVE_PERF` | the insole cable bundle and where it leaves the board |
| `PANE_T` | the clear acrylic offcut used as the OLED window |
| `LID_HOLES` | `[x, y]` of anything you need to reach through the lid. **Add the dev board's BOOT button:** the Protected Steps firmware uses it as its button (`PS_PIN_BUTTON = 0` in `ps_device.h`). Optionally add the GPIO2 status LED and EN. |

**Corner rule:** keep a 4 × 4 mm square at each perfboard corner free of parts, top and bottom. The board sits on four corner pads and the lid presses it down with four posts.

**Regenerate:**

```sh
cd hardware/outputs/NIVA-RevC2-protected-steps/interim-cabinet
freecadcmd build_interim_cabinet.py
```

Then read `cabinet-validation.json`:
- `interference` may list only the cable squeeze (intended).
- Every `gaps` entry between a DUMMY board and the lid or base must be ≥ 0.
- `usb plug block … intersects base` must be 0.

With the placeholder values the box is:
- 67.2 × 94.2 mm, 26.6 mm tall when closed;
- 91.2 mm wide over the strap wings.

## 2. Print

| Part | File | Orientation | Supports |
|---|---|---|---|
| Base | `STL/21_InterimCabinet_Base.stl` | floor on the bed, as exported | none. The USB opening top is a short bridge, and the cable-tie lug outside has a 45° underside. |
| Lid | `STL/22_InterimCabinet_Lid.stl` | top face on the bed (already flipped in the STL) | none. The window recess faces up. |

**Suggested slicer settings.** These are starting points, not tested values:
- **Material:** PETG. PLA is fine for a desk fit check, but it softens at lower temperatures than PETG, so do not wear a PLA box in the sun.
- **Layers and walls:** 0.2 mm layers; 3 perimeters, and at least 4 around the screw bosses.
- **Infill and adhesion:** 20–25 % infill; a brim is optional.
- **Temperatures:** the filament maker's.

Print one base and one lid first, check the fit, then tune `CLEAR`, `LIP_CLEAR` and `PILOT_D`.

## 3. Bought or cut parts

| Qty | Part | Note |
|---|---|---|
| 4 | M3 × 10 pan-head screws, thread-forming or self-tapping for plastic | The pilot is a 2.5 mm design value. Do not over-tighten PETG. |
| 1 | Clear acrylic pane, about 36.0 × 21.3 mm × `PANE_T` | Cut from the old box. Glue it into the lid recess from inside. |
| 1 | Cable tie, up to 3.4 mm wide | through the lug under the cable exit |
| 1 | 35 mm strap | Same width as the Rev C pod cradle. No strap has been chosen yet. Change `STRAP_W` to suit the one you buy. |

## 4. Assemble

1. Lay the perfboard stack on the four corner pads.
2. Lay the insole cable into the U-notch in the −x wall and tie it to the outside lug.
3. Fit the lid. Its tongue closes the notch and presses the cable by 0.4 mm (`CABLE_SQUEEZE`), which is the strain relief.
4. Drive the four screws.
5. Plug USB through the +x wall opening.

## 5. Wearing it as the ankle hub (engineering tests on the team only)

- **Fitting:** thread the strap through both wing slots. Wear the box on the lower shin with the **UP** arrow toward the knee.
- **Orientation:** write down how the MPU6050 axes sit relative to the arrow, because the firmware's stride detector depends on it.
- **Power:** there is no battery bay. Today the box is powered over USB.
- **Not assessed:** sealing (none claimed), skin contact, pressure under the strap, and wear with a sari or lungi.
- **Not a study:** testing on the team is engineering, not a study (README "Ethics and claims").
