/// Pixel art, drawn from letters. Each sprite is a grid of characters; a palette turns the characters into colours.
/// The hero is put together from a body, legs for the pose, and whatever gear is worn. Enemies are single grids
/// with a few colour sets ("tones"). Nothing here is an image file.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

const _k = Color(0xFF1C1B19);

// ---------------------------------------------------------------------------- the hero (16 x 18, facing right)

const _heroTop = [
  '................',
  '.....kkkkk......',
  '....khhhhhk.....',
  '....khhhsshk....',
  '....khsssssk....',
  '....khssksk.....',
  '.....kssssk.....',
  '.....kkssk......',
  '...ckkttttkk....',
  '..cckttttttsk...',
  '..cckttttttk....',
  '..cckttttttk....',
  '..cckkttttkk....',
];
const _legs = [
  // standing
  ['...c.kppppk.....', '.....kpkkpk.....', '.....kpk.kpk....', '....kbbk.kbbk...', '....kkkk.kkkk...'],
  // stride
  ['...c.kppppk.....', '....kppkkppk....', '...kppk..kppk...', '..kbbk....kbbk..', '..kkkk....kkkk..'],
  // passing
  ['...c.kppppk.....', '.....kppppk.....', '......kppk......', '.....kbbbbk.....', '.....kkkkkk.....'],
];

/// weapon overlays per pose: (x, y, char)
List<List<Object>> _weapon(int pose) {
  switch (pose) {
    case 1: // raised
      return [
        for (var i = 0; i < 6; i++) [12 + (i > 2 ? 1 : 0), 7 - i, 'w'],
        [11, 8, 'g'],
        [12, 8, 'g'],
        [13, 8, 'g'],
      ];
    case 2: // struck forward
      return [
        for (var i = 0; i < 5; i++) [11 + i, 9, 'w'],
        [10, 8, 'g'],
        [10, 9, 'g'],
        [10, 10, 'g'],
      ];
    default: // carried
      return [
        for (var i = 0; i < 6; i++) [12, 8 - i, 'w'],
        [11, 9, 'g'],
        [13, 9, 'g'],
      ];
  }
}

const _weaponBlade = [Color(0xFF9A7B5A), Color(0xFFB8BEC6), Color(0xFFD9DEE4), Color(0xFFEFF3F6), Color(0xFFC9B6E8), Color(0xFFF2D272)];
const _weaponHilt = [Color(0xFF5A3A22), Color(0xFF4A3520), Color(0xFF8E1B16), Color(0xFF1F3F73), Color(0xFF5A2A6B), Color(0xFF9A7B2C)];
const _shieldTone = [Color(0xFF8A6238), Color(0xFF8E959E), Color(0xFF5F6B7A), Color(0xFFDDE2E8), Color(0xFFC9A54A), Color(0xFFE8C766)];
const _cloakTone = [Color(0xFF6B4F3A), Color(0xFF2F5D3A), Color(0xFF8E1B16), Color(0xFF1F3F73), Color(0xFF5A2A6B), Color(0xFF9A7B2C)];

enum HeroPose { idle, walk, attack, hurt, cheer }

/// The hero's pixels for a pose and frame: a list of rows.
List<String> heroGrid(HeroPose pose, int frame, {required int weapon, required int shield, required int cloak}) {
  final legs = switch (pose) {
    HeroPose.walk => _legs[[1, 2, 1, 0][frame % 4]],
    HeroPose.attack => _legs[frame % 3 == 0 ? 0 : 1],
    _ => _legs[0],
  };
  final rows = [..._heroTop, ...legs].map((r) => r.split('')).toList();
  if (cloak < 0) {
    for (final r in rows) {
      for (var x = 0; x < r.length; x++) {
        if (r[x] == 'c') r[x] = '.';
      }
    }
  }
  final wp = switch (pose) {
    HeroPose.attack => frame % 3 == 0 ? 1 : 2,
    HeroPose.cheer => 1,
    _ => 0,
  };
  if (weapon >= 0) {
    for (final p in _weapon(wp)) {
      final x = p[0] as int, y = p[1] as int;
      if (y >= 0 && y < rows.length && x >= 0 && x < 16) rows[y][x] = p[2] as String;
    }
  }
  if (shield >= 0) {
    for (var y = 9; y <= 12; y++) {
      for (var x = 8; x <= 10; x++) {
        final edge = y == 9 || y == 12 || x == 8 || x == 10;
        rows[y][x] = edge ? 'k' : 'd';
      }
    }
    rows[12][8] = rows[12][10] = '.';
    rows[13][9] = 'k';
  }
  // breathing: on the second idle frame the head and shoulders sink one pixel
  var out = rows.map((r) => r.join()).toList();
  final sink = (pose == HeroPose.idle && frame.isOdd) || pose == HeroPose.hurt;
  if (sink) out = ['................', ...out.sublist(0, 12), ...out.sublist(13)];
  return out;
}

