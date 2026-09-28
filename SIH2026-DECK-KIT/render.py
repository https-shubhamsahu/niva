# usage: python render.py [scale]
#   build -> render/slideN.png (1920x1080 x scale) -> render/preview/slideN.jpg (1280 px, for looking at)
# Always inspect the small JPEG previews, never the full PNGs: full-size images waste context and can crash the session.
import pathlib, subprocess, sys
from PIL import Image

BASE = pathlib.Path(__file__).parent
R = BASE / "render"
sys.path.insert(0, str(BASE / "tools"))
from browser import CH, FLAGS  # noqa: E402

subprocess.run([sys.executable, str(BASE / "build.py")], check=True)
scale = sys.argv[1] if len(sys.argv) > 1 else "1"
(R / "preview").mkdir(exist_ok=True)
for n in range(1, 7):
    png = R / f"slide{n}.png"
    subprocess.run([CH, *FLAGS, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--force-device-scale-factor={scale}",
                    "--allow-file-access-from-files", "--window-size=1920,1080", "--virtual-time-budget=2000",
                    f"--screenshot={png}", (R / f"slide{n}.html").as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    im = Image.open(png).convert("RGB")
    im.thumbnail((1280, 720))
    im.save(R / "preview" / f"slide{n}.jpg", quality=80)
print("rendered -> render/preview/slide1..6.jpg")
