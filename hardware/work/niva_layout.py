"""Single source of truth for NIVA pod Rev C board geometry and component placement.

Imported by build_niva_pcb.py (KiCad python, inside kicad/kicad:9.0) and by
build_niva_cad.py (FreeCAD python) so the enclosure and the PCB cannot drift apart.

Pod frame (millimetres), shared with the FreeCAD model:
  x = pod width (0..42), y = pod height (0 = bottom/cable end, 60 = top),
  z = depth (0 = rear face against the cradle, 20 = front face).
The board top (component side) faces +z. KiCad looks at the top side, so
  kicad_x = KX0 + x,  kicad_y = KY0 - y.
"""

POD_W, POD_H = 42.0, 60.0
BOARD = dict(x0=4.0, y0=6.0, w=34.0, h=48.0, r=4.0, t=1.0)   # outline in pod frame (before corner notches)

# Enclosure screw bosses (rear housing <-> front cover), merged into the side walls so they sit
# inboard of a continuous gasket line and outboard of the battery bay. The board is notched around them.
CASE_SCREWS = [(3.6, 8.5), (38.4, 8.5), (3.6, 51.5), (38.4, 51.5)]
CASE_BOSS_R = 2.2          # M2 thread-forming boss (4.4 mm OD)
BOARD_NOTCH_R = 2.6        # board clearance around each boss (0.4 mm)
PCB_Z0 = 11.8                                                # board underside; top copper at PCB_Z0 + t
KX0, KY0 = 100.0, 100.0

def to_kicad(x, y):
    return KX0 + x, KY0 - y

# Two M2 screws through the board into rear-housing bosses outside the battery bay.
# The lower board edge rests on housing ledges and is clamped by front-cover ribs.
MOUNT_HOLES = [('H1', 9.0, 49.0), ('H2', 33.0, 49.0)]

# ref: (x, y, kicad_rotation_deg, side)   side 'F' = top, 'B' = underside (faces the battery bay)
PLACE = {
    # module: antenna end (footprint keepout) at the top board edge, away from the cell
    'U1': (21.0, 45.45, 0, 'F'),
    'H1': (9.0, 49.0, 0, 'F'), 'H2': (33.0, 49.0, 0, 'F'),
    # IMU beside screw H2 for a stiff mount; axes printed on silk
    'U3': (33.5, 42.5, 0, 'F'), 'C5': (29.8, 42.2, 90, 'F'), 'C20': (36.7, 42.5, 90, 'F'),
    # module support on the left, near the module 3V3/EN pins
    'C2': (11.6, 38.9, 0, 'F'), 'C3': (12.2, 46.5, 90, 'F'), 'R1': (5.5, 42.5, 90, 'F'),
    'C1': (8.3, 42.5, 90, 'F'), 'R2': (11.0, 42.5, 90, 'F'), 'R3': (6.2, 38.9, 0, 'F'),
    # ADC on the left, next to the force channel rows
    # ADC rotated so CH0-CH7 (pins 1-8) face the filter rows below and SPI/VREF/VDD face the module above
    'U2': (11.0, 26.0, 90, 'F'), 'C4': (7.0, 31.6, 0, 'F'), 'C19': (11.0, 31.6, 0, 'F'),
    # status emitters under the light window, below the module's SPI fan-out (window x 17..25, y 30.4..32.6)
    'D4': (19.4, 31.5, 0, 'F'), 'D5': (22.8, 31.5, 0, 'F'),
    'R45': (26.4, 32.4, 0, 'F'), 'R46': (26.4, 30.6, 0, 'F'),
    # power, right middle
    'U5': (30.5, 34.8, 0, 'F'), 'C6': (35.6, 35.5, 90, 'F'), 'C7': (26.7, 34.8, 90, 'F'), 'C8': (31.0, 38.2, 0, 'F'),
    'U6': (31.5, 29.5, 0, 'F'), 'C9': (35.6, 30.2, 90, 'F'), 'R4': (30.0, 26.0, 0, 'F'), 'R5': (34.2, 26.0, 0, 'F'),
    # insert connector: entry faces the pod bottom; front face at the board edge
    'J1': (21.0, 9.0, 0, 'F'),
    # user button under the front-cover actuator
    'SW1': (21.0, 22.0, 0, 'F'), 'U4': (33.0, 22.2, 0, 'F'),
    # underside: cartridge spring contacts and the service pads, both reached through the bay
    'J2': (29.0, 21.5, 0, 'B'), 'J3': (21.0, 28.0, 0, 'B'),
}
ROW_A = ['R11', 'R21', 'R12', 'R22', 'R13', 'R23', 'R14', 'R24', 'R15', 'R25',
         'R33', 'C18', 'R31', 'R32', 'C16', 'R30', 'R34', 'C17']
