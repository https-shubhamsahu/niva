# Paste-ready prompt for a new Claude Code session

Fill the `<<…>>` fields, then paste everything between the lines into Claude Code, opened in your new project's folder.

---

Build our Smart India Hackathon 2026 idea-submission deck (6-slide PDF) for the problem statement below.

**Use our existing deck kit and match our previous deck's look exactly.** Last time a session made "an SIH PPT" with a different template. That is the failure to avoid.

## The kit (the only allowed way to make the deck)

- **Kit:** `SIH2026-DECK-KIT/`. Look in this order:
  1. this repository (it may be on the branch `sih-deck-kit`: run `git fetch origin sih-deck-kit` and `git checkout origin/sih-deck-kit -- SIH2026-DECK-KIT`);
  2. on Windows, `C:\Users\shubh\_Active_Projects\SIH2026-DECK-KIT\`.
  If you cannot find it, **stop and tell me**. Do not build a deck any other way.
- **Setup:** copy the whole kit folder into this project as `sih-deck/` and work only in that copy. Never edit the original kit.
- **Cloud or Linux:** the kit bundles look-alike fonts, so the layout matches. If there is no Chrome, run `pip install playwright pillow pypdf qrcode && python -m playwright install --with-deps chromium`.
- **Read first:** `sih-deck/GUIDE.md`, completely. It is the method, the rules and the slide playbook. Follow it.
- **Reference:** `sih-deck/reference/`. `SURANG-SUTRA-SIH2026-PS26218.pdf` is the approved deck we submitted; `previews/slide1..6.jpg` are small images of it; `slides-html/` is its source.
  - Your deck must look like the same team made it with the same kit.
  - It must have the same SIH template frame, visual system, panel density, diagram-first style and quality.
  - Only the content changes.
- **Do not:**
  - use python-pptx, the pptx, sih-pptx-native, ppt-agent, slides, frontend-slides or design skills, Canva, Google Slides or any other template;
  - edit `chrome.css`, `tokens.css`, `fonts.css` or the template frame in `build.py`.
- **Output:** the PDF from `python make_pdf.py`.

## Problem statement

- **PS ID:** <<e.g. 25xxx>>
- **PS title (exact, as on the portal):** <<paste>>
- **Description:** <<paste the full PS description>>
- **Organisation / department:** <<paste>>
- **Category:** <<Hardware / Software>>
- **Theme:** <<paste>>

## Team

- **Team name:** Team Palanteen
- **Team ID:** 121295
- **College:** Thakur Shyamnarayan Engineering College

## Our idea and existing material

- **The idea in our words:** <<2–5 sentences, or "propose the strongest idea for this PS" if not decided>>
- **Already built:** <<code, simulation, app, CAD, renders, videos, demo URL, folders and their paths>>
- **What must not change:** <<e.g. "hardware and videos are final; only the story and deck may change", or "nothing fixed yet">>
- **Deadline:** <<date>>

## How to work

Follow the phases in GUIDE.md §2:
1. Intake.
2. Research dossier, with web-verified sources.
3. Slide blueprint. **Stop and show me the blueprint for approval before building.**
4. Assets.
5. Build all 6 slides.
6. Render and visual QA using only the small JPEG previews in `render/preview/`.
7. PDF.
8. Portal text.

**Rules:**
- **Reuse** everything we already have (diagrams, renders, screenshots, simulation) instead of redrawing from scratch.
- **Be bold** in the idea and the visuals, but **honest**: targets and concepts are labelled; no invented partners, results or statistics.

**Finish only when every box in GUIDE.md §9 is ticked.** Then send me the PDF and the six previews, and list any stats I should double-check.

---

## Tips

- **Modifying an existing deck instead of starting fresh:**
  - put that deck's `slide1..6.html` into `sih-deck/slides/`;
  - copy its assets into `sih-deck/assets/`;
  - say "edit the copy only; keep every graphic".
  - That is how the PS 26039 → 26218 remake was done: a copy-only rewrite, all graphics kept.
- **Model and effort:** use Opus with high effort for the research and blueprint phases. The build and QA loop works fine at medium effort.
- **If the session crashes (out of memory),** say "continue where you left". Everything is saved in `sih-deck/` and `sih-deck/work/`.
