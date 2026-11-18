"""Render the navigation buttons of nav.html to WebP with a transparent background, once per theme.
Run from the repo root: python -I assets/source/render-nav.py   (needs playwright and pillow; fonts load from Google Fonts)"""
import functools, http.server, io, threading
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

def launch(p):
    for name in ("msedge", "chrome"):
        try:
            return p.chromium.launch(channel=name)
        except Exception:
            pass
    return p.chromium.launch()


root = Path("assets").resolve()
out = Path("assets/readme").resolve()
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_address[1]
with sync_playwright() as p:
    browser = launch(p)
    for theme in ("light", "dark"):
        page = browser.new_page(viewport={"width": 2600, "height": 1400})
        page.goto(f"http://127.0.0.1:{port}/source/nav.html?theme={theme}", wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        page.add_style_tag(content="html, body, .item { background: transparent !important; }")
        page.wait_for_timeout(300)
        for item_id in page.eval_on_selector_all(".item", "els => els.map(e => e.id)"):
            png = page.locator("#" + item_id).screenshot(scale="css", omit_background=True)
            name = item_id + ("" if theme == "light" else "-dark") + ".webp"
            Image.open(io.BytesIO(png)).convert("RGBA").save(out / name, "WEBP", lossless=True)
            print(name)
        page.close()
    browser.close()
server.shutdown()

