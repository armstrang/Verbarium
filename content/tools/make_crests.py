#!/usr/bin/env python3
"""Makes the arms of the five kingdoms: the pictures behind the splash shown when the learner goes to another kingdom
(mobile/lib/ui/crest.dart). Everything is drawn here, by code, for Verbarium: the beasts (crests/lion.py, griffin.py,
dragon.py, phoenix.py, eastern.py) are built from tapering strokes, cast in silver or gold with a relief light
(crests/relief.py), set on a shield with a gold rim (crests/shield.py) under a crown of their own (crests/crowns.py)
and over a scroll with the kingdom's motto. No picture is traced or copied from anywhere.

    Aldmere     English     a crowned lion, leaping          royal crown       Word by word, the crown
    Grauwacht   Deutsch     a griffin striding, wings up     mural crown       Wort um Wort, Stein um Stein
    Valdoro     Español     a dragon rampant, breathing fire ducal crown       Paso a paso, hasta el oro
    Beaumarais  Français    a phoenix of gold, wings spread  crown of lilies   Des cendres, la parole
    Alvamar     Português   an eastern dragon and its pearl  naval crown       De onda em onda, além-mar

For each kingdom it writes, at half size so that the app shows them as large pixels (FilterQuality.none):
    shield.png  the shield alone          full.png   the shield with its beast, at rest
    crown.png   the crown                 scroll.png the motto on its scroll
    p_<name>.png one moving part of the beast, the size of the shield, in place
    parts.json  the parts in drawing order, the group each moves with, each group's pivot and parent, and the
                focus (mouth, beak or pearl) that sparks and embers come from
Needs numpy, scipy and Pillow. Run from the repository root:
    python3 content/tools/make_crests.py
Writes mobile/assets/crest/<code>/.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'crests'))

import beasts  # noqa: E402
import dragon  # noqa: E402
import eastern  # noqa: E402
import griffin  # noqa: E402
import lion  # noqa: E402
import phoenix  # noqa: E402
from crowns import render as crown_of  # noqa: E402
from relief import crest, metal, SILVER  # noqa: E402
from shield import W, H, GOLD  # noqa: E402

OUT = os.path.join(HERE, '..', '..', 'mobile', 'assets', 'crest')
B = 460                        # the beast's box inside the shield, px (full size)
BX, BY = (W - B) // 2, 52      # where that box sits on the shield
HALF = 2                       # the pictures are written at half size

# code: name, field, beast, motto, crown, crown's gem, shift down (units of the box), parts, groups
KINGDOMS = {
    'en': ('Aldmere', (31, 63, 115), lion.lion, 'WORD BY WORD, THE CROWN', 'royal', (40, 80, 190), 0,
           ['tail', 'far', 'body', 'mane', 'head', 'near', 'claws', 'crown'],
           {'tail': 'tail', 'mane': 'mane', 'head': 'head', 'crown': 'head'},
           {'tail': ((72, 54), None), 'mane': ((32, 30), None), 'head': ((31, 30), None)}),
    'de': ('Grauwacht', (92, 87, 77), griffin.griffin, 'WORT UM WORT, STEIN UM STEIN', 'mural', (70, 70, 70), 0,
           ['wingFar', 'tail', 'far', 'body', 'ruff', 'head', 'beak', 'hind', 'wingNear', 'legs', 'talons'],
           {'wingFar': 'wingFar', 'tail': 'tail', 'ruff': 'ruff', 'head': 'head', 'beak': 'head', 'wingNear': 'wingNear'},
           {'wingFar': ((40, 38), None), 'wingNear': ((46, 40), None), 'tail': ((78, 54), None),
            'ruff': ((24, 30), None), 'head': ((24, 28), None)}),
    'es': ('Valdoro', (142, 27, 22), None, 'PASO A PASO, HASTA EL ORO', 'ducal', (170, 20, 30), 0,
           ['wingR', 'wingL', 'tail', 'farleg', 'body', 'head', 'arms', 'leg', 'fire'],
           {'wingR': 'wingR', 'wingL': 'wingL', 'tail': 'tail', 'head': 'head', 'arms': 'arms', 'fire': 'fire'},
           {'wingR': ((57, 40), None), 'wingL': ((47, 40), None), 'tail': ((58, 64), None), 'head': ((48, 24), None),
            'arms': ((52, 46), None), 'fire': ((22, 22), 'head')}),
    'fr': ('Beaumarais', (90, 42, 107), phoenix.phoenix, 'DES CENDRES, LA PAROLE', 'lilies', (120, 50, 160), 5,
           ['wingR', 'wingL', 'tail', 'body', 'head'],
           {'wingR': 'wingR', 'wingL': 'wingL', 'tail': 'tail', 'head': 'head'},
           {'wingR': ((56, 46), None), 'wingL': ((44, 46), None), 'tail': ((50, 60), None), 'head': ((46, 30), None)}),
    'pt': ('Alvamar', (47, 93, 58), eastern.eastern, 'DE ONDA EM ONDA, ALÉM-MAR', 'naval', (30, 140, 80), 0,
           ['pearl', 'far', 'farClaws', 'body', 'mane', 'head', 'whiskers', 'near', 'nearClaws'],
           {'pearl': 'pearl', 'far': 'body', 'farClaws': 'body', 'body': 'body', 'mane': 'head', 'head': 'head',
            'whiskers': 'head', 'near': 'body', 'nearClaws': 'body'},
           {'pearl': ((82, 14), None), 'body': ((52, 52), None), 'head': ((36, 26), 'body')}),
}


# where the beast's voice comes from (mouth, beak, the pearl): the splash sends its sparks, rings and embers from there
FOCUS = {'en': (14, 28), 'de': (9, 24), 'es': (22, 22), 'fr': (46, 28), 'pt': (82, 14)}


def layers_of(code, fn):
    """the beast's layers, back to front, exactly as compose() gets them, and the beast as composed"""
    if code == 'es':
        dragon.PARTS = []
        s, g = beasts.dragon()
        got, dragon.PARTS = dragon.PARTS, None
        return got, s, g
    beasts.CAPTURE = []
    s, g = fn()
    got, beasts.CAPTURE = beasts.CAPTURE, None
    return got, s, g


