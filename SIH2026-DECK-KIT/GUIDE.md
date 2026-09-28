# SIH 2026 idea deck: the method (read fully before touching a slide)

This kit is the exact pipeline that produced the reference deck `reference/SURANG-SUTRA-SIH2026-PS26218.pdf`.

**Goal:** a new deck for a different problem statement that:
- **looks the same**: the same SIH template frame, visual system, density and polish;
- **uses the same method**: research first, then blueprint, then build, then visual QA, then PDF.

The content is new. The template and the method are not up for redesign.

---

## 1. Non-negotiables (the last attempt failed on these)

1. **Use this kit and nothing else to make the deck.**
   - **Do not use:** python-pptx, the `pptx`, `sih-pptx-native`, `ppt-agent`, `slides`, `frontend-slides` or `design` skills, Canva, Google Slides, Marp, reveal.js, or any "presentation template".
   - **The output is a PDF** printed from `render/deck.html` by `make_pdf.py`.
   - SIH accepts **PDF only**.
2. **Never edit `chrome.css`, `tokens.css`, `fonts.css` or `chrome()` in `build.py`.**
   - They reproduce the official SIH 2026 template frame.
   - On **slide 1:** the "SMART INDIA HACKATHON 2026" title, the SIH logo, and the grey hexagon art plus bulb on the right.
   - On **slides 2–6:** the team-name oval, the slide title, the SIH logo, and the blue footer with "Team / PS" and the page number.
   - The frame is injected automatically. **Do not redraw it**, cover it or add a second title.
3. **Exactly 6 slides**, in the template order:
   1. Title
   2. Idea
   3. Technical approach
   4. Feasibility and viability
   5. Impact and benefits
   6. Research and references
4. **The pointer headings are verbatim template text.** They are already in `slides/slide2..6.html` and must stay word-for-word, brackets included. You may move them vertically to fit the layout.
   - **Slide 1:** the metadata labels (Problem Statement ID, Problem Statement Title, Theme, PS Category, Team ID, Team Name) must all stay.
   - The PS title is pasted **exactly** as on the portal.
5. **Canvas:** 1920 × 1080 px per slide.
   - **Content area on slides 2–6:** x 40–1880, y about 185–990.
   - **Slide 1:** the content must stay left of x 1125.
6. **Match the reference.** Before building, open `reference/previews/slide1..6.jpg` and the matching `reference/slides-html/slideN.html`. The new deck must look like it was made by the same team with the same kit:
   - diagram-first;
   - dense but ordered panels;
   - navy / orange / green accents on white;
   - small uppercase tag headers;
   - icons everywhere;
   - one hero visual per slide.

   The reference HTML uses art files that are **not** in this kit (`brand`, `surang`, `surang-dark`, `cutaway`, `qr-demo`, `thumb-*`, `shot-cc`). Treat them as patterns, not as assets to reuse.

## 2. Workflow (stop for approval where marked)

| Phase | Output | Notes |
|---|---|---|
| **0. Intake** | Fill in `deck.json` | Read the PS text, the team's existing material (code, simulation, CAD, renders, docs, videos) and any earlier deck. List what already exists; **reuse it, don't reinvent it**. |
| **1. Research** | `sih-deck/work/RESEARCH-DOSSIER.md` | See §3. Web-verify every number you will print. |
| **2. Blueprint** | `sih-deck/work/SLIDE-BLUEPRINT.md` | Slide by slide: every heading, every line of copy, every visual (what it shows, where it sits), every stat with its source. Map each slide to the judging criteria (§6). **⏸ Show the user and get approval.** |
| **3. Assets** | `assets/*.svg`, `*.jpg`, `icons/*.svg` | Hand-written inline SVG diagrams and illustrations. `tools/qr.py` for the demo QR. `tools/shot.py` for screenshots of a live demo. `tools/icon.py` for extra Lucide icons. Reuse the team's diagrams and renders (copy them into `assets/`). |
| **4. Build** | `slides/slide1..6.html` | Absolute-positioned panels, slide-local `<style>` (auto-scoped). Build all six first, then render once. |
| **5. Visual QA** | `python render.py`, then look at `render/preview/slideN.jpg` | Check for overflow, clipping, overlaps, text under the QR, awkward wraps and empty holes. Fix with small edits and re-render. **Look only at the 1280 px JPEG previews.** Full-size PNGs crashed an earlier session (out of memory). |
| **6. PDF** | `python make_pdf.py` | Must report 6 pages. Grep the extracted text for leftover placeholders (`XXXXX`, `IDEA NAME`, `TODO`) and for the old project's name. |
| **7. Portal text** | `sih-deck/work/PORTAL-TEXT.md` | Idea title plus an idea description of about 120–150 words, paste-ready. |

