"""Shared pieces of the beasts (compose, gold, claws, locks) and the first drawings, kept for the dragon's wrapper."""
import math

import numpy as np
from scipy.ndimage import binary_dilation

from relief import Layer, bez, path
from dragon import thorns, thorn, dragon as _dragon


CAPTURE = None  # when a list, compose() also hands over the layers it was given (make_crests.py: the moving parts)


def compose(layers):
    """back to front; each layer cuts a thin gap into what lies behind it. Returns (silver, gold)."""
    if CAPTURE is not None:
        CAPTURE.extend(layers)
    s = np.zeros((1000, 1000))
    g = np.zeros((1000, 1000))
    for L in layers:
        m = L.mask()
        gap = binary_dilation(m > .5, iterations=8)
        s *= 1 - gap
        g *= 1 - gap
        if getattr(L, 'gold', False):
            g += m
        else:
            s += m
    return np.clip(s, 0, 1), np.clip(g, 0, 1)


def gold():
    L = Layer()
    L.gold = True
    return L


def claws(layer, at, ang0, n=3, spread=26, length=3.6, w=1.6):
    for k in range(n):
        a = math.radians(ang0 + (k - (n - 1) / 2) * spread)
        e = (at[0] + length * math.cos(a), at[1] + length * math.sin(a))
        thorn(layer, bez(at, (at[0] + length * .5 * math.cos(a - .25), at[1] + length * .5 * math.sin(a - .25)), e,
                         (e[0] + 1.1 * math.cos(a + 1.5), e[1] + 1.1 * math.sin(a + 1.5)), 8), w)


def locks(layer, c, r0, r1, a0, a1, n, w, curl=.5):
    """flame-like locks of hair or feathers radiating from c, curling clockwise"""
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / max(1, n - 1))
        p0 = (c[0] + r0 * math.cos(a), c[1] + r0 * math.sin(a))
        p3 = (c[0] + r1 * math.cos(a + curl), c[1] + r1 * math.sin(a + curl))
        mid = (c[0] + (r0 + r1) / 2 * math.cos(a + curl * .2), c[1] + (r0 + r1) / 2 * math.sin(a + curl * .2))
        thorn(layer, bez(p0, mid, mid, p3, 14), w)


