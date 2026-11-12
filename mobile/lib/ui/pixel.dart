/// Pixel art, built from shapes. A figure is put together on a grid of materials (skin, hair, steel, the job's
/// colour, …) from ellipses, lines and rows of '#'. Light comes from the upper left: each material gets a light, a
/// middle and a shaded tone, and an outline in its own dark tone. The result is a grid of characters and a palette,
/// drawn by [PixelPainter]. Nothing here is an image file.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/jobs.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------- tones and the board

/// light, middle, shaded, outline
class _T {
  final Color hi, mid, lo, edge;
  const _T(this.hi, this.mid, this.lo, this.edge);
}

_T _of(Color c) =>
    _T(Color.lerp(c, Colors.white, .3)!, c, Color.lerp(c, Colors.black, .32)!, Color.lerp(c, Colors.black, .72)!);
_T _one(int a, [int? edge]) => _T(Color(a), Color(a), Color(a), Color(edge ?? a));

/// materials drawn in one flat colour, never shaded or outlined from inside
const _flat = {'eyew', 'iris', 'lash', 'brow', 'mouth', 'ember', 'slash', 'spark', 'eye'};

const _skin = _T(Color(0xFFFFE1C2), Color(0xFFF2C298), Color(0xFFD08E62), Color(0xFF6E3420));
const _steel = _T(Color(0xFFFFFFFF), Color(0xFFC3CDD9), Color(0xFF7C8898), Color(0xFF2A303C));
const _gold = _T(Color(0xFFFFF2A0), Color(0xFFE8BC3A), Color(0xFFA87A1E), Color(0xFF4A300A));
const _leather = _T(Color(0xFF9C7552), Color(0xFF6E4A2E), Color(0xFF4A2F1C), Color(0xFF1E1209));
const _boot = _T(Color(0xFF5E4434), Color(0xFF3E2C22), Color(0xFF281A14), Color(0xFF0E0806));
const _straw = _T(Color(0xFFFFF0A8), Color(0xFFE0BE62), Color(0xFFB08A34), Color(0xFF4E3A10));
const _page = _T(Color(0xFFFFFFFF), Color(0xFFF3EEDF), Color(0xFFD6CDB4), Color(0xFF6B624E));
const _hair = _T(Color(0xFFB47C46), Color(0xFF83522C), Color(0xFF58321A), Color(0xFF24120A));
const _bone = _T(Color(0xFFFFFFFF), Color(0xFFEDE8D8), Color(0xFFB8B09A), Color(0xFF4E4838));

/// the fixed materials every figure may use
final _common = <String, _T>{
  'skin': _skin,
  'eyew': _one(0xFFFFFFFF),
  'iris': _one(0xFF4A2E1E),
  'lash': _one(0xFF1A1414),
  'brow': _one(0xFF24120A),
  'mouth': _one(0xFF9A4A34),
  'ember': _one(0xFFFF5A3C),
  'slash': _one(0xFFFFFFFF),
  'steel': _steel,
  'trim': _gold,
  'leather': _leather,
  'boot': _boot,
  'straw': _straw,
  'page': _page,
  'hair': _hair,
  'bone': _bone,
  'string': _one(0xFFEEE6CC, 0xFF6B624E),
};

/// a drawn figure: rows of characters and the colour of each character
class PixelArt {
  final List<String> grid;
  final Map<String, Color> palette;
  const PixelArt(this.grid, this.palette);
}

class _B {
  final int w, h;
  final List<String?> m;
  final List<int> lay;
  int n = 0;
  double ox = 0, oy = 0;
  _B(this.w, this.h) : m = List.filled(w * h, null), lay = List.filled(w * h, 0);

  void put(num x, num y, String mat) {
    final xi = (x + ox).round(), yi = (y + oy).round();
    if (xi < 0 || yi < 0 || xi >= w || yi >= h) return;
    m[yi * w + xi] = mat;
    lay[yi * w + xi] = n;
  }

  void span(num y, num x0, num x1, String mat) {
    for (var x = x0.round(); x <= x1.round(); x++) {
      put(x, y, mat);
    }
  }

  void rect(int x0, int y0, int x1, int y1, String mat) {
    n++;
    for (var y = y0; y <= y1; y++) {
      span(y, x0, x1, mat);
    }
  }

  void ell(double cx, double cy, double rx, double ry, String mat, {double ymin = -99, double ymax = 99}) {
    n++;
    for (var y = (cy - ry - 1).floor(); y <= (cy + ry + 1).ceil(); y++) {
      if (y < ymin || y > ymax) continue;
      for (var x = (cx - rx - 1).floor(); x <= (cx + rx + 1).ceil(); x++) {
        final dx = (x + .5 - cx) / rx, dy = (y + .5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) put(x, y, mat);
      }
    }
  }

  void rows(int x0, int y0, List<String> rs, String mat) {
    n++;
    for (var dy = 0; dy < rs.length; dy++) {
      for (var dx = 0; dx < rs[dy].length; dx++) {
        if (rs[dy][dx] == '#') put(x0 + dx, y0 + dy, mat);
      }
    }
  }

