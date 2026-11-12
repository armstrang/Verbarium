"""An eagle's wing of layered feathers, used by the griffin; and the second griffin."""
import math
from relief import Layer, bez, path
from dragon import thorn
from beasts import compose, gold, claws
from mane import lock


def eagle_wing(arm_pts, a0, a1, l0, l1, n=12, w=4.6, mirror=None):
    if mirror is not None:
        arm_pts = [(2 * mirror - x, y) for x, y in arm_pts]
        a0, a1 = 180 - a0, 180 - a1
    L = Layer()
    k = len(arm_pts) - 1
    feathers = []
    for i in range(n):
        t = i / (n - 1)
        bx, by = arm_pts[int(t * k)]
        a = math.radians(a0 + (a1 - a0) * t)
        ln = l0 + (l1 - l0) * t
        e = (bx + ln * math.cos(a), by + ln * math.sin(a))
        c = (bx + ln * .5 * math.cos(a + .12), by + ln * .5 * math.sin(a + .12))
        feathers.append(bez((bx, by), c, c, e, 16))
    for f in feathers:
        L.stroke(f, w, 1.2)
    L.stroke(arm_pts, 5, 3)
    for i in range(n - 1):  # coverts
        t = (i + .5) / (n - 1)
        bx, by = arm_pts[int(t * k)]
        a = math.radians(a0 + (a1 - a0) * t)
        e = (bx + 6 * math.cos(a), by + 6 * math.sin(a))
        L.stroke([(bx, by), e], 5.5, 2.2)
    for f in feathers:
        L.stroke(f[3:int(len(f) * .8)], .4, .2, cut=True)
    return L


def griffin():
    layers = []
    arm_far = path((50, 38), ((44, 28), (36, 18), (24, 10)))
    layers.append(eagle_wing(arm_far, -175, -135, 12, 22, 10, 4.6))          # far wing, peeking out on the left
    arm = path((58, 38), ((62, 28), (68, 16), (80, 6)))
    layers.append(eagle_wing(arm, 5, -40, 16, 30, 13, 5))

    tail = Layer()
    tc = path((64, 62), ((74, 64), (84, 56), (82, 44)), ((80, 36), (84, 30), (90, 30)))
    tail.stroke(tc, 4, 2.2)
    for k in range(6):
        a = math.radians(-140 + k * 34)
        lock(tail, (90, 30), (90 + 8 * math.cos(a), 30 + 8 * math.sin(a)), .25, 3)
    layers.append(tail)
    far = Layer()
    far.stroke(path((64, 64), ((70, 70), (73, 78), (71, 85)), ((70, 89), (73, 91), (77, 91))), 8, 4.2)
    layers.append(far)
    body = Layer()
    body.oval(46, 38, 9, 10)
    body.stroke(path((46, 38), ((50, 46), (53, 52), (57, 58))), 14, 10)
    body.oval(59, 62, 8, 8)
    for row in range(4):                                  # breast feathers
        for k in range(3):
            x, y = 41 + k * 3.4 + row * 1.6, 32 + row * 3.4
            body.stroke(bez((x - 1.5, y), (x - .5, y + 1.6), (x + .5, y + 1.6), (x + 1.5, y), 6), .45, .45, cut=True)
    layers.append(body)
    ruff = Layer()                                        # neck feathers falling down the back
    c = (36, 20)
    for k in range(9):
        a = math.radians(-20 + k * 17)
        lock(ruff, (c[0] + 4 * math.cos(a), c[1] + 4 * math.sin(a)),
             (c[0] + 15 * math.cos(a + .3), c[1] + 15 * math.sin(a + .3)), .15, 6)
    ruff.fur(c, 6, 15, -20, 120, 10, .3, .5)
    layers.append(ruff)
    head = Layer()
    head.oval(33, 18, 6.5, 6)
    thorn(head, path((36, 13), ((38, 9), (41, 6), (45, 5))), 2.8)
    thorn(head, path((38.5, 15), ((42, 12), (45, 11), (49, 11))), 2.2)
    head.c.polygon(head.k([(29, 16.6), (33.5, 15.2), (32.6, 17.6)]), fill=255)
    head.stroke(bez((28, 15.2), (31, 13.6), (34, 13), (37, 13.4), 8), .9, .3, cut=True)
    layers.append(head)
    beak = gold()
    beak.poly(path((28.5, 14.5), ((25, 14), (21, 15.5), (19.5, 19)), ((19, 21.5), (19.5, 23.5), (21, 25)),
                   ((21.2, 23), (22, 21.6), (23.5, 21)), ((25.5, 20.8), (27.5, 21.2), (29, 22))))
    beak.poly(path((28, 22.8), ((25.5, 23), (23.5, 23.6), (22.5, 24.8)), ((24.5, 26.2), (27, 26), (29, 25))))
    beak.stroke(bez((26, 16), (27, 17), (27.2, 18.4), (26.6, 19.6), 6), .4, .3, cut=True)
    layers.append(beak)
    legs = Layer()
    for a, b, c in (((46, 35), (40, 36), (31, 36)), ((50, 46), (43, 49), (35, 47))):
        legs.stroke(path(a, (b, b, c)), 5, 3)
        pts = bez(a, b, b, c, 10)
        for j in range(3, 9):
            p = pts[j]
            legs.stroke([(p[0] - .3, p[1] - 1.4), (p[0] + .3, p[1] + 1.4)], .4, .4, cut=True)
    layers.append(legs)
    tg = gold()
    claws(tg, (30.5, 36), 195, 4, 26, 4.2, 1.6)
    claws(tg, (34.5, 47), 190, 4, 26, 4.2, 1.6)
    claws(tg, (77.5, 91), 15, 3, 24, 3.2, 1.5)
    layers.append(tg)
    leg = Layer()
    leg.stroke(path((59, 62), ((59, 68), (57, 72), (54, 75))), 13, 8)
    leg.stroke(path((54, 74), ((51, 79), (49, 83), (48, 87)), ((47.5, 89), (45, 90.5), (41, 91))), 7, 4.4)
    layers.append(leg)
    lg = gold()
    claws(lg, (40.5, 91), 180, 3, 24, 3.2, 1.5)
    layers.append(lg)
    return compose(layers)
