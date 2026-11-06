#!/usr/bin/env python3
"""Build the README SVGs in assets/readme/ from the repo's own data.

The insole outline and sensor centres come from hardware/work/insole-layout-R.json
(the 1:1 right medium fit template). Phase rules and thresholds mirror
niva web/src/utils/biomechanicsEngine.ts. Run from the repo root:

    python3 scripts/build_readme_assets.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "readme")

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace"

PAPER = "#f3f5f1"
EDGE = "#d6ddd8"
INK = "#1d2a30"
MUTED = "#4f5d63"
TEAL = "#14a8ab"
TEAL_DK = "#0b7478"
TINT = "#dcefed"
HEAT = "#e8553a"
CARD = "#ffffff"


def head(w, h, title, desc, extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'role="img" aria-labelledby="t d">\n<title id="t">{title}</title>\n<desc id="d">{desc}</desc>\n{extra}'
            f'<rect x="1" y="1" width="{w - 2}" height="{h - 2}" rx="24" fill="{PAPER}" stroke="{EDGE}" stroke-width="2"/>\n')


def text(x, y, s, size, fill=INK, weight=400, family=SANS, anchor="start", extra=""):
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{extra}>{s}</text>\n')


def load_insole():
    with open(os.path.join(ROOT, "hardware", "work", "insole-layout-R.json"), encoding="utf-8") as f:
        return json.load(f)["insole"]


# ---------------------------------------------------------------- hero (animated gait cycle)

# Bench build channels, placed on the Rev C sensor-region centres of the same 1:1 template
# (insole frame mm: x across the foot, medial small; y from heel 0 to toe 260).
SENSORS = [  # key, (x_mm, y_mm), label offset
    ("heel", (43, 32)),
    ("inner", (24, 193)),
    ("outer", (80, 180)),
    ("toe", (24, 235)),
]
# Filtered load per phase (0 to 100), chosen so each phase satisfies its rule in detectPhase().
PHASES = [
    ("HEEL_STRIKE", ["heel &gt; 80", "toe &lt; 40"], {"heel": 86, "inner": 18, "outer": 14, "toe": 6}),
    ("MID_STANCE", ["heel, inner, outer", "all &gt; 50"], {"heel": 58, "inner": 62, "outer": 55, "toe": 30}),
    ("TOE_OFF", ["toe &gt; 80", "heel &lt; 30"], {"heel": 12, "inner": 40, "outer": 30, "toe": 88}),
    ("SWING", ["total load &lt; 20", "sum of four pads"], {"heel": 2, "inner": 1, "outer": 1, "toe": 1}),
]
# One 6 s loop. Each phase holds, then crosses over in 4 % (240 ms).
WIN = [(0, 23), (27, 48), (52, 73), (77, 96)]
BASE = 1  # still frame (reduced motion and non-animating renderers) shows MID_STANCE

FX, FY, FS = 690, 92, 1.615  # foot origin and mm-to-unit scale (heel at left, toe at right)


def to_svg(x_mm, y_mm):
    return FX + y_mm * FS, FY + x_mm * FS


def bloom_r(v):
    return 14 + 0.32 * v


def opacity_frames(i):
    """Keyframes that show phase i only inside its window, crossfading at the edges."""
    a, b = WIN[i]
    if i == 0:
        return "0%,23%{opacity:1}26%,96%{opacity:0}100%{opacity:1}"
    return f"0%,{a - 3}%{{opacity:0}}{a}%,{b}%{{opacity:1}}{b + 3}%,100%{{opacity:0}}"


def value_frames(vals, fmt):
    """Hold vals[i] across WIN[i], move between windows, end where it began."""
    stops = []
    for i, (a, b) in enumerate(WIN):
        stops.append(f"{a}%,{b}%{{{fmt(vals[i])}}}")
    stops.append(f"100%{{{fmt(vals[0])}}}")
    return "".join(stops)


def build_hero():
    pts = load_insole()[::2]
    outline = "M" + " L".join(f"{to_svg(x, y)[0]:.1f} {to_svg(x, y)[1]:.1f}" for x, y in pts) + " Z"
    pos = {k: to_svg(*xy) for k, xy in SENSORS}

    css = ["@keyframes ring{0%{transform:scale(.4);opacity:.9}6%{transform:scale(1.7);opacity:0}100%{transform:scale(1.7);opacity:0}}"]
    for i in range(4):
        css.append(f"@keyframes p{i}{{{opacity_frames(i)}}}")
    for k, _ in SENSORS:
        vals = [p[2][k] for p in PHASES]
        ratios = [bloom_r(v) / bloom_r(100) for v in vals]
        css.append(f"@keyframes b_{k}{{{value_frames(ratios, lambda r: f'transform:scale({r:.3f})')}}}")
    # centre of pressure along the heel-to-toe rail, from the engine's weighted average
    cop = []
    for _, _, vals in PHASES:
        tot = sum(vals.values())
        cop.append(sum(pos[k][0] * v for k, v in vals.items()) / tot)
    rail0 = FX
    css.append("@keyframes cop{" + value_frames([c - rail0 for c in cop[:3]] + [cop[2] - rail0],
                                                lambda d: f"transform:translateX({d:.1f}px)") + "}")
    css.append("@keyframes copfade{0%,73%{opacity:1}76%,96%{opacity:0}100%{opacity:1}}")

    base_vals = PHASES[BASE][2]
    rules = []
    for k, _ in SENSORS:
        r = bloom_r(base_vals[k]) / bloom_r(100)
        rules.append(f".b_{k}{{transform-box:fill-box;transform-origin:center;transform:scale({r:.3f});animation:b_{k} 6s infinite}}")
    for i in range(4):
        rules.append(f".p{i}{{opacity:{1 if i == BASE else 0};animation:p{i} 6s infinite}}")
    rules.append(f".cop{{transform:translateX({cop[BASE] - rail0:.1f}px);animation:cop 6s infinite,copfade 6s infinite}}")
    rules.append(".ring{transform-box:fill-box;transform-origin:center;opacity:0;animation:ring 6s infinite}")
    rules.append("@media (prefers-reduced-motion: reduce){*{animation:none !important}}")
    style = "<style>\n" + "\n".join(css + rules) + "\n</style>\n"

    W, H = 1200, 480
    s = head(W, H, "niva: ESP32 smart insole with explainable gait analytics",
             "A right insole outline from the 1:1 fit template with four pressure pads: heel, inner, outer and toe. "
             "Pressure moves from heel to toe through one gait cycle while the matching phase rule lights up: "
             "HEEL_STRIKE when heel is above 80 and toe below 40, MID_STANCE when heel, inner and outer are all above 50, "
             "TOE_OFF when toe is above 80 and heel below 30, SWING when the total load is below 20.", style)

    # title block
    s += text(60, 92, "ESP32 smart insole · explainable gait analytics", 20, TEAL_DK, 600, MONO)
    s += text(54, 208, "niva", 132, INK, 800, SANS, extra=' letter-spacing="-4"')
    s += text(60, 258, "Pressure, heel impact and tilt at 20 Hz,", 27, INK, 500)
    s += text(60, 294, "scored by thresholds you can read.", 27, INK, 500)

    # foot
    s += f'<path d="{outline}" fill="{CARD}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>\n'
    hx, hy = pos["heel"]
    s += f'<circle class="ring" cx="{hx:.1f}" cy="{hy:.1f}" r="40" fill="none" stroke="{HEAT}" stroke-width="3"/>\n'
    s += f'<defs><clipPath id="foot"><path d="{outline}"/></clipPath></defs>\n<g clip-path="url(#foot)">\n'
    for k, _ in SENSORS:
        x, y = pos[k]
        s += f'<circle class="b_{k}" cx="{x:.1f}" cy="{y:.1f}" r="{bloom_r(100):.1f}" fill="{HEAT}" fill-opacity=".82"/>\n'
    s += "</g>\n"
    for k, _ in SENSORS:
        x, y = pos[k]
        s += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="19" fill="{CARD}" stroke="{INK}" stroke-width="2"/>\n'
    for i, (_, _, vals) in enumerate(PHASES):
        s += f'<g class="p{i}">\n'
        for k, _ in SENSORS:
            x, y = pos[k]
            s += text(f"{x:.1f}", f"{y + 7:.1f}", str(vals[k]), 19, INK, 700, MONO, "middle")
        s += "</g>\n"
    labels = {"heel": (hx, hy + 84, "middle"), "inner": (pos["inner"][0], 66, "middle"),
              "toe": (pos["toe"][0], 66, "middle"), "outer": (pos["outer"][0] + 58, pos["outer"][1] + 40, "start")}
    for k, (x, y, a) in labels.items():
        s += text(f"{x:.1f}", f"{y:.1f}", k, 19, MUTED, 600, MONO, a)

    # centre-of-pressure rail
    ry = 282
    s += f'<line x1="{FX}" y1="{ry}" x2="{FX + 260 * FS:.1f}" y2="{ry}" stroke="{EDGE}" stroke-width="6" stroke-linecap="round"/>\n'
    s += text(FX - 14, ry + 7, "CoP", 19, MUTED, 600, MONO, "end")
    s += (f'<g class="cop"><circle cx="{rail0}" cy="{ry}" r="11" fill="{TEAL}" stroke="{CARD}" stroke-width="3"/></g>\n')

    # phase strip
    x0, y0, cw, ch, gap = 60, 336, 262, 112, 12
    for i, (name, rule, _) in enumerate(PHASES):
        x = x0 + i * (cw + gap)
        s += f'<rect x="{x}" y="{y0}" width="{cw}" height="{ch}" rx="14" fill="{CARD}" stroke="{EDGE}" stroke-width="2"/>\n'
        s += (f'<g class="p{i}"><rect x="{x}" y="{y0}" width="{cw}" height="{ch}" rx="14" fill="{TINT}" stroke="{TEAL}" stroke-width="2"/>'
              f'<rect x="{x + 1}" y="{y0 + 16}" width="6" height="{ch - 32}" rx="3" fill="{TEAL}"/></g>\n')
        s += text(x + 22, y0 + 40, name, 21, INK, 700, MONO)
        s += text(x + 22, y0 + 72, rule[0], 19, MUTED, 400, MONO)
        s += text(x + 22, y0 + 98, rule[1], 19, MUTED, 400, MONO)
    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- bench signal path (static)

ANALOG = HEAT
BUS = TEAL_DK


def box(x, y, w, h, fill=CARD, stroke=EDGE, rx=14, sw=2):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>\n'


def wire(x1, y1, x2, y2, color, dash=False):
    d = ' stroke-dasharray="8 7"' if dash else ""
    mx = (x1 + x2) / 2
    return (f'<path d="M{x1} {y1} C{mx} {y1} {mx} {y2} {x2} {y2}" fill="none" stroke="{color}" '
            f'stroke-width="3"{d} stroke-linecap="round"/>\n')


def build_bench():
    W, H = 1200, 640
    s = head(W, H, "Niva bench build: sensor pins to apps",
             "Four FSRs on GPIO 32 to 35 and a piezo heel disc on GPIO 36 feed the ESP32 ADC. An MPU6050 at 0x68 and an "
             "SH1106 OLED at 0x3C share I2C on SDA 21 and SCL 22. The niva_hardware sketch oversamples each channel 16 times, "
             "subtracts a zero-load tare saved in NVS, and sends one frame every 50 ms as JSON over WebSocket port 81 "
             "and as CSV over USB Serial at 115200 baud. niva web and niva flutter run the same biomechanics engine.")
    s += text(60, 70, "niva arduino/niva_hardware/niva_hardware.ino on an ESP32 dev board", 20, MUTED, 600, MONO)

    # column A: insole side
    rows = [("FSR heel", "GPIO 32", ANALOG), ("FSR inner", "GPIO 33", ANALOG), ("FSR outer", "GPIO 34", ANALOG),
            ("FSR toe", "GPIO 35", ANALOG), ("Piezo heel disc", "GPIO 36", ANALOG),
            ("MPU6050 0x68", "SDA 21", BUS), ("SH1106 OLED 0x3C", "SCL 22", BUS)]
    ax, ay, aw, rh = 60, 110, 320, 56
    for i, (name, pin, col) in enumerate(rows):
        y = ay + i * (rh + 8)
        s += box(ax, y, aw, rh, rx=12)
        s += f'<rect x="{ax}" y="{y}" width="8" height="{rh}" rx="4" fill="{col}"/>\n'
        s += text(ax + 24, y + 36, name, 21, INK, 600)
        s += text(ax + aw - 18, y + 36, pin, 20, col if col == BUS else "#b23a20", 700, MONO, "end")

    # column B: ESP32
    bx, by, bw, bh = 470, 110, 330, 440
    s += box(bx, by, bw, bh, fill=INK, stroke=INK, rx=18)
    s += text(bx + 26, by + 50, "ESP32", 34, "#ffffff", 800)
    s += text(bx + 26, by + 80, "Arduino core, 12-bit ADC", 19, "#c9d6d9", 400, MONO)
    items = [("16× oversample", "per channel, every frame"), ("Zero-load tare", "60 samples, kept in NVS"),
             ("Tilt from MPU6050", "pitch, roll, accZ"), ("One frame / 50 ms", "20 Hz to every client"),
             ("WiFiManager portal", "NIVA-GaitGuard-AP")]
    for i, (a, b) in enumerate(items):
        y = by + 128 + i * 64
        s += f'<rect x="{bx + 26}" y="{y - 22}" width="6" height="46" rx="3" fill="{TEAL}"/>\n'
        s += text(bx + 46, y, a, 21, "#ffffff", 700)
        s += text(bx + 46, y + 24, b, 19, "#c9d6d9", 400)

    for i, (_, _, col) in enumerate(rows):
        y = ay + i * (rh + 8) + rh / 2
        s += wire(ax + aw, y, bx, by + 90 + i * 50, col)

    # column C: transports and apps
    cx, cw = 880, 260
    outs = [("WebSocket", "JSON on :81", "ws://niva.local:81"), ("USB Serial", "CSV, 115200 baud", "H,I,O,T,Piezo,…")]
    for i, (a, b, c) in enumerate(outs):
        y = 110 + i * 132
        s += box(cx, y, cw, 112, rx=14)
        s += text(cx + 20, y + 38, a, 23, INK, 800)
        s += text(cx + 20, y + 66, b, 19, MUTED, 400)
        s += text(cx + 20, y + 94, c, 18, TEAL_DK, 600, MONO)
        s += wire(bx + bw, by + 160 + i * 120, cx, y + 56, INK, dash=True)

    apps = [("niva web", "USB or Wi-Fi, IndexedDB"), ("niva flutter", "Wi-Fi only, Hive")]
    s += f'<path d="M{cx + cw / 2} 354 L{cx + cw / 2} 384" stroke="{TEAL_DK}" stroke-width="3"/>\n'
    s += f'<path d="M{cx + cw / 2 - 8} 376 L{cx + cw / 2} 388 L{cx + cw / 2 + 8} 376" fill="none" stroke="{TEAL_DK}" stroke-width="3" stroke-linejoin="round"/>\n'
    for i, (a, b) in enumerate(apps):
        y = 396 + i * 84
        s += box(cx, y, cw, 70, fill=TINT, stroke=TEAL, rx=14)
        s += text(cx + 20, y + 32, a, 22, INK, 800)
        s += text(cx + 20, y + 56, b, 18, MUTED, 400)

    # engine band
    s += box(60, 572, 1080, 44, fill=CARD, stroke=TEAL, rx=12)
    s += text(80, 601, "Both apps run BiomechanicsEngine: tare check, EMA α 0.1, phase rules, CoP, step count, flags", 20, INK, 600)
    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- Rev C.1 pod analog front end (static)

def build_pod():
    W, H = 1200, 716
    s = head(W, H, "Niva Rev C.1 pod: insole flex to ESP32-C3",
             "Five printed force regions and a PVDF heel film on the insole flex reach the pod through a 10-pin JST GH tail. "
             "Each force region has a 10 kilo-ohm 0.1 percent load resistor and a 3.3 kilo-ohm, 1 microfarad filter into "
             "MCP3208 channels 0 to 4. The PVDF film is biased, clamped by a BAV199 and buffered by an MCP6001 into channel 5. "
             "Channel 6 reads 3V3 over 2 as a tail-fault monitor and channel 7 reads the insert ID resistor. VEXC is both sensor "
             "excitation and ADC reference, so readings are ratiometric. The MCP3208 and an LSM6DSO32 IMU share SPI with an "
             "ESP32-C3-MINI-1; a MAX17048 gauge sits on I2C; a TLV75533 regulates the cartridge cell to 3.3 V.")
    s += text(60, 70, "Rev C.1 pod front end: designed and routed in KiCad 9, not built yet", 20, MUTED, 600, MONO)

    # insole flex (vertical, real outline)
    pts = load_insole()[::3]
    sc, ox, oy = 1.62, 64, 128
    def p(x, y):
        return ox + x * sc, oy + (260 - y) * sc
    d = "M" + " L".join(f"{p(x, y)[0]:.1f} {p(x, y)[1]:.1f}" for x, y in pts) + " Z"
    s += f'<path d="{d}" fill="{CARD}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>\n'
    regions = [("P1", 24, 235), ("P2", 24, 193), ("P3", 80, 180), ("P4", 70, 117), ("P5", 43, 32)]
    for n, x, y in regions:
        X, Y = p(x, y)
        s += f'<circle cx="{X:.1f}" cy="{Y:.1f}" r="16" fill="{HEAT}" fill-opacity=".85"/>\n'
        s += text(f"{X:.1f}", f"{Y + 6:.1f}", n, 16, "#ffffff", 700, MONO, "middle")
    vx, vy = p(55, 14)
    s += f'<rect x="{vx - 14:.1f}" y="{vy - 9:.1f}" width="28" height="18" rx="4" fill="{TEAL}"/>\n'
    s += text(64, 600, "Insole flex, right medium", 20, INK, 700)
    s += text(64, 626, "P1-P5 force, teal PVDF pad", 18, MUTED, 400)
    s += text(64, 652, "115 mm tail, F.Cu underfoot", 18, MUTED, 400)

    # tail
    tx = p(96, 20)[0]
    s += f'<path d="M{tx - 8:.1f} {p(96, 20)[1]:.1f} C 300 {p(96, 20)[1]:.1f} 280 360 330 360" fill="none" stroke="{TEAL}" stroke-width="10" stroke-linecap="round"/>\n'
    s += text(284, 300, "JST GH", 18, TEAL_DK, 700, MONO, "middle")
    s += text(284, 322, "10-pin", 18, TEAL_DK, 700, MONO, "middle")

    # front-end rows into MCP3208
    rx0, rw, rh = 344, 450, 74
    fe = [("CH0-4", "Force regions P1 to P5", "10 kΩ 0.1 % load, 3.3 kΩ + 1 µF", HEAT),
          ("CH5", "PVDF heel film", "10 MΩ bias, BAV199 clamp, MCP6001", HEAT),
          ("CH6", "3V3 / 2 against VEXC", "tail-fault monitor, 2000 to 2400 ok", INK),
          ("CH7", "Insert ID resistor", "4.7 kΩ right, 47 kΩ left", INK)]
    for i, (ch, a, b, col) in enumerate(fe):
        y = 116 + i * (rh + 14)
        s += box(rx0, y, rw, rh, rx=12)
        s += f'<rect x="{rx0}" y="{y}" width="8" height="{rh}" rx="4" fill="{col}"/>\n'
        s += text(rx0 + 24, y + 32, a, 21, INK, 700)
        s += text(rx0 + 24, y + 58, b, 18, MUTED, 400)
        s += text(rx0 + rw - 16, y + 32, ch, 19, col if col != INK else TEAL_DK, 700, MONO, "end")

    # MCP3208
    mx, my, mw, mh = 840, 116, 300, 340
    s += box(mx, my, mw, mh, fill=INK, stroke=INK, rx=18)
    s += text(mx + 24, my + 48, "MCP3208", 32, "#ffffff", 800)
    s += text(mx + 24, my + 78, "8-ch 12-bit SAR ADC", 19, "#c9d6d9", 400, MONO)
    s += f'<rect x="{mx + 24}" y="{my + 102}" width="{mw - 48}" height="88" rx="12" fill="#2b3b42"/>\n'
    s += text(mx + 42, my + 136, "VREF = VEXC", 22, "#ffffff", 700, MONO)
    s += text(mx + 42, my + 166, "3V3 through 220 Ω", 18, "#c9d6d9", 400, MONO)
    s += text(mx + 24, my + 230, "Every force reading is", 20, "#ffffff", 500)
    s += text(mx + 24, my + 256, "ratiometric in hardware,", 20, "#ffffff", 500)
    s += text(mx + 24, my + 282, "no firmware normalising.", 20, "#ffffff", 500)
    for i in range(4):
        y = 116 + i * (rh + 14) + rh / 2
        s += wire(rx0 + rw, y, mx, my + 120 + i * 40, HEAT if i < 2 else INK)

    # MCU row
    yy = 486
    blocks = [(344, 220, "ESP32-C3-MINI-1", "RISC-V MCU, radio"), (584, 210, "LSM6DSO32", "IMU on SPI, INT1"),
              (814, 156, "MAX17048", "gauge, I2C"), (990, 150, "TLV75533", "3.3 V LDO")]
    for x, w, a, b in blocks:
        s += box(x, yy, w, 82, fill=TINT if a.startswith("ESP") else CARD, stroke=TEAL if a.startswith("ESP") else EDGE, rx=14)
        s += text(x + 18, yy + 36, a, 21, INK, 800)
        s += text(x + 18, yy + 64, b, 18, MUTED, 400)
    s += f'<path d="M{mx + 150} {my + mh} L{mx + 150} 470 L454 470 L454 {yy}" fill="none" stroke="{TEAL_DK}" stroke-width="3"/>\n'
    s += f'<line x1="689" y1="470" x2="689" y2="{yy}" stroke="{TEAL_DK}" stroke-width="3"/>\n'
    s += text(560, 462, "SPI", 18, TEAL_DK, 700, MONO)
    s += f'<path d="M454 568 L454 590 L892 590 L892 568" fill="none" stroke="{TEAL_DK}" stroke-width="3"/>\n'
    s += text(660, 614, "I2C", 18, TEAL_DK, 700, MONO)
    s += text(344, 652, "Pod PCB 34 × 48 mm, 4 layers, 126 vias. KiCad DRC: 0 errors, 0 unconnected.", 19, INK, 600)
    s += text(344, 680, "Power: LP502030 cartridge cell (230 mAh min) on J2 spring contacts. No charger in the pod.", 18, MUTED, 400)
    s += "</svg>\n"
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("hero.svg", build_hero), ("bench-signal-path.svg", build_bench), ("pod-front-end.svg", build_pod)]:
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(fn())
        print("wrote", os.path.join("assets", "readme", name))


if __name__ == "__main__":
    main()
