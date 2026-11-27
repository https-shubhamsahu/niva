"""NIVA cartridge interconnect board and charging dock: KiCad 9 schematics (Rev C.1).

Two single-sheet projects, written with the shared niva_kisch writer:
  electronics/cartridge/NIVA-cartridge.kicad_sch   strip PCB inside the battery cartridge
  electronics/dock/NIVA-dock.kicad_sch             USB-C charging dock for bare cartridges

Safety architecture (no firmware in the safety path):
  1. Cell: EEMB LP502030 class with integrated protection module (over-charge, over-discharge,
     over-current, short circuit) and NTC lead.
  2. Cartridge: series polyfuse between the cell and every external contact (pod plates and dock pads).
  3. Dock: MCP73831 linear charger, 4.20 V, I_REG = 1000 V / R_PROG = 100 mA (~0.43 C of 230 mAh min).
     PROG is grounded only through Q1; an LM393 window on the pack NTC turns Q1 off outside ~4-41 C,
     with the NTC open (no cartridge) or shorted. A floating PROG disables the MCP73831 (datasheet).
     USB input: F1 polyfuse then D2 SMAJ5.0A TVS to GND (datasheet 6.1.1.2). No charge timer and no input OVP
     in this charger: both wait for the Rev C.3 charger IC.
  4. Mechanics: the pod has no charge input; only a bare cartridge fits the dock well; the cartridge
     screw is hidden by the cradle while worn.
"""
from pathlib import Path
import json, shutil
import niva_kisch as K
from niva_kisch import *
import niva_layout as L

BASE = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
K.POWER.update({'VBUS': 'power:VBUS'})
RFP = 'Resistor_SMD:R_0603_1608Metric'; CFP = 'Capacitor_SMD:C_0603_1608Metric'; C0805 = 'Capacitor_SMD:C_0805_2012Metric'

def footprints(folder):
    """Project-local footprints: wire solder pads, gold contact pads and a spring-pin placeholder."""
    folder.mkdir(parents=True, exist_ok=True)
    fx = lambda sz: f'(effects (font (size {sz} {sz}) (thickness {round(sz * 0.15, 3)})))'
    def fp(name, descr, pads, body, model=None, attr='smd'):
        w, h = body
        txt = (f'(footprint "{name}" (version 20241229) (generator "niva_revC") (generator_version "9.0")\n(layer "F.Cu")\n'
               f'(descr {q(descr)})\n'
               f'(property "Reference" "REF**" (at 0 {-h / 2 - 1.0} 0) (layer "F.SilkS") (uuid "{uid()}") {fx(0.6)})\n'
               f'(property "Value" {q(name)} (at 0 {h / 2 + 1.0} 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.5)})\n'
               f'(property "Footprint" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(property "Datasheet" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(property "Description" {q(descr)} (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(attr {attr})\n'
               f'(fp_rect (start {-w / 2} {-h / 2}) (end {w / 2} {h / 2}) (stroke (width 0.1) (type default)) (fill no) (layer "F.Fab") (uuid "{uid()}"))\n'
               f'(fp_rect (start {-w / 2 - 0.25} {-h / 2 - 0.25}) (end {w / 2 + 0.25} {h / 2 + 0.25}) (stroke (width 0.05) (type default)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n')
        for num, x, y, shape, sx, sy, layers in pads:
            txt += f'(pad "{num}" smd {shape} (at {x} {y}) (size {sx} {sy}) (layers {layers}) (uuid "{uid()}"))\n'
        if model: txt += f'(model "${{KIPRJMOD}}/3dmodels/{model}" (offset (xyz 0 0 0)) (scale (xyz 1 1 1)) (rotate (xyz 0 0 0)))\n'
        (folder / f'{name}.kicad_mod').write_text(txt + ')\n')
    CU = '"F.Cu" "F.Mask"'; CUP = '"F.Cu" "F.Paste" "F.Mask"'
    fp('WirePads_1x03_P1.8mm', 'Solder pads for the three cell leads: pad 1 cell +, pad 2 NTC, pad 3 cell - (AWG26-30; EEMB LP502030 leads are AWG28)',
       [(str(i + 1), 0, (i - 1) * 1.8, 'rect', 1.5, 1.1, CU) for i in range(3)], (1.7, 4.9))
    fp('WirePads_1x04_P1.7mm', 'Solder pads for four leads to the lid contact plates',
       [(str(i + 1), 0, (i - 1.5) * 1.7, 'rect', 1.5, 1.0, CU) for i in range(4)], (1.7, 6.1))
    fp('ContactPads_1x03_P6.0mm', 'Gold (ENIG) dock contact pads, reached through the cartridge floor; place on B.Cu',
       [(str(i + 1), 0, (i - 1) * 6.0, 'circle', 2.0, 2.0, CU) for i in range(3)], (2.4, 14.4))
    fp('SpringPins_1x03_P6.0mm_Vertical', 'Dock J2, Rev C.2: 3 x Mill-Max 0900-0-15-20-76-14-11-0 SMT spring-loaded pins '
       'at 6.0 mm pitch on 2.08 mm round pads (datasheet: .082 in min. solder pad; 3.48 mm free height, 2.97 mm at the '
       '0.508 mm rated travel)', [(str(i + 1), 0, (i - 1) * 6.0, 'circle', 2.08, 2.08, CUP) for i in range(3)],
       (2.4, 14.4), 'NIVA_SpringPin_1x03_ENVELOPE.step')

