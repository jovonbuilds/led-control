import sys
from PIL import Image
src = Image.open(sys.argv[3] if len(sys.argv) > 3 else "onepw_blue.png").convert("RGB")
step = int(sys.argv[1]); out = sys.argv[2]
W = src.width
frames = []
for k in range(0, W, step):
    f = Image.new("RGB", (W, 16))
    f.paste(src.crop((k, 0, W, 16)), (0, 0)); f.paste(src.crop((0, 0, k, 16)), (W - k, 0))
    frames.append(f)
frames[0].save(out, save_all=True, append_images=frames[1:], duration=100, loop=0)
print(len(frames), "frames")