  void line(num x0, num y0, num x1, num y1, String mat, {int width = 1}) {
    n++;
    final steps = (max((x1 - x0).abs(), (y1 - y0).abs()) * 2).ceil() + 1;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      for (var k = 0; k < width; k++) {
        put(x0 + (x1 - x0) * t + k, y0 + (y1 - y0) * t, mat);
      }
    }
  }

  /// a drawing given as rows of letters; each letter names a material in [key] ('.' and unknown letters stay empty)
  void grid(int x0, int y0, List<String> rs, Map<String, String> key) {
    n++;
    for (var dy = 0; dy < rs.length; dy++) {
      for (var dx = 0; dx < rs[dy].length; dx++) {
        final mat = key[rs[dy][dx]];
        if (mat != null) put(x0 + dx, y0 + dy, mat);
      }
    }
  }

  /// the same, with each row written as its left half and mirrored into the right
  void mirrored(int x0, int y0, List<String> half, Map<String, String> key) =>
      grid(x0, y0, [for (final r in half) r + r.split('').reversed.join()], key);

  String? at(int x, int y) => x < 0 || y < 0 || x >= w || y >= h ? null : m[y * w + x];

  PixelArt render(Map<String, _T> pal, {bool mirror = false}) {
    final codes = <String, String>{};
    final palette = <String, Color>{};
    String code(String mat, int tone, Color c) => codes.putIfAbsent('$mat/$tone', () {
      final ch = String.fromCharCode(0x100 + codes.length);
      palette[ch] = c;
      return ch;
    });
    final out = List<String>.filled(w * h, '.');
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x, mat = m[i];
        if (mat == null) continue;
        final t = pal[mat]!;
        if (_flat.contains(mat)) {
          out[i] = code(mat, 1, t.mid);
          continue;
        }
        bool same(int dx, int dy) => at(x + dx, y + dy) == mat;
        var tone = 1;
        if (!same(1, 0) || !same(0, 1) || !same(1, 1)) {
          tone = 2;
        } else if (!same(-1, 0) || !same(0, -1)) {
          tone = 0;
        }
        var c = [t.hi, t.mid, t.lo][tone];
        // a part lying on another gets a thin line of its own dark tone where they meet
        if (mat != 'skin') {
          for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final o = at(x + d.$1, y + d.$2);
            if (o != null &&
                o != mat &&
                !_flat.contains(o) &&
                lay[(y + d.$2) * w + x + d.$1] > lay[i] &&
                pal[o]!.edge != t.edge) {
              c = t.edge;
              tone = 3;
              break;
            }
          }
        }
        out[i] = code(mat, tone, c);
      }
    }
    final res = List<String>.of(out);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (m[y * w + x] != null) continue;
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final o = at(x + d.$1, y + d.$2);
          if (o != null) {
            res[y * w + x] = code(o, 3, pal[o]!.edge);
            break;
          }
        }
      }
    }
    final grid = [
      for (var y = 0; y < h; y++)
        if (mirror) res.sublist(y * w, y * w + w).reversed.join() else res.sublist(y * w, y * w + w).join(),
    ];
    return PixelArt(grid, palette);
  }
}

// ---------------------------------------------------------------------------- figures (hero and the people you fight)

enum HeroPose { idle, walk, attack, hurt, cheer }

/// width and height of a figure's grid; the body stands in the left 35 columns, the rest is room for a swing
const figW = 40, figH = 43;

/// What a figure wears and carries.
/// head: 0 bare, 1 hood, 2 helm, 3 pointed hat, 4 crown, 5 band, 6 straw hat.
/// arm: 0 stick, 1 sword, 2 spear, 3 bow, 4 daggers, 5 staff, 6 mace, 7 book.
class _Fig {
  final int head, arm;
  final bool shield, roundShield, cape, heavy, robe, mask, visor, bone, beard;
  final String hairStyle;
  const _Fig({
    required this.head,
    required this.arm,
    this.shield = false,
    this.roundShield = false,
    this.cape = false,
    this.heavy = false,
    this.robe = false,
    this.mask = false,
    this.visor = false,
    this.bone = false,
    this.beard = false,
    this.hairStyle = 'spiky',
  });
}

/// the right hand, the direction the weapon points and its length, for a pose
({double hx, double hy, double dx, double dy, int len}) _grip(int arm, int wp) {
  const idleLen = [24, 18, 26, 0, 6, 24, 12, 0];
  const upLen = [16, 14, 18, 0, 6, 16, 10, 0];
  const hitLen = [11, 10, 12, 0, 7, 10, 8, 0];
  final dagger = arm == 4;
  return switch (wp) {
    1 => (hx: 24, hy: 13, dx: -3, dy: -12, len: upLen[arm]),
    2 => (hx: 25, hy: 20, dx: 10, dy: -5, len: hitLen[arm]),
    3 => (hx: 25, hy: 13, dx: .5, dy: -20, len: upLen[arm]),
    _ => (hx: 24, hy: 24, dx: dagger ? 6 : 2.5, dy: dagger ? -4 : -20, len: idleLen[arm]),
  };
}

void _weapon(_B b, int arm, double hx, double hy, double dx, double dy, int len, {bool slash = false}) {
  final l = sqrt(dx * dx + dy * dy);
  dx /= l;
  dy /= l;
  final px = -dy, py = dx;
  final steep = dy.abs() > dx.abs();
  void dot(double t, double s, String mat, {bool thick = false}) {
    final x = hx + dx * t + px * s, y = hy + dy * t + py * s;
    b.put(x, y, mat);
    if (thick) steep ? b.put(x + 1, y, mat) : b.put(x, y + 1, mat);
  }

  b.n++;
  switch (arm) {
    case 1:
      for (var t = -3.0; t <= -1; t += .5) {
        dot(t, 0, 'grip');
      }
      b.n++;
      for (var s = -3.0; s <= 3; s += .5) {
        dot(0, s, 'trim');
      }
      b.n++;
      for (var t = 1.0; t <= len; t += .5) {
        dot(t, 0, 'blade', thick: true);
      }
      dot(len + 1.0, 0, 'blade');
    case 2:
      for (var t = -12.0; t <= len - 4; t += .5) {
        dot(t, 0, 'grip');
      }
      b.n++;
      for (var t = len - 4.0; t <= len; t += .5) {
        dot(t, 0, 'blade', thick: t < len - .5);
      }
      dot(len - 4.0, -1.5, 'trim');
      dot(len - 4.0, 1.5, 'trim');
    case 0:
      for (var t = -12.0; t <= len; t += .5) {
        dot(t, 0, 'grip');
      }
    case 5:
      for (var t = -12.0; t <= len - 2; t += .5) {
        dot(t, 0, 'grip');
      }
      final ex = hx + dx * len, ey = hy + dy * len;
      b.ell(ex + .5, ey + .5, 2.5, 2.5, 'blade');
      b.n++;
      b.put(ex - 1, ey - 1, 'eyew');
      dot(len - 2.0, -1.5, 'trim');
      dot(len - 2.0, 1.5, 'trim');
    case 6:
      for (var t = -2.0; t <= len - 3; t += .5) {
        dot(t, 0, 'grip');
      }
      final ex = hx + dx * (len - 1), ey = hy + dy * (len - 1);
      b.ell(ex + .5, ey + .5, 2.7, 2.7, 'blade');
      b.n++;
      dot(len + 2.0, 0, 'blade');
      dot(len - 1.0, -3.4, 'blade');
      dot(len - 1.0, 3.4, 'blade');
    case 4:
      dot(-1, 0, 'grip');
      dot(0, -1.5, 'trim');
      dot(0, 1.5, 'trim');
      dot(0, 0, 'trim');
      for (var t = 1.0; t <= len; t += .5) {
        dot(t, 0, 'blade');
      }
  }
  if (slash) {
    // the arc a swing leaves behind
    b.n++;
    final base = atan2(dy, dx) * 180 / pi;
    for (var a = base - 50; a <= base - 8; a += 4) {
      for (final r in [len - 1.0, len.toDouble()]) {
        b.put(hx + cos(a * pi / 180) * r, hy + sin(a * pi / 180) * r, 'slash');
      }
    }
  }
}

