"""Caption band for the Protected Steps 3D renders (python3 + Pillow), same style as the Rev C.1 set.

renders-work/raw/<scene>.png -> hardware/outputs/renders-protected-steps/<file>_3D-render.png
Every filename and every caption says "3D render", so no image can be taken for a photo of a built device.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HW = Path('/home/shubh/_Active_Projects/niva-pcbway/hardware')
RAW = HW / 'outputs/NIVA-RevC2-protected-steps/renders-work/raw'
OUT = HW / 'outputs/renders-protected-steps'; OUT.mkdir(parents=True, exist_ok=True)
FONT = next((f for f in ['/usr/share/fonts/TTF/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'] if Path(f).exists()), None)
BOLD = next((f for f in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if Path(f).exists()), None)
NAVY, TEAL, PALE = (20, 49, 75), (11, 111, 121), (234, 240, 242)
STATUS = ('Nothing shown has been printed, built, powered or measured. Not a medical device; '
          'no clinical claim.')
CAPTIONS = {
    'PS01_AnkleHub_Strap': ('PS01_ankle-hub-on-strap_3D-render',
        '3D render - Niva Protected Steps ankle hub (concept): Rev C.1 pod on the Rev C.2 ankle-strap cradle',
        'CAD geometry: unchanged Rev C.1 pod enclosure (FreeCAD) on the new 13_AnkleCradle with the 16_AnkleSaddlePad (TPU) '
        'and the 15_TailBlank plug closing the unused insole-tail opening. Strap is a 35 mm placeholder band; the leg is a '
        'neutral mannequin form, not anthropometric data. ' + STATUS),
    'PS02_ShoeNode_Collar': ('PS02_shoe-collar-node_3D-render',
        '3D render - Niva Protected Steps shoe node (concept): the same pod clipped at the shoe collar, cable end up',
        'CAD geometry: unchanged Rev C.1 pod and tail boot on the new 14_CollarClip, whose hook and short inner tongue grip '
        'the collar; the insole tail (teal band) passes through a slot in the hook into the shoe. The collar thickness is a '
        'placeholder to be measured on the prescribed footwear. The shoe is a stand-in form built from the 1:1 insole template, '
        'not a footwear model. Skin-side pressure of the tongue is unassessed. ' + STATUS),
    'PS03_Pod_Exploded': ('PS03_pod-exploded_3D-render',
        '3D render - Niva pod Rev C.1, exploded, ankle-hub build (Rev C.2 mounting parts)',
        'Top to bottom: button and light pipe, front cover, gasket, routed PCBA (KiCad model: ESP32-C3-MINI-1, MCP3208, '
        'LSM6DSO32, MAX17048), rear housing with the tail-opening plug beside it, cartridge lid and plates, cell, strip PCB, '
        'cup, ankle cradle, TPU saddle pad. ORANGE = placeholder envelopes (cell drawn at its published maximum size; U6 and '
        'J2 are not supplier models). PCB passes KiCad ERC/DRC; not independently reviewed. ' + STATUS),
    'PS04_Interim_Cabinet': ('PS04_interim-cabinet_3D-render',
        '3D render - interim printable cabinet for the current ESP32 + MPU6050 + OLED perfboard prototype (lid lifted)',
        'Parametric FreeCAD box: USB opening, OLED window with a clear pane, insole-cable exit clamped by the lid, '
        'strap slots so it can be worn as the ankle hub. The boards inside are labelled DUMMY blocks sized from PLACEHOLDER '
        'parameters: measure the real boards and regenerate before printing. ' + STATUS),
}

def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=font) > width and cur: lines.append(cur); cur = w
        else: cur = t
    return lines + [cur]

for key, (fname, title, body) in CAPTIONS.items():
    src = RAW / f'{key}.png'
    if not src.exists(): print('missing', src); continue
    im = Image.open(src).convert('RGB'); W, H = im.size; s = W / 2400
    ft = ImageFont.truetype(BOLD, int(40 * s)); fb = ImageFont.truetype(FONT, int(29 * s))
    d = ImageDraw.Draw(im); tl = wrap(d, title, ft, W - 120 * s); lines = wrap(d, body, fb, W - 120 * s)
    band = int((26 + len(tl) * 50 + 14 + len(lines) * 38 + 40) * s)
    out = Image.new('RGB', (W, H + band), NAVY); out.paste(im, (0, 0)); d = ImageDraw.Draw(out)
    d.rectangle([0, H, int(14 * s), H + band], fill=TEAL)
    # corner tag on the image itself, so a crop of the picture still says what it is
    tag = '3D RENDER - NOT A PHOTO'; fs = ImageFont.truetype(BOLD, int(30 * s))
    tw = d.textlength(tag, font=fs); pad = int(14 * s)
    d.rectangle([W - tw - 3 * pad, pad, W - pad, pad + int(46 * s)], fill=NAVY)
    d.text((W - tw - 2 * pad, pad + int(8 * s)), tag, font=fs, fill=PALE)
    y = H + int(26 * s)
    for ln in tl: d.text((int(50 * s), y), ln, font=ft, fill=PALE); y += int(50 * s)
    y += int(14 * s)
    for ln in lines: d.text((int(50 * s), y), ln, font=fb, fill=(200, 214, 222)); y += int(38 * s)
    out.save(OUT / f'{fname}.png', optimize=True); print('captioned', fname, out.size)
