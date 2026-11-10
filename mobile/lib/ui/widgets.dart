/// Shared pieces: the paper, buttons, the shield of each rank, the wax seal, bars and entrances.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import 'theme.dart';

/// The page everything sits on: paper with a faint grain, drawn once.
class Paper extends StatelessWidget {
  final Widget child;
  const Paper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _GrainPainter(pal))),
        child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  final Pal pal;
  _GrainPainter(this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.bg);
    final r = Random(7);
    final speck = Paint()..color = pal.ink.withValues(alpha: pal.dark ? 0.05 : 0.035);
    for (var i = 0; i < 900; i++) {
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height), 0.4 + r.nextDouble() * 0.6, speck);
    }
    final fibre = Paint()
      ..color = pal.ink.withValues(alpha: pal.dark ? 0.04 : 0.03)
      ..strokeWidth = 0.6;
    for (var i = 0; i < 70; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final a = r.nextDouble() * pi;
      final len = 6 + r.nextDouble() * 14;
      canvas.drawLine(p, p + Offset(cos(a) * len, sin(a) * len), fibre);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.pal != pal;
}

/// Anything you can press: it gives a little under the finger and is at least 48 high.
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool sound;
  const Press({super.key, required this.child, required this.onTap, this.label, this.sound = true});

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final calm = Look.of(context).calm;
    final on = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTap: on
            ? () {
                if (widget.sound) App.I.sfx('tap', 0.7);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down && !calm ? 0.97 : 1,
          duration: Dur.tap,
          curve: Curves.easeOut,
          child: AnimatedOpacity(opacity: _down ? 0.85 : 1, duration: Dur.tap, child: widget.child),
        ),
      ),
    );
  }
}

/// The main action of a screen: one per screen, in the rank's tincture.
class InkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  final bool sound;
  const InkButton(this.text, {super.key, required this.onTap, this.outline = false, this.sound = true});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final off = onTap == null;
    final fill = off ? pal.deep : (outline ? Colors.transparent : look.accent);
    final fg = off ? pal.muted : (outline ? pal.ink : pal.onAccent);
    return Press(
      onTap: onTap,
      sound: sound,
      child: AnimatedContainer(
        duration: Dur.out,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: outline || off ? Border.all(color: off ? pal.line : pal.ink, width: 1.5) : null,
        ),
        child: Text(text, style: T.body(18, fg, w: FontWeight.w700).copyWith(letterSpacing: 0.4)),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const GhostButton(this.text, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: T.body(16.5, pal.muted, w: FontWeight.w500)),
      ),
    );
  }
}

/// A small heading in spaced capitals.
class Label extends StatelessWidget {
  final String text;
  final Color? color;
  const Label(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: T.label(color ?? Look.of(context).pal.muted));
}

class Rule extends StatelessWidget {
  final double thickness;
  final Color? color;
  const Rule({super.key, this.thickness = 1, this.color});

  @override
  Widget build(BuildContext context) => Container(height: thickness, color: color ?? Look.of(context).pal.line);
}

/// A thin bar that fills smoothly.
class Bar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  final bool animate;
  const Bar(this.value, {super.key, this.height = 4, this.color, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: look.calm || !animate ? Duration.zero : Dur.slow,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(size: Size(double.infinity, height), painter: _BarPainter(v, look.pal.line, color ?? look.accent)),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double v;
  final Color track, fill;
  _BarPainter(this.v, this.track, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * v, size.height), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.v != v || old.fill != fill || old.track != track;
}

/// Comes in from a little below, after [delay]. With calm motion it is simply there.
class Rise extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const Rise({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Dur.enter);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Look.of(context).calm) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(offset: Offset(0, 12 * (1 - a.value)), child: child),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------- heraldry

Path shieldPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(w * 0.04, h * 0.03)
    ..lineTo(w * 0.96, h * 0.03)
    ..lineTo(w * 0.96, h * 0.48)
    ..cubicTo(w * 0.96, h * 0.76, w * 0.62, h * 0.93, w * 0.5, h * 0.98)
    ..cubicTo(w * 0.38, h * 0.93, w * 0.04, h * 0.76, w * 0.04, h * 0.48)
    ..close();
}

