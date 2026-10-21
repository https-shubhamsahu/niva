# SIH 2026 deck kit

This is the pipeline that built Team Palanteen's SURANG-SUTRA SIH 2026 deck. It produces 6 slides as HTML, rendered in Chrome to a vector PDF, inside the official SIH 2026 template frame.

- **Starting a new problem statement:** fill in and paste [PROMPT.md](PROMPT.md) into a new Claude Code session.
- **Method and rules:** [GUIDE.md](GUIDE.md).
- **Approved example:** [reference/](reference/) holds the PDF, the slide previews and the slide source.

| Command | What it does |
|---|---|
| `python render.py` | Builds the slides and writes `render/preview/slide1..6.jpg` |
| `python make_pdf.py` | Writes the final PDF named in `deck.json` |
| `python tools/icon.py <name>` | Fetches a Lucide icon |
| `python tools/qr.py <url> qr-demo` | Makes a vector QR code |
| `python tools/shot.py <url> <name>` | Takes a screenshot of a demo page |

**Requirements:** Python 3 with `pillow`, `pypdf` and `qrcode`, plus Chrome or Edge. On Linux or cloud, see GUIDE.md §2; the bundled open fonts keep the layout identical.
