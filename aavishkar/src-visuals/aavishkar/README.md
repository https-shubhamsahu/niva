# Current Aavishkar source

`current.scene.json` is the complete editable source for the approved presentation and poster. It replaces the old chain of version-specific generators. Each page contains positioned text, native chart/table data, scientific diagram geometry, logo outlines and speaker notes. Edit this file or the delivered PowerPoint when making future changes. Changes made directly in PowerPoint are not synchronized back to the scene.

## Files

- `build.mjs`: validates the source and builds both editable PowerPoints.
- `renderer.mjs`: shared native-object renderer and finalizer.
- `export_pdf.py`: vector PDF exporter from the same scene.
- `fonts/`: IBM Plex font files and their licence. Install for PowerPoint editing.
- `assets/footprints.json`: the actual pressure-map example and sensor geometry, retained for future figure changes.
- `assets/logo-vector-paths.json`: reusable traced logo geometry and light/dark colours. SVG copies remain in `docs/brand/niva_logo_assets`.

## Rebuilding

Use the bundled Codex Node and Python runtimes. No previous revision files are required.

```powershell
& 'C:/Users/shubh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' src-visuals/aavishkar/build.mjs --check
& 'C:/Users/shubh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' src-visuals/aavishkar/build.mjs
& 'C:/Users/shubh/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' src-visuals/aavishkar/export_pdf.py
```

Default outputs: `docs/aavishkar/current`. The PowerPoint finalizer refuses to overwrite a current file. For a review build, set `NIVA_OUTPUT_DIR` to a new absolute directory inside the repository and pass that same directory as `--output-dir` to the PDF exporter. Review the exports before replacing approved deliverables. Scratch files go to ignored `data/visual-build`.

## Evidence boundaries

Preserve the values in `docs/r2/run_20260912T161228Z/summary.json` and the sampling plan. R2 is a completed 12-participant subset analysis of assumed layouts, not calibrated Niva performance. R1/R3 remain to be measured. Footprint data are participant 002, right foot, BF/ST W1, first selected step. Do not recompute R2 merely to redraw a figure. Keep sensor/foot scales proportional and retain count/placement and floor/insole limitations.