# ------------------------------------------------------------------------------------------------ lion
def lion():
    layers = []
    tail = Layer()
    tc = path((62, 62), ((74, 62), (82, 52), (78, 40)), ((75, 32), (80, 24), (86, 22)))
    tail.stroke(tc, 4.2, 2)
    locks(tail, (86, 22), 1, 9, -130, 60, 6, 3, .8)
    tail.fur((86, 22), 1.5, 9, -130, 60, 14, .8, .35)
    layers.append(tail)

    far = Layer()
    far.stroke(path((62, 62), ((68, 70), (72, 78), (68, 86)), ((67, 89), (70, 91), (73, 91))), 7, 4)
    claws(far, (73, 91), 20, 3, 28, 3.4)
    far.stroke(path((50, 48), ((44, 52), (38, 54), (32, 52))), 5.5, 3.6)        # far foreleg
    claws(far, (31, 51.5), 195, 3, 28, 3.4)
    layers.append(far)

    body = Layer()
    body.stroke(path((40, 30), ((44, 36), (48, 42), (52, 50)), ((55, 56), (58, 60), (60, 64))), 18, 11)
    body.ell(46, 38, 9.5)
    body.stroke(path((58, 58), ((61, 62), (62, 66), (60, 69))), 15, 12)
    for i in range(4):  # ribs
        y = 46 + i * 3.4
        body.stroke(bez((53 - i * .2, y), (55, y - .6), (57, y - .4), (58, y + .4), 6), .6, .4, cut=True)
    layers.append(body)

    mane = Layer()
    locks(mane, (40, 25), 6, 21, -110, 190, 17, 6.5, .6)
    mane.ell(40, 25, 11)
    mane.fur((40, 25), 9, 22, -110, 200, 40, .6)
    layers.append(mane)

    head = Layer()
    head.poly(path((44, 17), ((40, 14), (34, 14), (30, 16)), ((27, 17.5), (24, 19), (23, 21.5)),
                   ((25, 23), (28, 23.4), (31, 23.4)), ((28, 25), (27, 27), (28, 29)),
                   ((32, 30), (37, 30), (41, 28)), ((46, 25), (47, 20), (44, 17))))
    thorn(head, path((40, 15), ((41, 11), (43, 9), (46, 8.5))), 3.6)              # ear
    head.ell(23.6, 20.6, 1.3, head.c)                                             # nose
    head.c.polygon(head.k([(31, 18.6), (36, 17), (35, 19.4)]), fill=255)          # eye
    head.stroke(bez((30, 17.2), (33, 15.8), (36, 15.2), (39, 15.2), 8), .9, .3, cut=True)
    head.stroke(bez((27, 23.6), (30, 24.4), (33, 24.6), (36, 24.2), 8), .7, .3, cut=True)  # lip
    for x in (25.5, 28):
        head.poly([(x - .6, 23.2), (x + .6, 23.2), (x, 25.4)])
    layers.append(head)

    tongue = gold()
    thorn(tongue, bez((27, 25), (23, 25.5), (20, 27), (18, 30), 12), 2.2)
    layers.append(tongue)

    arm = Layer()  # the raised foreleg
    arm.stroke(path((46, 38), ((38, 40), (30, 40), (22, 36))), 6.5, 4.2)
    claws(arm, (21, 35), 215, 3, 30, 3.8)
    layers.append(arm)

    leg = Layer()
    leg.stroke(path((58, 62), ((60, 66), (58, 72), (54, 74))), 13, 9)
    leg.stroke(path((54, 73), ((50, 78), (47, 83), (46, 88)), ((45.5, 90), (43, 91.5), (40, 92))), 7, 4)
    claws(leg, (39.5, 92), 180, 3, 26, 3.4)
    layers.append(leg)

    crown = gold()
    crown.poly([(31, 13.5), (31, 7), (34, 10), (36.5, 4), (39, 10), (42, 5), (43.5, 11), (45.5, 8), (45.5, 14.5)])
    for x, y in ((36.5, 3.6), (42, 4.6), (31, 6.6), (45.5, 7.6)):
        crown.ell(x, y, 1)
    layers.append(crown)
    return compose(layers)


# ------------------------------------------------------------------------------------------------ griffin
def feather_wing(sign, root, n=9, a0=-118, a1=-28, l0=34, l1=44, w=5):
    """a raised wing of long feathers fanning from the root; sign mirrors it (1 right, -1 left)"""
    L = Layer()
    rx, ry = root
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(a0 + (a1 - a0) * t)
        ln = l0 + (l1 - l0) * math.sin(t * math.pi)
        e = (rx + ln * math.cos(a), ry + ln * math.sin(a))
        c = (rx + ln * .55 * math.cos(a - .18), ry + ln * .55 * math.sin(a - .18))
        pts = bez((rx, ry), c, c, e, 20)
        if sign < 0:
            pts = [(2 * rx - x, y) for x, y in pts]
        L.stroke(pts, w, .4)
        L.stroke(pts[:int(len(pts) * .7)], .35, .15, cut=True)
    # coverts: a row of short feathers near the root
    for i in range(6):
        t = i / 5
        a = math.radians(a0 + 10 + (a1 - a0 - 20) * t)
        ln = 14
        e = (rx + ln * math.cos(a), ry + ln * math.sin(a))
        pts = bez((rx, ry), (rx + 8 * math.cos(a - .2), ry + 8 * math.sin(a - .2)), e, e, 10)
        if sign < 0:
            pts = [(2 * rx - x, y) for x, y in pts]
        L.stroke(pts, 7, 2)
    return L


