# usage: python build.py -> render/slideN.html (one slide, for PNG checks) and render/deck.html (all six, PDF source)
# The SIH 2026 template frame (title, SIH logo, team oval, blue footer, page number) is added here from deck.json.
# Do not draw template chrome inside slides/slideN.html.
# Placeholders in slides/slideN.html:
#   <i data-icon="lucide-name" data-color=".." data-size=".."></i>   inline Lucide icon from icons/ (fetch more: python tools/icon.py name)
#   <i data-svg="art-name" style="..."></i>                           inline vector art = assets/art-name.svg (HTML context)
#   <art name="art-name" x=".." y=".." w=".." h=".."/>                inline vector art (inside an <svg>)
import json, re, pathlib

BASE = pathlib.Path(__file__).parent
R = BASE / "render"
CFG = json.loads((BASE / "deck.json").read_text(encoding="utf8"))
TITLES = {1: "SMART INDIA HACKATHON 2026", 2: CFG["idea_title"], 3: "TECHNICAL APPROACH",
          4: "FEASIBILITY AND VIABILITY", 5: "IMPACT AND BENEFITS", 6: "RESEARCH AND REFERENCES"}


def svg_parts(name):
    path = BASE / "assets" / f"{name}.svg"
    if not path.exists():
        raise SystemExit(f"missing art: assets/{name}.svg")
    t = path.read_text(encoding="utf8")
    t = re.sub(r"<\?xml.*?\?>|<!--.*?-->|<title[^>]*>.*?</title>|<desc[^>]*>.*?</desc>", "", t, flags=re.S).strip()
    head = re.search(r"<svg[^>]*>", t).group(0)
    return re.search(r'viewBox="([^"]+)"', head).group(1), t[t.find(head) + len(head):t.rfind("</svg>")]


def html_art(m):
    vb, inner = svg_parts(m.group(1))
    return f'<span class="art" style="{m.group(2)}"><svg viewBox="{vb}" aria-hidden="true">{inner}</svg></span>'


def svg_art(m):
    name, x, y, w, h = m.groups()
    vb, inner = svg_parts(name)
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{vb}">{inner}</svg>'


def icon(m):
    name, color, size = m.group(1), (m.group(2) or "currentColor"), m.group(3)
    path = BASE / "icons" / f"{name}.svg"
    if not path.exists():
        raise SystemExit(f"missing icon: icons/{name}.svg  ->  run: python tools/icon.py {name}")
    svg = re.sub(r"<!--.*?-->", "", path.read_text(encoding="utf8"), flags=re.S)
    svg = re.sub(r"<svg[^>]*>", lambda t: re.sub(r'\s(width|height)="\d+"', "", t.group(0)).replace("<svg", '<svg aria-hidden="true"'), svg, count=1)
    style = f"color:{color}" + (f";width:{size}px;height:{size}px" if size else "")
    return f'<span class="ico" style="{style}">{svg.strip()}</span>'


def expand(html):
    html = re.sub(r'<i data-icon="([\w-]+)"(?: data-color="([^"]+)")?(?: data-size="(\d+)")?\s*></i>', icon, html)
    html = re.sub(r'<i data-svg="([\w-]+)" style="([^"]*)"\s*></i>', html_art, html)
    html = re.sub(r'<art name="([\w-]+)" x="([-\d.]+)" y="([-\d.]+)" w="([\d.]+)" h="([\d.]+)"\s*/>', svg_art, html)
    return html


def chrome(n):
    logo = '<img class="tpl-logo" src="../assets/sih-logo.png" alt="Smart India Hackathon 2026 logo"'
    if n == 1:
        return (f'<h1 class="tpl-t1">{TITLES[1]}</h1>{logo} style="top:9.24px">'
                '<i data-svg="hex-art" style="position:absolute;left:1134.26px;top:171.19px;width:730.49px;height:811.81px"></i>'
                '<img class="tpl-bulb" src="../assets/sih-bulb.png" alt="">', "")
    return (f'<div class="tpl-oval">{CFG["team_name"]}</div><h1 class="tpl-title">{TITLES[n]}</h1>{logo}>',
            f'<footer class="tpl-foot"><span class="ft">{CFG["team_name"]} / PS {CFG["ps_id"]}</span><span class="pn">{n}</span></footer>')


def scope(css, sid):
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    return "\n".join(", ".join(f"#{sid} {s.strip()}" for s in sel.split(",") if s.strip()) + "{" + body + "}"
                     for sel, body in re.findall(r"([^{}]+)\{([^{}]*)\}", css))


HEAD = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{title}</title>'
        '<link rel="stylesheet" href="../fonts.css"><link rel="stylesheet" href="../tokens.css"><link rel="stylesheet" href="../chrome.css">'
        '<style>{css}</style></head><body>{body}</body></html>')

R.mkdir(exist_ok=True)
styles, sections = [], []
for n in range(1, 7):
    src = (BASE / "slides" / f"slide{n}.html").read_text(encoding="utf8")
    style = re.search(r"<style>(.*?)</style>", src, flags=re.S)
    css = scope(style.group(1), f"s{n}") if style else ""
    body = re.search(r"<main>(.*?)</main>", src, flags=re.S).group(1)
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)  # comments may hold example placeholders
    head, foot = chrome(n)
    section = expand(f'<section class="slide" id="s{n}">{head}{body}{foot}</section>')
    (R / f"slide{n}.html").write_text(HEAD.format(title=f"Slide {n}", css=css, body=section), encoding="utf8")
    styles.append(css)
    sections.append(section)
(R / "deck.html").write_text(HEAD.format(title=f'{CFG["idea_title"]} - SIH 2026 PS {CFG["ps_id"]} - {CFG["team_name"]}',
                                         css="\n".join(styles), body="\n".join(sections)), encoding="utf8")
print("built 6 slides + deck")
