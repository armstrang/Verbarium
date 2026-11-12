"""Valdoro's dragon, rampant and breathing fire: everything built from thorns (tapering curved strokes)."""
import math
import numpy as np
from scipy.ndimage import binary_dilation
from relief import Layer, bez, path


PARTS = None


def thorns(layer, curve, away, every, h, w, start=0.0, end=1.0, grow=1.0, rake=.9):
    n = len(curve)
    i0, i1 = int(start * (n - 1)), int(end * (n - 1))
    for k, i in enumerate(range(max(1, i0 + every // 2), min(i1, n - 2), every)):
        (x0, y0), (x1, y1) = curve[i - 1], curve[i + 1]
        tx, ty = x1 - x0, y1 - y0
        L = math.hypot(tx, ty) or 1
        tx, ty = tx / L, ty / L
        x, y = curve[i]
        nx, ny = -ty, tx
        if (x + nx - away[0]) ** 2 + (y + ny - away[1]) ** 2 < (x - nx - away[0]) ** 2 + (y - ny - away[1]) ** 2:
            nx, ny = -nx, -ny
        f = i1 - i0
        hh = h * (1 + (grow - 1) * (i - i0) / max(1, f))
        tip = (x + nx * hh + tx * hh * rake, y + ny * hh + ty * hh * rake)
        layer.stroke(bez((x - tx * w * .4, y - ty * w * .4), (x + nx * hh * .45, y + ny * hh * .45),
                         (tip[0] - tx * hh * .2, tip[1] - ty * hh * .2), tip, 12), w * 2, .2)


def thorn(layer, pts, w):
    layer.stroke(pts, w, .25)


def wing(sign):
    """sign 1: right wing, -1: left wing (mirror around x=52)"""
    m = lambda p: (52 + sign * (p[0] - 52), p[1])
    L = Layer()
    arm0 = path((57, 40), ((63, 34), (70, 26), (75, 18)), ((78, 12), (81, 7), (85, 4)))
    arm = [m(p) for p in arm0]
    L.stroke(arm, 4.2, 2.2)
    thorn(L, [m(p) for p in bez((84.5, 4.2), (86, 1.5), (89, .8), (92, 1.5), 10)], 2.2)        # wrist hook
    thorn(L, [m(p) for p in bez((75, 18), (73, 14), (72, 10), (70, 7), 10)], 2.2)           # thumb claw
    tips = [(99, 18), (97, 34), (90, 46), (78, 52)]
    root = (62, 52)
    edge, prev = [], (85, 4)
    for t in tips:
        # deep scallop: control points pulled towards the wrist
        c = ((prev[0] + t[0]) / 2 - 6, (prev[1] + t[1]) / 2 - 3)
        edge += bez(prev, c, c, t, 18)
        prev = t
    c = ((prev[0] + root[0]) / 2, (prev[1] + root[1]) / 2 - 6)
    edge += bez(prev, c, c, root, 18)
    L.poly([m(p) for p in [(57, 40)] + arm0 + edge])
    # finger bones as fine gaps fanning from the wrist
    for t in tips:
        a = (84, 6)
        L.stroke([m(p) for p in bez(a, (a[0] + 2, (a[1] + t[1]) / 2), (t[0] - 1, t[1] - 8), t, 14)], 1.0, .4,
                 cut=True)
    return L


def dragon():
    layers = [wing(1), wing(-1)]

    tail = Layer()
    tc = path((56, 64), ((68, 72), (76, 84), (68, 93)), ((60, 100), (42, 99), (36, 90)),
              ((32, 83), (38, 77), (45, 80)))
    tail.stroke(tc, 9.5, 1.2)
    thorns(tail, tc, (54, 82), 8, 7.5, 1.3, .06, .8, grow=.35)
    thorn(tail, bez((45, 80), (48, 80), (50, 82), (51, 85), 10), 1.6)
    tail.scales(2.2, w=5)
    layers.append(tail)

    far = Layer()  # far hind leg
    far.stroke(path((60, 62), ((66, 68), (70, 74), (68, 80)), ((67, 84), (70, 87), (74, 88))), 6, 3.4)
    for k in range(3):
        thorn(far, bez((73, 88), (75 + k, 88 + k), (77 + k * 1.2, 90 + k), (77 + k * 1.6, 93 + k * .4), 8), 1.6)
    layers.append(far)

    body = Layer()
    spine = path((47, 18), ((56, 18), (60, 26), (56, 34)), ((52, 42), (54, 54), (58, 62)))
    body.stroke(spine, 4.6, 12)
    body.stroke(path((57, 58), ((59, 62), (60, 66), (58, 69))), 12.5, 10)
    thorns(body, spine, (40, 40), 7, 6.5, 1.5, .05, .75, grow=1.45)     # dorsal thorns on the outer side
    for i in range(7):  # belly plates
        t = .38 + i * .075
        j = int(t * (len(spine) - 1))
        (x0, y0), (x1, y1) = spine[j - 1], spine[j + 1]
        tx, ty = x1 - x0, y1 - y0
        Ln = math.hypot(tx, ty)
        nx, ny = -ty / Ln, tx / Ln
        if nx > 0:
            nx, ny = -nx, -ny
        x, y = spine[j]
        w = 2.4 + i * .55
        body.stroke(bez((x + nx * w * .2, y + ny * w * .2), (x + nx * w * .7 - tx * .3, y + ny * w * .7 - ty * .3),
                        (x + nx * w - tx * .3, y + ny * w - ty * .3), (x + nx * w * 1.5, y + ny * w * 1.5), 6),
                    .6, .4, cut=True)
    body.scales(2.4, w=5)
    layers.append(body)

    head = Layer()
    # a long, narrow wedge of a head, snout to the left, jaws apart
    head.poly(path((49, 15), ((46, 11), (40, 11), (35, 13)), ((31, 14), (27, 15), (24, 17.5)),
                   ((28, 18.5), (33, 18.8), (37, 19.5)), ((33, 21), (29, 23), (26, 25)),
                   ((31, 25), (37, 24.5), (42, 23)), ((47, 22), (50, 19), (49, 15))))
    thorn(head, path((45, 12.5), ((48, 7), (54, 4), (60, 4))), 3)          # horns sweeping back
    thorn(head, path((41, 12), ((43, 7), (46, 4), (51, 2))), 2.2)
    thorn(head, path((47, 20), ((51, 21), (54, 21), (57, 19))), 2.2)       # jaw frills
    thorn(head, path((45, 22.5), ((48, 24.5), (51, 25), (54, 24))), 1.8)
    thorn(head, path((31, 14.2), ((32, 12), (33, 11), (35, 10.5))), 1.4)    # nose horn
    for x in (26.5, 29, 31.5, 34):
        head.poly([(x - .6, 18.6), (x + .6, 18.8), (x + .1, 20.4)])
    for x in (28, 30.5, 33):
        head.poly([(x - .6, 23.6), (x + .6, 23.4), (x, 22)])
    import PIL.ImageDraw as _D; head.c.polygon(head.k([(36.5, 16.2), (41.5, 14.2), (40.5, 16.4)]), fill=255); head.stroke(bez((35, 14.6), (38, 13.6), (41, 12.8), (44, 12.4), 8), .9, .3, cut=True)
    head.stroke(bez((26, 16.6), (27, 16.3), (28, 16.4), (28.5, 16.8), 5), .5, .3, cut=True)       # nostril
    layers.append(head)

    arms = Layer()
    for a, b, c in (((52, 44), (44, 46), (38, 42)), ((53, 52), (45, 56), (39, 54))):
        arms.stroke(path(a, (b, b, c)), 3.6, 2.2)
        for k in range(3):
            ang = math.radians(170 + k * 28)
            e = (c[0] + 3.6 * math.cos(ang), c[1] + 3.6 * math.sin(ang))
            thorn(arms, bez(c, (c[0] + 2 * math.cos(ang - .3), c[1] + 2 * math.sin(ang - .3)), e,
                            (e[0] + .8 * math.cos(ang + 1.4), e[1] + .8 * math.sin(ang + 1.4)), 8), 1.6)
    layers.append(arms)

    leg = Layer()
    leg.stroke(path((57, 62), ((61, 64), (60, 70), (55, 73))), 11, 7)
    leg.stroke(path((55, 72), ((51, 76), (48, 80), (48, 85)), ((48, 88), (46, 90), (43, 91))), 6.5, 3.4)
    for k in range(3):
        thorn(leg, bez((43, 91), (41 - k, 91 + k * .6), (39.5 - k * 1.2, 92 + k), (39.5 - k * 1.5, 95 + k * .3), 8),
              1.7)
    thorn(leg, bez((49, 83), (52, 83), (54, 84), (55, 87), 8), 1.6)          # spur
    leg.scales(2.0, w=5)
    layers.append(leg)

    fire = Layer()
    for (a, b, c, d), w in ((((24, 21), (16, 20), (10, 24), (3, 22)), 7), (((24, 22), (17, 25), (12, 30), (5, 32)), 4),
                            (((24, 23), (19, 28), (16, 34), (10, 40)), 5.5), (((22, 21), (17, 18), (13, 17), (9, 14)), 4)):
        fire.stroke(bez(a, b, c, d, 20), w, .2)
    fire.poly([(24, 20), (14, 21), (14, 30), (24, 24)])

    if PARTS is not None:
        PARTS.extend(layers)
        PARTS.append(fire)
    acc = np.zeros((1000, 1000))
    for L in layers:
        mk = L.mask()
        gap = binary_dilation(mk > .5, iterations=8)
        acc = acc * (1 - gap) + mk
    return np.clip(acc, 0, 1), fire.mask()
