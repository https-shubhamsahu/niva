# Niva — agent brief

Read this before touching anything. It is short on purpose; the long-form
reasoning lives in `docs/`.

---

## 1. The one thing that governs everything

Niva is a sensorised insole: ESP32, four FSR402 force sensors, an MPU6050 IMU,
a 27 mm piezo disc at the heel.

**It is not a product project. It is a measurement project.** The insole is the
research *instrument*, not the result. The contribution is the characterisation
of what a cheap sparse sensor array can and cannot observe, how fast it
degrades, and how it can report its own loss of validity.

If you find yourself improving the insole, stop. The question is what the
insole can measure, not how to make it measure more.

This reframe was reached after a 121-source literature review. Building "a
smart insole that classifies diabetic foot with a CNN" is the default project
in this field — already published in 2026 at 88% accuracy on eight FSRs. Any
version of that loses.

---

## 2. Hard rules

**Never invent a number.** Every figure, percentage, accuracy claim or
comparison must trace to a cited source or to the team's own measurement. If a
value does not exist yet, write `to be measured` — do not estimate, do not
"illustrate with plausible data". Three result frames in the poster and deck
are deliberately empty for this reason. Leave them empty.

**Never add hardware without a research justification.** Sensor count is the
independent variable of this study. Adding sensors, a temperature sensor, or a
flexible matrix destroys the research question. Deliberately excluded, with
reasons, in `docs/Niva_Aavishkar_Research_Framework.docx` §5.

**Never add an ML classifier.** Published, better-resourced, already beaten.

**Never make a clinical claim.** No diagnosis, no risk prediction, no ulcer
prevention, no sensitivity/specificity. India's CDSCO guidance (doc
CDSCO/MD/GD/MDSW/01/2026, 21 July 2026) treats "screening" as a *medical
purpose* that voids the general-wellness exemption — so the word itself carries
regulatory weight. Defensible claims are listed in `docs/Niva_Work_Package.docx` §1.

**Synthetic pathology data is not evidence.** The old analytics layer contained
simulated Parkinsonian / stroke / neuropathy gait signatures. They are demo
material only and must never appear in a results section or in front of a
clinician.

---

## 3. Firmware state

`niva arduino/niva_hardware/niva.ino` has nine known defects, registered with
evidence and fixes in `docs/Niva_Work_Package.docx` §3. The three that invalidate
every measurement until fixed:

| ID | Defect | Fix |
|----|--------|-----|
| FW-01 | Whole acquisition loop runs at 20 Hz (`STREAM_INTERVAL_MS = 50`) | 100 Hz for FSR+IMU, ≥500 Hz burst for piezo |
| FW-02 | Piezo passed through the same 16-sample mean as the FSRs, destroying the transient | peak-hold maximum on that channel only |
| FW-03 | Accelerometer at ±2 g (scale 16384) against 24.6 g heel strikes | `AFS_SEL = 3` (±16 g, scale 2048) |

`niva arduino/niva_hardware/niva_signal.h` is a header-only drop-in that fixes
FW-01 through FW-08. It compiles clean under `-Wall -Wextra`. It is not yet
wired into `niva.ino` — doing that is real, useful work.

---

## 4. Design system

Use these exact values. Do not invent new colours.

```
navy      #14314B   section headers, rules, structure
teal      #0B6F79   the accent — the one thing that carries meaning
teal-ink  #08535B   accent text on light grounds
ink       #0F1B1E   body text (near-black, cyan bias)
mute      #5A6C72   captions, secondary
panel     #EAF0F2   light fills
rule      #CBD8DC   hairlines
```

Semantic colours, used **only** for the device's three validity states, never
as decoration:

```
ok    #2A6640 on #DEEDE2     VALID     — metrics reported
warn  #8A5300 on #F8ECD8     DEGRADED  — metrics suppressed
crit  #A32017 on #F8E2E0     INVALID   — recalibration required
```

**Type**: IBM Plex, all three cuts.
- `IBM Plex Serif` — titles and slide headings (fallback Georgia)
- `IBM Plex Sans` — body (fallback Helvetica Neue, Arial)
- `IBM Plex Mono` — every unit, pin name and measurement: `GPIO32`,
  `507 mm²`, `0.2–20 N`. This is deliberate. Setting measurements in mono makes
  the work read as instrument output rather than marketing copy.