def shifted(m, dy):
    """moves a 1000 × 1000 drawing down by dy units of the box (the phoenix sits a little lower)"""
    if not dy:
        return m
    k = int(dy * 10)
    out = np.zeros_like(m)
    out[k:] = m[:-k]
    return out


def sprite(mask, gold, tint):
    """one part cast in metal, outlined in the field's dark tone, placed on a shield-sized canvas"""
    m = np.asarray(Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8)).resize((B, B), Image.LANCZOS),
                   float) / 255
    col = metal(m, GOLD * 1.05, 7, .8, 20) if gold else metal(m, SILVER, 8, .55, 30)
    ring = binary_dilation(m > .4, iterations=3).astype(float)
    dark = np.array(tint) * .3
    rgb = col * m[..., None] + dark[None, None, :] * (ring - np.minimum(ring, m))[..., None]
    a = np.clip(np.maximum(ring, m), 0, 1)
    box = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(box, (BX, BY))
    return canvas


def half(img):
    return img.resize((img.width // HALF, img.height // HALF), Image.BOX)


def make(code):
    name, tint, fn, motto, crown_kind, gem, dy, names, group_of, groups = KINGDOMS[code]
    layers, s, g = layers_of(code, fn)
    assert len(layers) == len(names), f'{code}: {len(layers)} layers, {len(names)} names'
    s, g = shifted(s, dy), shifted(g, dy)
    out = os.path.join(OUT, code)
    os.makedirs(out, exist_ok=True)
    crown = crown_of(crown_kind, gem)
    full, cr, sc, _, _ = crest(tint, s, g, motto, name, '', crown, parts=True)
    empty, *_ = crest(tint, s * 0, g * 0, motto, name, '', crown, parts=True)
    half(full).save(os.path.join(out, 'full.png'), optimize=True)
    half(empty).save(os.path.join(out, 'shield.png'), optimize=True)
    half(cr).save(os.path.join(out, 'crown.png'), optimize=True)
    half(sc).save(os.path.join(out, 'scroll.png'), optimize=True)
    parts = []
    for n, L in zip(names, layers):
        half(sprite(shifted(L.mask(), dy), getattr(L, 'gold', False) or n == 'fire', tint)).save(os.path.join(out, f'p_{n}.png'),
                                                                                  optimize=True)
        parts.append({'name': n, 'group': group_of.get(n, '')})

    def px(p):  # a point in the box's units, on the half-size shield
        return [round((BX + p[0] * B / 100) / HALF, 1), round((BY + (p[1] + dy) * B / 100) / HALF, 1)]

    manifest = {
        'size': [W // HALF, H // HALF],
        'crown': [cr.width // HALF, cr.height // HALF],
        'scroll': [sc.width // HALF, sc.height // HALF],
        'parts': parts,
        'groups': {k: {'pivot': px(p), 'parent': par} for k, (p, par) in groups.items()},
        'focus': px(FOCUS[code]),
    }
    with open(os.path.join(out, 'parts.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    print(code, name, len(parts), 'parts')


if __name__ == '__main__':
    for code in (sys.argv[1:] or KINGDOMS):
        make(code)
