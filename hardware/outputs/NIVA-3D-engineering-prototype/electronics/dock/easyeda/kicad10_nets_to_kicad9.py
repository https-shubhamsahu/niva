#!/usr/bin/env python3
"""Rewrite a KiCad 10 .kicad_pcb so EasyEDA Pro's KiCad importer reads its nets.

KiCad 10 names nets inline, (net "VBUS"), with no net table. EasyEDA Pro 3.2
expects the KiCad 9 form: a top-level (net N "name") table, pads with
(net N "name"), tracks and vias with (net N), zones with (net N)(net_name ..).
Without it the import keeps footprints and vias but drops every net and track.
Nothing else in the file is changed.

usage: kicad10_nets_to_kicad9.py IN.kicad_pcb OUT.kicad_pcb
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()

NET = re.compile(r'\(net "((?:[^"\\]|\\.)*)"\)')
names = []
for m in NET.finditer(text):
    if m.group(1) not in names:
        names.append(m.group(1))
code = {n: i + 1 for i, n in enumerate(names)}

# Split into top-level children: each starts with "\n\t(" at depth 1.
starts = [m.start() + 1 for m in re.finditer(r'\n\t\(', text)]
bounds = list(zip(starts, starts[1:] + [len(text)]))
head = text[: starts[0]]
blocks = [text[a:b] for a, b in bounds]


def kind(block):
    return re.match(r'\t\((\w+)', block).group(1)


out = []
for b in blocks:
    k = kind(b)
    if k in ("segment", "via", "arc"):
        b = NET.sub(lambda m: f"(net {code[m.group(1)]})", b)
    elif k == "zone":
        b = NET.sub(lambda m: f'(net {code[m.group(1)]})\n\t\t(net_name "{m.group(1)}")', b)
        # KiCad 10 dropped this token; without it a KiCad 9 reader falls back to
        # the legacy stroked fill and fattens the pour.
        if "filled_areas_thickness" not in b:
            b = re.sub(r'(\(min_thickness [\d.]+\))', r'\1\n\t\t(filled_areas_thickness no)', b, count=1)
    else:  # footprints (pads) and anything else
        b = NET.sub(lambda m: f'(net {code[m.group(1)]} "{m.group(1)}")', b)
    out.append(b)

table = '\t(net 0 "")\n' + "".join(f'\t(net {code[n]} "{n}")\n' for n in names)
first_fp = next(i for i, b in enumerate(out) if kind(b) == "footprint")
out.insert(first_fp, table)

result = head + "".join(out)
result = result.replace("(version 20260206)", "(version 20241229)", 1)
result = result.replace('(generator_version "10.0")', '(generator_version "9.0")', 1)
open(dst, "w", encoding="utf-8").write(result)
print(f"{len(names)} nets, {len(NET.findall(text))} references rewritten -> {dst}")
