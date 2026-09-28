# usage: python tools/icon.py name [name ...]  -> icons/name.svg from Lucide (https://lucide.dev/icons, ISC licence)
import pathlib, sys, urllib.request

OUT = pathlib.Path(__file__).parent.parent / "icons"
for name in sys.argv[1:]:
    url = f"https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/{name}.svg"
    try:
        data = urllib.request.urlopen(url, timeout=20).read()
    except Exception as e:
        print(f"{name}: not found ({e}); browse https://lucide.dev/icons for the exact name")
        continue
    (OUT / f"{name}.svg").write_bytes(data)
    print(f"{name}: ok")
