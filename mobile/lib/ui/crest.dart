/// The arms of a kingdom coming alive, shown when the learner goes to another kingdom: the shield rises out of the
/// dark, its beast moves (the dragon breathes fire, the lion roars, the griffin beats its wings and cries, the phoenix
/// flares, the eastern dragon sways after its pearl), the crown comes down, the motto unrolls. 2.5 s, a tap ends it;
/// with calm motion the arms only fade in. The pictures are made by content/tools/make_crests.py (assets/crest/<code>/),
/// drawn at half size and shown as large pixels; the voice is crest_<code> from make_music.py.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
import '../data/deck.dart';
import 'theme.dart';

/// shows the arms of the kingdom [code] over everything, until they have played or are tapped away
Future<void> showCrest(BuildContext context, String code) {
  final look = Look.of(context);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: look.calm ? Duration.zero : const Duration(milliseconds: 220),
      reverseTransitionDuration: look.calm ? Duration.zero : const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => Look(pal: Pal.night, rank: look.rank, calm: look.calm, child: CrestSplash(code)),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class CrestPart {
  final String name, group;
  const CrestPart(this.name, this.group);
}

class CrestGroup {
  final Offset pivot;
  final String? parent;
  const CrestGroup(this.pivot, this.parent);
}

/// what a kingdom's arms are made of: parts.json, read once
class CrestParts {
  final String code;
  final Size size, crown, scroll;
  final List<CrestPart> parts;
  final Map<String, CrestGroup> groups;
  final Offset focus;
  CrestParts._(this.code, this.size, this.crown, this.scroll, this.parts, this.groups, this.focus);

  static final _cache = <String, CrestParts>{};

  static Future<CrestParts> load(String code) async {
    final hit = _cache[code];
    if (hit != null) return hit;
    final m = json.decode(await rootBundle.loadString('assets/crest/$code/parts.json')) as Map<String, dynamic>;
    Size size(String k) => Size((m[k][0] as num).toDouble(), (m[k][1] as num).toDouble());
    Offset at(List p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
    final c = CrestParts._(
      code,
      size('size'),
      size('crown'),
      size('scroll'),
      [for (final p in m['parts'] as List) CrestPart(p['name'] as String, p['group'] as String)],
      {
        for (final e in (m['groups'] as Map).entries)
          e.key as String: CrestGroup(at(e.value['pivot'] as List), e.value['parent'] as String?),
      },
      at(m['focus'] as List),
    );
    return _cache[code] = c;
  }

  String path(String file) => 'assets/crest/$code/$file';
}

class CrestSplash extends StatefulWidget {
  final String code;
  const CrestSplash(this.code, {super.key});

  /// how long the arms play
  static const length = Duration(milliseconds: 2500);

  @override
  State<CrestSplash> createState() => _CrestSplashState();
}

class _CrestSplashState extends State<CrestSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: CrestSplash.length);
  CrestParts? _p;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final p = await CrestParts.load(widget.code);
    if (!mounted) return;
    // every picture is in memory before anything moves
    await Future.wait([
      for (final f in ['shield.png', 'full.png', 'crown.png', 'scroll.png', for (final q in p.parts) 'p_${q.name}.png'])
        precacheImage(AssetImage(p.path(f)), context),
    ]);
    if (!mounted) return;
    setState(() => _p = p);
    App.I.sfx('crest_${widget.code}');
    if (Look.of(context).calm) {
      _c.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    } else {
      await _c.forward();
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    _close();
  }

  void _close() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final p = _p;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Material(
        color: pal.bg,
        child: SafeArea(
          child: Center(
            child: p == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: FittedBox(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => _Arms(p, _c.value, Kingdom.of(widget.code)),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- the moving arms

double _ease(double t) => 1 - pow(1 - t.clamp(0.0, 1.0), 3).toDouble();
double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _back(double t) {
  final x = t.clamp(0.0, 1.0) - 1;
  const c = 1.7;
  return 1 + (c + 1) * x * x * x + c * x * x;
}

/// the beast's pose at t (0..1 of the splash): each group's turn in degrees (clockwise) and size, the light behind
/// the shield and how hard it shakes
class CrestPose {
  final Map<String, ({double turn, double grow})> g = {};
  double glow = 0, shake = 0;
  void set(String group, double turn, [double grow = 1]) => g[group] = (turn: turn, grow: grow);
}

/// the parts of the splash: shield rises 0-.12, the beast gathers itself .12-.28, acts .28-.56, settles .56-.68,
/// the crown comes down .64-.84, the motto unrolls .72-.9, the name .8-1
CrestPose poseOf(String code, double t) {
  final p = CrestPose();
  final prep = _ease(_span(t, .12, .28));
  final act = _ease(_span(t, .28, .34)) * (1 - _ease(_span(t, .56, .68)));
  final settle = _ease(_span(t, .56, .68));
  final secs = t * 2.5;
  final flick = sin(secs * 2 * pi * 7);
  p.glow = .35 + .65 * act;
  p.shake = act * (t < .5 ? 1 : 0);
  switch (code) {
    case 'es': // the dragon draws breath, then breathes fire
      final pre = prep * (1 - act) * (1 - settle);
      p.set('head', 12 * pre - 7 * act + 1.5 * act * flick);
      p.set('wingR', -10 * pre - 16 * act + 3 * act * flick);
      p.set('wingL', 10 * pre + 16 * act - 3 * act * flick);
      p.set('tail', 6 * pre + 9 * act * sin(secs * 2 * pi * 1.4));
      p.set('arms', -8 * pre - 12 * act);
      p.set('fire', 0, 1 + 1.4 * act + .1 * act * flick);
    case 'en': // the lion rears, then roars, its mane shaking
      final pre = prep * (1 - act) * (1 - settle);
      p.set('head', 9 * pre - 9 * act);
      p.set('mane', 3 * pre + 3.5 * act * sin(secs * 2 * pi * 9));
      p.set('tail', -6 * pre + 14 * act * sin(secs * 2 * pi * 1.6));
    case 'de': // the griffin beats its wings three times and cries
      final beat = _span(t, .12, .52);
      final flap = beat > 0 && beat < 1 ? sin(beat * 3 * 2 * pi) : 0.0;
      p.set('wingNear', -16 * flap);
      p.set('wingFar', -12 * flap);
      p.set('head', 11 * _ease(_span(t, .34, .42)) * (1 - settle));
      p.set('ruff', 4 * act * sin(secs * 2 * pi * 8));
      p.set('tail', 10 * act * sin(secs * 2 * pi * 1.5));
    case 'fr': // the phoenix opens its wings twice and flares
      final beat = _span(t, .12, .6);
      final flap = beat > 0 && beat < 1 ? sin(beat * 2 * 2 * pi) : 0.0;
      p.set('wingR', -13 * flap);
      p.set('wingL', 13 * flap);
      p.set('head', 7 * act);
      p.set('tail', 5 * sin(secs * 2 * pi * 1.2) * (1 - settle));
    case 'pt': // the eastern dragon sways after its pearl, which glows
      final live = _ease(_span(t, .12, .2)) * (1 - settle);
      p.set('body', 3 * sin(secs * 2 * pi * .9) * live);
      p.set('head', 7 * sin(secs * 2 * pi * .9 + 1) * live);
      p.set('pearl', 0, 1 + .25 * act + .05 * flick * act);
      p.shake = 0;
  }
  return p;
}

class _Arms extends StatelessWidget {
  final CrestParts p;
  final double t;
  final Kingdom k;
  const _Arms(this.p, this.t, this.k);

  static const canvas = Size(380, 520);
  static const shieldAt = Offset(60, 75);

  /// a group's transform on the shield, its parent's first
  Matrix4 _matrix(String group, CrestPose pose) {
    final g = p.groups[group];
    if (g == null) return Matrix4.identity();
    final m = g.parent == null ? Matrix4.identity() : _matrix(g.parent!, pose);
    final v = pose.g[group];
    if (v == null) return m;
    return m
      ..translateByDouble(g.pivot.dx, g.pivot.dy, 0, 1)
      ..rotateZ(v.turn * pi / 180)
      ..scaleByDouble(v.grow, v.grow, 1, 1)
      ..translateByDouble(-g.pivot.dx, -g.pivot.dy, 0, 1);
  }

  Widget _img(String file, Size s) => Image.asset(
    p.path(file),
    width: s.width,
    height: s.height,
    filterQuality: FilterQuality.none,
    gaplessPlayback: true,
  );

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final pose = poseOf(p.code, t);
    final rise = _ease(_span(t, 0, .12));
    final shake = pose.shake * 2.2 * sin(t * 2.5 * 2 * pi * 13);
    final atRest = t >= .7;
    final tint = Color(k.tint);
    final beast = Stack(
      children: [
        for (final q in p.parts)
          Transform(
            transform: q.group.isEmpty ? Matrix4.identity() : _matrix(q.group, pose),
            child: _img('p_${q.name}.png', p.size),
          ),
      ],
    );
    final crownT = _span(t, .64, .84);
    final scrollT = _ease(_span(t, .72, .9));
    final nameT = _ease(_span(t, .8, 1));
    return SizedBox.fromSize(
      size: canvas,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // candlelight behind the shield, warmer while the beast acts
          Positioned.fill(
            child: Opacity(
              opacity: rise,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.12),
                    radius: .62,
                    colors: [
                      Color.lerp(const Color(0xFF6B4A22), tint, .25)!.withValues(alpha: .55 * pose.glow),
                      pal.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: shieldAt.dx + shake,
            top: shieldAt.dy + 14 * (1 - rise),
            width: p.size.width,
            height: p.size.height,
            child: Opacity(
              opacity: rise,
              child: Stack(
                children: [
                  _img('shield.png', p.size),
                  beast,
                  // the arms at rest, exactly as drawn, once the beast has settled
                  if (atRest) Opacity(opacity: _ease(_span(t, .7, .8)), child: _img('full.png', p.size)),
                ],
              ),
            ),
          ),
          // sparks, embers and rings, free to leave the shield
          Positioned(
            left: shieldAt.dx + shake,
            top: shieldAt.dy,
            width: p.size.width,
            height: p.size.height,
            child: IgnorePointer(child: CustomPaint(painter: _Sparks(p.code, t, p.focus))),
          ),
          if (crownT > 0)
            Positioned(
              left: (canvas.width - p.crown.width) / 2,
              top: shieldAt.dy - p.crown.height + 11 - 90 * (1 - _back(crownT)),
              child: Opacity(opacity: _ease(crownT * 2), child: _img('crown.png', p.crown)),
            ),
          if (scrollT > 0)
            Positioned(
              left: (canvas.width - p.scroll.width) / 2,
              top: shieldAt.dy + p.size.height - 35,
              width: p.scroll.width,
              height: p.scroll.height,
              // unrolled from the middle outwards
              child: Center(
                child: ClipRect(
                  child: SizedBox(
                    width: p.scroll.width * scrollT,
                    child: OverflowBox(maxWidth: p.scroll.width, child: _img('scroll.png', p.scroll)),
                  ),
                ),
              ),
            ),
          if (nameT > 0)
            Positioned(
              left: 0,
              right: 0,
              top: shieldAt.dy + p.size.height + 52 + 6 * (1 - nameT),
              child: Opacity(
                opacity: nameT,
                child: Column(
                  children: [
                    Text(k.name, style: T.display(34, pal.ink)),
                    const SizedBox(height: 2),
                    Text(k.language, style: T.body(15, pal.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// what flies from the beast: embers from the dragon's jaws, rings of the lion's roar, feathers from the griffin,
/// sparks rising from the phoenix, light around the pearl. Seeded, so every showing is the same.
class _Sparks extends CustomPainter {
  final String code;
  final double t;
  final Offset at;
  _Sparks(this.code, this.t, this.at);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(7);
    final act = _span(t, .28, .62);
    if (act <= 0 || act >= 1) return;
    final paint = Paint();
    switch (code) {
      case 'es':
        for (var i = 0; i < 70; i++) {
          final born = r.nextDouble() * .8, life = .25 + r.nextDouble() * .2;
          final u = (act - born) / life;
          final vx = -(40 + r.nextDouble() * 70), vy = -10 + r.nextDouble() * 34, sz = 1.2 + r.nextDouble() * 2.2;
          if (u <= 0 || u >= 1) continue;
          final pos = at + Offset(vx * u * 1.4, vy * u + 30 * u * u);
          paint.color = Color.lerp(const Color(0xFFFFF1B0), const Color(0xFFE0561C), u)!.withValues(alpha: 1 - u);
          canvas.drawRect(Rect.fromCenter(center: pos, width: sz * 2, height: sz * 2), paint);
        }
      case 'en':
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        for (var i = 0; i < 3; i++) {
          final u = (act * 1.4 - i * .22);
          if (u <= 0 || u >= 1) continue;
          paint.color = const Color(0xFFE7C66A).withValues(alpha: (1 - u) * .9);
          canvas.drawArc(Rect.fromCircle(center: at, radius: 8 + 70 * u), pi * .72, pi * .56, false, paint);
        }
      case 'de':
        for (var i = 0; i < 16; i++) {
          final born = r.nextDouble() * .6, x = 120 + r.nextDouble() * 120, y = 10 + r.nextDouble() * 90;
          final u = (act - born) / .4;
          if (u <= 0 || u >= 1) continue;
          paint.color = const Color(0xFFEDEBE4).withValues(alpha: 1 - u);
          canvas.save();
          canvas.translate(x + 18 * sin(u * 6 + i), y + 60 * u);
          canvas.rotate(sin(u * 5 + i) * .8);
          canvas.drawOval(const Rect.fromLTWH(-4, -1.6, 8, 3.2), paint);
          canvas.restore();
        }
        if (_span(t, .34, .52) > 0 && _span(t, .34, .52) < 1) {
          final u = _span(t, .34, .52);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE7C66A).withValues(alpha: 1 - u);
          for (var i = 0; i < 2; i++) {
            canvas.drawArc(Rect.fromCircle(center: at, radius: 6 + 40 * u + i * 9), pi * .8, pi * .4, false, paint);
          }
        }
      case 'fr':
        for (var i = 0; i < 60; i++) {
          final born = r.nextDouble() * .8, x = 40 + r.nextDouble() * 180, life = .25 + r.nextDouble() * .25;
          final u = (act - born) / life;
          if (u <= 0 || u >= 1) continue;
          final pos = Offset(x + 8 * sin(u * 7 + i), 300 - 260 * u);
          paint.color = Color.lerp(const Color(0xFFFFE9A0), const Color(0xFFE8731E), u)!.withValues(alpha: 1 - u);
          canvas.drawRect(Rect.fromCenter(center: pos, width: 3, height: 3), paint);
        }
      case 'pt':
        final glow = sin(act * pi);
        paint.shader = RadialGradient(
          colors: [
            const Color(0xFFFFF0B0).withValues(alpha: .7 * glow),
            const Color(0x00FFF0B0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: 34));
        canvas.drawCircle(at, 34, paint);
        paint.shader = null;
        for (var i = 0; i < 18; i++) {
          final a = r.nextDouble() * 2 * pi, born = r.nextDouble() * .7;
          final u = (act - born) / .3;
          if (u <= 0 || u >= 1) continue;
          paint.color = const Color(0xFFFFF4C8).withValues(alpha: 1 - u);
          canvas.drawRect(
            Rect.fromCenter(center: at + Offset(cos(a), sin(a)) * (10 + 30 * u), width: 2.6, height: 2.6),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_Sparks old) => old.t != t || old.code != code;
}
