"""Alvamar's eastern dragon: a scaled serpent with a mane down its back, chasing its pearl."""
import math
from relief import Layer, bez, path
from dragon import thorn, thorns
from beasts import compose, gold, claws
from mane import lock


def eastern():
    layers = []
    pearl = gold()
    pc = (82, 14)
    pearl.ell(*pc, 5.5)
    for k in range(8):
        a = math.radians(-90 + k * 45)
        p0 = (pc[0] + 4.5 * math.cos(a), pc[1] + 4.5 * math.sin(a))
        thorn(pearl, bez(p0, (pc[0] + 8 * math.cos(a + .25), pc[1] + 8 * math.sin(a + .25)),
                         (pc[0] + 10 * math.cos(a + .55), pc[1] + 10 * math.sin(a + .55)),
                         (pc[0] + 12.5 * math.cos(a + .8), pc[1] + 12.5 * math.sin(a + .8)), 12), 3)
    pearl.stroke(bez((79, 12), (80.5, 10.5), (83, 10), (85, 11), 8), .7, .3, cut=True)
    layers.append(pearl)

    sp = path((34, 30), ((46, 38), (60, 24), (72, 32)), ((82, 40), (80, 54), (66, 58)),
              ((52, 62), (30, 56), (24, 68)), ((18, 80), (34, 90), (50, 86)), ((60, 83), (68, 86), (74, 92)))
    far = Layer()
    for a, b, c in (((60, 27), (63, 20), (69, 19)), ((60, 59), (64, 67), (70, 69))):
        far.stroke(path(a, (b, b, c)), 3.8, 2.6)
        for k in range(3):
            lock(far, b, (b[0] + 4 + k, b[1] + 3 - k * 2), .2, 1.8)
    layers.append(far)
    fg = gold()
    claws(fg, (69.5, 19), -15, 4, 24, 3.2, 1.4)
    claws(fg, (70.5, 69), 10, 4, 24, 3.2, 1.4)
    layers.append(fg)

    body = Layer()
    body.stroke(sp, 11.5, 2)
    # flowing tufts of mane along the back instead of fins
    n = len(sp)
    for i in range(4, int(n * .9), 4):
        (x0, y0), (x1, y1) = sp[i - 1], sp[i + 1]
        tx, ty = x1 - x0, y1 - y0
        Ln = math.hypot(tx, ty)
        tx, ty = tx / Ln, ty / Ln
        nx, ny = -ty, tx
        x, y = sp[i]
        if (x + nx - 50) ** 2 + (y + ny - 50) ** 2 < (x - nx - 50) ** 2 + (y - ny - 50) ** 2:
            nx, ny = -nx, -ny
        h = 9 * (1 - i / n) + 3
        for j in (-1, 1):
            lock(body, (x, y), (x + nx * h - tx * h * .8 + j * tx, y + ny * h - ty * h * .8 + j * ty), .25, 3.4 * (1 - i / n) + 1.2)
    body.scales(2.2, w=5)
    # belly plates: a band on the inner side cut into segments
    for i in range(3, int(n * .95), 3):
        (x0, y0), (x1, y1) = sp[i - 1], sp[i + 1]
        tx, ty = x1 - x0, y1 - y0
        Ln = math.hypot(tx, ty)
        tx, ty = tx / Ln, ty / Ln
        nx, ny = -ty, tx
        x, y = sp[i]
        if (x + nx - 50) ** 2 + (y + ny - 50) ** 2 > (x - nx - 50) ** 2 + (y - ny - 50) ** 2:
            nx, ny = -nx, -ny
        w = 5.4 * (1 - i / n) + 1
        body.stroke([(x + nx * w * .2, y + ny * w * .2), (x + nx * w, y + ny * w)], .5, .5, cut=True)
    for k in range(5):                                     # tail tuft
        a = math.radians(10 + k * 22)
        lock(body, (74, 92), (74 + 9 * math.cos(a - .9), 92 + 9 * math.sin(a - .9)), .25, 3.2)
    layers.append(body)

    mane = Layer()
    c = (36, 26)
    for k in range(8):
        a = math.radians(-60 + k * 20)
        lock(mane, (c[0] + 2 * math.cos(a), c[1] + 2 * math.sin(a)),
             (c[0] + 15 * math.cos(a + .2), c[1] + 15 * math.sin(a + .2)), .2, 4.5)
    mane.fur(c, 4, 15, -60, 80, 9, .2, .45)
    layers.append(mane)

    head = Layer()
    head.poly(path((37, 24), ((35, 19), (29, 16), (22, 17)), ((18, 17.5), (14, 18), (10, 19.5)),
                   ((9, 21), (10, 22.5), (13, 22.5)), ((16, 22.6), (19, 23), (21, 23.6)),
                   ((17, 25), (13.5, 26.5), (11, 28.5)), ((15, 30), (22, 30.5), (28, 30)),
                   ((34, 29.5), (38, 28), (37, 24))))
    for base, pts in (((27, 17), ((27, 11), (31, 6), (37, 3))), ((22, 17.4), ((21, 12), (23, 7), (27, 4)))):
        head.stroke(path(base, pts), 2.6, 1.2)
    thorn(head, bez((32, 8.8), (35, 8.4), (36.5, 10), (37.5, 12), 8), 1.6)
    thorn(head, bez((24.5, 10), (27, 9), (28.5, 10), (29.5, 12), 8), 1.4)
    head.ell(11.5, 20.2, .9, head.c)
    head.c.polygon(head.k([(20, 19.6), (25, 18), (24, 20.4)]), fill=255)
    head.stroke(bez((19, 18), (22, 16.6), (25, 16), (28, 16.2), 8), .9, .3, cut=True)
    for x in (13, 15.5, 18):
        head.poly([(x - .5, 22.6), (x + .5, 22.7), (x, 24.4)])
    thorn(head, bez((28, 29), (31, 32), (34, 33), (37, 33), 10), 2.4)            # beard
    thorn(head, bez((25, 30), (27, 33), (29, 35), (32, 36), 10), 2.2)
    layers.append(head)
    wh = gold()                                                                 # whiskers
    thorn(wh, bez((10.5, 20), (5, 18), (2, 13), (6, 8), 24), 1.5)
    thorn(wh, bez((11, 27.5), (6, 30), (2, 36), (6, 42), 24), 1.5)
    layers.append(wh)

    near = Layer()
    for a, b, c in (((42, 35), (40, 42), (34, 45)), ((32, 58), (28, 65), (22, 66)), ((52, 86), (52, 92), (46, 95))):
        near.stroke(path(a, (b, b, c)), 4, 2.8)
        for k in range(3):
            lock(near, b, (b[0] + 4 + k, b[1] - 1 + k * 1.5), .2, 1.8)
    layers.append(near)
    ng = gold()
    for c in ((33.5, 45), (21.5, 66), (45.5, 95)):
        claws(ng, c, 185, 4, 24, 3.2, 1.4)
    layers.append(ng)
    return compose(layers)