ROW_B = ['C11', 'C12', 'C13', 'C14', 'C15', 'R6', 'R40', 'R41', 'C40', 'R42', 'R43', 'R44', 'C41', 'C42', 'D2', 'D3']
def _rows():
    x = 5.4
    for ref in ROW_A:
        PLACE[ref] = (round(x, 2), 14.4, 90, 'F'); x += 1.8
    x = 5.4
    for ref in ROW_B:
        wide = ref.startswith('D')
        if wide: x += 0.25
        PLACE[ref] = (round(x, 2), 17.9, 90, 'F'); x += 2.1 if wide else 1.8
_rows()

# Front-panel features that the CAD must align with (pod frame).
BUTTON_XY = PLACE['SW1'][:2]
LIGHT_WINDOW = dict(x0=17.0, y0=30.4, w=8.0, h=2.2)
EMITTERS = [PLACE['D4'][:2], PLACE['D5'][:2]]
CONNECTOR_XY = PLACE['J1'][:2]
SPRING_CONTACTS_XY = PLACE['J2'][:2]
SERVICE_PADS_XY = PLACE['J3'][:2]

# Antenna copper keepout extension beyond the module's own zone (pod frame).
ANTENNA_KEEPOUT = dict(x0=11.0, y0=48.4, x1=31.0, y1=54.0)

# Measured model heights above the top copper (from the 3D models in electronics/3dmodels).
HEIGHT = {'J1': 4.25, 'U1': 2.40, 'SW1': 1.90, 'U2': 1.75, 'U5': 1.55, 'U4': 1.55, 'D4': 1.10, 'D5': 1.10,
          'J2': 3.00}

# ---------------------------------------------------------------- battery cartridge (Rev C.1)
# Selected cell: EEMB LP502030 family with integrated PCM and NTC leads (e.g. LP502030-PCM-NTC-LD).
# Published maximum size 20.5 x 32.0 x 5.3 mm (W x L x T, PCM included), 250 mAh typ / 230 mAh min,
# 3.7 V nominal, ~5 g (EEMB listing; confirm against the purchased lot's datasheet).
CELL = dict(model='EEMB LP502030-PCM-NTC-LD (class)', w=20.5, l=32.0, t=5.3, swell=0.08,
            cap_min_mAh=230, cap_typ_mAh=250)
# Cartridge in the pod frame. The cell sits against the -x side; a 3.4 mm interconnect strip PCB lies
# beside it on the cup floor. Lead room of 2 mm at the PCM (+y) end.
CART = dict(cup_x0=7.0, cup_y0=5.0, cup_w=28.0, cup_l=37.5, cup_h=8.0, wall=1.5, floor=1.0,
            lid_z=8.0, lid_t=1.2, plug_t=0.8)
CART['cav'] = (CART['cup_x0'] + CART['wall'], CART['cup_y0'] + CART['wall'],
               CART['cup_w'] - 2 * CART['wall'], CART['cup_l'] - 2 * CART['wall'])       # x0, y0, w, l