**Print**: the poster is exactly 1000 × 1000 mm. Author at 96 px per inch, so
3780 × 3780 px. Body type never below 12 pt (16 px at that scale); on a metre
poster use ~30 pt body, ~46 pt section headers, ~110 pt title.

---

## 5. Making visuals — read this before drawing anything

The figures in this project were rebuilt twice. What failed and what worked:

**Do not use matplotlib, plotly or any plotting library for diagrams.** Their
output is plotting-library output: baked colours, their own font, heavy path
data, no theme awareness. It looks like a chart engine made it, because one did.

**Hand-author inline SVG.** Native shapes only — `rect`, `circle`, `line`,
`path`, `text`. Size by `viewBox` and let CSS scale it. Take colour from the
page (`currentColor` or the tokens above) so the drawing works on light and
dark grounds. Inherit the page's font. A figure should be a few KB, not 300.

**A diagram earns its place by showing a mechanism**, not by labelling one. A
box that says "cache" is worse than the sentence. Show the path, the boundary,
the thing that changes.

**Label the arrows.** An unlabelled arrow means "related somehow". `100 Hz`,
`features`, `invalidates` is information.

**Where the drawing is a scale figure, keep it accurate.** The foot diagram
draws 12.7 mm sensor discs against a 260 mm foot at true relative scale. That
accuracy *is* the argument — 507 mm² of active area against a loaded surface an
order of magnitude larger. If you redraw it by eye, you have destroyed the
claim and kept the picture.

**For layouts a human will edit**, prefer real DOM elements with inline styles
over one big SVG. Flex/grid with `gap`, never margins between siblings. That
survives direct manipulation; a monolithic SVG does not.

---

## 6. Where things are

```
docs/
  evidence-base.html                       121-source literature review
  Niva_Work_Package.docx                   claims framework, ISO 14971 hazard
                                           analysis, firmware defect register,
                                           SOP-01 calibration, SOP-02 endurance,
                                           V3 six-month plan
  Niva_CDSCO_Classification_Request.docx   ready-to-send regulatory letter
  Niva_Aavishkar_Research_Framework.docx   problem, gap, objectives, methodology,
                                           hardware justification, evaluator Q&A
  aavishkar/
    current/Niva_Poster_1m.pptx/.pdf       approved poster, 1000 × 1000 mm
    current/Niva_Presentation.pptx/.pdf    approved 13-slide presentation
    README.md                              current outputs and editing guide
  brand/niva_logo_assets/                  logo lockups
src-visuals/aavishkar/                     consolidated source, renderers, fonts
niva arduino/niva_hardware/                firmware + niva_signal.h
tools/sensor_placement_study.py            the O1 experiment, ready to run
```

---

## 7. What is done and what is not

Done: literature review, research framing, claims framework, hazard analysis,
firmware defect register, lab protocols, six-month plan, poster, deck,
regulatory letter.

**Not done — and this is the whole remaining job:**

| # | Experiment | Blocker | Cost |
|---|-----------|---------|------|
| R1 | FSR sensitivity vs load cycles to 10 000 | needs a 1 Hz cyclic loading fixture | build the fixture |
| R2 | Observable plantar area vs sensor count | needs the StepUP-P150 dataset downloaded | one weekend, zero hardware |
| R3 | Validity-gate detection rate | needs R1's aged sensors | after R1 |

R2 is the cheapest and also produces the baseline comparison table. Start there.
`tools/sensor_placement_study.py --demo` runs today; point it at real data with
`--data`.

---

## 8. How to verify your own work

- Any document: render to PDF and look at every page before handing it over.
  Text overflow at a box boundary is the most common defect and always visible.
- Any figure: check it at final size, not at authoring size.
- Any number you write: name the source in the same sentence you write it.
- Any firmware change: it must compile under `-Wall -Wextra`.

---

## 9. Context

Undergraduate team of three, Mumbai University, fifth semester. Entering the
21st Aavishkar Research Convention 2026–27, category Engineering & Technology,
level UG. Judges question every claim and any team member may be asked about
any part of the project. Design and write accordingly: a claim that cannot be
defended in one sentence is worse than no claim.
