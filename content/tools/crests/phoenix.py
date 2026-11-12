"""Beaumarais' phoenix, rising, all of gold: wings high in a V, feathers ending in flames."""
import math
from relief import Layer, bez, path
from dragon import thorn
from beasts import compose, gold, claws
from mane import lock
from lion import sweep


def flame_wing(sign):
    L = gold()
    m = (lambda p: p) if sign > 0 else (lambda p: (100 - p[0], p[1]))
    arm = [m(p) for p in path((54, 46), ((60, 34), (68, 20), (80, 8)))]
    k = len(arm) - 1
    n = 13
    for i in range(n):
        t = i / (n - 1)
        bx, by = arm[int(t * k)]
        a = math.radians(15 - 55 * t) if sign > 0 else math.radians(180 - 15 + 55 * t)
        ln = 14 + 16 * t
        e = (bx + ln * math.cos(a), by + ln * math.sin(a))
        c = (bx + ln * .55 * math.cos(a - .15 * sign), by + ln * .55 * math.sin(a - .15 * sign))
        f = bez((bx, by), c, c, e, 18)
        L.stroke(f, 10, 2)
        # a flame flicking off the tip
        a2 = a - .5 * sign
        thorn(L, bez(e, (e[0] + 3 * math.cos(a), e[1] + 3 * math.sin(a)),
                     (e[0] + 5 * math.cos(a2), e[1] + 5 * math.sin(a2)),
                     (e[0] + 7 * math.cos(a2 - .6 * sign), e[1] + 7 * math.sin(a2 - .6 * sign)), 12), 1.6)
        L.stroke(f[3:int(len(f) * .75)], .4, .2, cut=True)
    L.stroke(arm, 6, 3.5)
    for i in range(n - 1):                                      # coverts
        t = (i + .5) / (n - 1)
        bx, by = arm[int(t * k)]
        a = math.radians(15 - 55 * t) if sign > 0 else math.radians(180 - 15 + 55 * t)
        L.stroke([(bx, by), (bx + 13 * math.cos(a), by + 13 * math.sin(a))], 9, 3)
    return L


def phoenix():
    layers = [flame_wing(1), flame_wing(-1)]
    tail = gold()
    for dx, k in ((0, 0), (-7, 1), (7, 1), (-14, 2), (14, 2)):
        sw = 4 if k % 2 else -4
        pts = bez((50, 60), (50 + dx * .5 + sw, 72), (50 + dx * 1.3 - sw, 84), (50 + dx * 1.6 + sw * .5, 97 - k * 4), 30)
        tail.stroke(pts, 8.5 - k * 1.5, .4)
        tail.stroke(pts[3:int(len(pts) * .7)], .4, .2, cut=True)
    layers.append(tail)
    body = gold()
    body.oval(50, 50, 8, 12)
    for row in range(5):
        for k in (-1, 0, 1):
            x, y = 50 + k * 3.2 + (row % 2) * 1.6 - .8, 42 + row * 3.2
            body.stroke(bez((x - 1.6, y), (x - .5, y + 1.8), (x + .5, y + 1.8), (x + 1.6, y), 6), .45, .45, cut=True)
    body.stroke(path((50, 42), ((49, 36), (47, 32), (45, 28))), 7.5, 5.5)
    for k in range(4):                                          # neck plumage
        lock(body, (47, 31 + k * 2.5), (54 + k, 34 + k * 3), .2, 2.6)
    layers.append(body)
    head = gold()
    head.oval(44, 25, 5.2, 4.6)
    for k in range(4):
        thorn(head, bez((46, 21), (48 + k, 16), (52 + k * 2, 12), (57 + k * 3, 11 + k * 3), 16), 2.8 - k * .4)
    head.c.polygon(head.k([(40.4, 23.8), (44.4, 22.6), (43.6, 24.8)]), fill=255)
    sweep(head, (39.6, 22.4), (42, 21), (44.6, 20.6), (47, 21.2), .8)
    head.poly(path((40, 23), ((37, 23), (34.5, 24), (33.4, 26.4)), ((35.4, 26.2), (37.4, 26.2), (39.6, 27))))
    layers.append(head)
    feet = gold()
    for x in (46, 54):
        feet.stroke(bez((x, 58), (x, 62), (x - .5, 64), (x, 66), 8), 2.4, 1.6)
        claws(feet, (x, 66.5), 90, 3, 34, 2.6, 1.2)
    return compose(layers)
