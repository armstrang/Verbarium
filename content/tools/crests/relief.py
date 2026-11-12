"""Drawing tools (Layer: strokes, ovals, carved lines, scales, fur), metal in relief, and a whole crest: shield, beast, crown, motto."""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, binary_erosion, binary_dilation, distance_transform_edt

from shield import relief, shield_mask, W, H, GOLD, FONT

N = 1000                  # drawing resolution of the charge, units 0..100
SILVER = np.array([238, 236, 230.])


def bez(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def path(*segs):
    """segments of cubic béziers given as (p1, p2, p3) after a start point"""
    start, rest = segs[0], segs[1:]
    pts, cur = [start], start
    for s in rest:
        if len(s) == 3:
            pts += bez(cur, *s)[1:]
            cur = s[2]
        else:
            pts.append(s[0])
            cur = s[0]
    return pts


class Layer:
    def __init__(self):
        self.img = Image.new('L', (N, N), 0)
        self.d = ImageDraw.Draw(self.img)
        self.cut = Image.new('L', (N, N), 0)
        self.c = ImageDraw.Draw(self.cut)

    def k(self, pts):
        return [(x * N / 100, y * N / 100) for x, y in pts]

    def poly(self, pts):
        self.d.polygon(self.k(pts), fill=255)

    def ell(self, x, y, r, d=None):
        d = d or self.d
        d.ellipse([(x - r) * N / 100, (y - r) * N / 100, (x + r) * N / 100, (y + r) * N / 100], fill=255)

    def oval(self, x, y, rx, ry):
        self.d.ellipse([(x - rx) * N / 100, (y - ry) * N / 100, (x + rx) * N / 100, (y + ry) * N / 100], fill=255)

    def stroke(self, pts, w0, w1, cut=False):
        """a tapering stroke along a sampled curve"""
        d = self.c if cut else self.d
        dense = []
        for a, b in zip(pts, pts[1:]):
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            m = max(1, int(L * 6))
            dense += [(a[0] + (b[0] - a[0]) * i / m, a[1] + (b[1] - a[1]) * i / m) for i in range(m)]
        dense.append(pts[-1])
        for i, (x, y) in enumerate(dense):
            self.ell(x, y, (w0 + (w1 - w0) * i / max(1, len(dense) - 1)) / 2, d)

    def scales(self, r=1.6, box=(0, 0, 100, 100), w=3):
        """a field of overlapping scale arcs, carved into whatever this layer fills"""
        k = N / 100
        x0, y0, x1, y1 = box
        row = 0
        y = y0
        while y < y1:
            off = r if row % 2 else 0
            x = x0 + off
            while x < x1:
                self.c.arc([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], 20, 160, fill=255, width=w)
                x += 2 * r
            y += r * 1.1
            row += 1

    def fur(self, c, r0, r1, a0, a1, n, curl=.4, w=.45):
        """fine carved strands radiating from c"""
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * i / max(1, n - 1))
            rr0 = r0 + (i * 7 % 5) * .6
            p0 = (c[0] + rr0 * math.cos(a), c[1] + rr0 * math.sin(a))
            p3 = (c[0] + r1 * math.cos(a + curl), c[1] + r1 * math.sin(a + curl))
            m = (c[0] + (rr0 + r1) / 2 * math.cos(a + curl * .3), c[1] + (rr0 + r1) / 2 * math.sin(a + curl * .3))
            self.stroke(bez(p0, m, m, p3, 10), w, .2, cut=True)

    def mask(self):
        return (np.asarray(self.img, float) / 255) * (1 - np.asarray(self.cut, float) / 255)


