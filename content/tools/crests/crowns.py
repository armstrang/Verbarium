"""Five crowns, one per kingdom."""
import math
import numpy as np
from PIL import Image, ImageDraw
from relief import metal, bez
from shield import GOLD

W2, H2 = 640, 320   # drawn at twice the size, shown at 320x160


def fleur(d, cx, base, s, fill=255):
    """a fleur-de-lis standing on (cx, base), height about 100*s"""
    def P(pts):
        return [(cx + x * s, base - y * s) for x, y in pts]
    centre = bez((0, 30), (-14, 55), (-10, 80), (0, 100), 16) + bez((0, 100), (10, 80), (14, 55), (0, 30), 16)
    d.polygon(P(centre), fill=fill)
    for sg in (-1, 1):
        petal = (bez((sg * 4, 34), (sg * 30, 40), (sg * 46, 66), (sg * 34, 80), 16) +
                 bez((sg * 34, 80), (sg * 30, 64), (sg * 22, 56), (sg * 8, 50), 16))
        d.polygon(P(petal), fill=fill)
        foot = bez((sg * 4, 22), (sg * 20, 20), (sg * 28, 6), (sg * 22, 0), 12) + [(0, 8)]
        d.polygon(P(foot), fill=fill)
    d.rectangle([cx - 20 * s, base - 34 * s, cx + 20 * s, base - 24 * s], fill=fill)


def cross(d, cx, cy, r, fill=255):
    """a cross pattée"""
    for a in range(4):
        t = math.radians(a * 90)
        ux, uy = math.cos(t), math.sin(t)
        vx, vy = -uy, ux
        d.polygon([(cx + ux * r * .15 + vx * r * .12, cy + uy * r * .15 + vy * r * .12),
                   (cx + ux * r + vx * r * .45, cy + uy * r + vy * r * .45),
                   (cx + ux * r - vx * r * .45, cy + uy * r - vy * r * .45),
                   (cx + ux * r * .15 - vx * r * .12, cy + uy * r * .15 - vy * r * .12)], fill=fill)
    d.ellipse([cx - r * .22, cy - r * .22, cx + r * .22, cy + r * .22], fill=fill)


def leaf(d, cx, base, s, fill=255):
    """a strawberry leaf: three rounded lobes"""
    for dx, dy, r in ((0, 70, 26), (-26, 46, 22), (26, 46, 22)):
        d.ellipse([cx + (dx - r) * s, base - (dy + r) * s, cx + (dx + r) * s, base - (dy - r) * s], fill=fill)
    d.polygon([(cx - 30 * s, base), (cx + 30 * s, base), (cx + 12 * s, base - 60 * s), (cx - 12 * s, base - 60 * s)], fill=fill)


def render(kind, gem):
    m = Image.new('L', (W2, H2), 0)
    cut = Image.new('L', (W2, H2), 0)
    gems = Image.new('L', (W2, H2), 0)
    d, c, g = ImageDraw.Draw(m), ImageDraw.Draw(cut), ImageDraw.Draw(gems)
    band = (50, 228, 590, 300)
    d.rounded_rectangle(band, 14, fill=255)
    c.line([(60, 240), (580, 240)], fill=255, width=3)
    c.line([(60, 288), (580, 288)], fill=255, width=3)

    def gemrow(xs, y=264, r=13):
        for x in xs:
            g.ellipse([x - r, y - r, x + r, y + r], fill=255)

    if kind == 'royal':            # Aldmere: crosses and fleurs, two arches, an orb
        for sx in (-1, 1):
            pts = bez((320 + sx * 250, 232), (320 + sx * 240, 120), (320 + sx * 120, 70), (320, 74), 30)
            d.line(pts, fill=255, width=22, joint='curve')
            for i in range(3, 28, 4):
                x, y = pts[i]
                d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=255)
        for x in (90, 320, 550):
            cross(d, x, 196, 34)
        for x in (205, 435):
            fleur(d, x, 232, .9)
        d.ellipse([292, 34, 348, 90], fill=255)
        c.line([(296, 62), (344, 62)], fill=255, width=3)
        cross(d, 320, 14, 18)
        gemrow((140, 260, 380, 500))
    elif kind == 'mural':          # Grauwacht: a wall with towers and gates
        d.rectangle([60, 120, 580, 232], fill=255)
        for i in range(6):
            x0 = 60 + i * 96
            d.rectangle([x0, 76, x0 + 52, 122], fill=255)
        for row, y in enumerate(range(140, 232, 30)):
            c.line([(60, y), (580, y)], fill=255, width=3)
            off = 0 if row % 2 else 32
            for x in range(60 + off, 580, 64):
                c.line([(x, y), (x, min(y + 30, 228))], fill=255, width=3)
        for x in (190, 320, 450):
            c.rectangle([x - 18, 176, x + 18, 232], fill=255)
            c.ellipse([x - 18, 158, x + 18, 194], fill=255)
        gemrow((120, 220, 320, 420, 520), r=10)
    elif kind == 'ducal':          # Valdoro: strawberry leaves and pearls on points
        for x, s in ((80, .95), (200, 1.1), (320, 1.35), (440, 1.1), (560, .95)):
            leaf(d, x, 232, s)
        for x in (140, 260, 380, 500):
            d.polygon([(x - 12, 232), (x + 12, 232), (x, 150)], fill=255)
            d.ellipse([x - 13, 132, x + 13, 158], fill=255)
        gemrow((140, 260, 380, 500))
    elif kind == 'lilies':         # Beaumarais: three great fleurs-de-lis, two small
        for x, s in ((90, .95), (320, 1.75), (550, .95), (205, 1.3), (435, 1.3)):
            fleur(d, x, 232, s)
        gemrow((150, 260, 380, 490))
    elif kind == 'naval':          # Alvamar: sails and sterns, waves on the band
        for i, x in enumerate((90, 205, 320, 435, 550)):
            if i % 2 == 0:         # a square sail on its mast
                d.line([(x, 232), (x, 90)], fill=255, width=10)
                d.polygon(bez((x - 46, 120), (x - 30, 150), (x - 30, 180), (x - 44, 206), 10) +
                          bez((x + 44, 206), (x + 30, 180), (x + 30, 150), (x + 46, 120), 10), fill=255)
                d.polygon([(x, 72), (x + 30, 82), (x, 92)], fill=255)
            else:                  # a ship's stern
                d.polygon([(x - 44, 232), (x - 52, 166), (x - 30, 150), (x + 30, 150), (x + 52, 166), (x + 44, 232)], fill=255)
                for wx in (-24, 0, 24):
                    c.rectangle([x + wx - 7, 168, x + wx + 7, 190], fill=255)
                c.line([(x - 40, 204), (x + 40, 204)], fill=255, width=3)
        wave = []
        for x in range(64, 580, 4):
            wave.append((x, 264 + 9 * math.sin(x / 24)))
        c.line(wave, fill=255, width=4)
        gemrow((140, 260, 380, 500), y=252, r=9)
    mm = np.asarray(m, float) / 255 * (1 - np.asarray(cut, float) / 255)
    gg = np.asarray(gems, float) / 255
    mm = mm * (1 - gg)
    col = metal(mm, GOLD * 1.05, 6, .8, 20)
    gcol = metal(gg, np.array(gem, float), 5, .9, 40)
    col = col * mm[..., None] + gcol * gg[..., None]
    a = np.clip(mm + gg, 0, 1)
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    return img.resize((W2 // 2, H2 // 2), Image.LANCZOS)
