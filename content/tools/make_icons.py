#!/usr/bin/env python3
"""Draws the launcher icon (a red shield with a V on paper) into mobile/android/app/src/main/res/mipmap-*.
Needs Pillow. Run from the repository root:  python3 content/tools/make_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "mobile")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
FONT = os.path.join(ROOT, "assets", "fonts", "fell-400.ttf")
PAPER, INK, GULES, WHITE = (245, 242, 234, 255), (28, 27, 25, 255), (142, 27, 22, 255), (252, 251, 247, 255)
S = 1024  # drawing size, scaled down afterwards


def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3; b = 3 * (1 - t) ** 2 * t; c = 3 * (1 - t) * t * t; d = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def shield(cx, cy, w):
    """the same outline as shieldPath() in lib/ui/widgets.dart"""
    h = w * 1.22
    x0, y0 = cx - w / 2, cy - h / 2
    P = lambda fx, fy: (x0 + w * fx, y0 + h * fy)
    pts = [P(0.04, 0.03), P(0.96, 0.03), P(0.96, 0.48)]
    pts += bezier(P(0.96, 0.48), P(0.96, 0.76), P(0.62, 0.93), P(0.5, 0.98))
    pts += bezier(P(0.5, 0.98), P(0.38, 0.93), P(0.04, 0.76), P(0.04, 0.48))
    return pts


def art(shield_w, mono=False, bg=None):
    im = Image.new("RGBA", (S, S), bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = shield(S / 2, S / 2, shield_w)
    if mono:
        d.polygon(pts, fill=(255, 255, 255, 255))
        return im
    d.polygon(pts, fill=GULES)
    d.line(pts + [pts[0]], fill=INK, width=int(shield_w * 0.05), joint="curve")
    font = ImageFont.truetype(FONT, int(shield_w * 0.74))
    box = d.textbbox((0, 0), "V", font=font)
    d.text((S / 2 - (box[0] + box[2]) / 2, S / 2 - shield_w * 0.07 - (box[1] + box[3]) / 2), "V", font=font, fill=WHITE)
    return im


def save(im, folder, name, px):
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    im.resize((px, px), Image.LANCZOS).save(os.path.join(path, name))


legacy = art(540, bg=PAPER)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse((0, 0, S, S), fill=255)
round_ = Image.new("RGBA", (S, S), (0, 0, 0, 0))
round_.paste(art(500, bg=PAPER), (0, 0), mask)
fore = art(400)          # inside the adaptive icon's safe zone
mono = art(400, mono=True)
for dens, k in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)):
    save(legacy, f"mipmap-{dens}", "ic_launcher.png", int(48 * k))
    save(round_, f"mipmap-{dens}", "ic_launcher_round.png", int(48 * k))
    save(fore, f"mipmap-{dens}", "ic_launcher_foreground.png", int(108 * k))
    save(mono, f"mipmap-{dens}", "ic_launcher_monochrome.png", int(108 * k))
legacy.resize((512, 512), Image.LANCZOS).save(os.path.join(os.path.dirname(__file__), "..", "..", "docs", "icon-512.png"))
print("icons written")
