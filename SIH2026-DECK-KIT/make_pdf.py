# usage: python make_pdf.py -> <output_pdf from deck.json> (vector, selectable text, tagged, links kept)
import json, pathlib, subprocess, sys
from pypdf import PdfReader, PdfWriter

BASE = pathlib.Path(__file__).parent
CFG = json.loads((BASE / "deck.json").read_text(encoding="utf8"))
sys.path.insert(0, str(BASE / "tools"))
from browser import CH, FLAGS  # noqa: E402

tmp = BASE / "render" / "deck-raw.pdf"
out = BASE / CFG["output_pdf"]
subprocess.run([sys.executable, str(BASE / "build.py")], check=True)
subprocess.run([CH, *FLAGS, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--export-tagged-pdf",
                "--generate-pdf-document-outline", "--allow-file-access-from-files", "--virtual-time-budget=4000",
                f"--print-to-pdf={tmp}", (BASE / "render" / "deck.html").as_uri()],
               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

w = PdfWriter(clone_from=str(tmp))
w.add_metadata({"/Title": CFG["pdf_title"], "/Author": f'{CFG["team_name"]} (Team ID {CFG["team_id"]})',
                "/Subject": f'Smart India Hackathon 2026 idea submission, Problem Statement {CFG["ps_id"]}',
                "/Keywords": CFG.get("pdf_keywords", ""), "/Creator": "SIH 2026 deck kit (HTML to PDF)"})
w.compress_identical_objects(remove_duplicates=True, remove_unreferenced=True)
with open(out, "wb") as f:
    w.write(f)

r = PdfReader(str(out))
text = " ".join(p.extract_text() for p in r.pages)
print(out.name, round(out.stat().st_size / 1024), "KB,", len(r.pages), "pages,", f'PS {CFG["ps_id"]} mentioned {text.count(CFG["ps_id"])}x')
if len(r.pages) != 6:
    raise SystemExit("ERROR: the SIH template allows exactly 6 slides")
