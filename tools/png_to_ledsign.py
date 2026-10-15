"""png_to_ledsign.py in.png out.ledsign [mode] [loopDelay] — wrap a 1-pixel-per-LED PNG in the app's .ledsign JSON."""
import json, sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
rows = ["".join(str((r > 127) | (g > 127) << 1 | (b > 127) << 2) for r, g, b in
                (im.getpixel((x, y)) for x in range(im.width))) for y in range(im.height)]
doc = {"format": "ledsign", "version": 1, "width": im.width, "height": im.height,
       "settings": {"brightness": 200, "speed": 128,
                    "mode": sys.argv[3] if len(sys.argv) > 3 else "scrollLeft",
                    "loopDelay": int(sys.argv[4]) if len(sys.argv) > 4 else 150},
       "colors": "0 off, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white",
       "rows": rows}
json.dump(doc, open(sys.argv[2], "w"), indent=2, sort_keys=True)
