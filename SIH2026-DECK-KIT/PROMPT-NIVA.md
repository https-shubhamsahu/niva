# NIVA: paste-ready prompt

Fill in the Problem statement fields and the deadline, then paste everything between the lines into Claude Code. It works on your PC or in the cloud session for `https-shubhamsahu/niva`. In the cloud, the kit must first be pushed to the repo's `sih-deck-kit` branch.

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

- **The idea in our words:**
  - NIVA is a low-cost bilateral knee-load screening kit for Indian health camps.
  - **Insole:** passive, with 5 force points and a heel PVDF film; nothing rigid underfoot.
  - **Shin pod:** connected to the insole by a shielded strip. It carries an ESP32-C3, a 12-bit ADC, a 6-axis IMU, and a removable battery cartridge that is charged only in a dock.
  - **Use:** it records walking and chair-rise in the patient's own chappal, sandal or shoe, fully offline.
  - **Output:** a referral-triage result (refer for X-ray / clinical exam), not a diagnosis.
  - **Claims limits:** the knee adduction moment (KAM) estimate is an experiment, gated by a gait-lab test. Medial knee contact force is never claimed.
- **Already built** (repo `https-shubhamsahu/niva`, main branch):
  - **Engineering brief:** `hardware/brief/engineering-brief.txt` (sensing table, BOM in INR, power and data budgets, roadmap stages 0–5, experiments E1–E7).
  - **6 vector blueprint sheets:** `hardware/outputs/NIVA-vector-blueprints-Rev-A.pdf` and `hardware/outputs/niva-vector-blueprints/` (pod, insole stack, footwear, battery/charging exclusion, electronics, camp kit), plus a 1:1 fit template SVG.
  - **Renders:** `hardware/outputs/NIVA-3D-engineering-prototype/renders/`. `raw/` is uncaptioned: pod assembled, exploded, flat-lay, bilateral kit, dock, insole flex. `pcb-raw/` holds KiCad raytraces.
  - **AI concept images (label them as concept):** `hardware/outputs/niva-worn-hero.png`, `niva-health-camp-kit.png`, `niva-three-footwear.png`.
  - **KiCad 9 projects for 5 boards** (pod 4-layer 34×48 mm, cartridge, dock, insole R/L flex). All pass ERC/DRC with 0 errors and 0 unconnected. The Gerbers are for review only; nothing is fabricated.
  - **Also:** a FreeCAD Rev C printable enclosure, Blender scenes, GLB/STEP models, `VERIFICATION-PLAN.md` and `ELECTRICAL-REVIEW.md`.
  - **Verified research (for the dossier):**
    - 62.35 M Indians with OA in 2019 (GBD, Singh 2022);
    - 20.2% knee-OA prevalence (Hazra 2025 meta-analysis);
    - 28.7% X-ray-confirmed (Pal 2016);
    - 6.46× progression risk per 1% KAM (Miyazaki 2002);
    - insole KAM r 0.88–0.98 walking, 0.50 sit-to-stand (Snyder 2025);
    - insole AUC 0.83 (Wipperman 2024);
    - shoe-IMU 56% specificity (Raza 2024);
    - flip-flops ≈ barefoot, clogs ≈ +15% KAM (Shakoor 2010).
  - **Do not use** the brief's "r = 0.96" (Snyder 2023). It is unverified.
- **What must not change:**
  - The hardware architecture and all renders and blueprints are final. Only the story and the deck may change.
  - Nothing is built or clinically tested, so there are no results, accuracy figures or partner claims.
  - Reuse the blueprints, renders and PCB raytraces as the deck's visuals (copy them into `sih-deck/assets/`). Draw new inline SVG only where nothing exists.
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