**Commands** (run from the kit copy):
- `python render.py`: build all slides, render them, and write the previews.
- `python make_pdf.py`: build the final PDF.
- `python tools/icon.py name1 name2`: fetch extra icons.
- `python tools/qr.py URL qr-demo`: make a vector QR code.

**Requirements:** Python 3 with `pillow`, `pypdf` and `qrcode`, plus Chrome or Edge.

**On Linux or in a cloud container:**
- Run `pip install pillow pypdf qrcode playwright && python -m playwright install --with-deps chromium`. `tools/browser.py` finds that Chromium and adds `--no-sandbox`.
- Missing Microsoft fonts are replaced by the metric-compatible open fonts in `fonts/` (via `fonts.css`), so the layout matches the Windows render.

## 3. Research dossier (what made the reference deck win-grade)

1. **The PS decoded.** Split it into every requirement, one per row: *PS words → our answer*. That table later becomes the "How it addresses the problem" panel.
2. **The field.** What other SIH teams on this PS will propose: search GitHub for "SIH 2026 <PS id>" and look at typical student ideas. Then name our **white space**, the one thing they can't do.
3. **The benchmarks.** Commercial and research systems, with **real prices** in ₹ (convert from USD and state the rate). A cost-shock ratio such as "16–24× cheaper" is gold.
4. **The India story.**
   - 3 verified numbers with sources: government data (NCRB, ministry replies in Parliament, annual reports) beats news.
   - One named real incident as the emotional hook. The reference deck used Silkyara: first sight of the trapped workers on day 10, through a medical endoscope.
5. **Research → design.** About 10 recent papers or technical facts. Each one justifies a specific design choice.
6. **Named innovations.** 6 features, each with:
   - a catchy name;
   - a one-line hook;
   - the mechanism;
   - a research anchor;
   - a defence line for when a judge pushes.
7. **Risks.** 7 real risks with concrete mitigations, each tagged `designed-in` or `roadmap`.
8. **Judge Q&A.** The 6 hardest questions, with answers.

## 4. Slide playbook (copy this structure; see the reference HTML for code)

| Slide | Must contain (reference layout) |
|---|---|
| **1 Title** | Idea name (58 px) plus a tagline (30 px) plus an optional sub-line. **Four feature pills** (2×2, coloured, icon + CAPS title + proof line). One orange **shock line** (cost, speed or scale). The template metadata block with the PS values. The college name. A **hero column** (x 745–1125), e.g. three stacked hexagon vignettes, "1 does X / 2 does Y / 3 does Z". A **demo box** with QR and link at the bottom left. |
| **2 Idea** | A **lead sentence** (one line, bold keywords). Two mode chips. A big **mission/flow illustration** in inline SVG (numbered steps 1–9, labelled, "concept illustration" caption). A right panel **"<PS> problem → our answer"** with 6 rows (red pain chip → answer). **Six innovation cards** (3×2, numbered, icon, bold key phrase). A **comparison matrix** against 3 alternatives, with ✓/✗/~ icons and a price row, our column highlighted in orange. |
| **3 Technical** | A **product cutaway or architecture diagram** with numbered callouts. A **tech-stack grid** of 4 coloured columns (Hardware / Firmware / AI & Software / App or Command centre) naming real frameworks, parts and languages, with `BUILT ✓` chips for what already exists. A **flowchart** of 5 stages (e.g. Sense → Think → Act → Connect → Command) with arrows. One **mechanism or algorithm diagram**. A **working-prototype strip**: screenshots, QR and "N automated checks passing" (only if true). A safety or ethics line. |
| **4 Feasibility** | **4 pillars** (Technical, Economic, Operational, Safety/Regulatory) with status chips. A **cost bar chart** against the alternatives, with the source line. A **risk → strategy table** (7 rows, icon, arrow, `designed-in`/`roadmap` chip). A **budget/spec bar** (mass, power, time or whatever fits). A **roadmap ladder** from "NOW ✓" to the SIH finale (Dec 2026) to 2027 pilots, with partners marked "(proposed)". |
| **5 Impact** | A **before/after hero** (dark panel: "TODAY: …" ✗ list vs "WITH <IDEA>: …" ✓ list, over an illustration). **Who gains**: 6 icon tiles. **Why India, why now**: 3 big stats with a sources line. **4 benefit columns** (Social / Economic / Environmental / Strategic), each with one big number or word and 3 bullets. A **product UI panel**: a real screenshot plus 3 "UI concept · example values" widgets. |
| **6 References** | **Research → our design**: 10 cards (source chip, finding with an orange highlight, "→ what we do", and an orange decision bar). **15 numbered, clickable references** in 3 columns. Demo links. A one-line honesty note ("renders and simulations are labelled; performance figures are design targets"). |

