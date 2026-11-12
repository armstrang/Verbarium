"""Grauwacht's griffin, striding (passant), wings raised."""
import math
from relief import Layer, bez, path
from dragon import thorn
from beasts import compose, gold, claws
from mane import lock
from wings import eagle_wing
from lion import sweep


def griffin():
    layers = []
    layers.append(eagle_wing(path((40, 38), ((44, 24), (50, 12), (58, 4))), -50, -5, 12, 22, 10, 4.8))   # far wing
    tail = Layer()
    tc = path((78, 54), ((88, 56), (94, 48), (92, 38)), ((91, 32), (86, 30), (86, 25)))
    tail.stroke(tc, 4, 2.2)
    for k in range(5):
        a = math.radians(-150 + k * 30)
        lock(tail, (86, 25), (86 + 8 * math.cos(a), 25 + 8 * math.sin(a)), .3, 3.2)
    layers.append(tail)
    far = Layer()
    far.stroke(path((76, 60), ((82, 68), (86, 76), (86, 86))), 10, 5)
    far.oval(87.5, 87, 3.6, 2.4)
    far.stroke(path((40, 60), ((42, 70), (42, 78), (41, 86))), 6, 4)
    layers.append(far)
    body = Layer()
    body.poly(path((26, 40), ((36, 36), (52, 42), (66, 44)), ((76, 46), (82, 52), (80, 62)),
                   ((78, 70), (68, 70), (60, 66)), ((52, 64), (44, 66), (36, 64)), ((26, 60), (22, 50), (26, 40))))
    sweep(body, (66, 50), (72, 52), (75, 58), (73, 65), 1.3)
    sweep(body, (50, 58), (56, 61), (60, 62), (63, 66), .9)
    for row in range(5):                                   # feathered breast
        for k in range(3):
            x, y = 26 + k * 3.6 + row * .8, 42 + row * 3.6
            body.stroke(bez((x - 1.8, y), (x - .6, y + 2), (x + .6, y + 2), (x + 1.8, y), 6), .45, .4, cut=True)
    layers.append(body)
    ruff = Layer()
    c = (24, 26)
    for k in range(10):
        a = math.radians(-30 + k * 16)
        lock(ruff, (c[0] + 3 * math.cos(a), c[1] + 3 * math.sin(a)),
             (c[0] + 16 * math.cos(a + .25), c[1] + 16 * math.sin(a + .25)), .18, 7)
    ruff.fur(c, 6, 16, -30, 115, 12, .25, .5)
    layers.append(ruff)
    head = Layer()
    head.oval(21, 21, 7, 6.4)
    thorn(head, path((24, 15.5), ((26, 11), (29, 8.5), (33, 8))), 2.8)
    head.c.polygon(head.k([(16.6, 19.4), (21.4, 18), (20.4, 20.4)]), fill=255)
    sweep(head, (15.6, 18), (18.6, 16.4), (21.6, 15.8), (25, 16.4), .9)
    sweep(head, (19, 24), (21.5, 25), (24, 25), (26, 23.5), .6)
    layers.append(head)
    beak = gold()
    beak.poly(path((16.4, 17), ((12.5, 16.6), (8.5, 18.4), (7.5, 22)), ((7.2, 24.6), (8, 26.4), (9.6, 27.6)),
                   ((9.8, 25.6), (10.6, 24.4), (12, 24)), ((14, 23.8), (16, 24.2), (17.6, 25))))
    beak.poly(path((16.6, 25.8), ((14, 26), (12, 26.6), (11, 27.8)), ((13, 29.2), (15.6, 29), (17.6, 28))))
    layers.append(beak)
    legs = Layer()
    for a, b, c in (((30, 56), (28, 66), (27, 76)), ((34, 58), (31, 70), (33, 84))):
        legs.stroke(path(a, (b, b, c)), 6, 3.4)
        pts = bez(a, b, b, c, 10)
        for j in range(4, 10):
            p = pts[j]
            legs.stroke([(p[0] - 1.4, p[1] - .2), (p[0] + 1.4, p[1] + .2)], .4, .4, cut=True)
    near_hind = Layer()
    near_hind.stroke(path((70, 56), ((72, 64), (70, 70), (66, 74))), 15, 8)
    near_hind.stroke(path((66, 74), ((66, 78), (68, 82), (70, 86))), 7, 4.4)
    near_hind.oval(71.5, 87, 3.8, 2.4)
    layers.append(near_hind)
    layers.append(eagle_wing(path((46, 40), ((52, 26), (62, 14), (78, 4))), 12, -28, 14, 30, 13, 5.2))  # near wing
    layers.append(legs)
    tg = gold()
    claws(tg, (26.5, 76.5), 175, 4, 26, 4, 1.5)
    claws(tg, (32.5, 84.5), 175, 4, 26, 4, 1.5)
    claws(tg, (68, 87.5), 175, 3, 24, 3, 1.3)
    claws(tg, (84, 87.5), 175, 3, 24, 3, 1.3)
    claws(tg, (40.5, 86.5), 175, 3, 24, 3, 1.3)
    layers.append(tg)
    return compose(layers)