def project(folder, name, sheet, parts_note):
    pro = json.loads((ROOT / 'work/kicad_pro_template.json').read_text())
    pro['meta']['filename'] = name + '.kicad_pro'; pro['sheets'] = [[sheet.uuid, 'Root']]
    base = pro['net_settings']['classes'][0]
    def nc(n, t, c, pr):
        d = dict(base); d.update(name=n, track_width=t, clearance=c, via_diameter=0.6, via_drill=0.3, priority=pr); return d
    pro['net_settings']['classes'] = [nc('Default', 0.2, 0.15, 2147483647), nc('Power', 0.4, 0.2, 0)]
    pro['net_settings']['netclass_patterns'] = [{'netclass': 'Power', 'pattern': n} for n in parts_note]
    pro['net_settings']['netclass_assignments'] = None
    pro['board']['design_settings']['rules'].update(min_clearance=0.15, min_track_width=0.15, min_via_diameter=0.5,
        min_through_hole_diameter=0.25, min_via_annular_width=0.1, min_copper_edge_clearance=0.25, min_hole_to_hole=0.25,
        min_hole_clearance=0.2)
    (folder / (name + '.kicad_pro')).write_text(json.dumps(pro, indent=2))
    (folder / 'fp-lib-table').write_text('(fp_lib_table (version 7)\n  (lib (name "NIVA_power")(type "KiCad")'
                                         '(uri "${KIPRJMOD}/NIVA_power.pretty")(options "")(descr "NIVA contact and pad footprints"))\n)\n')

def single_sheet(folder, name, title, paper='A4'):
    K.PROJECT = name; K.OUT = folder; folder.mkdir(parents=True, exist_ok=True)
    s = Sch(name, title, paper, 1); s.path = '/' + s.uuid; return s

