/// The coronation: shown once, right after a coronation trial is passed. About five seconds; a tap goes to the end.
/// The old shield turns over into the new one, rays open behind it, the title is written letter by letter, the
/// seal comes down. With calm motion everything is simply there.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/engine.dart';
import '../engine/lore.dart';
import '../engine/jobs.dart';
import 'lore.dart';
import 'root.dart';
import 'run.dart' show runRoute;
import 'theme.dart';
import 'widgets.dart';

class Coronation extends StatelessWidget {
  final int rank;
  final int right, total;
  final List<String> news;

  /// the job the build has just decided
  final Job? job;
  const Coronation({
    super.key,
    required this.rank,
    required this.right,
    required this.total,
    this.news = const [],
    this.job,
  });

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    // a coronation is held by candlelight; its button is gold
    return Look(pal: Pal.night, rank: Engine.maxRank, calm: look.calm, stamp: look.stamp, child: _Crowning(this));
  }
}

class _Crowning extends StatefulWidget {
  final Coronation c;
  const _Crowning(this.c);

  @override
  State<_Crowning> createState() => _CoronationState();
}

class _CoronationState extends State<_Crowning> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5600));

  /// the candle breathing and the rays turning, for as long as the page is open
  late final AnimationController _air = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  bool _horn = false, _crowned = false, _sealed = false, _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Look.of(context).calm) {
      _c.value = 1;
      App.I.sfx('fanfare', 0.8);
      return;
    }
    _air.repeat();
    _c.addListener(() {
      if (!_horn && _c.value > 0.2) {
        _horn = true;
        App.I.sfx('fanfare');
        App.I.haptic(strong: true);
      }
      if (!_crowned && _c.value > 0.6) {
        _crowned = true;
        App.I.haptic();
      }
      if (!_sealed && _c.value > 0.86) {
        _sealed = true;
        App.I.sfx('seal');
        App.I.haptic(strong: true);
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _air.dispose();
    super.dispose();
  }

  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  void _accept() {
    final job = widget.c.job;
    // the new character is introduced once, on its own page that only its button closes
    if (job == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(runRoute(JobIntro(job: job, rank: widget.c.rank)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final w = widget.c;
    final rank = w.rank;
    final name = rankNames[rank];
    final job = w.job;
    final lore = LoreBook.title(rank);
    // what else was won; the job already has its card
    final news = [
      for (final n in w.news.toSet())
        if (job == null || !(n.contains(job.name) || n.contains(job.perk.text))) n,
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_c.value < 1) _c.value = 1;
      },
      child: Leaf(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: AnimatedBuilder(
          animation: Listenable.merge([_c, _air]),
          builder: (context, _) {
            final turn = _span(0.2, 0.42, Curves.easeInOutCubic); // the shield turns over
            final grow = _span(0.06, 0.42, Curves.easeOutBack);
            final showNew = turn > 0.5;
            final flip = (cos(turn * pi)).abs().clamp(0.04, 1.0);
            final drop = _span(0.5, 0.64, Curves.bounceOut); // the crown comes down onto the shield
            final seal = _span(0.84, 0.94, Curves.easeOutBack);
            final end = _span(0.92, 1.0);
            final breath = look.calm ? 0.5 : 0.5 + 0.5 * sin(_air.value * 2 * pi * 4);
            return LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        Opacity(
                          opacity: _span(0.0, 0.1),
                          child: Text(
                            tr(
                              'TERCATAT DALAM KRONIK',
                              'ENTERED IN THE CHRONICLE',
                              'REGISTRADO EN LA CRÓNICA',
                              'CONSIGNÉ DANS LA CHRONIQUE',
                              'IN DIE CHRONIK EINGETRAGEN',
                              'REGISTRADO NA CRÔNICA',
                            ),
                            textAlign: TextAlign.center,
                            style: T.label(pal.gold),
                          ),
                        ),
                        SizedBox(
                          height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _RaysPainter(
                                      _span(0.36, 0.7),
                                      _c.value + _air.value,
                                      pal.gold,
                                      pal.gold,
                                      spin: look.calm ? 0 : _air.value * 2 * pi,
                                      glow: 0.12 + 0.08 * breath,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, 16),
                                child: Transform.scale(
                                  scale: 0.72 + 0.28 * grow,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.diagonal3Values(flip, 1, 1),
                                    child: Opacity(
                                      opacity: _span(0.04, 0.14),
                                      child: Shield(showNew ? rank : rank - 1, width: 124),
                                    ),
                                  ),
                                ),
                              ),
                              // the crown falls from above and settles on the shield's top
                              Transform.translate(
                                offset: Offset(0, -86 - 120 * (1 - drop)),
                                child: Opacity(
                                  opacity: _span(0.5, 0.54, Curves.linear),
                                  child: CustomPaint(size: const Size(84, 40), painter: _CrownPainter(pal.gold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: _span(0.44, 0.54),
                          child: Text(
                            tr(
                              'Engkau dinobatkan sebagai',
                              'You are crowned',
                              'Has sido coronado',
                              'Te voici couronné',
                              'Du wirst gekrönt zum',
                              'Você é coroado',
                            ),
                            textAlign: TextAlign.center,
                            style: T.display(21, pal.muted, italic: true),
                          ),
                        ),
                        Semantics(
                          label: name,
                          child: ExcludeSemantics(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < name.length; i++)
                                  Builder(
                                    builder: (context) {
                                      final t = _span(0.5 + i * 0.035, 0.62 + i * 0.035);
                                      return Opacity(
                                        opacity: t,
                                        child: Transform.translate(
                                          offset: Offset(0, 14 * (1 - t)),
                                          child: Text(name[i], style: T.display(60, pal.ink, height: 1.05)),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: _span(0.66, 0.76),
                          child: Text(
                            tr(
                              'Kosakata setara ${scoreLine(rank, App.I.banner)} · ${w.right} dari ${w.total} kata benar',
                              'Vocabulary on a par with ${scoreLine(rank, App.I.banner)} · ${w.right} of ${w.total} words right',
                              'Vocabulario equivalente a ${scoreLine(rank, App.I.banner)} · ${w.right} de ${w.total} palabras bien',
                              'Vocabulaire équivalent à ${scoreLine(rank, App.I.banner)} · ${w.right} mots justes sur ${w.total}',
                              'Wortschatz auf dem Niveau von ${scoreLine(rank, App.I.banner)} · ${w.right} von ${w.total} Wörtern richtig',
                              'Vocabulário no nível de ${scoreLine(rank, App.I.banner)} · ${w.right} de ${w.total} palavras certas',
                            ),
                            textAlign: TextAlign.center,
                            style: T.body(16, pal.muted, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // the job the build has chosen, sealed
                        Opacity(
                          opacity: _span(0.72, 0.82),
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - _span(0.72, 0.84))),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: pal.line),
                                borderRadius: BorderRadius.circular(12),
                                color: pal.field.withValues(alpha: 0.6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job == null
                                              ? tr(
                                                  'Gelar ini dijaga',
                                                  'This title is kept',
                                                  'Este título se conserva',
                                                  'Ce titre est conservé',
                                                  'Dieser Titel bleibt dir',
                                                  'Este título é seu',
                                                )
                                              : tr(
                                                  'Build-mu memilih jalan',
                                                  'Your build chose the path',
                                                  'Tu build eligió el camino',
                                                  'Ton build a choisi la voie',
                                                  'Dein Build hat den Weg gewählt',
                                                  'Seu build escolheu o caminho',
                                                ),
                                          style: T.body(13.5, pal.muted),
                                        ),
                                        if (job != null) ...[
                                          Text(job.name, style: T.display(26, pal.gold)),
                                          Text(job.perk.text, style: T.body(14.5, pal.muted, height: 1.35)),
                                        ] else
                                          Text(
                                            rank >= Engine.maxRank
                                                ? tr(
                                                    'Tidak ada gelar di atas ini. Jagalah.',
                                                    'There is no title above this one. Guard it.',
                                                    'No hay título por encima de este. Guárdalo.',
                                                    'Il n’y a pas de titre au-dessus. Garde-le.',
                                                    'Über diesem Titel gibt es keinen. Hüte ihn.',
                                                    'Não há título acima deste. Guarde-o.',
                                                  )
                                                : tr(
                                                    'Kata yang terlupa harus direbut kembali.',
                                                    'Words forgotten must be won back.',
                                                    'Las palabras olvidadas hay que recuperarlas.',
                                                    'Les mots oubliés doivent être reconquis.',
                                                    'Vergessene Wörter müssen zurückerobert werden.',
                                                    'Palavras esquecidas precisam ser reconquistadas.',
                                                  ),
                                            style: T.body(14.5, pal.muted, height: 1.35),
                                          ),
                                        if (news.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(news.take(2).join(' · '), style: T.body(13.5, pal.muted, height: 1.35)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Opacity(
                                    opacity: _span(0.84, 0.87, Curves.linear),
                                    child: Transform.rotate(
                                      angle: -0.16 * (1 - seal),
                                      child: Transform.scale(scale: 1.9 - 0.9 * seal, child: const Seal(size: 50)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _span(0.8, 0.9),
                          child: Text(
                            '“${lore.quote}”',
                            textAlign: TextAlign.center,
                            style: T.display(18, pal.ink, italic: true, height: 1.4),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          ignoring: end < 0.5,
                          child: Opacity(
                            opacity: end,
                            child: InkButton(
                              tr(
                                'Terima gelar',
                                'Accept the title',
                                'Aceptar el título',
                                'Accepter le titre',
                                'Titel annehmen',
                                'Aceitar o título',
                              ),
                              onTap: _accept,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// a gold crown of three points, each tipped with a pearl
class _CrownPainter extends CustomPainter {
  final Color gold;
  _CrownPainter(this.gold);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(0, h * 0.28)
      ..lineTo(w * 0.22, h * 0.62)
      ..lineTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.78, h * 0.62)
      ..lineTo(w, h * 0.28)
      ..lineTo(w * 0.92, h)
      ..lineTo(w * 0.08, h)
      ..close();
    canvas.drawPath(body, Paint()..color = gold);
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF9A7B2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.8, w * 0.84, h * 0.08), Paint()..color = const Color(0xFF9A7B2C));
    final pearl = Paint()..color = const Color(0xFFF1EBDD);
    for (final p in [Offset(0, h * 0.28), Offset(w * 0.5, h * 0.08), Offset(w, h * 0.28)]) {
      canvas.drawCircle(p, 3.6, pearl);
    }
    canvas.drawCircle(Offset(w * 0.5, h * 0.66), 4, Paint()..color = const Color(0xFF8E1B16));
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.gold != gold;
}

/// Rays that open behind the shield, and a little gold dust rising.
class _RaysPainter extends CustomPainter {
  final double open, time, spin, glow;
  final Color ray, dust;
  _RaysPainter(this.open, this.time, this.ray, this.dust, {this.spin = 0, this.glow = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero) + const Offset(0, 16);
    // the candle behind it all
    if (glow > 0) {
      canvas.drawCircle(
        c,
        150,
        Paint()
          ..shader = RadialGradient(
            colors: [
              dust.withValues(alpha: glow),
              dust.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: 150)),
      );
    }
    if (open <= 0) return;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = ray.withValues(alpha: 0.5);
    const n = 28;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * (2 * pi / n) + spin * 0.08;
      final long = i.isEven;
      final r0 = 88.0, r1 = r0 + (long ? 30 : 18) * open;
      canvas.drawLine(c + Offset(cos(a) * r0, sin(a) * r0), c + Offset(cos(a) * r1, sin(a) * r1), p);
    }
    final r = Random(11);
    final d = Paint();
    for (var i = 0; i < 26; i++) {
      final x = r.nextDouble(), s = r.nextDouble(), ph = r.nextDouble();
      final t = ((time * 1.6 + ph) % 1.0);
      final y = size.height * (0.95 - t * 0.9);
      d.color = dust.withValues(alpha: 0.55 * open * sin(t * pi));
      canvas.drawCircle(Offset(size.width * (0.12 + x * 0.76) + sin(t * 6 + ph * 6) * 6, y), 1 + s * 1.4, d);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.open != open || old.time != time || old.ray != ray || old.spin != spin || old.glow != glow;
}