/// Draws a figure. Coordinates are those of a body 32 wide, moved by (3, 4) on the board.
void _figure(_B b, _Fig f, HeroPose pose, int frame) {
  final wp = switch (pose) {
    HeroPose.attack => frame % 3 == 0 ? 1 : 2,
    HeroPose.cheer => 3,
    _ => 0,
  };
  final hurt = pose == HeroPose.hurt;
  final breathe = pose == HeroPose.idle && frame.isOdd;
  final ux = hurt ? -1.0 : (wp == 2 ? 1.0 : 0.0);
  final uy = breathe || hurt ? 1.0 : (pose == HeroPose.walk && frame.isOdd ? -1.0 : 0.0);
  final sleeve = f.heavy ? 'metal' : 'coat';
  final hand = f.heavy ? 'metal' : (f.bone ? 'skin' : 'skin');

  void upper() {
    b.ox = 3 + ux;
    b.oy = 4 + uy;
  }

  void lower() {
    b.ox = 3;
    b.oy = 4;
  }

  // ---- behind: the cape, long hair
  upper();
  if (f.cape) {
    b.n++;
    for (var y = 16; y < 38; y++) {
      final k = (y - 16) / 21;
      var xl = 10 - 6 * pow(k, 1.2);
      final xr = 21 + 3 * k;
      if (y >= 35 && (xl.toInt() + y + frame) % 3 == 0) xl += 1;
      b.span(y, xl, xr, 'cape');
    }
    for (var x = 4 + frame % 3; x < 25; x += 3) {
      b.put(x, 38, 'cape');
    }
  }
  if (f.hairStyle == 'long' && f.head != 1 && f.head != 2) {
    b.rows(9, 9, [...List.filled(9, '##............##'), '.#............#.'], 'hair');
  }

  // ---- legs
  lower();
  final leg = f.bone ? 'skin' : (f.heavy ? 'metal' : 'leather');
  if (f.robe) {
    b.n++;
    for (var y = 27; y <= 36; y++) {
      b.span(y, 11 - (y - 27) * .45, 20 + (y - 27) * .45, 'coat');
    }
    b.rect(10, 37, 14, 38, 'boot');
    b.rect(17, 37, 21, 38, 'boot');
  } else if (pose == HeroPose.walk) {
    final lift = [0, -1, 1, -1][frame % 4]; // 0 left up, 1 and 3 passing, 2 right up
    b.n++;
    for (var y = 28; y < 35; y++) {
      if (lift == 0 && y > 33) continue;
      if (lift == 1 && y > 33) continue;
      b.span(y, 12, 14, f.bone ? 'skin' : leg);
    }
    for (var y = 28; y < 35; y++) {
      b.span(y, 17, 19, leg);
    }
    b.rect(11, lift == 0 ? 33 : 35, 15, lift == 0 ? 35 : 37, 'boot');
    b.rect(16, lift == 1 ? 33 : 35, 20, lift == 1 ? 35 : 37, 'boot');
  } else {
    b.n++;
    for (var y = 28; y < 35; y++) {
      final d = (y - 28) ~/ 3;
      b.span(y, 12 - d, 14 - d, leg);
      b.span(y, 17 + d, 19 + d, leg);
    }
    b.rect(8, 35, 13, 37, 'boot');
    b.rect(18, 35, 23, 37, 'boot');
    if (f.heavy) {
      b.rect(9, 34, 13, 34, 'metal');
      b.rect(18, 34, 22, 34, 'metal');
    }
  }

  // ---- body
  upper();
  if (f.bone) {
    b.rows(10, 16, [
      '...######...',
      '.##########.',
      '##.##..##.##',
      '############',
      '.#.##..##.#.',
      '..########..',
      '....####....',
      '....####....',
      '...######...',
      '...######...',
      '..########..',
      '..########..',
    ], 'skin');
    b.rect(11, 26, 20, 26, 'leather');
  } else {
    b.n++;
    const widths = [
      (12, 19),
      (9, 22),
      (9, 22),
      (9, 22),
      (10, 21),
      (10, 21),
      (10, 21),
      (10, 21),
      (11, 20),
      (11, 20),
      (11, 20),
      (11, 20),
    ];
    for (var i = 0; i < widths.length; i++) {
      b.span(16 + i, widths[i].$1, widths[i].$2, 'coat');
    }
    if (f.heavy) {
      b.rows(10, 16, ['..########..', '############', '############', '.##########.', '..########..'], 'metal');
      b.rect(13, 19, 18, 25, 'tabard');
      b.rows(14, 20, ['..##..', '.####.', '..##..', '..##..'], 'trim');
    } else if (!f.robe) {
      b.line(11, 17, 19, 25, 'leather');
    } else {
      b.rect(15, 17, 16, 26, 'trim');
    }
    b.rect(11, 26, 20, 26, 'leather');
    b.rect(15, 26, 16, 26, 'trim');
    if (!f.robe) b.rows(12, 27, ['########', '.######.', '.######.', '..####..'], f.heavy ? 'tabard' : 'coat');
  }

  // ---- the left arm (shield side)
  final offHandUp = wp == 3 && !f.shield && f.arm != 4 && f.arm != 3;
  if (offHandUp) {
    b.line(7, 18, 6, 12, sleeve, width: 3);
    b.rect(6, 10, 8, 11, hand);
  } else {
    b.rect(7, 18, 9, hurt ? 21 : 23, sleeve);
    b.rect(7, hurt ? 22 : 24, 9, hurt ? 23 : 25, hand);
  }
  b.ell(9, 18, 2.6, 2.2, sleeve);
  if (f.heavy) b.rect(7, 20, 9, 20, 'trim');

  // ---- head
  b.rect(15, 15, 16, 16, 'skin');
  b.ell(16, 9.6, 6.2, 6.4, 'skin');
  final style = f.hairStyle;
  if (const [0, 4, 5].contains(f.head) && !f.bone) {
    b.ell(16, 7.6, 7.2, 6.2, 'hair', ymax: 6);
    b.rows(9, 7, ['##############', '#.###.##.####.', '#..#...#..##..', '#............#', '#............#'], 'hair');
    switch (style) {
      case 'spiky':
        b.rows(10, 0, ['.......#....##', '..#...##..###.', '.###.#######..', '############..'], 'hair');
      case 'swept':
        b.rows(9, 1, ['......########', '...###########', '.#############'], 'hair');
      default:
        b.rows(10, 2, ['..########', '.##########'], 'hair');
    }
  }
  switch (f.head) {
    case 1:
      b.ell(16, 8.8, 7.6, 7.8, 'hood', ymax: 8);
      b.rows(8, 8, [
        '###..........###',
        '###..........###',
        '###..........###',
        '####........####',
        '.####......####.',
      ], 'hood');
      if (!f.bone) b.rows(10, 7, ['#.##..#.##..'], 'hair');
    case 2:
      b.ell(16, 8.6, 7.2, 7.4, 'metal', ymax: 7);
      b.rows(9, 8, [
        '##............##',
        '##............##',
        '###..........###',
        '###..........###',
        '.###........###.',
      ], 'metal');
      if (f.visor) b.rect(10, 8, 21, 13, 'metal');
      b.rect(9, 7, 22, 7, 'trim');
      b.rect(15, 1, 16, 7, 'trim');
      b.rows(13, -3, ['...##', '..####', '.######', '.#####', '..###'], 'plume');
    case 3:
      if (!f.bone) b.rows(9, 8, ['#............#', '#............#', '##..........##'], 'hair');
      b.rows(11, -2, [
        '.........##',
        '........###',
        '.......####',
        '......#####',
        '.....######',
        '....#######',
        '...#########',
        '..##########',
        '.###########',
      ], 'hat');
      b.rect(4, 7, 27, 8, 'hat');
      b.rect(9, 6, 22, 6, 'trim');
    case 4:
      b.rows(10, -1, ['.#..#..#..#.', '.##.##.##.#.', '############', '############'], 'trim');
      b.n++;
      for (final x in const [13, 16, 19]) {
        b.put(x, 1, 'gem');
      }
    case 5:
      b.rect(9, 6, 22, 6, 'trim');
      b.n++;
      b.put(15, 6, 'gem');
      b.put(16, 6, 'gem');
    case 6:
      b.rows(9, 7, ['#.#....#....#.#'], 'hair');
      b.ell(16, 5, 5.6, 4.0, 'straw', ymax: 6);
      b.rect(4, 6, 27, 7, 'straw');
      b.rect(11, 5, 20, 5, 'leather');
  }

  // ---- face
  b.n++;
  if (f.visor) {
    b.span(10, 11, 20, 'lash');
    b.put(13, 10, 'ember');
    b.put(18, 10, 'ember');
  } else if (f.bone) {
    for (final ex in const [11, 18]) {
      b.rect(ex, 9, ex + 2, 11, 'lash');
      b.put(ex + 1, 10, 'ember');
    }
    b.put(16, 12, 'lash');
    b.span(14, 13, 18, 'lash');
    for (final x in const [14, 16, 18]) {
      b.put(x, 13, 'lash');
    }
  } else if (hurt) {
    for (final p in const [(11, 10), (12, 11), (11, 12), (20, 10), (19, 11), (20, 12)]) {
      b.put(p.$1, p.$2, 'lash');
    }
    b.span(14, 14, 17, 'mouth');
  } else if (wp == 3) {
    for (final p in const [(11, 11), (12, 10), (13, 11), (18, 11), (19, 10), (20, 11)]) {
      b.put(p.$1, p.$2, 'lash');
    }
    b.rect(15, 13, 16, 14, 'mouth');
  } else {
    for (final p in const [(11, 8), (12, 8), (13, 9), (18, 9), (19, 8), (20, 8)]) {
      b.put(p.$1, p.$2, 'brow');
    }
    for (final ex in const [11, 18]) {
      b.span(10, ex, ex + 2, 'lash');
      final ix = ex == 11 ? 12 : 18;
      b.rect(ix, 11, ix + 1, 12, 'iris');
      b.put(ix, 11, 'eyew');
    }
    if (wp == 2) {
      b.rect(15, 13, 16, 14, 'mouth');
    } else {
      b.span(14, 15, 16, 'mouth');
    }
  }
  if (f.mask) b.rows(10, 13, ['############', '.##########.'], 'mask');
  if (f.beard) b.rows(11, 13, ['##########', '##########', '.########.', '..######..', '...####...'], 'beard');

  // ---- the right arm and what it carries
  if (f.arm == 3) {
    // a bow is held out in front, at the height of the chest
    b.line(22, 18, 25, 15, sleeve, width: 3);
    b.rect(25, 14, 27, 16, hand);
    b.rows(25, 6, [
      '###..',
      '..##.',
      '...##',
      '...##',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '....#',
      '...##',
      '...##',
      '..##.',
      '###..',
    ], 'grip');
    b.n++;
    if (wp == 1) {
      b.line(25, 7, 22, 15, 'string');
      b.line(22, 15, 25, 23, 'string');
      b.n++;
      b.span(15, 21, 32, 'blade');
      b.put(33, 15, 'trim');
    } else {
      b.line(25, 7, 25, 23, 'string');
      if (wp == 2) {
        b.n++;
        b.span(14, 31, 37, 'blade');
        b.put(36, 13, 'slash');
        b.put(36, 15, 'slash');
      }
    }
  } else if (f.arm == 7) {
    final open = wp != 0;
    final hx = open ? 25.0 : 24.0, hy = open ? 18.0 : 23.0;
    b.line(22, 18, hx - 1, hy, sleeve, width: 3);
    if (open) {
      b.rect(23, 15, 30, 18, 'grip');
      b.rect(23, 14, 26, 16, 'page');
      b.rect(27, 14, 30, 16, 'page');
      if (wp == 2 || wp == 3) {
        b.n++;
        for (final p in const [(33, 12), (35, 15), (34, 18), (37, 11), (31, 10)]) {
          b.put(p.$1, p.$2, 'spark');
        }
      }
    } else {
      b.rect(23, 20, 29, 24, 'grip');
      b.rect(24, 21, 29, 21, 'page');
    }
    b.rect(hx.toInt() - 1, hy.toInt(), hx.toInt() + 1, hy.toInt() + 1, hand);
  } else {
    final g = _grip(f.arm, wp);
    b.line(22, 18, g.hx - 1, g.hy - 1, sleeve, width: 3);
    b.ell(22.6, 18, 2.6, 2.2, sleeve);
    _weapon(b, f.arm, g.hx + 1, g.hy - 1.5, g.dx, g.dy, g.len, slash: wp == 2 && const [1, 4, 6].contains(f.arm));
    b.rect(g.hx.toInt() - 1, g.hy.toInt(), g.hx.toInt() + 1, g.hy.toInt() + 1, hand);
    if (f.arm == 4 && !f.shield) {
      // the second dagger, in the left hand, held out to the side
      _weapon(b, 4, 6, 24, -5, -4, 5);
      b.rect(6, 24, 8, 25, hand);
    }
  }
  if (f.arm == 3 || f.arm == 7) b.ell(22.6, 18, 2.6, 2.2, sleeve);
  if (f.heavy) b.rect(22, 20, 24, 20, 'trim');

  // ---- the shield, in front of the left arm
  if (f.shield) {
    final sy = hurt ? 16 : 18;
    if (f.roundShield) {
      b.ell(6.5, sy + 6.0, 5.4, 5.6, 'shield');
      b.ell(6.5, sy + 6.0, 1.8, 1.8, 'metal');
    } else {
      b.rows(1, sy, [
        ...List.filled(7, '##########'),
        '.########.',
        '..######..',
        '...####...',
        '....##....',
      ], 'shield');
      b.rect(1, sy, 10, sy, 'trim');
      b.line(1, sy, 1, sy + 7, 'trim');
      b.line(10, sy, 10, sy + 7, 'trim');
      b.rows(3, sy + 2, ['..##..', '..##..', '######', '..##..', '..##..', '..##..'], 'charge');
    }
  }
  lower();
}