def griffin():
    layers = [feather_wing(1, (58, 40), 9, -112, -18, 30, 44, 5.2)]
    tail = Layer()
    tc = path((62, 64), ((76, 66), (84, 58), (82, 46)), ((80, 38), (84, 32), (90, 32)))
    tail.stroke(tc, 4, 2)
    locks(tail, (90, 32), 1, 8, -120, 60, 5, 2.8, .8)
    layers.append(tail)
    far = Layer()
    far.stroke(path((62, 64), ((68, 72), (72, 80), (68, 88)), ((67, 90), (70, 92), (73, 92))), 7, 4)
    claws(far, (73, 92), 20, 3, 28, 3.4)
    layers.append(far)
    body = Layer()
    body.stroke(path((40, 26), ((46, 34), (50, 44), (54, 52)), ((57, 58), (60, 62), (62, 66))), 15, 12)
    body.ell(46, 36, 9)
    body.ell(60, 62, 8)
    layers.append(body)
    neck = Layer()  # feathered breast: overlapping scales of thorns pointing down
    for row in range(5):
        for k in range(3):
            x, y = 38 + row * 2.6 + k * 3.2, 26 + row * 4 + k * 1.2
            thorn(neck, bez((x, y), (x - 1.5, y + 2), (x - 2, y + 4), (x - 1.2, y + 6.5), 8), 3.4)
    layers.append(neck)
    head = Layer()
    head.ell(36, 20, 7.5)
    thorn(head, path((39, 14), ((41, 9), (44, 6), (48, 5))), 3)                 # ear tufts
    thorn(head, path((41, 16), ((45, 12), (48, 10), (52, 10))), 2.4)
    for k in range(4):
        thorn(head, bez((40 + k, 22 + k * 1.4), (44 + k, 23 + k * 1.6), (46 + k, 25 + k * 1.6), (49 + k, 25 + k * 2), 8), 2.4)
    head.c.polygon(head.k([(32, 18.6), (37, 16.8), (36, 19.2)]), fill=255)
    head.stroke(bez((31, 16.8), (34, 15.4), (37, 14.6), (40, 14.6), 8), .9, .3, cut=True)
    layers.append(head)
    beak = gold()
    beak.poly(path((30, 16), ((26, 15), (21, 16), (19, 20)), ((18.5, 22.5), (19.5, 24.5), (21, 25.5)),
                   ((21, 23.5), (22, 22), (24, 21.6)), ((26, 21.8), (28, 22.4), (30, 23.4))))
    beak.poly(path((29, 24), ((26, 24.5), (24, 25), (23, 26)), ((25, 27.5), (28, 27.5), (30, 26.5))))
    layers.append(beak)
    talons = Layer()
    for a, b, c in (((46, 34), (38, 32), (32, 26)), ((50, 44), (42, 46), (36, 42))):
        talons.stroke(path(a, (b, b, c)), 4, 2.8)
        for j in range(4):  # scaled shin
            p = bez(a, b, b, c, 8)[2 + j]
            talons.stroke([(p[0] - .8, p[1] - 1.2), (p[0] + .8, p[1] + 1.2)], .5, .5, cut=True)
    layers.append(talons)
    tg = gold()
    claws(tg, (31.5, 25.5), 225, 4, 24, 4, 1.5)
    claws(tg, (35.5, 41.5), 200, 4, 24, 4, 1.5)
    layers.append(tg)
    leg = Layer()
    leg.stroke(path((60, 62), ((62, 66), (60, 72), (56, 74))), 12, 8)
    leg.stroke(path((56, 73), ((52, 78), (49, 83), (48, 88)), ((47.5, 90), (45, 91.5), (42, 92))), 6.5, 4)
    claws(leg, (41.5, 92), 180, 3, 26, 3.4)
    layers.append(leg)
    near = feather_wing(-1, (44, 40), 7, -150, -100, 22, 30, 4.6)  # tips of the near wing, low on the left
    layers.insert(0, near)
    return compose(layers)


