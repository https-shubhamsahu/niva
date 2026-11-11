# usage: python tools/qr.py https://your-demo-url  qr-demo  -> assets/qr-demo.svg (vector, seam-free)
# Use in a slide: <a href="https://your-demo-url"><i data-svg="qr-demo" style="width:100px;height:100px"></i></a>
import pathlib, sys
import qrcode

url, name = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "qr-demo")
q = qrcode.QRCode(border=2, error_correction=qrcode.constants.ERROR_CORRECT_M)
q.add_data(url); q.make(fit=True)
mx = q.get_matrix()
runs = []
for y, row in enumerate(mx):
    x = 0
    while x < len(row):
        if row[x]:
            s = x
            while x < len(row) and row[x]: x += 1
            runs.append(f"M{s},{y}h{x - s + 0.03:.2f}v1.03h-{x - s + 0.03:.2f}z")
        else:
            x += 1
n = len(mx)
out = pathlib.Path(__file__).parent.parent / "assets" / f"{name}.svg"
out.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n} {n}"><rect width="{n}" height="{n}" fill="#fff"/>'
               f'<path d="{"".join(runs)}" fill="#000"/></svg>', encoding="utf8")
print("wrote", out)