// ---------------------------------------------------------------------------- the hero

/// a job's colour: earth, green, red, blue, purple, black, cream, gold, teal, steel, orange
const _tint = [
  Color(0xFF7A5A3E),
  Color(0xFF3A7A48),
  Color(0xFFAE2E28),
  Color(0xFF3360AE),
  Color(0xFF74408E),
  Color(0xFF38353F),
  Color(0xFFE6DFCB),
  Color(0xFFC9A03A),
  Color(0xFF2C7A74),
  Color(0xFF6E7684),
  Color(0xFFC9682A),
];

/// blade, by the weapon's grade: wood, iron, steel, bright steel, crystal, gold, blood steel
const _weaponBlade = [
  Color(0xFF9A7B5A),
  Color(0xFFA8B0BA),
  Color(0xFFC3CDD9),
  Color(0xFFE4EAF0),
  Color(0xFF9AD8FF),
  Color(0xFFF2D272),
  Color(0xFFC4505E),
];
const _weaponHilt = [
  Color(0xFF6E4A2E),
  Color(0xFF5A3A22),
  Color(0xFF8E1B16),
  Color(0xFF1F3F73),
  Color(0xFF5A2A6B),
  Color(0xFF7A5A1C),
  Color(0xFF2A1E28),
];

/// shield: wood, iron, steel, silver, gold, bright gold, bone
const _shieldTone = [
  Color(0xFF94643A),
  Color(0xFF8E959E),
  Color(0xFF3360AE),
  Color(0xFFAE2E28),
  Color(0xFF74408E),
  Color(0xFFE8BC3A),
  Color(0xFFD8D0BC),
];
const _cloakTone = [
  Color(0xFF7A5A3E),
  Color(0xFF3A7A48),
  Color(0xFFAE2E28),
  Color(0xFF3360AE),
  Color(0xFF74408E),
  Color(0xFFC9A03A),
  Color(0xFF2A2433),
];