# ------------------------------------------------------------------------------------------------ phoenix
def phoenix():
    layers = []
    for sign in (1, -1):
        L = Layer()
        rx, ry = (56, 40) if sign > 0 else (44, 40)
        for i in range(10):  # primaries: long, curving up and out
            t = i / 9
            a = math.radians(-78 + 82 * t)
            ln = 34 + 12 * math.sin(t * math.pi * .8) - 8 * t
            e = (rx + ln * math.cos(a), ry + ln * math.sin(a) - 2)
            c1 = (rx + ln * .4 * math.cos(a + .25), ry + ln * .4 * math.sin(a + .25))
            c2 = (rx + ln * .8 * math.cos(a - .05), ry + ln * .8 * math.sin(a - .05))
            pts = bez((rx, ry), c1, c2, e, 20)
            if sign < 0:
                pts = [(100 - x, y) for x, y in pts]
            L.stroke(pts, 5, .3)
            L.stroke(pts[:int(len(pts) * .7)], .35, .15, cut=True)
        for i in range(6):
            t = i / 5
            a = math.radians(-70 + 70 * t)
            e = (rx + 18 * math.cos(a), ry + 18 * math.sin(a))
            pts = bez((rx, ry), (rx + 8 * math.cos(a + .2), ry + 8 * math.sin(a + .2)), e, e, 10)
            if sign < 0:
                pts = [(100 - x, y) for x, y in pts]
            L.stroke(pts, 7.5, 2.2)
        layers.append(L)
    flames = gold()
    for k in range(9):
        x = 26 + k * 6
        h = 12 + 10 * math.sin(k / 8 * math.pi)
        thorn(flames, bez((x, 98), (x - 3, 98 - h * .4), (x + 3, 98 - h * .7), (x - 1 + (k % 2) * 2, 98 - h), 12), 5.5)
    flames.poly([(24, 99), (78, 99), (76, 94), (26, 94)])
    layers.append(flames)
    tail = Layer()
    for sgn in (-1, 1):
        for k in range(3):
            dx = sgn * (8 + k * 9)
            pts = path((50, 58), ((50 + dx * .3, 66), (50 + dx * .9, 70 - k * 3), (50 + dx, 62 - k * 4)),
                       ((50 + dx * 1.05, 58 - k * 4), (50 + dx * .85, 56 - k * 4), (50 + dx * .8, 59 - k * 4)))
            tail.stroke(pts, 4.6 - k * .6, .6)
    tail.stroke(bez((50, 58), (49, 68), (51, 76), (50, 84), 20), 4.4, .8)
    layers.append(tail)
    body = Layer()
    body.stroke(path((50, 34), ((52, 42), (52, 52), (50, 60))), 12, 7)
    for row in range(4):
        for k in (-1, 0, 1):
            x, y = 50 + k * 2.6, 40 + row * 4.2
            body.stroke(bez((x, y), (x + .8, y + 1.4), (x, y + 2.6), (x - .6, y + 3), 6), .55, .4, cut=True)
    body.stroke(path((50, 36), ((48, 30), (46, 26), (44, 23))), 6, 4.6)          # neck turning left
    layers.append(body)
    head = Layer()
    head.ell(43, 21, 5)
    for k in range(3):                                                         # crest plumes
        thorn(head, bez((45, 17), (46 + k, 12), (49 + k * 2, 9), (53 + k * 3, 9 + k * 2), 14), 2.6 - k * .4)
    head.c.polygon(head.k([(40, 20.2), (43.6, 19), (43, 21)]), fill=255)
    layers.append(head)
    beak = gold()
    beak.poly(path((39, 19), ((36, 19.5), (34, 21), (33, 23.5)), ((35, 23), (37, 22.6), (39, 23))))
    layers.append(beak)
    return compose(layers)


