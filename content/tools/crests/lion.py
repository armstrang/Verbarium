"""Aldmere's lion, leaping (salient), a bold silhouette with carved sweeps for muscle and mane."""
import math
from relief import Layer, bez, path
from dragon import thorn
from beasts import compose, gold, claws
from mane import lock


def sweep(L, p0, c1, c2, p3, w=1.2):
    """a carved crescent: the tribal cut that marks a muscle or a lock"""
    L.stroke(bez(p0, c1, c2, p3, 20), w, .2, cut=True)


def lion():
    layers = []
    tail = Layer()
    tc = path((72, 54), ((82, 52), (90, 44), (88, 34)), ((87, 28), (82, 26), (82, 21)))
    tail.stroke(tc, 4.2, 2.2)
    for k in range(5):
        a = math.radians(-150 + k * 30)
        lock(tail, (82, 21), (82 + 8 * math.cos(a), 21 + 8 * math.sin(a)), .3, 3.4)
    layers.append(tail)

    far = Layer()                                          # far legs
    far.stroke(path((70, 60), ((76, 66), (82, 70), (90, 74))), 11, 5)
    far.oval(91, 74.5, 3.4, 2.4)
    far.stroke(path((38, 50), ((33, 58), (30, 66), (31, 74))), 10, 5)
    far.oval(30, 75.5, 3.6, 2.4)
    layers.append(far)

    body = Layer()
    body.poly(path((26, 36), ((34, 30), (48, 34), (60, 40)), ((70, 44), (78, 50), (76, 60)),
                   ((74, 68), (64, 68), (56, 64)), ((48, 60), (42, 60), (36, 58)), ((28, 54), (24, 44), (26, 36))))
    sweep(body, (60, 46), (66, 48), (70, 54), (68, 62), 1.4)                    # haunch
    sweep(body, (46, 52), (52, 55), (56, 58), (58, 63), 1.0)                    # belly
    sweep(body, (34, 42), (38, 46), (40, 52), (38, 57), 1.2)                    # shoulder
    layers.append(body)

    mane = Layer()                                         # locks streaming back in the wind
    roots = [(28, 14), (31, 17), (33, 21), (34, 25), (34, 29), (33, 33), (32, 37), (30, 41), (28, 45)]
    for i, r in enumerate(roots):
        ln = 20 + 9 * math.sin(i / 8 * math.pi)
        a = math.radians(-50 + i * 10)
        e = (r[0] + ln * math.cos(a), r[1] + ln * math.sin(a))
        lock(mane, r, e, .25, 12 - abs(i - 4) * .7)
    mane.oval(30, 30, 11, 17)
    for i, r in enumerate(roots[1:-1]):
        a = math.radians(-30 + i * 13)
        sweep(mane, (r[0] + 3, r[1] + 1), (r[0] + 8, r[1] + 1 + i * .5), (r[0] + 12, r[1] + 3), (r[0] + 16, r[1] + 6), 1.1)
    layers.append(mane)

    head = Layer()
    head.poly(path((32, 18), ((28, 16), (23, 16.5), (19, 19)), ((16, 21), (13, 22), (12.5, 24.5)),
                   ((13, 26.5), (15, 27.5), (17, 27.6)), ((15.5, 29), (15.5, 31), (17, 32)),
                   ((20, 33.5), (25, 33), (28, 31.5)), ((33, 28.5), (35, 22), (32, 18))))
    head.ell(13.4, 23.6, 1.1, head.c)
    head.c.polygon(head.k([(19.5, 21.5), (24.5, 20.2), (23.4, 22.4)]), fill=255)
    sweep(head, (18.5, 20), (21.5, 18.6), (24.5, 18.2), (27.5, 18.8), .9)
    sweep(head, (15.6, 27.8), (18, 27.4), (21, 28), (23.6, 29.8), .6)          # mouth line
    sweep(head, (22, 24.6), (24.5, 25), (26.5, 26.8), (27.5, 29.6), .7)        # cheek
    layers.append(head)

    near = Layer()                                         # near legs
    near.stroke(path((34, 42), ((27, 40), (21, 39), (15, 43))), 10, 5)
    near.oval(12.5, 46, 3.6, 3)
    near.stroke(path((64, 56), ((66, 64), (64, 70), (60, 74))), 15, 8)
    near.stroke(path((60, 74), ((58, 78), (56, 81), (54, 84))), 7, 5)
    near.oval(51.5, 85, 4.2, 2.6)
    sweep(near, (64, 62), (63, 68), (61, 73), (58, 77), .9)
    layers.append(near)
    cl = gold()
    claws(cl, (10, 46.5), 170, 4, 24, 3.2, 1.4)
    claws(cl, (48, 86), 175, 3, 24, 3, 1.3)
    claws(cl, (27, 76.5), 175, 3, 24, 3, 1.3)
    claws(cl, (94.5, 75), 10, 3, 24, 3, 1.3)
    layers.append(cl)

    crown = gold()
    crown.poly([(20, 17.4), (19.6, 11.6), (22.4, 14), (24.4, 8.4), (26.8, 13.4), (29.6, 9), (30.8, 14.6), (33, 12.4), (32.6, 18)])
    for x, y in ((24.4, 7.8), (29.6, 8.4), (19.6, 11), (33, 11.8)):
        crown.ell(x, y, .95)
    layers.append(crown)
    return compose(layers)
