# NIVA-dock Rev C.2: KiCad to EasyEDA Pro (11 Nov 2026)

EasyEDA Pro 3.2.209 (web), private project `NIVA-dock` in shubhamsahu6393's personal workspace.
It was imported from `NIVA-dock-RevC2-kicad9nets.zip`. That zip is the KiCad project with the
PCB passed through `kicad10_nets_to_kicad9.py`. A first import of the raw KiCad 10 zip lost every
net and all 170 tracks. That attempt was the project `NIVA-dock-RevC2`, now deleted.

## Checked against KiCad (via EasyEDA's API, `_EXTAPI_ROOT_`)
- Placement: all 21 parts and H1-H4 are at the same X/Y and rotation as NIVA-dock-placement.csv.
- Pins: all 58 pins are on the same nets as the KiCad netlist (0 mismatches).
- Vias: 11 vias, 0.6/0.3 mm, within 0.005 mm of KiCad's positions (EasyEDA stores coordinates in mils).
- Tracks: KiCad has 170 segments; EasyEDA has 167. Total length per net is the same. EasyEDA merged one
  collinear BAT segment and dropped two duplicate stubs that KiCad drew twice (VTH_LO 0.148 mm at
  110.3,70.8 and STAT 0.199 mm at 159.6,60.1, Freerouting artifacts).
- Outline: 103-161 x 41-97 mm (58 x 56 mm). GND pours on F.Cu and B.Cu.
- Holes: 4 x 2.2 mm NPTH. 4 plated 0.6 x 1.2 mm slots for the J1 shell at x 154.5/158.3,
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
6. Footprints: KiCad footprints kept, so the copper is identical. LCSC numbers were added as Supplier/Supplier Part
   plus Manufacturer/Manufacturer Part on the schematic and PCB (see LCSC-parts.csv). Substitutes:
   R8 Stackpole RMCF0603FT19K6 C2484079 (the Yageo part isn't on LCSC), D1 orange NationStar C84262
   (no amber 0805 found), D2 listed as "BORN" SMAJ5.0A C151932.

## LCSC stock (wmsc.lcsc.com product API, 11 Nov 2026; 5 boards)
- Out of stock, swapped in LCSC-parts.csv (same value, package and tolerance; footprints unchanged):
  C3/C4 C14663 -> Samsung CL10B104KB8NNNC C1591 (81,700); R7 C185339 -> UNI-ROYAL 0603WAF3162T5E
  C25967 (70,500). The EasyEDA project still carries the old numbers on these three parts.
- Out of stock, no swap: J2 Mill-Max 0900-0-15-20-76-14-11-0 C21211881 (0; 15 pins needed). Kept, since
  the footprint and the cartridge contacts are built around it: buy from DigiKey or Mouser and
  hand-solder after assembly (JLC rates it High difficulty anyway). Distributor stock not checked.
- Low: F1 C27856618, 11 in stock against 5 needed.
- D2: BORN's datasheet row for SMAJ5.0A matches the Bourns figures in STATUS.txt (VRWM 5 V,
  VBR 6.4-7.0 V at 10 mA, VC 9.2 V at 43.5 A, IR 800 uA). MDD C113952 has the same row and
  440,080 in stock.
- Everything else has thousands in stock or more: C1/C2 89,580, D1 220,320, D2 10,650, J1 2,036,
  U1 9,850, R8 4,500, U2 288,950, Q1 and the other resistors above 70,000.

## DRC in EasyEDA
- Schematic: 0 fatal, 0 errors, 0 warnings. 4 info lines: the M2 holes have no pins.
- PCB: 0 clearance, 0 via, 0 connection errors. 1 "Netlist Error" remains. Import Changes shows
  that it is property differences only (KiCad ki_* fields, Name/Value text, Channel ID). There are
  0 net, part or pin changes. Those changes were deliberately not applied, because applying them
  would overwrite part values such as "10u 16V X5R" with library names.

## Not done
- The parts are still KiCad library symbols and footprints with LCSC numbers added. They have not
  been replaced with EasyEDA library parts.
- The project is not yet published to OSHWLab, and the Spark "Apply Coupon" form is not filled in.
- NIVA-dock-RevC2 was deleted on 11 Nov 2026. It is in EasyEDA's Recycle Bin, so it can be restored.

## Draft to Bob (Discord easyeda_bob or bob@easyeda.com), for Shubham to send
Hi Bob, thanks for the note. I've now added the design to EasyEDA Pro: project "NIVA-dock", a USB-C
charging dock for my wearable's battery cartridge (MCP73831 charger, LM393 NTC window, 2 layers,
58 x 56 mm), with schematic, PCB and LCSC part numbers on every part. I first drew it in KiCad and
imported it into EasyEDA Pro, where I fixed the conversion issues, assigned LCSC parts and ran DRC.
Does an imported design count for Spark, or should I redraw the schematic natively in EasyEDA Pro?
I'm happy to do either. Shubham