Color _darker(Color c, double f) => Color.lerp(c, Colors.black, f)!;

final _heroCache = <String, PixelArt>{};

/// The hero for a pose and frame. [tier] is the job's tier: from tier 2 a fighter wears plate, from tier 3 the trim
/// turns to gold on a dark field.
PixelArt heroArt(
  HeroPose pose,
  int frame, {
  required int weapon,
  required int shield,
  required int cloak,
  required Garb garb,
  int tier = 0,
}) {
  final key = '${pose.index}/$frame/$weapon/$shield/$cloak/${garb.head}/${garb.arm}/${garb.tint}/$tier';
  final hit = _heroCache[key];
  if (hit != null) return hit;
  final arm = garb.arm.clamp(0, 7);
  final fighter = const [1, 2, 6].contains(arm);
  final heavy = garb.head == 2 || (tier >= 2 && fighter);
  final robe = !heavy && (arm == 5 || arm == 7 || garb.head == 3);
  final f = _Fig(
    head: garb.head.clamp(0, 6),
    arm: arm,
    shield: shield >= 0 && fighter,
    roundShield: shield == 0,
    cape: cloak >= 0,
    heavy: heavy,
    robe: robe,
    hairStyle: switch (garb.head) {
      4 => 'neat',
      5 => 'swept',
      _ => 'spiky',
    },
  );
  final tint = _tint[garb.tint.clamp(0, _tint.length - 1)];
  final cape = _cloakTone[cloak.clamp(0, 6)];
  final sh = _shieldTone[shield.clamp(0, 6)];
  final pal = <String, _T>{
    ..._common,
    'coat': _of(tint),
    'hood': _of(_darker(tint, .12)),
    'hat': _of(tint),
    'tabard': _of(tint),
    'plume': _of(cloak >= 0 ? cape : tint),
    'gem': _of(cloak >= 0 ? cape : const Color(0xFFAE2E28)),
    'cape': _of(_darker(cape, .16)),
    'metal': tier >= 4 && heavy ? _of(const Color(0xFF6E7488)) : _steel,
    'blade': _of(_weaponBlade[weapon.clamp(0, 6)]),
    'grip': _of(_weaponHilt[weapon.clamp(0, 6)]),
    'shield': _of(sh),
    'charge': shield == 5 ? _of(tint) : _gold,
    'spark': _one(0xFF9AD8FF),
    'mask': _of(const Color(0xFFAE2E28)),
    'beard': _of(const Color(0xFFE6E2D6)),
  };
  final b = _B(figW, figH);
  _figure(b, f, pose, frame);
  final art = b.render(pal);
  if (_heroCache.length > 400) _heroCache.clear();
  return _heroCache[key] = art;
}