Map<String, Color> heroPalette(Pal pal, int rank, {required int weapon, required int shield, required int cloak}) => {
  'k': _k,
  'h': const Color(0xFF5A3A22),
  's': const Color(0xFFE8B98A),
  't': Pal.day.tincture(rank == 5 ? 2 : rank),
  'p': const Color(0xFF4A463D),
  'b': const Color(0xFF2A211B),
  'c': cloak >= 0 ? _cloakTone[cloak.clamp(0, 5)] : _k,
  'w': _weaponBlade[weapon.clamp(0, 5)],
  'g': _weaponHilt[weapon.clamp(0, 5)],
  'd': _shieldTone[shield.clamp(0, 5)],
};

// ---------------------------------------------------------------------------- enemies (facing left)

const _sprites = <String, List<String>>{
  'wolf': [
    '................',
    '................',
    '................',
    '..k..k..........',
    '.kak.kak........',
    '.kaakaak....kk..',
    'kaaaaaaakkkkaak.',
    'kawaaaaaaaaaaaak',
    'kaaaaaaaaaaaaak.',
    '.kkbbaaaaaaaaak.',
    '...kkaaaaaaaaak.',
    '....kakkaakkakk.',
    '....kak.kak.kak.',
    '....kak.kak.kak.',
    '....kk..kk..kk..',
    '................',
  ],
  'boar': [
    '................',
    '................',
    '................',
    '......kkkkkk....',
    '...kkkaaaaaakk..',
    '..kaaaaaaaaaaak.',
    '.kaaaaaaaaaaaaak',
    'kawaaaaaaaaaaaak',
    'kaaaaaaaaaaaaaak',
    'kbbaaaaaaaaaaaak',
    '.wwkaaaaaaaaaak.',
    '.w..kakkaakkak..',
    '....kak.kak.kak.',
    '....kak.kak.kak.',
    '....kk..kk..kk..',
    '................',
  ],
  'bandit': [
    '................',
    '......kkkkk.....',
    '.....kaaaaak....',
    '....kaassaaak...',
    '....ksssssak....',
    '.....kskssak....',
    '.....kbbbbk.....',
    '......kbbk......',
    '....kkaaaakk....',
    '..wkaaaaaaak....',
    '..w.kaaaaaak....',
    '..w.kaaaaaak....',
    '..g.kkaaaakk....',
    '.....kppppk.....',
    '....kpk..kpk....',
    '...kbbk.kbbk....',
  ],
  'knight': [
    '.......b........',
    '......kbk.......',
    '.....kaaak......',
    '....kaaaaak.....',
    '....kakkkak.....',
    '....kawawak.....',
    '....kaaaaak.....',
    '.....kkkkk......',
    '..w.kaabaakk....',
    '..wkaaabaaaak...',
    '..w.kaabaaak....',
    '..w.kaaaaaak....',
    '.ggg.kaaaak.....',
    '.....kakkak.....',
    '....kak..kak....',
    '...kaak..kaak...',
  ],
  'skeleton': [
    '................',
    '.....kkkkk......',
    '....kaaaaak.....',
    '....kakakak.....',
    '....kaaaaak.....',
    '.....kakak......',
    '......kkk.......',
    '....kkkakkk.....',
    '..w.kakakak.....',
    '..wkakaaakak....',
    '..w..kakak.k....',
    '..w..kaaak......',
    '..g...kak.......',
    '.....kakak......',
    '....kak.kak.....',
    '...kaak.kaak....',
  ],
  'mage': [
    '.......k........',
    '......kak.......',
    '.....kaaak......',
    '....kaaaaak.....',
    '...kkkkkkkkk....',
    '....ksssssk.....',
    '.w..kskskk......',
    'www..ksssk......',
    '.w..kaaaaak.....',
    '.g.kaaabaaak....',
    '.gkaaaabaaak....',
    '.g.kaaabaaak....',
    '.g.kaaaaaaak....',
    '.g.kaaaaaaak....',
    '.g.kaaaaaaak....',
    '...kkkkkkkkk....',
  ],
  'gargoyle': [
    '................',
    'k.............k.',
    'kk...k...k...kk.',
    'kak..kkkkk..kak.',
    'kaak.kaaak.kaak.',
    'kaaakkawakkaaak.',
    'kaaaakaaakaaaak.',
    '.kaaaakkkaaaak..',
    '..kaaaaaaaaak...',
    '...kkaaaaakk....',
    '....kaaaaak.....',
    '....kaakaak.....',
    '....kak.kak.....',
    '...kaak.kaak....',
    '...kkk..kkk.....',
    '................',
  ],
  'dragon': [
    '........................',
    '..k...k.................',
    '..kk.kk.........kk......',
    '.kaakaak.......kaak.....',
    'kaaaaaaak.....kaaaak....',
    'kawaaaaaak...kaaaaaak...',
    'kaaaaaaaaak.kaaaaaaaak..',
    'kbbaaaaaaakkaaakkkaaaak.',
    '.kkkkaaaaaaaaaak..kkaaak',
    '.w.w.kaaaaaaaaak....kkk.',
    '.....kaaaaaaaaaak.......',
    '....kaabbbbbaaaaak......',
    '....kaabbbbbaaaaaak.....',
    '....kaabbbbbaaaaaaak....',
    '.....kaaaaaaaaakaaaak...',
    '.....kakkaaakkak.kaaak..',
    '.....kak.kak.kak..kaaak.',
    '....kaak.kak.kaak..kkak.',
    '....kkk..kk..kkk.....kk.',
    '........................',
  ],
};

