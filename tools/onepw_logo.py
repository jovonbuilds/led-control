from PIL import Image
import sys
G = {  # 11 rows tall (cap height); lowercase occupies rows 3-10
"1": ["..##","####","..##","..##","..##","..##","..##","..##","..##","..##","..##"],
"P": ["######.","#######","##...##","##...##","##...##","#######","######.","##.....","##.....","##.....","##....."],
"a": [".#####.","##...##",".....##",".######","##...##","##...##","##..###",".###.##"],
"s": [".####.","##..##","##....","#####.",".#####","....##","##..##",".####."],
"w": ["##......##","##......##","##..##..##","##..##..##","##.####.##","####..####",".##....##.",".##....##."],
"o": [".#####.","##...##","##...##","##...##","##...##","##...##","##...##",".#####."],
"r": ["##.##","#####","###..","##...","##...","##...","##...","##..."],
"d": [".....##",".....##",".....##",".######","##...##","##...##","##...##","##...##","##...##","##...##",".######"],
}
ICON_TOP = ["......####......","...##########...","..############..",".##############.",".##############."]
ICON = ICON_TOP + ["################"]*6 + ICON_TOP[::-1]
# keyhole slot cols 6-9 rows 3-12, rounded corners, left notch rows 6-7, right notch rows 8-9
for y in range(3, 13):
    row = list(ICON[y])
    for x in range(6, 10):
        corner = (y in (3, 12)) and x in (6, 9)
        notch = (x == 6 and y in (6, 7)) or (x == 9 and y in (8, 9))
        if not corner and not notch: row[x] = "."
    ICON[y] = "".join(row)

def build(bg, fg, out, word_fg=None):
    word_fg = word_fg or fg
    gap, icon_gap = 1, 4
    text_w = sum(len(G[c][0]) for c in "1Password") + gap * 8
    total = 16 + icon_gap + text_w
    x0 = (96 - total) // 2
    im = Image.new("RGB", (96, 16), bg)
    for y, row in enumerate(ICON):
        for x, ch in enumerate(row):
            if ch == "#": im.putpixel((x0 + x, y), fg)
    x, top = x0 + 16 + icon_gap, 3
    for c in "1Password":
        rows = G[c]; off = top + 11 - len(rows)
        for y, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch == "#": im.putpixel((x + dx, off + y), word_fg)
        x += len(rows[0]) + gap
    print("lockup width", total, "x0", x0)
    im.save(out)
    return im
a = build((0,0,255), (255,255,255), "onepw_blue.png")
b = build((0,0,0), (255,255,255), "onepw_black.png")
c = Image.new("RGB", (960, 340), "gray")
c.paste(a.resize((960,160), Image.NEAREST), (0,0)); c.paste(b.resize((960,160), Image.NEAREST), (0,180))
c.save("compare2.png")