// ---------------------------------------------------------------------------- enemies (facing left)

/// a = main colour, b = second colour, w = eye, blade or tusk, g = grip, s = skin, p = legs
const _tones = <String, List<Map<String, Color>>>{
  'wolf': [
    {'a': Color(0xFF5A5560), 'b': Color(0xFF2E2B33), 'w': Color(0xFFFF4A2E)},
    {'a': Color(0xFF2A2730), 'b': Color(0xFF141217), 'w': Color(0xFFFF2A1A)},
  ],
  'boar': [
    {'a': Color(0xFF5E3A28), 'b': Color(0xFF2A1A12), 'w': Color(0xFFFF4A2E)},
  ],
  'bat': [
    {'a': Color(0xFF3A2E3E), 'b': Color(0xFF1E1622), 'w': Color(0xFFFF4A2E)},
  ],
  'count': [
    {
      'a': Color(0xFF221D28),
      'b': Color(0xFF7A1420),
      'w': Color(0xFFD9DEE4),
      'g': Color(0xFF3B271A),
      's': Color(0xFFD6D0DE),
    },
  ],
  'bandit': [
    {
      'a': Color(0xFF4E5A44),
      'b': Color(0xFF2A211B),
      'w': Color(0xFFC3CDD9),
      'g': Color(0xFF5A3A22),
      's': Color(0xFFD9A678),
      'p': Color(0xFF4A463D),
    },
    {
      'a': Color(0xFF7A5434),
      'b': Color(0xFF8E1B16),
      'w': Color(0xFFC3CDD9),
      'g': Color(0xFF5A3A22),
      's': Color(0xFFD9A678),
      'p': Color(0xFF3B3A36),
    },
    {
      'a': Color(0xFF5A6A30),
      'b': Color(0xFF2A211B),
      'w': Color(0xFF9A7B5A),
      'g': Color(0xFF5A3A22),
      's': Color(0xFFE8B98A),
      'p': Color(0xFF4A463D),
    },
  ],
  'knight': [
    {'a': Color(0xFF4A4E58), 'b': Color(0xFF8E1B16), 'w': Color(0xFFD9DEE4), 'g': Color(0xFF5A3A22)},
    {'a': Color(0xFF8C94A2), 'b': Color(0xFF1F3F73), 'w': Color(0xFFEFF3F6), 'g': Color(0xFF9A7B2C)},
    {'a': Color(0xFF3A3248), 'b': Color(0xFF5A2A6B), 'w': Color(0xFFB9A6DA), 'g': Color(0xFF3B3A36)},
    {'a': Color(0xFFC9A54A), 'b': Color(0xFF8E1B16), 'w': Color(0xFFF6F2E4), 'g': Color(0xFF5A3A22)},
  ],
  'skeleton': [
    {'a': Color(0xFFEDE8D8), 'w': Color(0xFFB8BEC6), 'g': Color(0xFF5A3A22)},
    {'a': Color(0xFFC9B8E8), 'w': Color(0xFFF2D272), 'g': Color(0xFF5A2A6B)},
  ],
  'mage': [
    {
      'a': Color(0xFF2E3F6B),
      'b': Color(0xFFC9A54A),
      'w': Color(0xFF8FD0E8),
      'g': Color(0xFF5A3A22),
      's': Color(0xFFD9C3A8),
    },
    {
      'a': Color(0xFF5A2A6B),
      'b': Color(0xFFC9A54A),
      'w': Color(0xFFE39A91),
      'g': Color(0xFF3B271A),
      's': Color(0xFFD9C3A8),
    },
  ],
  'gargoyle': [
    {'a': Color(0xFF8C919C), 'w': Color(0xFFFF5A3C)},
  ],
  'dragon': [
    {'a': Color(0xFF8E1B16), 'b': Color(0xFFC9A54A), 'w': Color(0xFFFFE066)},
  ],
};

final _enemyCache = <String, PixelArt>{};

PixelArt enemyArt(String sprite, int tone) {
  final l = _tones[sprite] ?? _tones['wolf']!;
  final t = l[tone.clamp(0, l.length - 1)];
  final key = '$sprite/${tone.clamp(0, l.length - 1)}';
  final hit = _enemyCache[key];
  if (hit != null) return hit;
  Color c(String k, Color or) => t[k] ?? or;
  final a = c('a', const Color(0xFF8E8A9C));
  final pal = <String, _T>{
    ..._common,
    'a': _of(a),
    'al': _of(Color.lerp(a, Colors.white, .45)!),
    'ad': _of(_darker(a, .35)),
    'b': _of(c('b', _darker(a, .4))),
    'w': _of(c('w', const Color(0xFFFFE066))),
    'eye': _one(c('w', const Color(0xFFFFE066)).toARGB32()),
    'stone': _of(a),
    'b2': _of(_darker(a, .55)),
  };
  late PixelArt art;
  switch (sprite) {
    case 'bandit' || 'knight' || 'skeleton' || 'mage' || 'count':
      final f = switch (sprite) {
        'bandit' => const _Fig(head: 1, arm: 4, mask: true),
        'count' => const _Fig(head: 4, arm: 1, cape: true, heavy: true),
        'knight' => const _Fig(head: 2, arm: 1, heavy: true, visor: true, shield: true, cape: true),
        'skeleton' => const _Fig(head: 0, arm: 1, bone: true),
        _ => const _Fig(head: 3, arm: 5, robe: true, beard: true),
      };
      pal.addAll({
        'coat': _of(a),
        'hood': _of(_darker(a, .12)),
        'hat': _of(a),
        'tabard': _of(c('b', a)),
        'plume': _of(c('b', a)),
        'cape': _of(_darker(c('b', a), .2)),
        'metal': _of(sprite == 'knight' ? a : const Color(0xFFC3CDD9)),
        'blade': _of(c('w', const Color(0xFFC3CDD9))),
        'grip': _of(c('g', const Color(0xFF5A3A22))),
        'shield': _of(c('b', a)),
        'charge': _of(c('w', const Color(0xFFE8BC3A))),
        'mask': _of(c('b', const Color(0xFF2A211B))),
        'beard': _of(const Color(0xFFE6E2D6)),
        'gem': _of(c('w', a)),
        'leather': _of(c('p', const Color(0xFF6E4A2E))),
        if (sprite == 'skeleton') 'skin': _of(a),
        if (t['s'] != null) 'skin': _of(t['s']!),
        'hair': _of(const Color(0xFF3A3434)),
        // the people you fight look back with burning eyes
        'eyew': _one(0xFFFF4A2E),
        'iris': _one(0xFFFFE066),
      });
      final b = _B(figW, figH);
      _figure(b, f, HeroPose.idle, 0);
      art = b.render(pal, mirror: true);
    default:
      // the dragon, last of the guards, is drawn on a larger board
      final b = sprite == 'dragon' ? _B(40, 30) : _B(32, 32);
      _beast(b, sprite);
      art = b.render(pal);
  }
  return _enemyCache[key] = art;
}

