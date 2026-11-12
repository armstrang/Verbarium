"""A lock of mane (an S-shaped tapering stroke) and the second lion, kept for its lock."""
import math
from relief import Layer, bez, path
from dragon import thorn
from beasts import compose, gold, claws


def lock(L, p0, p3, bend, w):
    """one S-shaped lock of the mane, thick at the root, sharp at the tip"""
    mx, my = (p0[0] + p3[0]) / 2, (p0[1] + p3[1]) / 2
    dx, dy = p3[0] - p0[0], p3[1] - p0[1]
    nx, ny = -dy, dx
    c1 = (p0[0] + dx * .3 + nx * bend, p0[1] + dy * .3 + ny * bend)
    c2 = (p0[0] + dx * .75 - nx * bend * .8, p0[1] + dy * .75 - ny * bend * .8)
    L.stroke(bez(p0, c1, c2, p3, 24), w, .25)


def lion():
    layers = []
    tail = Layer()
    tc = path((64, 60), ((74, 62), (84, 54), (80, 42)), ((77, 33), (81, 25), (88, 24)))
    tail.stroke(tc, 4, 2.2)
    for k in range(6):
        a = math.radians(-140 + k * 34)
        lock(tail, (88, 24), (88 + 9 * math.cos(a), 24 + 9 * math.sin(a)), .25, 3.2)
    tail.fur((88, 24), 1, 9, -140, 40, 10, .3, .3)
    layers.append(tail)

    far = Layer()
    far.stroke(path((64, 62), ((70, 68), (73, 76), (71, 84)), ((70, 88), (73, 90), (77, 90))), 8, 4.2)
    claws(far, (77, 90), 15, 4, 22, 3.2, 1.5)
    far.stroke(path((48, 46), ((43, 50), (37, 51), (31, 49))), 5.5, 4)
    claws(far, (30, 48.5), 195, 4, 24, 3.4, 1.5)
    layers.append(far)

    body = Layer()
    body.ell(45, 38, 9.5)
    body.stroke(path((45, 38), ((49, 46), (52, 52), (56, 58))), 15, 10)
    body.oval(58, 61, 8, 8)
    for i in range(4):
        y = 44 + i * 3
        body.stroke(bez((50 + i * .8, y), (52 + i * .8, y - .8), (54 + i * .8, y - .4), (55.5 + i * .8, y + .6), 6), .5, .3, cut=True)
    layers.append(body)

    mane = Layer()
    mane.oval(39, 25, 13, 15)
    c = (38, 24)
    for k in range(15):                              # outer locks
        a = math.radians(-115 + k * 19)
        r1 = 23 + 3 * math.sin(k * 1.7)
        lock(mane, (c[0] + 6 * math.cos(a), c[1] + 6 * math.sin(a)),
             (c[0] + r1 * math.cos(a + .35), c[1] + r1 * math.sin(a + .35)), .22, 11)
    mane.fur(c, 10, 21, -115, 175, 15, .45, .6)
    layers.append(mane)

    inner = Layer()                                  # a second ring of locks over the first
    for k in range(9):
        a = math.radians(-70 + k * 22)
        lock(inner, (c[0] + 4 * math.cos(a), c[1] + 4 * math.sin(a)),
             (c[0] + 14 * math.cos(a + .4), c[1] + 14 * math.sin(a + .4)), .2, 7.5)
    inner.fur(c, 7, 14, -70, 110, 9, .4, .5)
    layers.append(inner)

    head = Layer()
    head.k = (lambda f: (lambda pts: f([(30 + (x - 30) * .85, 22 + (y - 22) * .85) for x, y in pts])))(head.k)
    head.poly(path((36, 13), ((33, 12.5), (29, 13), (26, 15)), ((24, 16), (21, 17), (19.5, 19.5)),
                   ((20, 21), (21, 22), (22.5, 22.4)), ((24.5, 22.6), (26.5, 22.8), (28, 23.4)),
                   ((26, 24.5), (23.5, 25.5), (22.5, 27)), ((24, 29.5), (28, 30), (31.5, 29.5)),
                   ((36, 28.5), (38, 25), (38, 21)), ((38, 17), (38, 14), (36, 13))))
    head.ell(20.6, 19.4, 1.2, head.c)                                            # nose
    head.c.polygon(head.k([(27, 17.4), (31.8, 16), (30.8, 18.2)]), fill=255)     # eye
    head.stroke(bez((25.5, 15.6), (28.5, 14.2), (31.5, 13.6), (34.5, 14), 8), .9, .3, cut=True)  # brow
    head.stroke(bez((22, 18), (23, 19.5), (23.2, 21), (22.6, 22.2), 6), .45, .3, cut=True)       # muzzle
    head.stroke(bez((28.4, 23.4), (30, 22), (32, 21.5), (34, 22.5), 8), .5, .3, cut=True)         # cheek
    for x in (22.5, 25):
        head.poly([(x - .55, 22.4), (x + .55, 22.5), (x, 24.4)])
    head.poly([(23.4, 26.6), (24.4, 26.4), (24, 25)])
    layers.append(head)

    tongue = gold()
    thorn(tongue, bez((25, 24.4), (21, 24.6), (18, 26), (16, 29.5), 14), 2.4)
    layers.append(tongue)

    arm = Layer()
    arm.stroke(path((44, 36), ((39, 37), (33, 37), (28, 35))), 7.5, 5)
    arm.stroke(path((28, 35), ((25, 35.5), (21, 36.5), (18, 38))), 5, 4)
    layers.append(arm)
    ac = gold()
    claws(ac, (17, 37.5), 200, 4, 24, 3.6, 1.5)
    layers.append(ac)

    leg = Layer()
    leg.stroke(path((59, 62), ((59, 68), (57, 72), (54, 75))), 13, 8)
    leg.stroke(path((54, 74), ((51, 79), (49, 83), (48, 87)), ((47.5, 89), (45, 90.5), (41, 91))), 7, 4.4)
    leg.stroke(bez((58, 66), (57, 69), (55.5, 71.5), (53.5, 73.5), 8), .5, .3, cut=True)
    layers.append(leg)
    lc = gold()
    claws(lc, (40.5, 91), 180, 4, 22, 3.2, 1.5)
    claws(lc, (77.5, 90), 15, 0, 22, 3.2, 1.5)
    layers.append(lc)

    crown = gold()
    crown.poly([(25, 15), (24.5, 9.5), (27.5, 12), (29.5, 6), (32, 11.5), (35, 6.5), (36.5, 12.5), (39, 10), (39, 15.5)])
    for x, y in ((29.5, 5.5), (35, 6), (24.5, 9), (39, 9.5)):
        crown.ell(x, y, 1)
    layers.append(crown)
    return compose(layers)