/// a = main colour, b = second colour, w = eye, blade or tusk, g = grip, s = skin, p = legs
const _tones = <String, List<Map<String, Color>>>{
  'wolf': [
    {'a': Color(0xFF7D7A72), 'b': Color(0xFF3B3A36), 'w': Color(0xFFF2E6B0)},
  ],
  'boar': [
    {'a': Color(0xFF6B4A33), 'b': Color(0xFF3B271A), 'w': Color(0xFFF4F0E0)},
  ],
  'bandit': [
    {'a': Color(0xFF3E4A3A), 'b': Color(0xFF2A211B), 'w': Color(0xFFB8BEC6), 'g': Color(0xFF5A3A22), 's': Color(0xFFD9A678), 'p': Color(0xFF4A463D)},
    {'a': Color(0xFF5C4630), 'b': Color(0xFF2A211B), 'w': Color(0xFFB8BEC6), 'g': Color(0xFF5A3A22), 's': Color(0xFFD9A678), 'p': Color(0xFF3B3A36)},
    {'a': Color(0xFF4A5A2E), 'b': Color(0xFF2A211B), 'w': Color(0xFF8A6238), 'g': Color(0xFF5A3A22), 's': Color(0xFFE8B98A), 'p': Color(0xFF4A463D)},
  ],
  'knight': [
    {'a': Color(0xFF34363C), 'b': Color(0xFF8E1B16), 'w': Color(0xFFD9DEE4), 'g': Color(0xFF5A3A22)},
    {'a': Color(0xFF6E7480), 'b': Color(0xFF1F3F73), 'w': Color(0xFFEFF3F6), 'g': Color(0xFF9A7B2C)},
    {'a': Color(0xFF2A2433), 'b': Color(0xFF5A2A6B), 'w': Color(0xFFB9A6DA), 'g': Color(0xFF3B3A36)},
    {'a': Color(0xFFB8963E), 'b': Color(0xFF8E1B16), 'w': Color(0xFFF6F2E4), 'g': Color(0xFF5A3A22)},
  ],
  'skeleton': [
    {'a': Color(0xFFE9E4D4), 'w': Color(0xFFB8BEC6), 'g': Color(0xFF5A3A22)},
    {'a': Color(0xFFB9A6DA), 'w': Color(0xFFF2D272), 'g': Color(0xFF5A2A6B)},
  ],
  'mage': [
    {'a': Color(0xFF2E3F6B), 'b': Color(0xFFC9A54A), 'w': Color(0xFF8FD0E8), 'g': Color(0xFF5A3A22), 's': Color(0xFFD9C3A8)},
    {'a': Color(0xFF5A2A6B), 'b': Color(0xFFC9A54A), 'w': Color(0xFFE39A91), 'g': Color(0xFF3B271A), 's': Color(0xFFD9C3A8)},
  ],
  'gargoyle': [
    {'a': Color(0xFF6B7078), 'w': Color(0xFFE39A91)},
  ],
  'dragon': [
    {'a': Color(0xFF3F6B4A), 'b': Color(0xFFC9B37A), 'w': Color(0xFFF2D272)},
  ],
};

List<String> enemyGrid(String sprite) => _sprites[sprite] ?? _sprites['wolf']!;
Map<String, Color> enemyPalette(String sprite, int tone) {
  final l = _tones[sprite] ?? _tones['wolf']!;
  return {'k': _k, ...l[tone.clamp(0, l.length - 1)]};
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
  bool shouldRepaint(PixelPainter old) => old.grid != grid || old.flash != flash || old.mirror != mirror || old.palette != palette;
}

/// The hero, alive: breathes when idle, walks, strikes, staggers. With calm motion it stands still.
class HeroSprite extends StatefulWidget {
  final int rank, weapon, shield, cloak;
  final HeroPose pose;
  final double size;
  final bool mirror;
  const HeroSprite({
    super.key,
    required this.rank,
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
    final palette = heroPalette(pal, widget.rank, weapon: widget.weapon, shield: widget.shield, cloak: widget.cloak);
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
            final f = _calm ? 0 : (_c.value * frames * speed).floor() % frames;
            return CustomPaint(
              size: Size(widget.size, widget.size * 18 / 16),
              painter: PixelPainter(
                heroGrid(widget.pose, f, weapon: widget.weapon, shield: widget.shield, cloak: widget.cloak),
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
  const EnemySprite({super.key, required this.sprite, this.tone = 0, this.size = 96, this.struck = false, this.beaten = false});

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
    final grid = enemyGrid(widget.sprite);
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
                  painter: PixelPainter(grid, enemyPalette(widget.sprite, widget.tone), flash: widget.struck ? 0.7 : 0),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
