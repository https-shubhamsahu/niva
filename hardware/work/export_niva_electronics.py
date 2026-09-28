"""Export every NIVA KiCad project (host python3; drives kicad-cli through the kicad9 docker wrapper).

  python3 export_niva_electronics.py [pod] [cartridge] [dock]      (default: all three)

Per board: schematic PDF, BOM, ERC, netlist, DRC (with schematic parity), assembly PDFs, PCBA STEP + GLB.
Fabrication files (Gerber, drill, placement) are written ONLY when ERC and DRC report zero errors and zero
unconnected items, and even then into fab-REVIEW-ONLY-NOT-RELEASED/ with a STATUS.txt that lists the
blockers still open for that board. Passing the automated checks is not a design review.
"""
import re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
BOARDS = {'pod': E, 'cartridge': E / 'cartridge', 'dock': E / 'dock'}

# Open items that block ordering boards even when every automated check passes.
BLOCKERS = {
    'pod': ['J2 cartridge spring contacts: NIVA land pattern and 3D envelope, part not selected - replace with supplier data.',
            'U6 MAX17048 TDFN: stock KiCad land pattern, simplified 3D envelope - confirm against the purchased package.',
            'Antenna keep-out and ESP32-C3-MINI-1 placement need a radiated check in the closed enclosure.',
            'No independent schematic/layout review, no DFM report from the chosen fabricator, no bring-up of a first article.'],
    'cartridge': ['F1 polyfuse part number not selected (hold/trip current must be set against the cell PCM limits).',
                  'Wire pad sizes assume 30 AWG leads - confirm with the cell lot lead gauge.',
                  'ENIG finish and contact-pad wear under the dock spring pins untested.',
                  'No independent review, no DFM report from the chosen fabricator.'],
    'dock': ['J2 spring pins: PLACEHOLDER land pattern (part not selected; supplier datasheet not reachable here).',
             'Charger thermal window thresholds (R6/R7/R8) depend on the NTC fitted to the purchased cell - verify.',
             'No independent review, no DFM report from the chosen fabricator.'],
}

def kc(cwd, *args):
    r = subprocess.run(['kicad9', 'kicad-cli', *args], cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

def counts(rpt):
    t = rpt.read_text()
    n = lambda pat: int(m.group(1)) if (m := re.search(pat, t)) else 0
    errors = len(re.findall(r';\s*error', t))
    return dict(violations=n(r'Found (\d+) (?:DRC violations|ERC violations|violations)'), errors=errors,
                unconnected=n(r'Found (\d+) unconnected'), footprint=n(r'Found (\d+) Footprint errors'))

def export(key):
    d = BOARDS[key]; name = f'NIVA-{key}'; sch, pcb = f'{name}.kicad_sch', f'{name}.kicad_pcb'
    x = d / 'exports'; p = x / 'pcb'; p.mkdir(parents=True, exist_ok=True)
    rel = lambda f: str(f.relative_to(d))
    kc(d, 'sch', 'erc', '--severity-all', '-o', rel(x / f'{name}-ERC.rpt'), sch)
    kc(d, 'sch', 'export', 'pdf', '-o', rel(x / f'{name}-schematic.pdf'), sch)
    kc(d, 'sch', 'export', 'netlist', '--format', 'kicadsexpr', '-o', rel(x / f'{name}.net'), sch)
    kc(d, 'sch', 'export', 'bom', '--fields', 'Reference,Value,Footprint,MPN,${QUANTITY}', '--group-by', 'Value,Footprint,MPN',
       '-o', rel(x / f'{name}-BOM.csv'), sch)
    kc(d, 'pcb', 'drc', '--severity-all', '--schematic-parity', '-o', rel(p / f'{name}-DRC.rpt'), pcb)
    kc(d, 'pcb', 'export', 'pdf', '--layers', 'Edge.Cuts,F.Fab,F.Courtyard,F.Cu', '--include-border-title',
       '-o', rel(p / f'{name}-assembly-top.pdf'), pcb)
    kc(d, 'pcb', 'export', 'pdf', '--layers', 'Edge.Cuts,B.Fab,B.Courtyard,B.Cu', '--mirror', '--include-border-title',
       '-o', rel(p / f'{name}-assembly-bottom.pdf'), pcb)
    for fmt in ('step', 'glb'):
        extra = ['--subst-models'] if fmt == 'step' else []
        kc(d, 'pcb', 'export', fmt, '--force', '--user-origin', '100x100mm', *extra, '--include-tracks', '--include-zones',
           '--include-silkscreen', '--include-soldermask', '--include-pads', '-o', rel(p / f'{name}-PCBA.{fmt}'), pcb)
    erc, drc = counts(x / f'{name}-ERC.rpt'), counts(p / f'{name}-DRC.rpt')
    clean = erc['errors'] == 0 and drc['errors'] == 0 and drc['unconnected'] == 0 and drc['footprint'] == 0
    routed = 'UNROUTED' not in (d / pcb).read_text()
    print(f'{key}: ERC {erc} | DRC {drc} | routed={routed}')
    fab = p / 'fab-REVIEW-ONLY-NOT-RELEASED'
    if clean and routed:
        g = fab / 'gerber'; g.mkdir(parents=True, exist_ok=True)
        for f in g.glob('*'): f.unlink()
        cu = 'F.Cu,' + ('In1.Cu,In2.Cu,' if key == 'pod' else '') + 'B.Cu'
        kc(d, 'pcb', 'export', 'gerbers', '--no-protel-ext', '--subtract-soldermask', '--layers',
           cu + ',F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts', '-o', rel(g) + '/', pcb)
        kc(d, 'pcb', 'export', 'drill', '--format', 'excellon', '--excellon-separate-th', '--generate-map', '--map-format', 'pdf',
           '-o', rel(g) + '/', pcb)
        kc(d, 'pcb', 'export', 'pos', '--format', 'csv', '--units', 'mm', '--side', 'both', '-o', rel(fab / f'{name}-placement.csv'), pcb)
        (fab / 'STATUS.txt').write_text(
            f'{name} - FABRICATION DATA FOR REVIEW ONLY - NOT RELEASED - DO NOT ORDER\n\n'
            f'Automated checks at export: ERC errors {erc["errors"]}, DRC errors {drc["errors"]}, '
            f'unconnected {drc["unconnected"]}, footprint errors {drc["footprint"]} (KiCad 9.0.9, schematic parity on).\n'
            'Passing KiCad ERC/DRC is not a design review. Open blockers:\n' + ''.join(f'  - {b}\n' for b in BLOCKERS[key]))
        print(f'  fab data (review only) -> {fab.relative_to(ROOT)}')
    elif fab.exists():
        for f in sorted(fab.rglob('*'), reverse=True): f.unlink() if f.is_file() else f.rmdir()
        fab.rmdir(); print('  stale fab data removed (board no longer clean)')

if __name__ == '__main__':
    for k in (sys.argv[1:] or BOARDS): export(k)