# ------------------------------------------------------------------------------------------------ eastern dragon
def eastern():
    layers = []
    pearl = gold()
    pearl.ell(84, 16, 6)
    for k in range(7):  # flames around the pearl
        a = math.radians(-90 + k * 52)
        p0 = (84 + 5 * math.cos(a), 16 + 5 * math.sin(a))
        thorn(pearl, bez(p0, (84 + 8 * math.cos(a + .2), 16 + 8 * math.sin(a + .2)),
                         (84 + 10 * math.cos(a + .5), 16 + 10 * math.sin(a + .5)),
                         (84 + 12 * math.cos(a + .75), 16 + 12 * math.sin(a + .75)), 10), 2.6)
    pearl.c.ellipse([(84 - 3) * 10, (16 - 3) * 10, (84 + 1) * 10, (16 + 1) * 10], fill=0)
    layers.append(pearl)

    sp = path((30, 26), ((42, 34), (58, 22), (70, 30)), ((80, 38), (78, 52), (64, 56)),
              ((50, 60), (30, 54), (24, 66)), ((18, 78), (34, 88), (50, 84)), ((62, 81), (72, 86), (78, 94)))
    far = Layer()  # far legs
    for a, b, c in (((56, 26), (60, 18), (66, 16)), ((58, 57), (62, 66), (68, 68))):
        far.stroke(path(a, (b, b, c)), 3.4, 2.4)
        claws(far, c, -10 if c[1] < 20 else 10, 3, 30, 3)
    layers.append(far)
    body = Layer()
    body.stroke(sp, 10.5, 1.4)
    thorns(body, sp, (50, 48), 9, 6.5, 1.5, .03, .85, grow=.45)              # dorsal fins, on the outside
    n = len(sp)
    for i in range(6, n - 12, 5):                                            # belly scales
        (x0, y0), (x1, y1) = sp[i - 1], sp[i + 1]
        tx, ty = x1 - x0, y1 - y0
        Ln = math.hypot(tx, ty)
        x, y = sp[i]
        w = 3.2 * (1 - i / n)
        body.stroke([(x - ty / Ln * w * .7 - tx / Ln, y + tx / Ln * w * .7 - ty / Ln),
                     (x + tx / Ln * .6, y + ty / Ln * .6),
                     (x + ty / Ln * w * .7 - tx / Ln, y - tx / Ln * w * .7 - ty / Ln)], .5, .5, cut=True)
    body.scales(2.3, w=5)
    layers.append(body)
    head = Layer()
    head.poly(path((34, 22), ((32, 17), (26, 14), (20, 15)), ((16, 15.5), (12, 17), (9, 19)),
                   ((12, 21), (16, 21.5), (19, 21.5)), ((16, 23), (13, 25), (11, 27)),
                   ((16, 28), (24, 29), (30, 28)), ((34, 27), (36, 25), (34, 22))))
    for p in ((path((26, 15), ((26, 9), (30, 5), (36, 3)))), path((22, 15), ((21, 10), (23, 6), (27, 3)))):
        head.stroke(p, 2.4, 1.2)                                             # antlers
    thorn(head, bez((31.5, 9), (34, 8.6), (35, 10), (36, 11.5), 8), 1.6)
    thorn(head, bez((24, 9.5), (26, 8.6), (27.5, 9.6), (28.5, 11), 8), 1.4)
    thorn(head, bez((10, 19), (6, 18), (3, 14), (5, 9), 20), 1.6)          # whiskers
    thorn(head, bez((12, 26), (7, 28), (3, 34), (6, 40), 20), 1.6)
    locks(head, (33, 24), 3, 13, -40, 120, 8, 3.6, .7)                         # mane
    head.c.polygon(head.k([(19, 17.6), (24, 16), (23, 18.4)]), fill=255)
    head.stroke(bez((18, 16), (21, 14.6), (24, 14), (27, 14), 8), .8, .3, cut=True)
    for x in (12, 14.5, 17):
        head.poly([(x - .5, 21.2), (x + .5, 21.2), (x, 23)])
    layers.append(head)
    near = Layer()
    for a, b, c in (((40, 33), (38, 40), (32, 43)), ((32, 58), (28, 64), (22, 64)), ((52, 84), (52, 91), (46, 94))):
        near.stroke(path(a, (b, b, c)), 3.6, 2.6)
        claws(near, c, 180 + (10 if c[1] > 60 else 0), 3, 30, 3)
    layers.append(near)
    return compose(layers)


def dragon():
    s, g = _dragon()
    g = g * (1 - binary_dilation(s > .5, iterations=0)) if False else g
    return s, g
