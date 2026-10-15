# tools

Python experiments from the first session (2026-10-13), kept so they aren't lost.
Run with any Python 3.11+ that has Pillow (`uv venv --python 3.12 && uv pip install pillow bleak`).

| File | What it does |
|---|---|
| `onepw_logo.py` | Hand-drawn 96×16 1Password pixel logo. Writes `onepw_blue.png`, `onepw_black.png` and a 10× `compare2.png` preview. |
| `scroll_gif.py` | `python scroll_gif.py <step_px> <out.gif> [in.png]` — builds a seamless loop: each frame is the image rotated left by `step_px`, so the background stays fixed while the content moves (no black gap). 2 px = 48 frames for a 96-wide image. |
| `coolledx-driver-fixes.patch` | Fixes for [coolledx-driver](https://github.com/UpDryTwist/coolledx-driver) at commit `ba24137` (MIT). Needed to drive this sign at all: circular import, missing packet framing, write-without-response, and swapped width/height (caused the scrambled display). |

Sending with the patched driver (from a clone with the patch applied):

    PYTHONPATH=src:. python utils/tweak_sign.py -i onepw_blue.png               # still image
    PYTHONPATH=src:. python utils/tweak_sign.py --animation loop2.gif --animation-speed 150

Known-good for the 1Password scroll: `scroll_gif.py 2` (48 frames), animation speed 150. Upload ≈ 1 min (217 chunks).
