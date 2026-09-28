# usage: python tools/shot.py https://url-or-file.html  name  [width height]
#   -> assets/name.jpg: a crisp 2x screenshot of a live demo/app page for a "working prototype" panel.
import pathlib, subprocess, sys
from PIL import Image
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from browser import CH, FLAGS  # noqa: E402

url, name = sys.argv[1], sys.argv[2]
w, h = (sys.argv[3], sys.argv[4]) if len(sys.argv) > 4 else ("1920", "1080")
assets = pathlib.Path(__file__).parent.parent / "assets"
png = assets / f"{name}.png"
subprocess.run([CH, *FLAGS, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                f"--window-size={w},{h}", "--virtual-time-budget=8000", f"--screenshot={png}", url],
               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
Image.open(png).convert("RGB").save(assets / f"{name}.jpg", quality=88, optimize=True)
png.unlink()
print("wrote", assets / f"{name}.jpg")
