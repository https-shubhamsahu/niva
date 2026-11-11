# NIVA-dock Rev C.2: KiCad to EasyEDA Pro (11 Nov 2026)

EasyEDA Pro 3.2.209 (web), private project `NIVA-dock` in shubhamsahu6393's personal workspace.
It was imported from `NIVA-dock-RevC2-kicad9nets.zip`. That zip is the KiCad project with the
PCB passed through `kicad10_nets_to_kicad9.py`. A first import of the raw KiCad 10 zip lost every
net and all 170 tracks. That attempt was the project `NIVA-dock-RevC2`, now deleted.

After the import, the KiCad parts were replaced with EasyEDA/LCSC library devices (see "Library
parts" below), following Bob Bao's reply of 10 Nov ("importing it and replacing the components").

## Checked against KiCad (via EasyEDA's API, `_EXTAPI_ROOT_`), after the part swap
- Pins: all 58 pins are on the same nets as the KiCad netlist, on both the schematic and the PCB
  (0 mismatches). J1's shell pin is "S1" in KiCad and "7" in the library part.
- Placement: every part is at the same X/Y as NIVA-dock-placement.csv, except J1, whose library
  footprint origin sits 1.14 mm from KiCad's. J1 was moved 1.14 mm so its pads and shell slots land
  exactly on the KiCad ones (0.000 mm). Q1 is rotated 0 -> 180, U1 and U2 0 -> 270, because the
  library footprints are drawn rotated; their pads land on the KiCad pads (table below).
- Vias: 11 vias, 0.6/0.3 mm, untouched (within 0.005 mm of KiCad; EasyEDA stores mils).
- Tracks: 158 segments (KiCad 170). EasyEDA merges collinear segments and dropped two duplicate
  Freerouting stubs (VTH_LO 0.148 mm at 110.3,70.8; STAT 0.199 mm at 159.6,60.1). Six spots were
  re-routed for the library pads (below). Every net is one connected piece through tracks, pads and
  vias alone.
- Outline: 103-161 x 41-97 mm (58 x 56 mm). GND pours on F.Cu and B.Cu, re-filled after the swap.
- Holes: 4 x 2.2 mm NPTH (H1-H4). 4 plated 0.6 x 1.2 mm slots for the J1 shell at x 154.5/158.3,
  y 45.68/54.32, on GND.
- Silk: F "NIVA DOCK REV C.2" and "+", B "PCBWay".

## Changed in the conversion
1. PCB file: KiCad 10 inline nets were rewritten to the KiCad 9 net-table form, and
   `(filled_areas_thickness no)` was added to the zones. KiCad DRC on the converted file gives the
   same result as the original (24 lib warnings, 0 unconnected, 0 parity).
2. Schematic: deleted #FLG01 and #FLG02 (PWR_FLAG). EasyEDA treats them as one global net,
   "PWR_FLAG", which shorted VBUS to GND.
3. Power flags renamed from power_GND/power_VBUS to GND/VBUS. PCB net names lost KiCad's "/"
   prefix (/BAT -> BAT and so on). Connectivity is unchanged.
4. Via rule: the importer swapped KiCad's via limits (0.3 mm min outer, 0.5 mm min hole). The rule
   is now 0.5 mm min outer, 0.25 mm min hole, default 0.6/0.3, matching KiCad.
5. H1-H4 set to "not in BOM", as in KiCad (the import had switched them on).
6. Parts replaced with EasyEDA library devices (next section). LCSC numbers are in
   Supplier/Supplier Part plus Manufacturer/Manufacturer Part on the schematic and PCB.

## Library parts
Swapped with Device Standardization / Device Manager, keeping designators. A second pass ("Use
Recommended Device", "Merge properties (target first)", "Keep current symbol") then took the
library's properties, so Value, Manufacturer and Name now follow the library: C1/C2 "10uF", C3/C4
"100nF", resistors "5.1kΩ", "31.6kΩ" and so on. Parts whose library device has no Value (D1, D2,
F1, J1, Q1, U1, U2) keep the KiCad text. The full KiCad values ("10u 16V X5R", "PTC 0.5 A hold,
24 V", ...) stay in LCSC-parts.csv. Positions, rotations and connectivity were checked unchanged
after this pass.

| Ref | LCSC | Library footprint (was KiCad) | Pad change vs KiCad land |
|---|---|---|---|
| C1, C2 | C77075 | C0805 (C_0805_2012Metric) | pitch 1.90 -> 2.00 mm, pad centres 0.05 mm out |
| C3, C4 | C1591 | C0603 (C_0603_1608Metric) | pitch 1.55 -> 1.40 mm, 0.075 mm in |
| R1-R7, R9 | per CSV | R0603 (R_0603_1608Metric) | pitch 1.65 -> 1.51 mm, 0.07 mm in |
| R8 | C22898 | R0603 (R_0603_1608Metric) | as above |
| D1 | C84262 | LED0805-RD_ORANGE (LED_0805_2012Metric) | pitch 1.875 -> 2.20 mm, 0.16 mm out |
| D2 | C151932 | SMA_L4.4-W2.6-LS5.0-RD (D_SMA) | pitch 4.00 -> 4.39 mm, 0.19 mm out |
| F1 | C27856618 | F1206 (Fuse_1206_3216Metric) | pitch 2.80 -> 2.89 mm, 0.045 mm out |
| Q1 | C8545 | SOT-23-3_L2.9-W1.3-P1.90-LS2.4-BR (SOT-23) | same land, footprint drawn at 180: part rotated, pads within 0.06 mm |
| U1 | C424093 | SOT-23-5_L3.0-W1.7-P0.95-LS2.8-BL (SOT-23-5) | same land, drawn at 270: part rotated, pads within 0.015 mm |
| U2 | C7955 | SOIC-8_L5.0-W4.0-P1.27-LS6.0-BL (SOIC-8_3.9x4.9mm) | rows 4.95 -> 5.41 mm apart (pads 0.23 mm out), drawn at 270: part rotated |
| J1 | C5246813 | TYPE-C-SMD_TYPE-C-6P_USB4125-GF-A-0190 (USB_C_..._USB4125) | same pads and 0.6 x 1.2 mm shell slots; origin 1.14 mm off, part moved to match |
| J2 | C21211881 | kept: NIVA_power:SpringPins_1x03_P6.0mm_Vertical | no EasyEDA library device for C21211881 |
| H1-H4 | none | kept: MountingHole_2.2mm_M2 | not a purchased part |

Pin numbering matches by number on every swapped part (U1 and U2 pinouts checked pad by pad).
- R8: the Stackpole RMCF0603FT19K6 (C2484079) has no EasyEDA library device, so R8 is now
  UNI-ROYAL 0603WAF1962T5E C22898 (19.6k 1% 0603, 4,600 in stock). LCSC-parts.csv updated.
- U2: EasyEDA would not swap the symbol ("number of parts is not the same": KiCad's LM393 has 3
  units, the library symbol has 1). U2 uses the library device and footprint with the KiCad
  3-unit symbol kept.
- Schematic rewiring after the symbol swap: two-terminal parts rotated 270 with 0.05 in wire stubs
  to the old pin ends; U1 and J1 rotated 180 and re-wired, J1 with labelled stubs (GND, VBUS_IN,
  CC1, CC2). The GND flag #PWR02 and its wire were deleted (J1's GND pins now use GND labels).

Tracks re-routed for the library pads (all on F.Cu):
- U2 pins 3/4: VBUS trunk moved 0.23 mm left and its 45 degree run to C4 re-drawn; the NTC_S
  detour round pad 3 moved 0.25 mm left. Before: VBUS overlapped pad 4 and NTC_S overlapped pad 3.
- U2 pin 7: VTH_HI and VTH_LO 45 degree runs lowered 0.12-0.13 mm to clear pad 7.
- R9: the GND track between R9's pads narrowed 0.40 -> 0.254 mm (3 segments; GND also has both pours).
- R1: the CC2 track between R1's pads moved up 0.11 mm to the middle of the gap.
- D1: the STAT 45 degree run starts 0.27 mm further right, plus a 0.28 mm vertical jog. Before, it
  overlapped D1 pad 2 (LED_A).
- J1: the VBUS_IN loop round the A5/B5 pad ends moved out 0.24 mm, and its approach to B9/B12 adjusted.

## LCSC stock (wmsc.lcsc.com product API, 11 Nov 2026; 5 boards)
- Out of stock, swapped (same value, package and tolerance): C3/C4 C14663 -> Samsung
  CL10B104KB8NNNC C1591 (81,700); R7 C185339 -> UNI-ROYAL 0603WAF3162T5E C25967 (70,500). The
  EasyEDA project carries the new numbers on both schematic and PCB.
- Out of stock, no swap: J2 Mill-Max 0900-0-15-20-76-14-11-0 C21211881 (0; 15 pins needed). Kept, since
  the footprint and the cartridge contacts are built around it: buy from DigiKey or Mouser and
  hand-solder after assembly (JLC rates it High difficulty anyway). Distributor stock not checked.
- Low: F1 C27856618, 11 in stock against 5 needed.
- D2: BORN's datasheet row for SMAJ5.0A matches the Bourns figures in STATUS.txt (VRWM 5 V,
  VBR 6.4-7.0 V at 10 mA, VC 9.2 V at 43.5 A, IR 800 uA). MDD C113952 has the same row and
  440,080 in stock.
- Everything else has thousands in stock or more: C1/C2 89,580, D1 220,320, D2 10,650, J1 2,036,
  U1 9,850, R8 (C22898) 4,600, U2 288,950, Q1 and the other resistors above 70,000.

## DRC in EasyEDA (after the part swap)
- PCB: 0 errors of any kind. The earlier property-only "Netlist Error" is gone: Import Changes was
  applied (20 footprint swaps plus H1-H4/J2 Name and Channel ID updates, 0 net changes), and again
  after the library-values pass (214 added properties plus Value, Manufacturer, Name and Description
  updates; no footprint or net changes). Re-checked after: 58/58 pad nets match KiCad, no part moved.
- Schematic: 0 fatal, 0 errors, 1 warning, 4 info (the M2 holes have no pins). The warning
  "Component attributes does not match the Supplier Part ... Device Standardization" now lists J2
  only (it listed all 21 parts while they kept KiCad Value and Manufacturer text). J2 stays
  flagged with Manufacturer set to LCSC's "Mill-Max Mfg. Corp." and even with its Supplier Part
  cleared, so it appears to fire for any part without an EasyEDA library device. J2 keeps
  C21211881 and "Mill-Max".

## Not done
- U2 keeps the KiCad 3-unit symbol; J2 and H1-H4 keep their KiCad footprints (see above). J2's
  Device Standardization warning stays for the same reason.
- The project is not yet published to OSHWLab, and the Spark "Apply Coupon" form is not filled in.
- NIVA-dock-RevC2 was deleted on 11 Nov 2026. It is in EasyEDA's Recycle Bin, so it can be restored.

## Draft to Bob (Discord easyeda_bob or bob@easyeda.com), for Shubham to send
Hi Bob, thanks for the note. I've now added the design to EasyEDA Pro: project "NIVA-dock", a USB-C
charging dock for my wearable's battery cartridge (MCP73831 charger, LM393 NTC window, 2 layers,
58 x 56 mm), with schematic, PCB and LCSC part numbers on every part. I first drew it in KiCad and
imported it into EasyEDA Pro, where I fixed the conversion issues, assigned LCSC parts and ran DRC.
Does an imported design count for Spark, or should I redraw the schematic natively in EasyEDA Pro?
I'm happy to do either. Shubham
