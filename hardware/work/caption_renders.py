"""Add a status caption band to every delivered render (python3 + Pillow).

renders/raw/*.png (Blender) and renders/pcb-raw/*.png (KiCad raytrace) -> renders/<name>.png
Captions state what the image is, where the geometry comes from and what is provisional,
so a render cannot be mistaken for a released or validated product.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
R = ROOT / 'outputs/NIVA-3D-engineering-prototype/renders'
FONT = next((f for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 'C:/Windows/Fonts/arial.ttf'] if Path(f).exists()), None)
BOLD = next((f for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'C:/Windows/Fonts/arialbd.ttf'] if Path(f).exists()), None)
NAVY, TEAL, PALE = (20, 49, 75), (11, 111, 121), (234, 240, 242)
PCB_NOTE = ('PCB: UNROUTED PLACEMENT PROTOTYPE - no copper tracks designed - not for fabrication. Models: KiCad library '
            '(generic) + Espressif ESP32-C3-MINI-1 (supplier); U6 TDFN and J2 spring contacts are simplified envelopes.')
CAPTIONS = {
    'raw/01_Pod_Assembled': ('NIVA pod Rev C (right) on its cradle',
        'Rendered from the FreeCAD Rev C meshes and the KiCad PCBA. Printed-prototype materials: PETG shells, TPU pad/button, '
        'teal tail boot. Engineering prototype, not a released medical device.'),
    'raw/02_Pod_Exploded': ('NIVA pod Rev C - exploded along the assembly axis',
        'Top to bottom: button + light pipe, front cover, gasket, PCBA, rear housing (tail boot beside), cartridge lid + plates, '
        'cup, cradle, TPU pad. ORANGE = placeholder envelopes (cell not selected, protection board not designed). ' + PCB_NOTE),
    'raw/03_PCB_Closeup': ('NIVA pod Rev C PCB - Blender close-up of the KiCad assembly',
        'Finishes assigned per part class because KiCad GLB/STEP exports drop library model colours. ' + PCB_NOTE),
    'raw/04_Complete_Product_Flatlay': ('NIVA right set: insole, protected tail, pod on cradle, strap',
        'Insole outline, toe-post slot and lateral heel tail tab from the 1:1 medium fit template; five force regions and the '
        'PVDF film are sealed inside and not shown. Toe-sensor tail routing (A201 length, hold H1) is unresolved.'),
    'raw/05_Bilateral_Kit': ('NIVA bilateral kit - left and right sets',
        'L/R keys: cradle key post + rear slot, keyed tail boot, debossed marks and tactile dots. A complete matched set worn '
        'on the wrong leg is not prevented mechanically; the app side check and fitting check remain required.'),
    'pcb-raw/pcb_iso': ('NIVA pod Rev C PCB - KiCad 9 raytrace, isometric', PCB_NOTE),
    'pcb-raw/pcb_top': ('NIVA pod Rev C PCB - KiCad 9 raytrace, top', PCB_NOTE),
    'pcb-raw/pcb_underside': ('NIVA pod Rev C PCB - KiCad 9 raytrace, underside (cartridge contacts J2, service pads J3)', PCB_NOTE),
    'pcb-raw/pcb_closeup': ('NIVA pod Rev C PCB - KiCad 9 raytrace, close-up', PCB_NOTE),
}

def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=font) > width and cur: lines.append(cur); cur = w
        else: cur = t
    return lines + [cur]

for key, (title, body) in CAPTIONS.items():
    src = R / (key + '.png')
    if not src.exists(): print('missing', src); continue
    im = Image.open(src).convert('RGB'); W, H = im.size; s = W / 2400
    ft = ImageFont.truetype(BOLD, int(34 * s)) if BOLD else ImageFont.load_default()
    fb = ImageFont.truetype(FONT, int(25 * s)) if FONT else ImageFont.load_default()
    d = ImageDraw.Draw(im); lines = wrap(d, body, fb, W - 120 * s)
    band = int((34 + 22 + len(lines) * 34 + 44) * s)
    out = Image.new('RGB', (W, H + band), NAVY); out.paste(im, (0, 0)); d = ImageDraw.Draw(out)
    d.rectangle([0, H, int(14 * s), H + band], fill=TEAL)
    y = H + int(22 * s); d.text((int(50 * s), y), title, font=ft, fill=PALE); y += int(52 * s)
    for ln in lines: d.text((int(50 * s), y), ln, font=fb, fill=(200, 214, 222)); y += int(34 * s)
    name = key.split('/')[-1]
    out.save(R / (name + '.png'), optimize=True); print('captioned', name, out.size)