void _beast(_B b, String kind) {
  switch (kind) {
    case 'boar':
      // head low, tusks out, the back bristling
      b.grid(
        0,
        15,
        const [
          '...........#.#.#.#.#............',
          '..........d#d#d#d#d#d...........',
          '.......dddaaaaaaaaaaaddd........',
          '.....ddaaaaaaaaaaaaaaaaadd......',
          '...ddaEaaaaaaaaaaaaaaaaaaad.....',
          '..lallaaaaaaaaaaaaaaaaaaaaad.dd.',
          '.lllaaaaaaaaaaaaaaaaaaaaaaaadad.',
          'lnllaaaaaaaaaaaaaaaaaaaaaaaad...',
          'llllWaaaaaaaaaaaaaaaaaaaaaaad...',
          '.ddWWdaaaaaaaaaaaaaaaaaaaaad....',
          '...W..daaaadddddddddddaaaad.....',
          '......daaad.......daaaddaaad....',
          '......daad........daad..daad....',
          '......dad.........dad...dad.....',
          '.....dddd........dddd..dddd.....',
        ],
        const {'a': 'a', 'd': 'ad', 'l': 'al', 'n': 'lash', 'E': 'ember', 'W': 'bone', '#': 'b'},
      );
    case 'bat':
      // wings spread wide, eyes burning, fangs bared
      b.mirrored(
        0,
        5,
        const [
          'A...............',
          'AA..............',
          'AAA.............',
          'AAAA.........B..',
          'AAAAA........BB.',
          'AAAAAA......BBBB',
          'AAAAAAA....BBBBB',
          'AAAAAAAA..BBEEBB',
          'AAAAAAAAABBBEEBB',
          'AAAAAAAAABBBBBBB',
          'AAAAAAAAABBBBBBB',
          '.A.AAAAAABBBBWBB',
          '...A.AAAABBBBWBB',
          '.....A.AABBBBBBB',
          '.......A.ABBBBBB',
          '..........BBBBBB',
          '...........BB.BB',
          '...........B..BB',
        ],
        const {'A': 'ad', 'B': 'a', 'E': 'ember', 'W': 'bone'},
      );
    case 'gargoyle':
      b.ox = 4;
      b.rows(0, 6, [
        '###.................###',
        '#####.............#####',
        '#######.........#######',
        '########.......########',
        '.#######.......#######.',
        '..#####.........#####..',
      ], 'ad');
      b.ell(11.5, 22, 7, 7.5, 'a');
      b.ell(11.5, 12, 6.5, 6, 'a');
      b.rows(5, 3, ['#..........#', '##........##', '.##......##.'], 'al');
      b.n++;
      for (final ex in const [8, 13]) {
        b.rect(ex, 11, ex + 1, 12, 'ember');
      }
      b.rect(9, 15, 14, 15, 'lash');
      b.put(10, 16, 'eyew');
      b.put(13, 16, 'eyew');
      b.rect(5, 28, 9, 30, 'a');
      b.rect(14, 28, 18, 30, 'a');
      b.rows(17, 26, ['....###', '..####.', '####...'], 'a');
    case 'dragon':
      // the last guard, side on: wing spread behind, fire between the teeth
      b.grid(
        0,
        0,
        const [
          '.........W...W...............W..........',
          '........W...W........W......Wv..........',
          '........W..W.........Wv....Wvvv.........',
          '.....aaWaaW.........Wvvv...Wvvv......W..',
          '....aaaaaWaa........Wvvv..Wvvvvv...WWv..',
          '...aaaaaaaaaa.......WvvvvWvvvvvv..Wvvv..',
          '..aaaaaEEaaaaa.....WvvvvWvvvvvvvWWvvvv..',
          '..aaaaaaaaaaaa.....WvvvWvvvvvvvWvvvvvv..',
          'aaaaaaaaaaaaaa.....WvvWvvvvvvWWvvvvvv...',
          'aaaaaaaaaaaaaa....WvvvWvvvvvWvvvvvvvv...',
          'WWWWWWmaaaaaaad...WvvWvvvvWWvvvvvvvvv...',
          'FFFFFmmaaaaaaaaa..WvWvvvvWvvvvvvvvvvv...',
          'FFFFFmmm.aaaaaaaaWdWvvdWWvvvvvvvvvvvv...',
          'FFFFFmma..aaaaaaaWvaaaaaaavvvvvvvvv.....',
          'mWaWaWaa...aaaaaaaaaaaaaaaaavvvvvv......',
          '.aaaaaaaa...aaaaaaaaaaaaaaaaaavv.......d',
          '.a..........aaaaaaaaaaaaaaaaaaa........d',
          '.............aaaaabbbbbaaaaaaaa.......dd',
          '.............aaaabbbbbbbaaaaaaaa......dd',
          '.............aaabbbbbbbbbaaaaaaa.....aad',
          '.............aabbbbbbbbbbbaaaaaa.....aad',
          '.............aabbbbbbbbbbbaaaaaa....aaaa',
          '..............abbbbbbbbbbbaaaaa....aaaaa',
          '..............aaaaabbbbbaaaaaaaaaaaaaaa.',
          '...............aaaabbbbbaaaaaa.aaaaa....',
          '...............aaaabbbbaaaaa.....a......',
          '...............aaaaaaaaaaaaa............',
          '...............aaaa.....aaaa............',
          '...............aaaa.....aaaa............',
          '..............WWWWWW...WWWWWW...........',
        ],
        const {'a': 'a', 'd': 'ad', 'v': 'b2', 'b': 'b', 'E': 'eye', 'W': 'bone', 'm': 'lash', 'F': 'ember'},
      );
    default: // wolf: head low, jaws open, hackles up, tail raised
      b.grid(
        0,
        12,
        const [
          '......dd..dd....................',
          '.....dad.dad....................',
          '.....daadaad......d.d.d.d.......',
          '....daaaaaaad....dadadadad......',
          '...daaddaaaaaddddaaaaaaaaadd..dd',
          '..daaEEaaaaaaaaaaaaaaaaaaaaad.da',
          '.ddaaaaaaaaaaaaaaaaaaaaaaaaaadda',
          'dlllaaaaaaaaaaaaaaaaaaaaaaaaaad.',
          'WlWlWdaaaaaaaaaaaaaaaaaaaaaaad..',
          'mmmmmmdaaaaaaaaaaaaaaaaaaaaad...',
          'rmmmmmdaaaallllllaaaaaaaaaad....',
          'WrWrWddaaallllllllaaaaaaaad.....',
          '.lllldaaaddddddddddaaaaaadd.....',
          '..dd.daaad........daaad.daad....',
          '......daad........daad...daad...',
          '.....daad.........daad...daad...',
          '.....dad..........dad.....dad...',
          '....dad..........dad......dad...',
          '...WdWd.........WdWd.....WdWd...',
        ],
        const {'a': 'a', 'd': 'ad', 'l': 'al', 'E': 'ember', 'W': 'bone', 'm': 'lash', 'r': 'mouth'},
      );
  }
}