def spikes(layer, curve, side, every, h, w, start=0.0, end=1.0, grow=1.0):
    """little curved thorns along a curve, on one side"""
    n = len(curve)
    i0, i1 = int(start * (n - 1)), int(end * (n - 1))
    for i in range(i0 + every // 2, i1, every):
        (x0, y0), (x1, y1) = curve[i - 1], curve[min(i + 1, n - 1)]
        tx, ty = x1 - x0, y1 - y0
        L = math.hypot(tx, ty) or 1
        tx, ty = tx / L, ty / L
        nx, ny = -ty * side, tx * side
        x, y = curve[i]
        hh = h * (1 + (grow - 1) * (i - i0) / max(1, i1 - i0))
        tip = (x + nx * hh - tx * hh * .7, y + ny * hh - ty * hh * .7)
        layer.poly([(x - tx * w, y - ty * w), tip, (x + tx * w * .6, y + ty * w * .6)])


def dragon():
    layers = []

    # far wing (behind the body, to the right)
    wing = Layer()
    arm = path((58, 40), ((66, 30), (72, 22), (80, 14)), ((84, 10), (88, 6), (94, 3)))
    wing.stroke(arm, 3.2, 1.6)
    wing.poly([(80, 14), (91, 4), (97, 10)])
    tips = [(99, 26), (97, 42), (88, 54)]
    edge = [(94, 3)]
    prev = (94, 3)
    for t in tips:
        mid = ((prev[0] + t[0]) / 2 - 7, (prev[1] + t[1]) / 2 + 2)
        edge += bez(prev, mid, mid, t, 16)[1:]
        prev = t
    edge += bez(prev, (80, 56), (70, 52), (62, 50), 16)[1:]
    wing.poly([(58, 40), (80, 14)] + edge)
    for t in tips:  # finger bones as thin gaps
        wing.stroke(bez((86, 10), ((86 + t[0]) / 2 + 2, (10 + t[1]) / 2), ((86 + t[0]) / 2, (10 + t[1]) / 2 + 3), t, 10),
                    .9, .5, cut=True)
    layers.append(wing)

    # near wing (to the left, behind the head)
    wing2 = Layer()
    arm2 = path((50, 42), ((40, 34), (30, 26), (20, 18)), ((14, 12), (9, 8), (4, 6)))
    wing2.stroke(arm2, 3.4, 1.6)
    wing2.poly([(20, 18), (5, 4), (1, 12)])
    tips2 = [(0, 30), (4, 46), (16, 58)]
    edge2, prev = [(4, 6)], (4, 6)
    for t in tips2:
        mid = ((prev[0] + t[0]) / 2 + 7, (prev[1] + t[1]) / 2 + 2)
        edge2 += bez(prev, mid, mid, t, 16)[1:]
        prev = t
    edge2 += bez(prev, (26, 60), (38, 56), (46, 52), 16)[1:]
    wing2.poly([(50, 42), (20, 18)] + edge2)
    for t in tips2:
        wing2.stroke(bez((14, 12), ((14 + t[0]) / 2 - 2, (12 + t[1]) / 2), ((14 + t[0]) / 2, (12 + t[1]) / 2 + 3), t, 10),
                     .9, .5, cut=True)
    layers.append(wing2)

    # tail, sweeping down and curling
    tail = Layer()
    tc = path((60, 64), ((76, 70), (86, 86), (72, 94)), ((60, 100), (40, 98), (34, 88)),
              ((30, 81), (38, 76), (44, 81)))
    tail.stroke(tc, 9, 1.8)
    spikes(tail, tc, 1, 10, 2.6, 1.4, .05, .8)
    tail.poly([(44, 81), (49, 77), (47, 84), (42, 85)])  # spade
    layers.append(tail)

    # far hind leg
    leg2 = Layer()
    leg2.stroke(path((64, 62), ((70, 70), (72, 76), (70, 82)), ((69, 85), (72, 88), (76, 89))), 6, 3.4)
    for dx in (0, 2.4, 4.8):
        leg2.stroke(bez((75 + dx * .3, 88), (77 + dx, 89), (78 + dx, 91), (77 + dx, 93), 6), 1.6, .5)
    layers.append(leg2)

    # body and neck
    body = Layer()
    spine = path((40, 22), ((50, 22), (54, 28), (50, 36)), ((46, 44), (52, 54), (60, 62)))
    body.stroke(spine, 6.5, 13)
    body.stroke(path((58, 58), ((60, 62), (62, 66), (60, 68))), 12, 10)
    spikes(body, spine, -1, 9, 3.4, 1.6, .02, .9, grow=.7)
    for i in range(6):  # belly plates as thin gaps
        t = .45 + i * .08
        j = int(t * (len(spine) - 1))
        (x0, y0), (x1, y1) = spine[j - 1], spine[j + 1]
        tx, ty = x1 - x0, y1 - y0
        L = math.hypot(tx, ty)
        nx, ny = ty / L, -tx / L
        x, y = spine[j]
        w = 2.6 + i * .5
        body.stroke(bez((x + nx * w * .3, y + ny * w * .3), (x + nx * w + tx, y + ny * w + ty),
                        (x + nx * w + tx, y + ny * w + ty), (x + nx * w * 1.6, y + ny * w * 1.6), 6), .55, .55, cut=True)
    layers.append(body)

    # head, facing left, jaws open
    head = Layer()
    head.poly(path((44, 18), ((42, 14), (36, 13), (30, 15)), ((27, 16), (24, 18), (22, 20)),
                   ((26, 21), (31, 21), (34, 22)), ((30, 24), (26, 26), (24, 27)),
                   ((29, 28), (35, 28), (40, 26)), ((44, 25), (46, 22), (44, 18))))
    head.stroke(path((40, 15), ((42, 9), (46, 5), (52, 3))), 3, .8)   # horns
    head.stroke(path((37, 14), ((37, 9), (39, 6), (43, 4))), 2.2, .6)
    for x, y in ((25, 21.2), (28, 21.4), (31, 21.6)):                  # teeth
        head.poly([(x - .7, y), (x + .7, y), (x, y + 1.6)])
    for x, y in ((26, 26.4), (29, 26.6)):
        head.poly([(x - .7, y), (x + .7, y), (x, y - 1.5)])
    head.poly([(44, 20), (49, 17), (47, 22)])                          # cheek frill
    head.poly([(43, 24), (48, 25), (44, 27)])
    head.ell(35.5, 17.6, .9, head.c)                                    # eye
    head.stroke(bez((33, 16), (35, 15.5), (37, 15.6), (39, 16.6), 8), .5, .5, cut=True)  # brow
    layers.append(head)

    # forelegs, raised
    arms = Layer()
    for (a, b, c) in (((50, 46), (42, 50), (36, 46)), ((52, 54), (44, 58), (38, 56))):
        arms.stroke(path(a, (b, b, c)), 4.6, 3)
        for k in range(3):
            ang = math.radians(150 + k * 30)
            arms.stroke(bez(c, (c[0] + 2 * math.cos(ang), c[1] + 2 * math.sin(ang) - .5),
                            (c[0] + 3 * math.cos(ang), c[1] + 3 * math.sin(ang) + .5),
                            (c[0] + 3.4 * math.cos(ang + .4), c[1] + 3.4 * math.sin(ang + .4)), 6), 1.5, .4)
    layers.append(arms)

    # near hind leg
    leg = Layer()
    leg.stroke(path((58, 64), ((54, 70), (50, 74), (48, 80)), ((47, 84), (50, 88), (46, 90))), 8, 3.6)
    leg.stroke(path((58, 62), ((62, 64), (60, 70), (56, 72))), 9, 6)
    for dx in (0, 2.4, 4.8):
        leg.stroke(bez((46 - dx * .2, 90), (44 - dx, 90.5), (43 - dx, 92), (44 - dx, 94), 6), 1.6, .5)
    layers.append(leg)

    # fire, gold
    fire = Layer()
    fl = path((23, 24), ((16, 24), (10, 28), (6, 34)), ((9, 32), (12, 32), (13, 33)), ((9, 36), (6, 40), (4, 46)),
              ((9, 42), (13, 40), (15, 40)), ((14, 36), (18, 30), (23, 26)))
    fire.poly(fl)
    fire.ell(4, 28, 1.4)
    fire.ell(8, 46.5, 1.1)

    # compose back to front, each layer cutting a thin gap into what lies behind it
    acc = np.zeros((N, N))
    for L in layers:
        m = L.mask()
        gap = binary_dilation(m > .5, iterations=9)
        acc = acc * (1 - gap) + m
    return np.clip(acc, 0, 1), fire.mask()


def crown(w=300, h=150):
    img = Image.new('L', (w * 2, h * 2), 0)
    d = ImageDraw.Draw(img)
    pts = [(20, 280), (20, 150), (75, 210), (110, 70), (165, 180), (300, 20), (435, 180), (490, 70), (525, 210),
           (580, 150), (580, 280)]
    d.polygon(pts, fill=255)
    for x, y in ((110, 62), (300, 12), (490, 62)):
        d.ellipse([x - 22, y - 22, x + 22, y + 22], fill=255)
    m = np.asarray(img.resize((w, h), Image.LANCZOS), float) / 255
    col = relief(m, GOLD, 2.5, 30, .6, 16)
    gems = np.zeros((h, w))
    for x in (75, 150, 225):
        yy, xx = np.mgrid[0:h, 0:w]
        gems += (np.hypot(xx - x, yy - 118) < 11)
    gem = relief(gems, np.array([150, 20, 24.]), 2, 25, .8, 30)
    col = col * (1 - gems[..., None]) + gem * gems[..., None]
    return Image.fromarray(np.dstack([col, m * 255]).astype(np.uint8), 'RGBA')


def scroll(text, w=640, h=150):
    """the motto ribbon: parchment band bowing upwards, with folded tails"""
    S = 2
    img = Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    par, dark, edge = (233, 220, 190), (180, 160, 120), (90, 70, 45)

    def bow(x):
        return 28 * S * math.sin(math.pi * x / (w * S))

    band = 66 * S
    top0 = 40 * S
    for side in (-1, 1):  # tails behind
        x0 = 0 if side == -1 else w * S
        xin = 90 * S if side == -1 else w * S - 90 * S
        ty = top0 + 30 * S
        tail = [(xin, ty), (x0 + side * -0 , ty + 10 * S), (x0 + side * -40 * S * -1 if False else x0, ty + 10 * S)]
        d.polygon([(xin, ty), (x0, ty + 8 * S), (x0 + (60 * S if side == -1 else -60 * S), ty + band / 2 + 8 * S),
                   (x0, ty + band + 8 * S), (xin, ty + band)], fill=dark, outline=edge, width=3 * S)
    pts_top = [(x, top0 - bow(x)) for x in range(60 * S, w * S - 60 * S + 1, 8)]
    pts_bot = [(x, top0 + band - bow(x)) for x in range(w * S - 60 * S, 60 * S - 1, -8)]
    d.polygon(pts_top + pts_bot, fill=par, outline=edge, width=3 * S)
    size = 34
    while True:
        f = ImageFont.truetype(FONT + 'fellsc-400.ttf', size * S)
        total = d.textlength(text, font=f)
        if total <= w * S - 190 * S or size <= 20:
            break
        size -= 1
    x = (w * S - total) / 2
    for ch in text:
        cw = d.textlength(ch, font=f)
        cx = x + cw / 2
        y = top0 + band / 2 - bow(cx)
        slope = math.degrees(math.atan(28 * S * math.pi / (w * S) * math.cos(math.pi * cx / (w * S))))
        g = Image.new('RGBA', (int(cw) + 20 * S, 60 * S), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((g.width / 2, g.height / 2), ch, font=f, fill=(70, 40, 24), anchor='mm')
        g = g.rotate(slope, resample=Image.BICUBIC)
        img.alpha_composite(g, (int(cx - g.width / 2), int(y - g.height / 2)))
        x += cw
    return img.resize((w, h), Image.LANCZOS)


def metal(mask, base, R=9.0, spec=.75, shine=28, env=True):
    """sculpted metal: each separate part swells like a cast relief (height from distance to its edge)"""
    d = distance_transform_edt(mask > .5)
    h = np.sqrt(np.minimum(d, R) / R) * R * 1.4
    h = gaussian_filter(h, 1.0)
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-.5, -.7, .75]); L /= np.linalg.norm(L)
    dif = np.clip((n * L).sum(2), 0, 1)
    H = L + np.array([0, 0, 1.]); H /= np.linalg.norm(H)
    sp = np.clip((n * H).sum(2), 0, 1) ** shine
    # environment: polished metal mirrors a bright sky above and a dark floor below
    envv = np.clip(.5 - n[..., 1] * .9, 0, 1) if env else 0
    col = base[None, None, :] * (.28 + .62 * dif[..., None] + .25 * envv[..., None])
    col += 255 * spec * sp[..., None]
    # ambient occlusion in the crevices
    ao = np.clip(gaussian_filter(mask, 4), 0, 1)
    col *= (.75 + .25 * ao)[..., None]
    return np.clip(col, 0, 255)


