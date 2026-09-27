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
    'U2': (9.2, 29.5, 0, 'F'), 'C4': (14.6, 26.6, 90, 'F'), 'C19': (14.6, 30.0, 90, 'F'),
    # status emitters directly under the light window (window x 17..25, y 33.9..36.1)
    'D4': (19.4, 35.2, 0, 'F'), 'D5': (22.8, 35.2, 0, 'F'),
    'R45': (19.4, 32.6, 0, 'F'), 'R46': (22.8, 32.6, 0, 'F'),
    # power, right middle
    'U5': (30.5, 34.8, 0, 'F'), 'C6': (35.6, 35.5, 90, 'F'), 'C7': (26.7, 34.8, 90, 'F'), 'C8': (26.7, 31.2, 90, 'F'),
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
LIGHT_WINDOW = dict(x0=17.0, y0=33.9, w=8.0, h=2.2)
EMITTERS = [PLACE['D4'][:2], PLACE['D5'][:2]]
CONNECTOR_XY = PLACE['J1'][:2]
SPRING_CONTACTS_XY = PLACE['J2'][:2]
SERVICE_PADS_XY = PLACE['J3'][:2]

# Antenna copper keepout extension beyond the module's own zone (pod frame).
ANTENNA_KEEPOUT = dict(x0=11.0, y0=48.4, x1=31.0, y1=54.0)

# Measured model heights above the top copper (from the 3D models in electronics/3dmodels).
HEIGHT = {'J1': 4.25, 'U1': 2.40, 'SW1': 1.90, 'U2': 1.75, 'U5': 1.55, 'U4': 1.55, 'D4': 1.10, 'D5': 1.10,
          'J2': 3.00}