# ================================================================ cartridge interconnect strip
cdir = BASE / 'cartridge'; footprints(cdir / 'NIVA_power.pretty')
cart = single_sheet(cdir, 'NIVA-cartridge', 'NIVA battery cartridge | interconnect strip + polyfuse | Rev C.1')
cart.text(20, 18, 'NIVA CARTRIDGE INTERCONNECT - ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 2.2)
cart.place('Connector_Generic:Conn_01x03', 'J1', 'CELL LEADS (+, NTC, -)', 40, 70,
           {'1': 'CELL_P', '2': 'NTC', '3': 'PACK_N'}, 'NIVA_power:WirePads_1x03_P1.8mm')
# F1 (Rev C.2): EEMB LP502030-PCM-LD spec ZJQM-RD-SPC-A03249 §6.1 rates the PCM for 0.3 A constant, 0.8 A peak for 3 s.
# MF-PSMF035X holds 0.30 A at 40 C and trips by 0.75 A (Bourns data), so it sits inside the PCM envelope as layer 2.
cart.place('Device:Polyfuse', 'F1', 'PTC 0805 0.35 A hold / 0.75 A trip, 6 V', 90, 60, {'1': 'CELL_P', '2': 'PACK_P'},
           'Fuse:Fuse_0805_2012Metric', extra={'MPN': 'Bourns MF-PSMF035X-2'})
cart.place('Connector_Generic:Conn_01x04', 'J2', 'TO LID PLATES (P-, P-, P+, P+) -> pod J2', 150, 70,
           {'1': 'PACK_N', '2': 'PACK_N', '3': 'PACK_P', '4': 'PACK_P'}, 'NIVA_power:WirePads_1x04_P1.7mm')
cart.place('Connector_Generic:Conn_01x03', 'J3', 'DOCK PADS (P+, NTC, P-), underside', 150, 110,
           {'1': 'PACK_P', '2': 'NTC', '3': 'PACK_N'}, 'NIVA_power:ContactPads_1x03_P6.0mm')
cart.text_block(20, 135, [
    'Cell: EEMB LP502030 class with integrated protection module (OV/UV/OC/short) and NTC lead - protection layer 1.',
    'F1 polyfuse in series with every external P+ path (pod and dock) - independent protection layer 2.',
    'NTC is passed to the dock only; the pod never sees it. No active parts in the cartridge.',
    'Dock pads are exposed only on the cartridge rear face, which the cradle covers while the pod is worn.'], 1.3)
cart.save('(sheet_instances (path "/" (page "1")))')
project(cdir, 'NIVA-cartridge', cart, ['*PACK_P', '*PACK_N', '*CELL_P'])
_p = json.loads((cdir / 'NIVA-cartridge.kicad_pro').read_text())          # 3.4 mm strip: 0.3 mm tracks, 0.15 mm gaps
_p['net_settings']['classes'][1].update(track_width=0.3, clearance=0.15); (cdir / 'NIVA-cartridge.kicad_pro').write_text(json.dumps(_p, indent=2))

# ================================================================ charging dock
ddir = BASE / 'dock'; footprints(ddir / 'NIVA_power.pretty')
dock = single_sheet(ddir, 'NIVA-dock', 'NIVA cartridge charging dock | USB-C, MCP73831, hardware NTC window | Rev C.1', 'A3')
dock.text(20, 16, 'NIVA CHARGING DOCK - ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 2.5)
sch = dock
def R(ref, v, x, y, a, b, mpn=None): dock.place('Device:R', ref, v, x, y, {'1': a, '2': b}, RFP, extra={'MPN': mpn} if mpn else None)
def Cc(ref, v, x, y, a, b, fp=CFP, mpn=None): dock.place('Device:C', ref, v, x, y, {'1': a, '2': b}, fp, extra={'MPN': mpn} if mpn else None)
dock.text(20, 30, '01  USB-C SINK (5 V ONLY)', 1.8)
# J1: GCT USB4125 drawing Rev A6 ordering grid: shell stake "S" blank = 1.00 mm, 0190 = 1.90 mm. The dock PCB is 1.6 mm,
# so only -0190 reaches through for the plated-slot fillet. KiCad's ..._USB4125-xx-x-0190_6P footprint has the same
# copper as the one used here (pads, four 0.6 x 1.2 mm slots); only its 3D model differs.
dock.place('Connector:USB_C_Receptacle_PowerOnly_6P', 'J1', 'USB-C 6P power-only', 45, 70,
           {'A5': 'CC1', 'B5': 'CC2', 'A9': 'VBUS_IN', 'B9': 'VBUS_IN', 'A12': 'GND', 'B12': 'GND', 'S1': 'GND'},
           'Connector_USB:USB_C_Receptacle_GCT_USB4125-xx-x_6P_TopMnt_Horizontal', extra={'MPN': 'GCT USB4125-GF-A-0190'})
R('R1', '5.1k', 85, 60, 'CC1', 'GND'); R('R2', '5.1k', 100, 60, 'CC2', 'GND')
# F1 (Rev C.2 fix): Bourns MF-NSMF050/24X-2, 1206: I_hold 0.50 A at 23 C (0.26 A at 85 C) against ~0.11 A of charger, LED
# and comparator; I_trip 1.00 A; 0.10 s max at 8 A; R 0.15-0.75 ohm. 24 V rated so it holds off a faulty 20 V source
# once D2 has made it trip (MF-NSMF050 is 13.2 V). Bourns land 1.0 x 1.6 mm, 2.0 mm gap: fits the KiCad 1206 land.
dock.place('Device:Polyfuse', 'F1', 'PTC 0.5 A hold, 24 V', 85, 95, {'1': 'VBUS_IN', '2': 'VBUS'}, 'Fuse:Fuse_1206_3216Metric',
           extra={'MPN': 'Bourns MF-NSMF050/24X-2'})
dock.flag(110, 110, 'VBUS'); dock.flag(125, 110, 'GND')
dock.text(150, 30, '02  LINEAR CHARGER  4.20 V / 100 mA', 1.8)
dock.place('Battery_Management:MCP73831-2-OT', 'U1', 'MCP73831T-2ACI/OT', 190, 70,
           {'1': 'STAT', '2': 'GND', '3': 'BAT', '4': 'VBUS', '5': 'PROG'}, 'Package_TO_SOT_SMD:SOT-23-5',
           extra={'MPN': 'MCP73831T-2ACI/OT'})
# C1/C2 (Rev C.2 fix): MCP73831 needs >= 4.7 uF on VDD and VBAT after DC bias; 10 uF 0805 X5R 16 V should keep that at
# 4-5 V (typical DC-bias curve, not measured). The 4.7 uF 10 V 0603 parts did not.
Cc('C1', '10u 16V X5R', 160, 100, 'VBUS', 'GND', C0805, 'Murata GRM21BR61C106KE15L')
Cc('C2', '10u 16V X5R', 225, 100, 'BAT', 'GND', C0805, 'Murata GRM21BR61C106KE15L')
R('R3', '10k 1%', 245, 70, 'PROG', 'PROG_SW')
dock.place('Transistor_FET:2N7002', 'Q1', '2N7002', 265, 90, {'1': 'TEMP_OK', '2': 'GND', '3': 'PROG_SW'},
           'Package_TO_SOT_SMD:SOT-23')
R('R4', '1k', 160, 130, 'VBUS', 'LED_A'); dock.place('Device:LED', 'D1', 'AMBER 0805 (charging)', 190, 130,
           {'1': 'STAT', '2': 'LED_A'}, 'LED_SMD:LED_0805_2012Metric')
dock.text_block(150, 150, ['R_PROG 10k -> I_REG = 1000 V / 10 kOhm = 100 mA (MCP73831 datasheet).',
                           'PROG reaches GND only through Q1: Q1 off -> PROG floats -> charger disabled.',
                           'D1 lights while STAT is low (charging). Charge complete or inhibited = off.'], 1.2)
dock.text(20, 170, '03  PACK NTC WINDOW (HARDWARE, NO FIRMWARE)', 1.8)
R('R5', '22k 1%', 40, 200, 'VBUS', 'NTC_S'); Cc('C3', '100n', 60, 230, 'NTC_S', 'GND')
# R6/R7/R8 (Rev C.2 retune): thresholds 0.525 / 0.201 of VBUS. 10k B3435: 3.7..41.2 C nominal; worst case with 1 % R5-R8,
# NTC R25 and B at 1 %, LM393 +-9 mV and 0..400 nA per input, VBUS 4.6-5.25 V: 2.2..43.0 C (B3380 1.8..43.3, B3950 4.9..40.5).
R('R6', '46.4k 1%', 90, 195, 'VBUS', 'VTH_HI', 'Yageo RC0603FR-0746K4L')
R('R7', '31.6k 1%', 90, 225, 'VTH_HI', 'VTH_LO', 'Yageo RC0603FR-0731K6L')
R('R8', '19.6k 1%', 90, 255, 'VTH_LO', 'GND', 'Yageo RC0603FR-0719K6L')
dock.place('Comparator:LM393', 'U2', 'LM393', 150, 205, {'1': 'TEMP_OK', '2': 'NTC_S', '3': 'VTH_HI'},
           'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=1)
dock.place('Comparator:LM393', 'U2', 'LM393', 150, 245, {'5': 'NTC_S', '6': 'VTH_LO', '7': 'TEMP_OK'},
           'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=2)
dock.place('Comparator:LM393', 'U2', 'LM393', 200, 225, {'8': 'VBUS', '4': 'GND'}, 'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=3)
Cc('C4', '100n', 225, 225, 'VBUS', 'GND'); R('R9', '100k', 245, 200, 'VBUS', 'TEMP_OK')
dock.text_block(20, 275, [
    'NTC_S = VBUS x R_NTC / (22k + R_NTC). Window (ratio of VBUS): cold/open trip 0.525 (VTH_HI), hot/short trip 0.201 (VTH_LO).',
    '10k B3435 NTC: charges 3.7..41.2 C nominal, 2.2..43.0 C worst case (1 % R and NTC, LM393 9 mV / 400 nA). B3950: 6.3..39.0 C.',
    'No cartridge: NTC_S = VBUS (5 V) -> unit A pulls TEMP_OK low -> no charge. Only VTH_HI (2.62 V) must be inside the',
    'LM393 common-mode range (VCC - 1.5 V at 25 C, VCC - 2 V over temperature): an input outside it still gives a correct output.',
    # A resistor TEMP_OK -> VTH_HI (review C10, 4.7M) gives +0.46 C at the cold edge, but it also pulls VTH_LO down when
    # TEMP_OK goes low, i.e. -0.35 C (negative feedback) at the hot edge: TEMP_OK would oscillate in a band
    # at ~41 C. Hysteresis on both edges needs VTH_LO from its own divider; the Rev C.3 TS-pin charger makes this moot.
    'No hysteresis. TEMP_OK->VTH_HI feedback would fix the cold edge but makes the hot edge unstable (shared divider): Rev C.3.'], 1.2)
dock.place('Connector_Generic:Conn_01x03', 'J2', 'SPRING PINS TO CARTRIDGE (P+, NTC, P-)', 300, 205,
           {'1': 'BAT', '2': 'NTC_S', '3': 'GND'}, 'NIVA_power:SpringPins_1x03_P6.0mm_Vertical',
           extra={'MPN': 'Mill-Max 0900-0-15-20-76-14-11-0 (3 pcs)'})
for ref, x in (('H1', 300), ('H2', 315), ('H3', 330), ('H4', 345)):
    dock.place('Mechanical:MountingHole', ref, 'M2', x, 250, {}, 'MountingHole:MountingHole_2.2mm_M2', bom=False)
# D2 (Rev C.2 fix, review C1): TVS after F1, VBUS to GND, as MCP73831 DS20001984H 6.1.1.2 / Fig. 6-1 show for hot-pluggable
# USB. Bourns SMAJ5.0A: VRWM 5.0 V, VBR 6.40-7.00 V at 10 mA (VDD abs. max 7.0 V), VC 9.2 V at 43.5 A, 400 W, 1.0 W steady.
# Placed last so the UUID sequence of every earlier symbol is unchanged. Board: D_SMA at (157.1, 59.2), beside C1/U1.
dock.place('Diode:SMAJ5.0A', 'D2', 'SMAJ5.0A', 100, 95, {'1': 'VBUS', '2': 'GND'}, 'Diode_SMD:D_SMA', rotation=270,
           extra={'MPN': 'Bourns SMAJ5.0A'})
_i = next(i for i, s in enumerate(dock.items) if '(property "Reference" "D2"' in s)    # place() writes field angle 0,
dock.items[_i] = (dock.items[_i].replace('(at 102.87 94.61 0)', '(at 102.87 94.61 90)')  # drawn vertical on a 270-degree
                  .replace('(at 102.87 97.16 0)', '(at 102.87 97.16 90)'))              # symbol: turn D2's fields upright
dock.text_block(20, 125, ['D2 TVS (Bourns SMAJ5.0A) after F1, VBUS to GND, as in MCP73831 DS20001984H 6.1.1.2: clamps hot-plug ringing',
                          '(VBR 6.40-7.00 V at 10 mA vs the 7.0 V VDD abs. max). A sustained overvoltage makes D2 conduct and trips F1 (24 V PTC).'], 1.2)
dock.save('(sheet_instances (path "/" (page "1")))')
project(ddir, 'NIVA-dock', dock, ['VBUS', 'VBUS_IN', 'GND', 'BAT'])
for d in (cdir, ddir):
    (d / 'sym-lib-table').write_text('(sym_lib_table (version 7)\n)\n')
print('cartridge parts:', len(cart.parts), '| dock parts:', len(dock.parts))