LAST = {}


def crest(tint, charge, fire, motto, name, sub, crown_img=None, parts=False):
    sm = shield_mask()
    rim = sm - binary_erosion(sm > .5, iterations=22).astype(float)
    inner = sm - rim
    yy, xx = np.mgrid[0:H, 0:W]
    light = 1.18 - 0.5 * np.clip(np.hypot(xx - W * .3, yy - H * .22) / (W * .95), 0, 1)
    lattice = ((((xx + yy) % 46) < 2) | (((xx - yy) % 46) < 2)).astype(float)
    grain = gaussian_filter(np.random.default_rng(3).normal(0, 1, (H, W)), 1.2) * 4
    field = np.array(tint, float)[None, None, :] * (light - .07 * lattice)[..., None] + grain[..., None]
    box = 460
    ox, oy = (W - box) // 2, 52

    def place(m):
        m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((box, box), Image.LANCZOS), float) / 255
        big = np.zeros((H, W))
        big[oy:oy + box, ox:ox + box] = m
        return big * inner

    ch, fi = place(charge), place(fire)
    ch = ch * (1 - np.clip(gaussian_filter(fi, 2) * 3, 0, 1))
    allc = np.clip(ch + fi, 0, 1)
    LAST['allc'] = allc
    shadow = np.roll(np.roll(gaussian_filter(allc, 5), 8, 0), 6, 1)
    out = field * (1 - .5 * shadow[..., None])
    sil = metal(ch, SILVER, 9, .55, 30)
    gol = metal(fi, GOLD * 1.05, 7, .8, 20)
    out = out * (1 - allc[..., None]) + sil * ch[..., None] + gol * fi[..., None]
    edge = np.clip(gaussian_filter(allc, 1.2) * 2.2, 0, 1) * (1 - allc)
    out = out * (1 - edge[..., None]) + (np.array(tint) * .3)[None, None, :] * edge[..., None]
    rim_col = relief(binary_erosion(sm > .5, iterations=2).astype(float) * rim, GOLD, 4, 60, .6, 18)
    inline = np.clip(gaussian_filter(rim, 1.5) - rim, 0, 1) * inner
    out = out * inner[..., None] * (1 - inline[..., None] * .8) + rim_col * rim[..., None]
    shield = Image.fromarray(np.dstack([np.clip(out, 0, 255), sm * 255]).astype(np.uint8), 'RGBA')

    paper = (246, 241, 230)
    CW, CH = 760, 1040
    img = Image.new('RGBA', (CW, CH), (*paper, 255))
    sx, sy = (CW - W) // 2, 150
    shade = Image.fromarray((gaussian_filter(sm, 10) * 110).astype(np.uint8))
    img.paste((60, 45, 30, 255), (sx + 8, sy + 12), shade)
    img.alpha_composite(shield, (sx, sy))
    cr = crown_img if crown_img is not None else crown()
    if parts:
        return shield, cr, scroll(motto), (sx, sy), allc
    img.alpha_composite(cr, ((CW - cr.width) // 2, sy - cr.height + 22))
    sc = scroll(motto)
    img.alpha_composite(sc, ((CW - sc.width) // 2, sy + H - 70))
    d = ImageDraw.Draw(img)
    d.text((CW / 2, sy + H + 112), name, font=ImageFont.truetype(FONT + 'fell-400.ttf', 56), fill=(40, 33, 26),
           anchor='mt')
    d.text((CW / 2, sy + H + 182), sub, font=ImageFont.truetype(FONT + 'sans-500.ttf', 26), fill=(110, 98, 84),
           anchor='mt')
    return img.convert('RGB')


if __name__ == '__main__':
    ch, fi = dragon()
    Image.fromarray((ch * 255).astype(np.uint8)).save('/home/claude/out/shields/dragon-mask.png')
    crest((142, 27, 22), ch, fi, 'PASO A PASO, HASTA EL ORO', 'Valdoro', 'Español · Naga barat').save(
        '/home/claude/out/shields/valdoro-mock-3.png')