CELL_XY = (8.8, 6.8)                                                                    # cell corner
STRIP = dict(x0=29.85, y0=8.0, w=3.4, l=30.0, t=0.8)                                    # cartridge PCB
DOCK_PADS = [('P+', 31.55, 12.0), ('NTC', 31.55, 18.0), ('P-', 31.55, 24.0)]            # strip underside
CART_TAB = dict(x0=27.0, y0=41.5, w=8.0, l=4.5, t=1.6, screw=(31.0, 44.3))             # retention tab
BAY_CLEAR = 0.4

# Cartridge interconnect strip placement (pod frame). J3's gold pads face the cartridge floor windows.
CART_PLACE = {'J1': (30.95, 35.0, 0, 'F'),        # cell leads (+, -, NTC) at the PCM end; pads offset -x
              'J2': (30.95, 27.5, 0, 'F'),        # four leads up to the lid contact plates  (leaves a 1.3 mm
              'F1': (30.95, 12.1, 90, 'F'),       # polyfuse                                   channel at +x)
              'J3': (31.55, 18.0, 0, 'B')}        # dock pads P+ / NTC / P- at y = 12 / 18 / 24

# ---------------------------------------------------------------- charging dock (dock frame, mm, z up)
# The bare cartridge sits rear face down in a keyed well; its x/y are the pod-frame x/y shifted by DOCK['dxy'],
# so the dock spring pins land on DOCK_PADS without any mirroring.
DOCK = dict(w=64.0, d=62.0, r=6.0, dxy=(11.0, 5.0), pcb_x0=3.0, pcb_y0=3.0, pcb_w=58.0, pcb_h=56.0, pcb_t=1.6,
            base_t=2.5, pcb_z=6.4, floor_t=1.2, well_depth=10.4, well_clear=0.5)
DOCK['pads'] = [(x + DOCK['dxy'][0], y + DOCK['dxy'][1]) for n, x, y in DOCK_PADS]
DOCK['floor_z'] = DOCK['pcb_z'] + DOCK['pcb_t'] + 2.8          # 2.8 mm component headroom under the well floor
DOCK['top_z'] = DOCK['floor_z'] + DOCK['well_depth']           # cartridge (9.2 mm tall) sits 1.2 mm below the top face
_px = DOCK['pads'][1][0]; _py = DOCK['pads'][1][1]
DOCK_PLACE = {
    'J2': (_px, _py, 180, 'F'),                                  # spring pins: pin 1 (P+) at the lowest y
    'J1': (57.5, 50.0, 90, 'F'), 'R1': (51.5, 51.5, 90, 'F'), 'R2': (49.7, 51.5, 90, 'F'),
    'F1': (50.8, 45.0, 90, 'F'), 'C1': (52.5, 40.3, 0, 'F'),
    'U1': (53.0, 35.5, 0, 'F'), 'C2': (53.0, 31.2, 0, 'F'), 'R3': (57.6, 35.5, 90, 'F'), 'Q1': (57.2, 29.8, 0, 'F'),
    'R4': (53.0, 14.2, 0, 'F'), 'D1': (54.8, 10.2, 0, 'F'),
    'U2': (10.5, 30.0, 0, 'F'), 'C4': (10.5, 25.3, 0, 'F'), 'R5': (6.2, 38.0, 90, 'F'), 'C3': (8.2, 38.0, 90, 'F'),
    'R6': (12.4, 38.0, 90, 'F'), 'R7': (14.4, 38.0, 90, 'F'), 'R8': (6.2, 22.0, 90, 'F'), 'R9': (14.4, 22.0, 90, 'F'),
    'H1': (6.5, 6.5, 0, 'F'), 'H2': (57.5, 6.5, 0, 'F'), 'H3': (6.5, 55.5, 0, 'F'), 'H4': (47.0, 55.5, 0, 'F'),
}
DOCK_LED = DOCK_PLACE['D1'][:2]
