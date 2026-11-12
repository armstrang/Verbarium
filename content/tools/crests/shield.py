"""The shield: its outline, the gold rim, the field's light and lattice; the first relief light."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, binary_erosion

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'mobile', 'assets', 'fonts') + '/'
W, H = 520, 620
CB = 380          # charge box
CX, CY = (W - CB) // 2, 92
SS = 2            # supersampling of the charge drawing
GOLD = np.array([212, 166, 60.])
SILVER = np.array([236, 234, 228.])


# ------------------------------------------------------------------ beasts (0..100 units, facing left)
class Pen:
    def __init__(self, size):
        self.n = size
        self.img = {1: Image.new('L', (size, size), 0), 2: Image.new('L', (size, size), 0)}
        self.cut = Image.new('L', (size, size), 0)
        self.d = {k: ImageDraw.Draw(v) for k, v in self.img.items()}
        self.c = ImageDraw.Draw(self.cut)

    def _p(self, pts):
        return [(x * self.n / 100, y * self.n / 100) for x, y in pts]

    def poly(self, pts, t=1):
        self.d[t].polygon(self._p(pts), fill=255)

    def ell(self, cx, cy, rx, ry=None, t=1):
        ry = ry or rx
        k = self.n / 100
        self.d[t].ellipse([(cx - rx) * k, (cy - ry) * k, (cx + rx) * k, (cy + ry) * k], fill=255)

    def line(self, pts, w, t=1, taper=None):
        # a stroke, optionally tapering to `taper` width at its end
        segs = []
        for a, b in zip(pts, pts[1:]):
            for i in range(12):
                s = i / 12
                segs.append((a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s))
        segs.append(pts[-1])
        for i, (x, y) in enumerate(segs):
            ww = w if taper is None else w + (taper - w) * i / (len(segs) - 1)
            self.ell(x, y, ww / 2, t=t)

    def hole(self, cx, cy, r):
        k = self.n / 100
        self.c.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=255)

    def masks(self):
        cut = np.asarray(self.cut, float) / 255
        out = {}
        for t in (1, 2):
            m = np.asarray(self.img[t], float) / 255
            out[t] = m * (1 - cut)
        out[1] = out[1] * (1 - out[2])
        return out


def tufts(p, cx, cy, r0, r1, a0, a1, n, t=1):
    pts = []
    for i in range(n * 2 + 1):
        a = math.radians(a0 + (a1 - a0) * i / (n * 2))
        r = r1 if i % 2 else r0
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    p.poly([(cx, cy)] + pts, t)


def lion(p):
    tufts(p, 36, 25, 11, 17, 150, 430, 9)                      # mane
    p.ell(29, 21, 8)
    p.poly([(23, 16), (14, 18), (12, 24), (16, 27), (25, 28)])  # muzzle
    p.poly([(15, 29), (24, 29), (19, 34)])                      # jaw
    p.poly([(14, 27), (8, 29), (13, 31)], 2)                    # tongue
    p.poly([(31, 13), (34, 6), (37, 14)])                        # ear
    p.poly([(31, 30), (46, 27), (55, 44), (63, 57), (59, 68), (46, 66), (40, 52), (33, 44)])
    p.line([(37, 34), (25, 32), (17, 25)], 6.5)                  # raised foreleg
    p.ell(15, 23, 4.2)
    p.line([(41, 45), (29, 49), (21, 45)], 6.5)
    p.ell(19, 44, 4.2)
    p.ell(56, 62, 9, 8)                                          # haunch
    p.line([(58, 66), (53, 80), (57, 91)], 6.5)
    p.ell(53, 93, 6.5, 3.2)
    p.line([(52, 65), (42, 75), (34, 82)], 6.5)
    p.ell(32, 83, 4.2)
    p.line([(62, 60), (78, 59), (83, 44), (77, 31)], 4.2, taper=3)
    tufts(p, 76, 27, 3, 7, 0, 360, 5)
    for x, y in ((12, 21), (11, 24), (15, 41), (14, 44), (29, 85), (28, 82)):
        p.line([(x + 2, y), (x - 1.5, y + .8)], 1.6, 2)          # claws
    p.poly([(23, 13), (24, 4), (27.5, 9), (30.5, 2), (33.5, 9), (37, 4), (38, 13)], 2)  # crown
    p.hole(25.5, 19.5, 1.4)


def griffin(p):
    p.ell(28, 20, 8)
    p.poly([(31, 13), (35, 4), (37, 14)])
    p.poly([(21, 15), (11, 17), (8, 24), (13, 22), (21, 26)], 2)  # beak
    tufts(p, 34, 32, 9, 13, 120, 300, 6)                          # neck feathers
    p.poly([(26, 26), (40, 24), (48, 42), (38, 48), (29, 38)])
    for i in range(7):                                            # wing feathers
        a = math.radians(-100 + i * 14)
        L = 38 - abs(i - 2) * 2.5
        p.line([(42, 34), (42 + L * math.cos(a), 34 + L * math.sin(a))], 6.5, taper=3.5)
    p.ell(48, 30, 9, 7)
    p.line([(33, 38), (21, 39), (15, 33)], 5.5)                   # talons
    p.line([(37, 47), (25, 52), (18, 50)], 5.5)
    for x, y in ((13, 31), (12, 34), (16, 49), (15, 52)):
        p.line([(x + 2, y), (x - 2, y + 1)], 1.6, 2)
    p.ell(56, 59, 12, 9)                                          # lion hindquarters
    p.line([(60, 64), (56, 80), (61, 91)], 6.5)
    p.ell(57, 93, 6.5, 3.2)
    p.line([(52, 64), (43, 76), (36, 83)], 6.5)
    p.ell(34, 84, 4.2)
    p.line([(66, 60), (82, 64), (88, 50), (83, 40)], 4, taper=3)
    tufts(p, 83, 36, 3, 6.5, 0, 360, 5)
    p.hole(27, 18.5, 1.5)


def dragon(p):
    p.poly([(10, 22), (18, 15), (28, 13), (35, 18), (35, 26), (24, 28), (16, 30), (10, 28)])
    p.poly([(12, 30), (23, 29), (16, 36)])
    p.line([(30, 15), (38, 3)], 3.2, taper=1.2)
    p.line([(26, 14), (29, 4)], 2.6, taper=1)
    p.line([(32, 22), (40, 30), (43, 41)], 9.5)                   # neck
    for x, y in ((36, 22), (41, 28), (45, 35)):
        p.poly([(x - 2, y + 1), (x + 3, y - 4), (x + 3, y + 2)])
    p.poly([(44, 41), (54, 22), (64, 4), (68, 18), (76, 9), (79, 25), (91, 15), (86, 34), (95, 32), (71, 48)])
    p.line([(44, 41), (54, 22), (64, 4)], 3)
    p.hole(73, 33, 3.5); p.hole(84, 29, 2.6); p.hole(64, 22, 3)  # scallops in the membrane
    p.ell(51, 53, 13, 10)
    p.line([(44, 50), (32, 52), (26, 46)], 5.5)
    p.line([(46, 58), (36, 64), (30, 62)], 5.5)
    p.ell(61, 60, 8)
    p.line([(61, 64), (57, 80), (63, 90)], 6)
    p.ell(60, 92, 6, 3)
    p.line([(55, 63), (47, 78), (41, 86)], 6)
    p.line([(63, 58), (79, 66), (85, 80), (76, 91), (88, 95)], 6, taper=2.5)
    p.poly([(86, 91), (97, 97), (86, 99)])
    for x, y in ((24, 45), (28, 61), (39, 87)):
        p.line([(x + 2, y), (x - 2, y + 1)], 1.6, 2)
    p.poly([(12, 28), (4, 23), (7, 30), (0, 34), (8, 36), (2, 43), (12, 36), (10, 42), (16, 34)], 2)  # fire
    p.hole(27, 19, 1.5)


def phoenix(p):
    for side in (1, -1):
        for i in range(8):
            a = math.radians(205 + i * 9) if side == 1 else math.radians(335 - i * 9)
            L = 30 + (7 - i) * 1.8
            sx = 50 - 6 * side
            p.line([(sx, 40), (sx + L * math.cos(a), 40 + L * math.sin(a))], 6, taper=3.2)
    p.ell(50, 48, 8, 14)
    p.ell(50, 28, 6.5)
    p.line([(50, 32), (50, 40)], 7)
    p.poly([(44, 27), (37, 30), (44, 32)], 2)
    for e in ((56, 10), (60, 12), (62, 17)):
        p.line([(52, 23), e], 2.6, taper=1.2)
    for pts in (((50, 60), (40, 72), (44, 84)), ((50, 60), (50, 78), (47, 88)), ((50, 60), (60, 72), (56, 84))):
        p.line(list(pts), 4.5, taper=2)
    pts = [(24, 99)]
    for i in range(9):
        x = 26 + i * 6
        pts += [(x, 90 - (6 if i % 2 else 12) - (4 if 2 < i < 6 else 0)), (x + 3, 93)]
    pts += [(78, 99)]
    p.poly(pts, 2)
    p.hole(49, 26.5, 1.5)


def eastern(p):
    p.line([(26, 22), (40, 30), (56, 24), (72, 32), (74, 48), (58, 58), (38, 56), (26, 66), (32, 80), (52, 84),
            (72, 78), (86, 88), (95, 96)], 9.5, taper=3)
    for i in range(10):
        t = i / 9
        x, y = 44 + t * 30, 26 + math.sin(t * 3) * 3 - 5
        p.poly([(x - 2, y + 4), (x + 1, y - 3), (x + 4, y + 4)])
    p.poly([(8, 22), (14, 12), (30, 10), (36, 20), (30, 30), (14, 30)])
    p.line([(27, 12), (33, 2), (37, 4)], 2.8, taper=1.3)
    p.line([(22, 11), (19, 2), (15, 3)], 2.8, taper=1.3)
    p.line([(9, 27), (4, 33), (0, 32)], 1.8, taper=.8)
    p.line([(10, 18), (4, 12), (1, 14)], 1.8, taper=.8)
    for a, b, c in (((46, 31), (44, 42), (40, 44)), ((66, 53), (72, 63), (76, 62)), ((42, 82), (40, 93), (36, 94))):
        p.line([a, b, c], 4)
    p.ell(88, 16, 7.5, t=2)
    p.hole(21, 17.5, 1.7)


# ------------------------------------------------------------------ rendering
def shield_mask():
    img = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(img)
    pts = [(14, 14), (W - 14, 14), (W - 14, 300)]
    for i in range(1, 41):  # right curve to the point
        t = i / 40
        x = (1 - t) ** 2 * (W - 14) + 2 * (1 - t) * t * (W - 14) + t * t * (W / 2)
        y = (1 - t) ** 2 * 300 + 2 * (1 - t) * t * 520 + t * t * (H - 10)
        pts.append((x, y))
    pts += [(W - x, y) for x, y in reversed(pts[3:-1])]
    pts += [(14, 300)]
    d.polygon(pts, fill=255)
    return np.asarray(img, float) / 255


def relief(mask, base, blur, depth, spec=0.5, shine=24):
    h = gaussian_filter(mask, blur) * depth
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-.55, -.65, .9]); L /= np.linalg.norm(L)
    d = np.clip((n * L).sum(2), 0, 1)
    col = base[None, None, :] * (0.45 + 0.75 * d[..., None])
    col += 255 * spec * (d ** shine)[..., None]
    return np.clip(col, 0, 255)


def render(tint, beast):
    sm = shield_mask()
    rim = sm - binary_erosion(sm > .5, iterations=22).astype(float)
    inner = sm - rim
    # field: tincture with soft light from the upper left and a faint diaper lattice
    yy, xx = np.mgrid[0:H, 0:W]
    light = 1.15 - 0.45 * np.clip(np.hypot(xx - W * .3, yy - H * .25) / (W * .9), 0, 1)
    lattice = ((((xx + yy) % 46) < 2) | (((xx - yy) % 46) < 2)).astype(float)
    grain = gaussian_filter(np.random.default_rng(3).normal(0, 1, (H, W)), 1.2) * 4
    field = np.array(tint, float)[None, None, :] * (light - .07 * lattice)[..., None] + grain[..., None]
    # the beast, drawn large then shrunk for smooth edges
    pen = Pen(CB * SS)
    beast(pen)
    ms = pen.masks()
    full = {}
    for t, m in ms.items():
        m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((CB, CB), Image.LANCZOS), float) / 255
        big = np.zeros((H, W)); big[CY:CY + CB, CX:CX + CB] = m
        full[t] = big
    charge = np.clip(full[1] + full[2], 0, 1)
    shadow = np.roll(np.roll(gaussian_filter(charge, 5), 9, 0), 7, 1)
    out = field * (1 - .5 * shadow[..., None])
    silver = relief(full[1], SILVER, 3.2, 26, .35)
    gold = relief(full[2], GOLD, 2.4, 22, .7, 16)
    out = out * (1 - charge[..., None]) + silver * full[1][..., None] + gold * full[2][..., None]
    # outline of the charge in a dark tone of the field
    edge = np.clip(gaussian_filter(charge, 1.1) * 1.6 - charge, 0, 1)
    dark = np.array(tint) * .35
    out = out * (1 - edge[..., None]) + dark[None, None, :] * edge[..., None]
    # gold rim with bevel, a dark line inside it
    rim_col = relief(binary_erosion(sm > .5, iterations=2).astype(float) * rim, GOLD, 4, 60, .6, 18)
    inline = np.clip(gaussian_filter(rim, 1.5) - rim, 0, 1) * inner
    out = out * inner[..., None] * (1 - inline[..., None] * .8) + rim_col * rim[..., None]
    alpha = np.clip(sm, 0, 1)
    rgba = np.dstack([np.clip(out, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA'), sm


KINGDOMS = [
    ('Aldmere', 'English · Singa', 0x1F3F73, lion),
    ('Grauwacht', 'Deutsch · Griffin', 0x5C574D, griffin),
    ('Valdoro', 'Español · Naga barat', 0x8E1B16, dragon),
    ('Beaumarais', 'Français · Phoenix', 0x5A2A6B, phoenix),
    ('Alvamar', 'Português · Naga timur', 0x2F5D3A, eastern),
]

if __name__ == '__main__':
    paper, ink, mute = (246, 241, 230), (40, 33, 26), (110, 98, 84)
    sc = .62
    sw, shh = int(W * sc), int(H * sc)
    cell, top, rowh = sw + 50, 40, shh + 120
    sheet = Image.new('RGB', (cell * 3 + 10, top + rowh * 2), paper)
    d = ImageDraw.Draw(sheet)
    f1 = ImageFont.truetype(FONT + 'fell-400.ttf', 40)
    f2 = ImageFont.truetype(FONT + 'sans-500.ttf', 22)
    for i, (name, sub, hexc, fn) in enumerate(KINGDOMS):
        row, col = divmod(i, 3)
        if row:
            col += .5
        tint = ((hexc >> 16) & 255, (hexc >> 8) & 255, hexc & 255)
        img, sm = render(tint, fn)
        img.save(f'/home/claude/out/shields/{name.lower()}.png')
        img = img.resize((sw, shh), Image.LANCZOS)
        x, y = int(col * cell + 30), top + row * rowh
        sh = Image.fromarray((gaussian_filter(sm, 8) * 90).astype(np.uint8)).resize((sw, shh))
        sheet.paste((60, 45, 30), (x + 6, y + 10), sh)
        sheet.paste(img, (x, y), img)
        cx = x + sw // 2
        d.text((cx, y + shh + 14), name, font=f1, fill=ink, anchor='mt')
        d.text((cx, y + shh + 62), sub, font=f2, fill=mute, anchor='mt')
    sheet.save('/home/claude/out/shields/perisai-mock-2.png')