/// The shield of a rank. Tincture *and* charge differ, so colour is never the only sign:
/// Petani plain, Squire a chevron, Knight a bend, Baron a pale, Duke a saltire, Raja a crown.
class ShieldPainter extends CustomPainter {
  final int rank;
  final Color field, charge, ink;
  final Color? gold;
  final bool hollow;
  ShieldPainter({required this.rank, required this.field, required this.charge, required this.ink, this.gold, this.hollow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = shieldPath(size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * 0.045)
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    if (hollow) {
      canvas.drawPath(path, stroke..color = ink.withValues(alpha: 0.55));
      return;
    }
    canvas.drawPath(path, Paint()..color = field);
    canvas.save();
    canvas.clipPath(path);
    final c = Paint()..color = charge;
    final band = w * 0.2;
    switch (rank) {
      case 1: // chevron
        final p = Path()
          ..moveTo(0, h * 0.72)
          ..lineTo(w * 0.5, h * 0.36)
          ..lineTo(w, h * 0.72)
          ..lineTo(w, h * 0.72 - band * 1.15)
          ..lineTo(w * 0.5, h * 0.36 - band * 1.15)
          ..lineTo(0, h * 0.72 - band * 1.15)
          ..close();
        canvas.drawPath(p, c);
      case 2: // bend
        final p = Path()
          ..moveTo(0, 0)
          ..lineTo(band * 1.2, 0)
          ..lineTo(w, h * 0.78)
          ..lineTo(w, h * 0.78 + band * 1.2)
          ..lineTo(w - band * 0.6, h)
          ..lineTo(0, band * 1.0)
          ..close();
        canvas.drawPath(p, c);
      case 3: // pale
        canvas.drawRect(Rect.fromLTWH(w * 0.5 - band * 0.7, 0, band * 1.4, h), c);
      case 4: // saltire
        final s = Paint()
          ..color = charge
          ..strokeWidth = band * 0.95
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, h * 0.02), Offset(w, h * 0.82), s);
        canvas.drawLine(Offset(w, h * 0.02), Offset(0, h * 0.82), s);
      case 5: // crown
        final g = Paint()..color = gold ?? charge;
        final top = h * 0.26, base = h * 0.56, l = w * 0.22, r = w * 0.78;
        final p = Path()
          ..moveTo(l, base)
          ..lineTo(l, top + h * 0.06)
          ..lineTo(w * 0.36, top + h * 0.17)
          ..lineTo(w * 0.5, top)
          ..lineTo(w * 0.64, top + h * 0.17)
          ..lineTo(r, top + h * 0.06)
          ..lineTo(r, base)
          ..close();
        canvas.drawPath(p, g);
        canvas.drawRect(Rect.fromLTWH(l, base + h * 0.03, r - l, h * 0.05), g);
    }
    canvas.restore();
    canvas.drawPath(path, stroke);
    if (rank == 5 && gold != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, w * 0.018)
          ..color = gold!,
      );
    }
  }

  @override
  bool shouldRepaint(ShieldPainter old) => old.rank != rank || old.field != field || old.charge != charge || old.ink != ink || old.hollow != hollow;
}

class Shield extends StatelessWidget {
  final int rank;
  final double width;
  final bool hollow;
  const Shield(this.rank, {super.key, this.width = 28, this.hollow = false});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, width * 1.22),
        painter: ShieldPainter(rank: rank, field: pal.tincture(rank), charge: pal.onAccent, ink: pal.ink, gold: pal.gold, hollow: hollow),
      ),
    );
  }
}

/// A wax seal with a V pressed into it.
class SealPainter extends CustomPainter {
  final Color wax, mark;
  SealPainter(this.wax, this.mark);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rnd = Random(3);
    final edge = Path();
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * pi;
      final rr = r * (0.9 + 0.1 * sin(a * 5 + 1) * 0.5 + rnd.nextDouble() * 0.05);
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        edge.moveTo(p.dx, p.dy);
      } else {
        edge.lineTo(p.dx, p.dy);
      }
    }
    edge.close();
    canvas.drawPath(edge, Paint()..color = wax);
    canvas.drawCircle(
      c,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = mark.withValues(alpha: 0.55),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'V',
        style: TextStyle(fontFamily: T.fell, fontSize: r * 0.95, color: mark, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(SealPainter old) => old.wax != wax || old.mark != mark;
}

class Seal extends StatelessWidget {
  final double size;
  const Seal({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: SealPainter(pal.dark ? const Color(0xFFB8463C) : const Color(0xFF8E1B16), const Color(0xFFFCFBF7))),
    );
  }
}

/// The screen frame most pages share: paper, safe area, side margins that grow on wide screens.
class Leaf extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Leaf({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 16)});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Paper(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A yes/no question on a slip of paper. Returns true for yes.
Future<bool> confirm(BuildContext context, {required String title, required String text, required String yes, String no = 'Batal'}) async {
  final look = Look.of(context);
  final pal = look.pal;
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Look(
      pal: pal,
      rank: look.rank,
      calm: look.calm,
      child: Dialog(
        backgroundColor: pal.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: pal.ink, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: T.display(25, pal.ink)),
              const SizedBox(height: 8),
              Text(text, style: T.body(16.5, pal.muted)),
              const SizedBox(height: 18),
              InkButton(yes, onTap: () => Navigator.of(ctx).pop(true)),
              GhostButton(no, onTap: () => Navigator.of(ctx).pop(false)),
            ],
          ),
        ),
      ),
    ),
  );
  return r ?? false;
}
