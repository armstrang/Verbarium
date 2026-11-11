/// The coronation: shown once, right after a coronation trial is passed. About five seconds; a tap goes to the end.
/// The old shield turns over into the new one, rays open behind it, the title is written letter by letter, the
/// seal comes down. With calm motion everything is simply there.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/engine.dart';
import '../engine/jobs.dart';
import 'lore.dart';
import 'root.dart';
import 'run.dart' show runRoute;
import 'theme.dart';
import 'widgets.dart';

class Coronation extends StatefulWidget {
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
  State<Coronation> createState() => _CoronationState();
}

class _CoronationState extends State<Coronation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  bool _horn = false, _sealed = false, _started = false;

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
    _c.addListener(() {
      if (!_horn && _c.value > 0.2) {
        _horn = true;
        App.I.sfx('fanfare');
        App.I.haptic(strong: true);
      }
      if (!_sealed && _c.value > 0.88) {
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
    super.dispose();
  }

  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final rank = widget.rank;
    final name = rankNames[rank];
    final tint = pal.tincture(rank);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_c.value < 1) _c.value = 1;
      },
      child: Leaf(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final turn = _span(0.2, 0.42, Curves.easeInOutCubic); // the shield turns over
            final grow = _span(0.06, 0.42, Curves.easeOutBack);
            final showNew = turn > 0.5;
            final flip = (cos(turn * pi)).abs().clamp(0.04, 1.0);
            final seal = _span(0.86, 0.96, Curves.easeOutBack);
            final end = _span(0.94, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Opacity(
                  opacity: _span(0.0, 0.1),
                  child: Center(child: Label(tr('Tercatat dalam kronik', 'Entered in the chronicle'))),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 268,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _RaysPainter(_span(0.36, 0.7), _c.value, pal.dark ? pal.gold : tint, pal.gold),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.72 + 0.28 * grow,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(flip, 1, 1),
                          child: Opacity(
                            opacity: _span(0.04, 0.14),
                            child: Shield(showNew ? rank : rank - 1, width: 132),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: _span(0.44, 0.54),
                  child: Text(
                    tr('Engkau dinobatkan sebagai', 'You are crowned'),
                    textAlign: TextAlign.center,
                    style: T.display(21, pal.muted, italic: true),
                  ),
                ),
                const SizedBox(height: 4),
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
                                  child: Text(name[i], style: T.display(66, pal.ink, height: 1.05)),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    width: 72 * _span(0.7, 0.8),
                    child: Container(height: 2, color: pal.dark ? pal.gold : tint),
                  ),
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: _span(0.74, 0.84),
                  child: Column(
                    children: [
                      if (widget.job != null) ...[
                        Text(
                          tr('dan menempuh jalan ${widget.job!.name}', 'and take the path of the ${widget.job!.name}'),
                          textAlign: TextAlign.center,
                          style: T.display(24, pal.ink, italic: true),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        tr(
                          'Kosakata setara ${scoreLine(rank, App.I.banner)}',
                          'Vocabulary on a par with ${scoreLine(rank, App.I.banner)}',
                        ),
                        textAlign: TextAlign.center,
                        style: T.body(19, pal.ink, w: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'Boss tumbang: ${widget.right} dari ${widget.total} kata diketik benar, dengan batas waktu, tanpa petunjuk.',
                          'The boss has fallen: ${widget.right} of ${widget.total} words typed right, against the clock, without hints.',
                        ),
                        textAlign: TextAlign.center,
                        style: T.body(16, pal.muted, height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.news.isNotEmpty
                            ? widget.news.toSet().take(3).join(' · ')
                            : (rank >= Engine.maxRank
                                  ? tr(
                                      'Tidak ada gelar di atas ini. Jagalah.',
                                      'There is no title above this one. Guard it.',
                                    )
                                  : tr(
                                      'Gelar ini dijaga. Kata yang terlupa harus direbut kembali.',
                                      'This title is kept. Words forgotten must be won back.',
                                    )),
                        textAlign: TextAlign.center,
                        style: T.body(15.5, pal.muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Center(
                  child: Opacity(
                    opacity: _span(0.85, 0.89, Curves.linear),
                    child: Transform.rotate(
                      angle: -0.14 * (1 - seal),
                      child: Transform.scale(scale: 1.9 - 0.9 * seal, child: const Seal(size: 58)),
                    ),
                  ),
                ),
                const Spacer(),
                IgnorePointer(
                  ignoring: end < 0.5,
                  child: Opacity(
                    opacity: end,
                    child: InkButton(
                      tr('Masuk ke negerimu', 'Enter your realm'),
                      onTap: () {
                        final job = widget.job;
                        // the new character is introduced once, on its own page that only its button closes
                        if (job == null) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(runRoute(JobIntro(job: job, rank: widget.rank)));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rays that open behind the shield, and a little gold dust rising.
class _RaysPainter extends CustomPainter {
  final double open, time;
  final Color ray, dust;
  _RaysPainter(this.open, this.time, this.ray, this.dust);

  @override
  void paint(Canvas canvas, Size size) {
    if (open <= 0) return;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = ray.withValues(alpha: 0.5);
    const n = 20;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + (i - (n - 1) / 2) * (pi * 1.5 / n);
      final long = i.isEven;
      final r0 = 90.0, r1 = r0 + (long ? 42 : 24) * open;
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
  bool shouldRepaint(_RaysPainter old) => old.open != open || old.time != time || old.ray != ray;
}