// ---------------------------------------------------------------------------- drawing

class PixelPainter extends CustomPainter {
  final List<String> grid;
  final Map<String, Color> palette;
  final bool mirror;

  /// 0..1: everything turns white (the flash of a hit)
  final double flash;
  PixelPainter(this.grid, this.palette, {this.mirror = false, this.flash = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final cols = grid.fold<int>(0, (m, r) => max(m, r.length));
    final px = min(size.width / cols, size.height / grid.length);
    final ox = (size.width - cols * px) / 2, oy = size.height - grid.length * px;
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final c = palette[row[x]];
        if (c == null) continue;
        p.color = flash > 0 ? Color.lerp(c, Colors.white, flash)! : c;
        final dx = mirror ? cols - 1 - x : x;
        canvas.drawRect(Rect.fromLTWH(ox + dx * px, oy + y * px, px + 0.5, px + 0.5), p);
      }
    }
  }

  @override
  bool shouldRepaint(PixelPainter old) =>
      old.grid != grid || old.flash != flash || old.mirror != mirror || old.palette != palette;
}

/// The hero, alive: breathes when idle, walks, strikes, staggers. With calm motion it stands still.
class HeroSprite extends StatefulWidget {
  final int weapon, shield, cloak;
  final Garb garb;

  /// the job's tier: plate and gold trim come with it
  final int tier;
  final HeroPose pose;
  final double size;
  final bool mirror;

  /// a job not yet reached: the shape only, in one colour
  final bool shadow;
  const HeroSprite({
    super.key,
    this.garb = const Garb(6, 0, 0),
    this.tier = 0,
    this.shadow = false,
    this.weapon = 0,
    this.shield = -1,
    this.cloak = -1,
    this.pose = HeroPose.idle,
    this.size = 72,
    this.mirror = false,
  });

  @override
  State<HeroSprite> createState() => _HeroSpriteState();
}

class _HeroSpriteState extends State<HeroSprite> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = Look.of(context).calm;
    if (_calm) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final frames = switch (widget.pose) {
              HeroPose.walk => 4,
              HeroPose.attack => 3,
              _ => 2,
            };
            final speed = widget.pose == HeroPose.idle ? 1 : (widget.pose == HeroPose.walk ? 2 : 1);
            final f = _calm || widget.shadow ? 0 : (_c.value * frames * speed).floor() % frames;
            final art = heroArt(
              widget.pose,
              f,
              weapon: widget.weapon,
              shield: widget.shield,
              cloak: widget.cloak,
              garb: widget.garb,
              tier: widget.tier,
            );
            final palette = widget.shadow ? {for (final k in art.palette.keys) k: pal.line} : art.palette;
            return CustomPaint(
              size: Size(widget.size, widget.size * 18 / 16),
              painter: PixelPainter(
                art.grid,
                palette,
                mirror: widget.mirror,
                flash: widget.pose == HeroPose.hurt ? 0.5 : 0,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// An enemy: bobs gently, flashes white when struck, sinks away when beaten.
class EnemySprite extends StatefulWidget {
  final String sprite;
  final int tone;
  final double size;
  final bool struck, beaten;
  const EnemySprite({
    super.key,
    required this.sprite,
    this.tone = 0,
    this.size = 96,
    this.struck = false,
    this.beaten = false,
  });

  @override
  State<EnemySprite> createState() => _EnemySpriteState();
}

class _EnemySpriteState extends State<EnemySprite> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = Look.of(context).calm;
    if (_calm) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = enemyArt(widget.sprite, widget.tone);
    final grid = art.grid;
    final ratio = grid.length / grid[0].length;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: widget.beaten ? 0 : 1,
          duration: const Duration(milliseconds: 700),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final bob = _calm ? 0.0 : (sin(_c.value * 2 * pi) > 0 ? 0.0 : widget.size / 16 / 2);
              return Transform.translate(
                offset: Offset(0, bob + (widget.beaten ? 10 : 0)),
                child: CustomPaint(
                  size: Size(widget.size, widget.size * ratio),
                  painter: PixelPainter(grid, art.palette, flash: widget.struck ? 0.7 : 0),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A foe on its own dark ground, the way the road shows it before a fight: a shadow under its feet and, behind a
/// boss, a red glow. The ground stays dark by daylight too, so that the burning eyes read.
class FoeStage extends StatelessWidget {
  final String sprite;
  final int tone;
  final bool boss;
  final double width;
  const FoeStage({super.key, required this.sprite, this.tone = 0, this.boss = false, this.width = 96});

  @override
  Widget build(BuildContext context) {
    final h = width * 0.88;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: width,
          height: h,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFF1E1C18))),
              if (boss)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, 0.5),
                        radius: 0.8,
                        colors: [Color(0x888E1B16), Color(0x001E1C18)],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: h * 0.07,
                child: Container(
                  width: width * 0.62,
                  height: h * 0.07,
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.all(Radius.elliptical(width * 0.31, h * 0.035)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: h * 0.08),
                child: EnemySprite(sprite: sprite, tone: tone, size: width * (boss ? 0.92 : 0.82)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