## 5. Visual system (already in `tokens.css`; use it, don't invent a new one)

- **Colours** (use the `var(--…)` names):
  - navy `--navy` for structure;
  - orange `--orange` for our idea and emphasis;
  - green `--green` for good or built;
  - red `--red` for pain or danger;
  - blue `--blue`;
  - tints `--sky --peach --mint --rose --sand --lilac --wash`.
- **Components:**
  - `.p` panel, `.p.wash` tinted panel;
  - `.tag` header (`.orange .green .red .blue .purple`);
  - `.chip.ok / .road / .p2`;
  - `.badge` numbered circle;
  - `.ptr` pointer heading;
  - `.cap` caption;
  - `.big` number.
- **Text:**
  - minimum 14 px everywhere; body 16–17 px;
  - Segoe UI (`var(--f)`); numbers in Bahnschrift (`var(--num)`);
  - no letter-spacing (it breaks PDF text extraction);
  - no emoji; use Lucide icons (`<i data-icon=…>`).
- **Graphics:**
  - inline SVG you draw (tunnels, devices, flows, maps, UI mocks), or the team's own renders and screenshots;
  - no stock photos, no AI images unless the user provides them, no external fonts or CDNs.
- **Every slide should read in 10 seconds:** one hero visual, a headline claim and scannable panels. Not paragraphs.

## 6. How judges score (SIH 2026 Guidelines, p.13)

The criteria are:
- novelty;
- complexity;
- clarity in the prescribed format;
- feasibility and practicability;
- sustainability;
- scale of impact;
- user experience;
- future potential.

Make sure each one visibly lands somewhere:

| Criterion | Where it lands |
|---|---|
| Novelty | Innovation cards, comparison matrix |
| Complexity | Tech stack, mechanism diagram |
| Clarity | Verbatim pointers, diagram-first |
| Feasibility | Pillars, cost chart, risks, prototype |
| Sustainability | Environmental column |
| Impact | Stats, who gains |
| User experience | UI panel |
| Future potential | Roadmap |

Only 4–5 teams per PS reach the finale, so the deck must stand out on the first scan.

## 7. Honesty rules (bold claims yes, fabricated evidence never)

- Proposed features are labelled **target**, **proposed**, **concept illustration**, **UI concept · example values** or **roadmap**.
- Never claim a partner, a pilot, a test result or a user that does not exist. Write "proposed pilot with X".
- Every printed statistic has a source in the slide's source line or on slide 6. **Verify it on the web** before printing.
- "BUILT ✓" only for things that really exist and are demonstrable.

## 8. Efficiency

- Edit slides with small targeted edits, or a Python script of `old → new` replacements that asserts each old string occurs exactly once. Don't rewrite whole files to change one line.
- Build all six slides, then run **one** render, then fix everything seen, then re-render.
- Read the reference HTML once, for the slides you are building; don't re-read it repeatedly.

## 9. Acceptance checklist (all must be true before you say "done")

- [ ] `make_pdf.py` reports **6 pages**. The file is named per `deck.json`.
- [ ] The template frame is identical to the reference: oval, titles, logo, footer "Team / PS id", page numbers, slide 1 hexagons and bulb.
- [ ] All pointer headings are verbatim. The slide 1 metadata is complete and the PS title is exact.
- [ ] No text overflows, is clipped, overlaps or runs under the QR. No text is smaller than 14 px.
- [ ] No placeholders are left (`XXXXX`, `IDEA NAME`, `FEATURE 1`, `demo-url`, `TODO`).
- [ ] Every stat has a source, and the references on slide 6 are clickable.
- [ ] Honesty labels are present on concept visuals and targets.
- [ ] `sih-deck/work/PORTAL-TEXT.md` has the idea title and description.
- [ ] The user was shown the previews (send `render/preview/*.jpg` or the PDF).
