# Finds a Chromium browser for headless rendering: Chrome, then Edge, then Chromium / Playwright's Chromium (Linux, cloud).
# No browser in a Linux container?  pip install playwright && python -m playwright install --with-deps chromium
import glob, os, shutil

HOME = os.path.expanduser("~")
CANDIDATES = [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
              "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              *(shutil.which(n) or "" for n in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome")),
              *sorted(glob.glob(f"{HOME}/.cache/ms-playwright/chromium-*/chrome-linux*/chrome"), reverse=True)]
CH = next((c for c in CANDIDATES if c and os.path.exists(c)), None)
if not CH:
    raise SystemExit("No Chrome/Chromium found. On Linux run: pip install playwright && python -m playwright install --with-deps chromium")
# containers usually run as root, where Chrome refuses to start without --no-sandbox
FLAGS = [] if os.name == "nt" else ["--no-sandbox", "--disable-dev-shm-usage"]
