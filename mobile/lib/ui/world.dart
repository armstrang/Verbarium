/// The world and its kingdoms. Negeri opens on a painted map of the five kingdoms, alive (clouds, birds, waves,
/// the mill, the lighthouse, snow on the peaks); tapping a kingdom flies into it through the clouds and lands on
/// its road: seven places, one per title, drawn as far as the learner has come. The ladder of titles has its own
/// page. With calm motion the map stands still and the flight is a plain fade.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../data/deck.dart';
import '../engine/engine.dart';
import 'banner.dart';
import 'crest.dart';
import 'pixel.dart';
import 'realm.dart' show SourcesPage;
import 'root.dart';
import 'run.dart' show runRoute, stageName, RunScreen, RunKind;
import 'theme.dart';
import 'widgets.dart';

/// the seven places on each kingdom's road, Peasant to King; proper names, the same in every language
const placeNames = <String, List<String>>{
  'en': ['Hamlet', 'Old Bridge', 'Iron Pass', 'Stone Hall', 'Silver Ford', 'Mist Tower', 'Crown Keep'],
  'de': ['Kieselweiler', 'Holzbrück', 'Eisenpass', 'Steinhalle', 'Silberfurt', 'Nebelhorn', 'Grauburg'],
  'es': [
    'Aldea del Sol',
    'Puente Viejo',
    'Paso de Hierro',
    'Salón de Piedra',
    'Vado de Plata',
    'Torre del Viento',
    'Alcázar de Oro',
  ],
  'fr': [
    'Hameau des Vignes',
    'Pont du Moulin',
    'Col de Fer',
    'Salle de Pierre',
    'Gué d’Argent',
    'Tour des Brumes',
    'Château Beaumarais',
  ],
  'pt': [
    'Vila da Praia',
    'Ponte Velha',
    'Passo do Ferro',
    'Salão de Pedra',
    'Vau de Prata',
    'Torre do Farol',
    'Paço de Alvamar',
  ],
};

/// where each kingdom lies on the world map (390 × 282), and the part of the map a tap on it covers
const _spot = <String, Offset>{
  'en': Offset(197, 150),
  'de': Offset(208, 66),
  'fr': Offset(80, 175),
  'es': Offset(190, 235),
  'pt': Offset(300, 200),
};
const _hit = <String, Rect>{
  'de': Rect.fromLTWH(40, 18, 290, 80),
  'en': Rect.fromLTWH(142, 102, 108, 96),
  'fr': Rect.fromLTWH(22, 100, 116, 162),
  'es': Rect.fromLTWH(130, 200, 124, 76),
  'pt': Rect.fromLTWH(254, 104, 130, 160),
};

// ---------------------------------------------------------------------------- the Negeri tab

class RealmWorld extends StatefulWidget {
  const RealmWorld({super.key});

  @override
  State<RealmWorld> createState() => _RealmWorldState();
}

class _RealmWorldState extends State<RealmWorld> with TickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  String _target = 'en';
  bool _flying = false;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _go(String code) async {
    if (_flying) return;
    final calm = Look.of(context).calm;
    App.I.sfx('page');
    setState(() {
      _target = code;
      _flying = true;
    });
    final changed = code != App.I.realm;
    final travel = App.I.chooseRealm(code);
    if (!calm) await _zoom.forward(from: 0);
    await travel;
    if (!mounted) return;
    // a kingdom entered anew shows its arms first
    if (changed) await showCrest(context, code);
    if (!mounted) return;
    await Navigator.of(context).push(_cloudRoute(const KingdomScreen(), calm));
    if (!mounted) return;
    _zoom.value = 0;
    setState(() => _flying = false);
  }

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    return TabBody(
      children: [
        Label(tr('Negeri', 'The realm', 'El reino', 'Le royaume', 'Das Reich', 'O reino')),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                tr(
                  'Pilih kerajaan',
                  'Choose a kingdom',
                  'Elige un reino',
                  'Choisis un royaume',
                  'Wähle ein Königreich',
                  'Escolha um reino',
                ),
                style: T.display(31, pal.ink),
              ),
            ),
            if (app.engine.streak > 0)
              Text(
                tr(
                  '${app.engine.streak} hari',
                  '${app.engine.streak} days',
                  '${app.engine.streak} días',
                  '${app.engine.streak} jours',
                  '${app.engine.streak} Tage',
                  '${app.engine.streak} dias',
                ),
                style: T.body(15, pal.gold, w: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Rise(
          child: AspectRatio(
            aspectRatio: 390 / 282,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final k = box.maxWidth / 390;
                  final at = _spot[_target]!;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final p = d.localPosition / k;
                      for (final e in _hit.entries) {
                        if (e.value.contains(p)) {
                          _go(e.key);
                          return;
                        }
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _zoom,
                      builder: (context, child) {
                        final z = Curves.easeInCubic.transform(_zoom.value);
                        return Opacity(
                          opacity: 1 - z * 0.85,
                          child: Transform(
                            alignment: Alignment((at.dx / 390) * 2 - 1, (at.dy / 282) * 2 - 1),
                            transform: Matrix4.diagonal3Values(1 + z * 2.6, 1 + z * 2.6, 1),
                            child: child,
                          ),
                        );
                      },
                      child: Semantics(
                        label: tr(
                          'Peta dunia: Grauwacht di utara, Beaumarais di barat, Valdoro di selatan, Alvamar di timur, Aldmere di tengah. Ketuk satu kerajaan.',
                          'World map: Grauwacht in the north, Beaumarais in the west, Valdoro in the south, Alvamar in the east, Aldmere in the middle. Tap a kingdom.',
                          'Mapa del mundo: Grauwacht al norte, Beaumarais al oeste, Valdoro al sur, Alvamar al este, Aldmere en el centro. Toca un reino.',
                          'Carte du monde : Grauwacht au nord, Beaumarais à l’ouest, Valdoro au sud, Alvamar à l’est, Aldmere au centre. Touche un royaume.',
                          'Weltkarte: Grauwacht im Norden, Beaumarais im Westen, Valdoro im Süden, Alvamar im Osten, Aldmere in der Mitte. Tippe auf ein Königreich.',
                          'Mapa do mundo: Grauwacht ao norte, Beaumarais a oeste, Valdoro ao sul, Alvamar a leste, Aldmere no centro. Toque num reino.',
                        ),
                        child: WorldMap(here: app.realm),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Ketuk wilayah untuk turun',
            'Tap a land to go down',
            'Toca una tierra para bajar',
            'Touche une terre pour descendre',
            'Tippe auf ein Land, um hinabzusteigen',
            'Toque numa terra para descer',
          ),
          style: T.body(14, pal.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Rise(child: TitleRoll()),
        const SizedBox(height: 16),
        for (final (i, k) in Kingdom.all.indexed)
          Rise(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KingdomRow(k, onTap: () => _go(k.code)),
            ),
          ),
      ],
    );
  }
}

/// a page that comes in through a wall of cloud
Route<void> _cloudRoute(Widget page, bool calm) => PageRouteBuilder<void>(
  transitionDuration: calm ? Dur.enter : const Duration(milliseconds: 950),
  reverseTransitionDuration: calm ? Dur.out : const Duration(milliseconds: 520),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, a, _, child) {
    if (calm) return FadeTransition(opacity: a, child: child);
    final land = CurvedAnimation(
      parent: a,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: land,
          child: ScaleTransition(scale: Tween(begin: 1.25, end: 1.0).animate(land), child: child),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: a,
            builder: (context, _) => CustomPaint(painter: _CloudPainter(a.value, a.status == AnimationStatus.reverse)),
          ),
        ),
      ],
    );
  },
);

class _CloudPainter extends CustomPainter {
  final double t;
  final bool back;
  _CloudPainter(this.t, this.back);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    // a white flash that peaks while the clouds rush past
    final flash = sin(pi * t).clamp(0.0, 1.0);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFCFBF7).withValues(alpha: flash * 0.92));
    if (back) return;
    final c = size.center(Offset.zero);
    const dirs = [(-1.0, -0.8), (1.0, -0.8), (-1.1, 0.2), (1.1, 0.2), (-0.7, 1.0), (0.7, 1.0), (0.0, -1.2), (0.0, 1.2)];
    for (final (i, d) in dirs.indexed) {
      final s = (t * 1.25 - i * 0.04).clamp(0.0, 1.0);
      if (s <= 0) continue;
      final r = size.shortestSide * (0.18 + s * 0.9);
      final p = c + Offset(d.$1, d.$2) * size.shortestSide * s * 0.8;
      final a = (sin(pi * s) * 0.95).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFFCFBF7) : const Color(0xFFEAE6DA)).withValues(alpha: a);
      _cloud(canvas, p, r, paint);
    }
  }

  static void _cloud(Canvas canvas, Offset p, double r, Paint paint) {
    canvas.drawCircle(p, r * 0.5, paint);
    canvas.drawCircle(p + Offset(-r * 0.45, r * 0.12), r * 0.36, paint);
    canvas.drawCircle(p + Offset(r * 0.45, r * 0.1), r * 0.4, paint);
    canvas.drawCircle(p + Offset(r * 0.1, -r * 0.3), r * 0.38, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.t != t;
}

/// The roll of titles: the five arms side by side, the title held under each. Whoever is King in three kingdoms is
/// named Emperor above them, an honour only: it changes no memory, rank or trial.
class TitleRoll extends StatelessWidget {
  const TitleRoll({super.key});

  /// Kings needed for the Emperor
  static const forEmperor = 3;

  static int kings(App app) => Kingdom.all.where((k) => app.standing(k.code).rank >= Engine.maxRank).length;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    final emperor = kings(app) >= forEmperor;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: pal.field,
        border: Border.all(color: emperor ? pal.gold : pal.line, width: emperor ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Label(
            tr(
              'Gulungan gelar',
              'Roll of titles',
              'Rollo de títulos',
              'Rouleau des titres',
              'Rolle der Titel',
              'Rolo de títulos',
            ),
          ),
          if (emperor) ...[
            const SizedBox(height: 6),
            Text('Emperor', style: T.display(26, pal.gold)),
            Text(
              tr(
                'King di ${kings(app)} negeri',
                'King in ${kings(app)} kingdoms',
                'King en ${kings(app)} reinos',
                'King dans ${kings(app)} royaumes',
                'King in ${kings(app)} Königreichen',
                'King em ${kings(app)} reinos',
              ),
              style: T.body(13.5, pal.muted),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (final k in Kingdom.all)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final st = app.standing(k.code);
                      final started = st.seen > 0 || k.code == app.realm;
                      return Column(
                        children: [
                          Opacity(
                            opacity: started ? 1 : .38,
                            child: Image.asset(
                              'assets/crest/${k.code}/full.png',
                              height: 52,
                              filterQuality: FilterQuality.none,
                              semanticLabel: k.name,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            started ? rankNames[st.rank] : '—',
                            style: T.body(12.5, started ? pal.ink : pal.muted, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                          Text(
                            k.name,
                            style: T.body(11, pal.muted),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// where the learner is: the kingdom's name and language, on Today and over the learning screen. A tap opens Negeri,
/// a long press offers all five kingdoms at once.
class KingdomName extends StatelessWidget {
  /// false on the learning screen: there it only says where you are
  final bool active;
  const KingdomName({super.key, this.active = true});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final k = App.I.kingdom;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(15, 18), painter: KingdomShield(Color(k.tint), k.charge)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${k.name} · ${k.language}',
            style: T.body(active ? 15 : 13.5, active ? pal.ink : pal.muted, w: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (active) Icon(Icons.unfold_more, size: 18, color: pal.muted),
      ],
    );
    if (!active) {
      return Semantics(
        label: '${k.name}, ${k.language}',
        child: ExcludeSemantics(child: row),
      );
    }
    return Press(
      label: '${k.name}, ${k.language}',
      onTap: () => Shell.tab.value = 1,
      onLongPress: () => pickKingdom(context),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row),
    );
  }
}

/// the five kingdoms at once (a long press on the kingdom's name): going to one shows its arms
Future<void> pickKingdom(BuildContext context) async {
  final look = Look.of(context);
  final app = App.I;
  final code = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Look(
      pal: look.pal,
      rank: look.rank,
      calm: look.calm,
      child: Dialog(
        backgroundColor: look.pal.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: look.pal.ink, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  tr(
                    'Pindah negeri',
                    'Change kingdom',
                    'Cambiar de reino',
                    'Changer de royaume',
                    'Königreich wechseln',
                    'Mudar de reino',
                  ),
                  style: T.display(24, look.pal.ink),
                ),
              ),
              for (final k in Kingdom.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KingdomRow(k, onTap: () => Navigator.of(ctx).pop(k.code)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (code == null || code == app.realm || !context.mounted) return;
  await app.chooseRealm(code);
  if (!context.mounted) return;
  await showCrest(context, code);
}

/// one kingdom in the list under the map: its arms, its language, where the learner stands in it
class KingdomRow extends StatelessWidget {
  final Kingdom k;
  final VoidCallback onTap;
  const KingdomRow(this.k, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final app = App.I;
    final here = k.code == app.realm;
    final st = app.standing(k.code);
    return Press(
      label: k.name,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Dur.enter,
        padding: EdgeInsets.symmetric(horizontal: here ? 11 : 12, vertical: here ? 8 : 9),
        decoration: BoxDecoration(
          color: pal.field,
          border: Border.all(color: here ? Color(k.tint) : pal.line, width: here ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CustomPaint(size: const Size(28, 32), painter: KingdomShield(Color(k.tint), k.charge)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.name, style: T.display(20, pal.ink)),
                  Text(
                    st.seen == 0
                        ? '${k.language} · ${tr('belum dimulai', 'not started', 'sin empezar', 'pas commencé', 'nicht begonnen', 'não começado')}'
                        : '${k.language} · ${rankNames[st.rank]} · ${tr('${st.seen} kata', '${st.seen} words', '${st.seen} palabras', '${st.seen} mots', '${st.seen} Wörter', '${st.seen} palavras')}',
                    style: T.body(14, pal.muted),
                  ),
                ],
              ),
            ),
            Text(
              here
                  ? tr('Lanjut', 'Go on', 'Seguir', 'Continuer', 'Weiter', 'Continuar')
                  : (st.seen == 0
                        ? tr('Masuk', 'Enter', 'Entrar', 'Entrer', 'Betreten', 'Entrar')
                        : tr('Lanjut', 'Go on', 'Seguir', 'Continuer', 'Weiter', 'Continuar')),
              style: T.body(14, here ? pal.good : pal.muted, w: here ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// a kingdom's arms: its colour and a mark of its own (a cross, a peak, a sun, a flame, waves)
class KingdomShield extends CustomPainter {
  final Color field;
  final int charge;
  KingdomShield(this.field, this.charge);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(w - 1, 1)
      ..lineTo(w - 1, h * 0.48)
      ..quadraticBezierTo(w - 1, h * 0.86, w / 2, h - 1)
      ..quadraticBezierTo(1, h * 0.86, 1, h * 0.48)
      ..close();
    canvas.drawPath(path, Paint()..color = field);
    final mark = Paint()
      ..color = const Color(0xFFFCFBF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09;
    switch (charge) {
      case 0:
        canvas.drawLine(Offset(w / 2, h * 0.16), Offset(w / 2, h * 0.72), mark);
        canvas.drawLine(Offset(w * 0.28, h * 0.32), Offset(w * 0.72, h * 0.32), mark);
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.66)
            ..lineTo(w * 0.5, h * 0.24)
            ..lineTo(w * 0.78, h * 0.66)
            ..close(),
          Paint()..color = const Color(0xFFEAE6DA),
        );
      case 2:
        canvas.drawCircle(Offset(w / 2, h * 0.43), w * 0.18, Paint()..color = const Color(0xFFD9B861));
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(w / 2, h * 0.18)
            ..quadraticBezierTo(w * 0.24, h * 0.42, w / 2, h * 0.58)
            ..quadraticBezierTo(w * 0.76, h * 0.42, w / 2, h * 0.18),
          mark,
        );
        canvas.drawLine(Offset(w * 0.28, h * 0.68), Offset(w * 0.72, h * 0.68), mark);
      default:
        for (final y in [0.36, 0.56]) {
          canvas.drawPath(
            Path()
              ..moveTo(w * 0.18, h * y)
              ..quadraticBezierTo(w * 0.34, h * (y - 0.1), w * 0.5, h * y)
              ..quadraticBezierTo(w * 0.66, h * (y + 0.1), w * 0.82, h * y),
            mark,
          );
        }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF1C1B19),
    );
  }

  @override
  bool shouldRepaint(KingdomShield old) => old.field != field || old.charge != charge;
}

// ---------------------------------------------------------------------------- the world map

/// The painted world, alive: drifting clouds, a flight of birds, waves, the mill, the sun, the lighthouse and its
/// ship, smoke from Aldmere, snow on Grauwacht. [here] gets a pulsing ring.
class WorldMap extends StatefulWidget {
  final String here;
  const WorldMap({super.key, required this.here});

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Look.of(context).calm) {
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(size: Size.infinite, painter: _WorldPainter(_c.value * 40, widget.here, pal.dark)),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  /// seconds since the loop began
  final double s;
  final String here;
  final bool night;
  _WorldPainter(this.s, this.here, this.night);

  static const ink = Color(0xFF1C1B19), paper = Color(0xFFFCFBF7);

  Paint fill(int c) => Paint()..color = Color(c);
  Paint stroke(int c, double w) => Paint()
    ..color = Color(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  double osc(double period, [double phase = 0]) => sin(2 * pi * (s / period + phase));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 390;
    canvas.save();
    canvas.scale(k);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 282), fill(0xFFD9E0DC));
    // waves at sea
    for (final (x, y, p) in const [
      (10.0, 30.0, 0.0),
      (340.0, 60.0, .3),
      (350.0, 250.0, .6),
      (14.0, 250.0, .2),
      (352.0, 150.0, .8),
      (300.0, 275.0, .5),
      (60.0, 276.0, .1),
      (8.0, 120.0, .7),
    ]) {
      final dx = osc(5.5, p) * 6;
      final w = Path()
        ..moveTo(x + dx, y)
        ..relativeQuadraticBezierTo(8, -5, 16, 0)
        ..relativeQuadraticBezierTo(8, 5, 16, 0);
      canvas.drawPath(w, stroke(0xFF9DB0AE, 1.4));
    }
    // the land
    final land = Path()
      ..moveTo(34, 42)
      ..cubicTo(84, 12, 204, 8, 282, 30)
      ..cubicTo(332, 44, 348, 88, 332, 128)
      ..cubicTo(352, 168, 338, 226, 302, 252)
      ..cubicTo(242, 276, 152, 278, 92, 260)
      ..cubicTo(42, 244, 16, 200, 26, 150)
      ..cubicTo(12, 112, 18, 72, 34, 42)
      ..close();
    canvas.drawPath(land, fill(0xFFEAE6DA));
    canvas.drawPath(land, stroke(0xFF5C574D, 1.6));
    // borders
    final border = stroke(0xFF8A8477, 1.2);
    for (final path in [
      Path()
        ..moveTo(30, 100)
        ..cubicTo(80, 92, 120, 104, 140, 98)
        ..cubicTo(200, 108, 262, 98, 336, 106),
      Path()
        ..moveTo(140, 98)
        ..cubicTo(146, 150, 122, 206, 126, 266),
      Path()
        ..moveTo(126, 200)
        ..cubicTo(170, 190, 222, 206, 256, 200),
      Path()
        ..moveTo(252, 102)
        ..cubicTo(246, 150, 262, 186, 256, 200)
        ..cubicTo(252, 230, 258, 250, 262, 262),
    ]) {
      _dash(canvas, path, border, 3, 4, 0);
    }
    // the river, flowing
    final river = Path()
      ..moveTo(112, 104)
      ..cubicTo(96, 130, 104, 150, 82, 176)
      ..cubicTo(66, 196, 46, 200, 22, 206);
    _dash(canvas, river, stroke(0xFF7F9AA0, 2.5), 6, 8, -(s * 6) % 14);

    _grauwacht(canvas);
    _aldmere(canvas);
    _beaumarais(canvas);
    _valdoro(canvas);
    _alvamar(canvas);

    // the kingdom being played
    final h = _spot[here]!;
    final pulse = (s % 2.4) / 2.4;
    canvas.drawCircle(
      h,
      10 + pulse * 18,
      stroke(0xFF2F5D3A, 2.2)..color = const Color(0xFF2F5D3A).withValues(alpha: (1 - pulse) * 0.9),
    );

    // clouds and birds above it all
    for (final (y, speed, phase, scale) in const [
      (70.0, 46.0, 0.0, 1.0),
      (120.0, 64.0, .55, .8),
      (230.0, 80.0, .25, .7),
    ]) {
      final x = -120 + ((s / speed + phase) % 1) * 560;
      _CloudPainter._cloud(
        canvas,
        Offset(x, y),
        26 * scale,
        fill(0xFFFCFBF7)..color = const Color(0xFFFCFBF7).withValues(alpha: .85),
      );
    }
    final bx = -60 + ((s / 28) % 1) * 510, by = 40 - ((s / 28) % 1) * 50;
    final flap = osc(.7) * 3;
    for (final (dx, dy) in const [(0.0, 0.0), (14.0, -6.0), (8.0, 8.0)]) {
      final p = Path()
        ..moveTo(bx + dx, by + dy)
        ..lineTo(bx + dx + 5, by + dy - 4 + flap)
        ..lineTo(bx + dx + 10, by + dy);
      canvas.drawPath(p, stroke(0xFF3F3B34, 1.3));
    }

    // names
    for (final (name, x, y, size) in const [
      ('Grauwacht', 208.0, 95.0, 14.0),
      ('Aldmere', 197.0, 182.0, 15.0),
      ('Beaumarais', 74.0, 208.0, 13.0),
      ('Valdoro', 196.0, 270.0, 13.0),
      ('Alvamar', 292.0, 226.0, 13.0),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontFamily: 'Fell',
            fontSize: size,
            letterSpacing: 0.6,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = const Color(0xFFEAE6DA),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final o = Offset(x - tp.width / 2, y - tp.height + 3);
      tp.paint(canvas, o);
      TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(fontFamily: 'Fell', fontSize: size, letterSpacing: 0.6, color: ink),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, o);
    }
    // a compass rose
    canvas.drawCircle(const Offset(356, 26), 14, fill(0xFFF5F2EA));
    canvas.drawCircle(const Offset(356, 26), 14, stroke(0xFF5C574D, 1));
    canvas.drawPath(
      Path()
        ..moveTo(356, 15)
        ..lineTo(359, 26)
        ..lineTo(356, 37)
        ..lineTo(353, 26)
        ..close(),
      fill(0xFF1C1B19),
    );
    if (night) canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 282), fill(0x33101820));
    canvas.restore();
  }

  void _grauwacht(Canvas c) {
    for (final (x, top, w, col) in const [
      (150.0, 46.0, 44.0, 0xFF8A8477),
      (186.0, 40.0, 52.0, 0xFF9A9488),
      (226.0, 56.0, 36.0, 0xFF8A8477),
    ]) {
      final base = top + w * 0.88;
      final m = Path()
        ..moveTo(x, base)
        ..lineTo(x + w / 2, top)
        ..lineTo(x + w, base)
        ..close();
      c.drawPath(m, fill(col));
      c.drawPath(m, stroke(0xFF3F3B34, 1.2));
      final cap = Path()
        ..moveTo(x + w / 2 - w * 0.18, top + w * 0.3)
        ..lineTo(x + w / 2, top)
        ..lineTo(x + w / 2 + w * 0.18, top + w * 0.3)
        ..lineTo(x + w / 2 + w * 0.08, top + w * 0.36)
        ..lineTo(x + w / 2, top + w * 0.3)
        ..lineTo(x + w / 2 - w * 0.08, top + w * 0.36)
        ..close();
      c.drawPath(cap, fill(0xFFFCFBF7));
    }
    // falling snow
    for (final (x, y0, p) in const [
      (160.0, 30.0, 0.0),
      (198.0, 24.0, .5),
      (230.0, 34.0, .2),
      (250.0, 28.0, .7),
      (215.0, 16.0, .35),
    ]) {
      final f = ((s / 5) + p) % 1;
      c.drawCircle(
        Offset(x + osc(3, p) * 2, y0 + f * 34),
        1.5,
        fill(0xFFFCFBF7)..color = paper.withValues(alpha: sin(pi * f)),
      );
    }
    // the road from Aldmere up to the pass
    final road = Path()
      ..moveTo(196, 132)
      ..cubicTo(200, 112, 206, 98, 210, 86);
    _dash(c, road, stroke(0xFF2F5D3A, 2), 4, 5, -(s * 15) % 9);
  }

  void _aldmere(Canvas c) {
    // smoke from the chimney
    for (final p in const [0.0, .5]) {
      final f = ((s / 4) + p) % 1;
      c.drawCircle(
        Offset(176 + f * 6, 118 - f * 18),
        2 + f * 2.5,
        fill(0xFFCFC9BA)..color = const Color(0xFFCFC9BA).withValues(alpha: (1 - f) * .8),
      );
    }
    c.drawRect(const Rect.fromLTWH(172, 112, 8, 10), fill(0xFF5C574D));
    for (final r in const [
      Rect.fromLTWH(180, 120, 34, 24),
      Rect.fromLTWH(174, 114, 10, 30),
      Rect.fromLTWH(210, 114, 10, 30),
    ]) {
      c.drawRect(r, fill(0xFFFCFBF7));
      c.drawRect(r, stroke(0xFF1C1B19, 1.4)..strokeCap = StrokeCap.butt);
    }
    for (final x in const [174.0, 210.0]) {
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(x + i * 4, 112, 2, 2), fill(0xFF1C1B19));
      }
    }
    c.drawPath(
      Path()
        ..moveTo(193, 144)
        ..lineTo(193, 136)
        ..arcToPoint(const Offset(201, 136), radius: const Radius.circular(4))
        ..lineTo(201, 144)
        ..close(),
      fill(0xFF1C1B19),
    );
    c.drawLine(const Offset(197, 120), const Offset(197, 100), stroke(0xFF1C1B19, 1.4));
    // the flag in the wind
    final wave = osc(1.6) * 1.6;
    c.drawPath(
      Path()
        ..moveTo(197.7, 100)
        ..quadraticBezierTo(205, 100 + wave, 212, 100)
        ..lineTo(208, 104.5)
        ..lineTo(212, 109)
        ..quadraticBezierTo(205, 109 + wave, 197.7, 109)
        ..close(),
      fill(0xFF1F3F73),
    );
  }

  void _beaumarais(Canvas c) {
    c.drawRect(const Rect.fromLTWH(85, 168, 10, 20), fill(0xFFFCFBF7));
    c.drawRect(const Rect.fromLTWH(85, 168, 10, 20), stroke(0xFF1C1B19, 1.3)..strokeCap = StrokeCap.butt);
    c.drawPath(
      Path()
        ..moveTo(83, 170)
        ..lineTo(90, 162)
        ..lineTo(97, 170)
        ..close(),
      fill(0xFF8E1B16),
    );
    // the mill turns
    c.save();
    c.translate(90, 165);
    c.rotate(s / 6 * 2 * pi);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset.zero, const Offset(0, -15), stroke(0xFF5C574D, 1.6));
      c.drawRect(const Rect.fromLTWH(0, -15, 4, 9), fill(0xFFFCFBF7));
      c.drawRect(const Rect.fromLTWH(0, -15, 4, 9), stroke(0xFF5C574D, 1)..strokeCap = StrokeCap.butt);
      c.rotate(pi / 2);
    }
    c.restore();
    for (final (x, y) in const [
      (60.0, 150.0),
      (66.0, 152.0),
      (72.0, 150.0),
      (58.0, 140.0),
      (64.0, 142.0),
      (70.0, 140.0),
    ]) {
      c.drawCircle(Offset(x, y), 2, fill(0xFF5A2A6B));
    }
  }

  void _valdoro(Canvas c) {
    c.save();
    c.translate(168, 232);
    c.rotate(s / 24 * 2 * pi);
    c.drawCircle(Offset.zero, 8, fill(0xFFD9B861));
    c.drawCircle(Offset.zero, 8, stroke(0xFF9A7B2C, 1.2));
    for (var i = 0; i < 8; i++) {
      c.drawLine(const Offset(0, -14), const Offset(0, -19), stroke(0xFF9A7B2C, 1.6));
      c.rotate(pi / 4);
    }
    c.restore();
    for (final (x, y) in const [(202.0, 236.0), (216.0, 246.0), (232.0, 236.0)]) {
      c.drawLine(Offset(x, y + 5), Offset(x, y + 10), stroke(0xFF5C574D, 1.4));
      c.drawCircle(Offset(x, y), 5, fill(0xFF6E7F4E));
      c.drawCircle(Offset(x, y), 5, stroke(0xFF3F4A2C, .8));
    }
    // heat over the plain
    final a = .25 + (osc(3) + 1) / 2 * .35;
    for (final (x, y) in const [(140.0, 214.0), (196.0, 220.0)]) {
      final p = Path()
        ..moveTo(x, y)
        ..relativeQuadraticBezierTo(6, -3, 12, 0)
        ..relativeQuadraticBezierTo(6, 3, 12, 0);
      c.drawPath(p, stroke(0xFFC9A27E, 1.2)..color = const Color(0xFFC9A27E).withValues(alpha: a));
    }
  }

  void _alvamar(Canvas c) {
    // the beam sweeps
    final beam = ((osc(4) + 1) / 2);
    c.save();
    c.translate(306, 180);
    c.scale(.4 + beam * .6, 1);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(60, -16)
        ..lineTo(60, 16)
        ..close(),
      fill(0xFFF4E3A6)..color = const Color(0xFFF4E3A6).withValues(alpha: .2 + beam * .7),
    );
    c.restore();
    final tower = Path()
      ..moveTo(298, 206)
      ..lineTo(301, 180)
      ..lineTo(309, 180)
      ..lineTo(312, 206)
      ..close();
    c.drawPath(tower, fill(0xFFFCFBF7));
    c.drawPath(tower, stroke(0xFF1C1B19, 1.3));
    c.drawLine(const Offset(300, 196), const Offset(312, 196), stroke(0xFF8E1B16, 3)..strokeCap = StrokeCap.butt);
    c.drawLine(const Offset(301, 188), const Offset(311, 188), stroke(0xFF8E1B16, 3)..strokeCap = StrokeCap.butt);
    c.drawRect(
      const Rect.fromLTWH(301, 174, 8, 6),
      fill(0xFFD9B861)..color = Color.lerp(const Color(0xFFB89A3C), const Color(0xFFFFE68A), beam)!,
    );
    c.drawPath(
      Path()
        ..moveTo(300, 174)
        ..lineTo(305, 169)
        ..lineTo(310, 174)
        ..close(),
      fill(0xFF1C1B19),
    );
    // the ship rocks on the swell
    c.save();
    c.translate(360, 240 + osc(3.2) * 2);
    c.rotate(osc(3.2, .25) * .07);
    c.drawPath(
      Path()
        ..moveTo(-14, -4)
        ..lineTo(14, -4)
        ..lineTo(9, 3)
        ..lineTo(-9, 3)
        ..close(),
      fill(0xFF6B4F3A),
    );
    c.drawLine(const Offset(0, -4), const Offset(0, -26), stroke(0xFF1C1B19, 1.3));
    c.drawPath(
      Path()
        ..moveTo(1, -24)
        ..lineTo(11, -8)
        ..lineTo(1, -8)
        ..close(),
      fill(0xFFFCFBF7),
    );
    c.drawPath(
      Path()
        ..moveTo(-1, -22)
        ..lineTo(-9, -8)
        ..lineTo(-1, -8)
        ..close(),
      fill(0xFFFCFBF7),
    );
    c.restore();
  }

  void _dash(Canvas canvas, Path path, Paint paint, double on, double off, double phase) {
    for (final m in path.computeMetrics()) {
      var d = phase % (on + off);
      if (d > 0) d -= on + off;
      while (d < m.length) {
        final a = max(0.0, d), b = min(m.length, d + on);
        if (b > a) canvas.drawPath(m.extractPath(a, b), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.s != s || old.here != here || old.night != night;
}

// ---------------------------------------------------------------------------- a kingdom's road

/// The kingdom being played, from close: its road of seven places, the learner on it, what is held and what lies
/// ahead, the guard of the road, the way on.
class KingdomScreen extends StatelessWidget {
  const KingdomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    final e = app.engine;
    final k = app.kingdom;
    final rank = e.rank;
    final places = placeNames[k.code]!;
    final next = min(rank + 1, Engine.maxRank);
    final share = rank >= Engine.maxRank ? 1.0 : e.stat(next).share;
    askViaOnce(context);
    return Leaf(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 390 / 340,
                child: KingdomRoad(code: k.code, rank: rank, share: share, places: places),
              ),
              Positioned(
                left: 12,
                top: MediaQuery.paddingOf(context).top + 10,
                child: Press(
                  label: tr(
                    'Kembali ke peta',
                    'Back to the map',
                    'Volver al mapa',
                    'Retour à la carte',
                    'Zurück zur Karte',
                    'Voltar ao mapa',
                  ),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFBF7),
                      border: Border.all(color: const Color(0xFFCFC9BA)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1C1B19)),
                        const SizedBox(width: 6),
                        Text(
                          tr('Peta', 'Map', 'Mapa', 'Carte', 'Karte', 'Mapa'),
                          style: T.body(15, const Color(0xFF1C1B19)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(k.name, style: T.display(30, pal.ink))),
                    if (k.code == 'en') Text(k.language, style: T.body(15, pal.muted)) else BannerPill(k),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Tile(tr('Gelar', 'Title', 'Título', 'Titre', 'Titel', 'Título'), rankNames[rank], display: true),
                    const SizedBox(width: 8),
                    _Tile(
                      tr('Kata', 'Words', 'Palabras', 'Mots', 'Wörter', 'Palavras'),
                      '${e.seenTotal}',
                      sub: ' / ${app.deck.words.length}',
                    ),
                    const SizedBox(width: 8),
                    _Tile(
                      tr('Ulangan hari ini', 'Due today', 'Para hoy', 'À revoir', 'Heute fällig', 'Para hoje'),
                      '${e.dueWords().length}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (var i = 0; i <= Engine.maxRank; i++)
                  Rise(
                    delay: Duration(milliseconds: 40 * i),
                    child: _PlaceRow(i, rank, places[i]),
                  ),
                const SizedBox(height: 16),
                const FightCard(),
                const SizedBox(height: 16),
                InkButton(
                  rank >= Engine.maxRank
                      ? tr(
                          'Ulang kata',
                          'Review words',
                          'Repasar palabras',
                          'Réviser des mots',
                          'Wörter wiederholen',
                          'Revisar palavras',
                        )
                      : (e.seenTotal == 0
                            ? tr(
                                'Mulai di ${k.name}',
                                'Begin in ${k.name}',
                                'Empezar en ${k.name}',
                                'Commencer à ${k.name}',
                                'In ${k.name} beginnen',
                                'Começar em ${k.name}',
                              )
                            : tr(
                                'Lanjut belajar',
                                'Keep learning',
                                'Seguir aprendiendo',
                                'Continuer',
                                'Weiterlernen',
                                'Continuar aprendendo',
                              )),
                  onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn)),
                ),
                const SizedBox(height: 8),
                Press(
                  onTap: () => Navigator.of(context).push(runRoute(const LadderPage())),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
                      tr(
                        'Tangga gelar',
                        'The ladder of titles',
                        'La escala de títulos',
                        'L’échelle des titres',
                        'Die Titelleiter',
                        'A escada de títulos',
                      ),
                      style: T.body(16, pal.ink, w: FontWeight.w500).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label, value, sub;
  final bool display;
  const _Tile(this.label, this.value, {this.sub = '', this.display = false});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: pal.field,
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.body(12.5, pal.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: display ? T.display(19, pal.ink) : T.body(19, pal.ink, w: FontWeight.w700),
                    ),
                    if (sub.isNotEmpty) TextSpan(text: sub, style: T.body(12.5, pal.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// one place on the road: held, being won, or still shut
class _PlaceRow extends StatelessWidget {
  final int i, rank;
  final String name;
  const _PlaceRow(this.i, this.rank, this.name);

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final e = App.I.engine;
    final held = i <= rank, winning = i == rank + 1;
    final st = i == 0 ? null : e.stat(i);
    final status = held
        ? tr('Dikuasai', 'Held', 'Dominado', 'Conquis', 'Gehalten', 'Conquistado')
        : (winning
              ? (st!.seen > 0
                    ? tr('Sedang direbut', 'Being won', 'En conquista', 'En cours', 'Wird erobert', 'Em conquista')
                    : tr('Mulai di sini', 'Start here', 'Empieza aquí', 'Commence ici', 'Hier beginnen', 'Comece aqui'))
              : tr('Terkunci', 'Locked', 'Cerrado', 'Fermé', 'Gesperrt', 'Fechado'));
    final tint = pal.tincture(i);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: held ? tint : (winning ? pal.field : pal.line),
              border: Border.all(color: held ? pal.ink : (winning ? tint : pal.muted), width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.body(
                    15.5,
                    held || winning ? pal.ink : pal.muted,
                    w: winning ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                Text('${rankNames[i]} · CEFR ${Engine.ranks[i].cefr} · $status', style: T.body(12.5, pal.muted)),
              ],
            ),
          ),
          if (st != null) ...[
            const SizedBox(width: 8),
            SizedBox(width: 72, child: Bar(st.share, height: 6, color: tint)),
            SizedBox(
              width: 70,
              child: Text('${st.solid}/${st.total}', textAlign: TextAlign.right, style: T.body(12.5, pal.muted)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The road of a kingdom painted in its own country, the seven places on it, the road drawn as far as the learner
/// has come, the learner standing there and the castle of the King at the end.
class KingdomRoad extends StatefulWidget {
  final String code;
  final int rank;
  final double share;
  final List<String> places;
  const KingdomRoad({super.key, required this.code, required this.rank, required this.share, required this.places});

  @override
  State<KingdomRoad> createState() => _KingdomRoadState();
}

class _KingdomRoadState extends State<KingdomRoad> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  static const pts = [
    Offset(60, 322),
    Offset(260, 294),
    Offset(110, 262),
    Offset(285, 226),
    Offset(110, 190),
    Offset(285, 154),
    Offset(225, 104),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Look.of(context).calm) {
      _draw.value = 1;
      _life.stop();
    } else {
      if (_draw.value == 0) Future.delayed(const Duration(milliseconds: 500), () => mounted ? _draw.forward() : null);
      if (!_life.isAnimating) _life.repeat();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final rank = widget.rank;
    final cur = min(rank, Engine.maxRank);
    final hero = pts[cur];
    final foe = rank < Engine.maxRank ? pts[rank + 1] : null;
    final en = App.I.game.enemy;
    final g = App.I.game;
    return LayoutBuilder(
      builder: (context, box) {
        final k = box.maxWidth / 390;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_draw, _life]),
                  builder: (context, _) => CustomPaint(
                    painter: _RoadPainter(
                      widget.code,
                      Color(Kingdom.of(widget.code).tint),
                      rank,
                      widget.share,
                      Curves.easeOutCubic.transform(_draw.value),
                      _life.value * 30,
                      widget.places,
                      pal.dark,
                    ),
                  ),
                ),
              ),
            ),
            if (foe != null && en != null)
              Positioned(
                // the guard stands just short of the place it keeps, on the side away from its name
                left: (foe.dx > 200 ? foe.dx + 2 : foe.dx - 48) * k,
                top: (foe.dy - 44) * k,
                child: EnemySprite(sprite: en.sprite, tone: en.tone, size: (en.boss ? 46 : 38) * k),
              ),
            Positioned(
              left: (hero.dx - 18) * k,
              top: (hero.dy - 46) * k,
              child: HeroSprite(
                garb: g.job.garb,
                tier: g.job.tier,
                weapon: g.tone('weapon'),
                shield: g.tone('shield'),
                cloak: g.tone('cloak'),
                livery: App.I.livery,
                size: 36 * k,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoadPainter extends CustomPainter {
  final String code;
  final Color accent;
  final int rank;
  final double share, drawn, s;
  final List<String> places;
  final bool night;
  _RoadPainter(this.code, this.accent, this.rank, this.share, this.drawn, this.s, this.places, this.night);

  static Path road() => Path()
    ..moveTo(60, 322)
    ..cubicTo(160, 318, 250, 310, 260, 294)
    ..cubicTo(270, 278, 120, 280, 110, 262)
    ..cubicTo(100, 244, 275, 244, 285, 226)
    ..cubicTo(295, 208, 120, 208, 110, 190)
    ..cubicTo(100, 172, 275, 172, 285, 154)
    ..cubicTo(295, 136, 225, 134, 225, 104)
    ..lineTo(225, 82);

  Paint fill(int c) => Paint()..color = Color(c);
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
  double osc(double period, [double phase = 0]) => sin(2 * pi * (s / period + phase));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 390;
    canvas.save();
    canvas.scale(k);
    _country(canvas);
    final path = road();
    final metric = path.computeMetrics().first;
    // the whole road, dotted
    var d = 0.0;
    final dot = stroke(const Color(0xFF8A8477), 3);
    while (d < metric.length) {
      canvas.drawPath(metric.extractPath(d, d + 2), dot);
      d += 8;
    }
    // the part already walked, in the kingdom's colour
    final frac = rank >= Engine.maxRank ? 1.0 : ((rank + share) / Engine.maxRank).clamp(0.0, 1.0);
    final upTo = metric.length * 0.94 * frac * drawn;
    if (upTo > 0) canvas.drawPath(metric.extractPath(0, upTo), stroke(accent, 4));
    _castle(canvas);
    const pts = _KingdomRoadState.pts;
    for (var i = 0; i < pts.length; i++) {
      final held = i <= rank, winning = i == rank + 1;
      if (winning) {
        final p = (s % 2.4) / 2.4;
        canvas.drawCircle(pts[i], 9 + p * 12, stroke(accent.withValues(alpha: 1 - p), 2.5));
      }
      canvas.drawCircle(pts[i], 8, fill(held ? accent.toARGB32() : (winning ? 0xFFFCFBF7 : 0xFFCFC9BA)));
      canvas.drawCircle(
        pts[i],
        8,
        stroke(held ? const Color(0xFF1C1B19) : (winning ? accent : const Color(0xFF8A8477)), 2),
      );
      final right = pts[i].dx > 200;
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${places[i]}\n',
              style: TextStyle(
                fontFamily: 'Fell',
                fontSize: 13.5,
                color: held || winning ? const Color(0xFF1C1B19) : const Color(0xFF5C574D),
              ),
            ),
            TextSpan(
              text: rankNames[i],
              style: const TextStyle(fontFamily: 'Alegreya', fontSize: 11, color: Color(0xFF5C574D)),
            ),
          ],
        ),
        textAlign: right ? TextAlign.right : TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 140);
      final o = right ? Offset(pts[i].dx - 16 - tp.width, pts[i].dy - 12) : Offset(pts[i].dx + 16, pts[i].dy - 12);
      final halo = RRect.fromRectAndRadius((o & tp.size).inflate(2), const Radius.circular(3));
      canvas.drawRRect(halo, fill(0xB3F5F2EA));
      tp.paint(canvas, o);
    }
    if (night) canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0x2A101820));
    canvas.restore();
  }

  void _castle(Canvas c) {
    for (final r in const [
      Rect.fromLTWH(205, 44, 40, 28),
      Rect.fromLTWH(198, 36, 12, 36),
      Rect.fromLTWH(240, 36, 12, 36),
    ]) {
      c.drawRect(r, fill(0xFFFCFBF7));
      c.drawRect(r, stroke(const Color(0xFF1C1B19), 1.4)..strokeCap = StrokeCap.butt);
    }
    for (final x in const [198.0, 240.0]) {
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(x + i * 4.5, 33, 2.5, 3), fill(0xFF1C1B19));
      }
    }
    c.drawPath(
      Path()
        ..moveTo(220, 72)
        ..lineTo(220, 63)
        ..arcToPoint(const Offset(230, 63), radius: const Radius.circular(5))
        ..lineTo(230, 72)
        ..close(),
      fill(0xFF1C1B19),
    );
    c.drawLine(const Offset(225, 44), const Offset(225, 22), stroke(const Color(0xFF1C1B19), 1.4));
    final w = osc(1.6) * 1.8;
    c.drawPath(
      Path()
        ..moveTo(225.7, 22)
        ..quadraticBezierTo(234, 22 + w, 241, 22)
        ..lineTo(237, 27)
        ..lineTo(241, 32)
        ..quadraticBezierTo(234, 32 + w, 225.7, 32)
        ..close(),
      Paint()..color = accent,
    );
  }

  void _country(Canvas c) {
    switch (code) {
      case 'de':
        c.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0xFFE2E3E6));
        final m = Path()..moveTo(0, 150);
        for (final (x, y) in const [
          (50.0, 70.0),
          (90.0, 120.0),
          (150.0, 30.0),
          (210.0, 110.0),
          (260.0, 50.0),
          (320.0, 120.0),
          (360.0, 80.0),
          (390.0, 110.0),
        ]) {
          m.lineTo(x, y);
        }
        m
          ..lineTo(390, 340)
          ..lineTo(0, 340)
          ..close();
        c.drawPath(m, fill(0xFF9A9488));
        for (final (x, y) in const [(150.0, 30.0), (260.0, 50.0), (50.0, 70.0)]) {
          c.drawPath(
            Path()
              ..moveTo(x - 15, y + 24)
              ..lineTo(x, y)
              ..lineTo(x + 15, y + 24)
              ..lineTo(x + 7, y + 20)
              ..lineTo(x, y + 26)
              ..lineTo(x - 7, y + 20)
              ..close(),
            fill(0xFFFCFBF7),
          );
        }
        c.drawPath(_hill(170, 156, 178, 152), fill(0xFFE6E4DE));
        for (final (x, y) in const [(20.0, 210.0), (34.0, 214.0), (340.0, 230.0), (354.0, 236.0), (300.0, 300.0)]) {
          c.drawPath(
            Path()
              ..moveTo(x, y)
              ..lineTo(x + 9, y - 22)
              ..lineTo(x + 18, y)
              ..close(),
            fill(0xFF4E5A4A),
          );
        }
        for (var i = 0; i < 9; i++) {
          final f = ((s / 6) + i * .11) % 1;
          c.drawCircle(
            Offset(20 + i * 42.0 + osc(3, i * .1) * 4, f * 200),
            1.8,
            fill(0xFFFCFBF7)..color = const Color(0xFFFCFBF7).withValues(alpha: sin(pi * f)),
          );
        }
      case 'fr':
        c.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0xFFE9E4EC));
        c.drawPath(_hill(110, 90, 116, 96), fill(0xFFE6E1DA));
        final r = Path()
          ..moveTo(390, 120)
          ..cubicTo(330, 150, 360, 200, 300, 230)
          ..cubicTo(240, 260, 200, 300, 120, 340);
        c.drawPath(r, stroke(const Color(0xFF7F9AA0), 6));
        for (var i = 0; i < 4; i++) {
          c.drawLine(
            Offset(10, 150.0 + i * 15),
            Offset(120, 150.0 + i * 15),
            stroke(const Color(0xFF5A2A6B), 2.5)..strokeCap = StrokeCap.round,
          );
        }
        c.save();
        c.translate(334, 92);
        c.rotate(s / 6 * 2 * pi);
        for (var i = 0; i < 4; i++) {
          c.drawLine(Offset.zero, const Offset(0, -20), stroke(const Color(0xFF5C574D), 2));
          c.drawRect(const Rect.fromLTWH(0, -20, 5, 12), fill(0xFFFCFBF7));
          c.rotate(pi / 2);
        }
        c.restore();
      case 'es':
        c.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0xFFF3E7CC));
        c.save();
        c.translate(64, 58);
        c.rotate(s / 24 * 2 * pi);
        c.drawCircle(Offset.zero, 20, fill(0xFFD9B861));
        for (var i = 0; i < 8; i++) {
          c.drawLine(const Offset(0, -32), const Offset(0, -42), stroke(const Color(0xFF9A7B2C), 2.4));
          c.rotate(pi / 4);
        }
        c.restore();
        c.drawPath(_hill(120, 104, 128, 110), fill(0xFFEADCB8));
        for (final (x, y) in const [(330.0, 150.0), (352.0, 164.0), (30.0, 200.0), (350.0, 300.0)]) {
          c.drawCircle(Offset(x, y), 9, fill(0xFF6E7F4E));
        }
        final a = .25 + (osc(3) + 1) / 2 * .35;
        for (final (x, y) in const [(150.0, 150.0), (220.0, 230.0), (40.0, 250.0)]) {
          final p = Path()
            ..moveTo(x, y)
            ..relativeQuadraticBezierTo(8, -4, 16, 0)
            ..relativeQuadraticBezierTo(8, 4, 16, 0);
          c.drawPath(p, stroke(const Color(0xFFC9A27E).withValues(alpha: a), 1.5));
        }
      case 'pt':
        c.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0xFFD2DEDB));
        final landP = Path()
          ..moveTo(0, 100)
          ..cubicTo(80, 90, 200, 110, 300, 96)
          ..cubicTo(320, 160, 290, 240, 330, 340)
          ..lineTo(0, 340)
          ..close();
        c.drawPath(landP, fill(0xFFE7E3D6));
        c.drawPath(landP, stroke(const Color(0xFF5C574D), 1.4));
        for (final (x, y, p) in const [
          (330.0, 140.0, 0.0),
          (340.0, 200.0, .4),
          (320.0, 290.0, .7),
          (20.0, 60.0, .2),
          (120.0, 40.0, .5),
        ]) {
          final w = Path()
            ..moveTo(x + osc(5, p) * 6, y)
            ..relativeQuadraticBezierTo(8, -5, 16, 0)
            ..relativeQuadraticBezierTo(8, 5, 16, 0);
          c.drawPath(w, stroke(const Color(0xFF8FA6A3), 1.6));
        }
        final beam = (osc(4) + 1) / 2;
        c.drawPath(
          Path()
            ..moveTo(352, 52)
            ..lineTo(390, 40)
            ..lineTo(390, 64)
            ..close(),
          fill(0xFFF4E3A6)..color = const Color(0xFFF4E3A6).withValues(alpha: .2 + beam * .7),
        );
        c.drawPath(
          Path()
            ..moveTo(344, 80)
            ..lineTo(347, 52)
            ..lineTo(357, 52)
            ..lineTo(360, 80)
            ..close(),
          fill(0xFFFCFBF7),
        );
        c.drawLine(
          const Offset(346, 70),
          const Offset(358, 70),
          stroke(const Color(0xFF8E1B16), 3)..strokeCap = StrokeCap.butt,
        );
        c.save();
        c.translate(357, 252 + osc(3.2) * 2);
        c.rotate(osc(3.2, .25) * .07);
        c.drawPath(
          Path()
            ..moveTo(-17, 0)
            ..lineTo(17, 0)
            ..lineTo(11, 8)
            ..lineTo(-11, 8)
            ..close(),
          fill(0xFF6B4F3A),
        );
        c.drawLine(Offset.zero, const Offset(0, -26), stroke(const Color(0xFF1C1B19), 1.3));
        c.drawPath(
          Path()
            ..moveTo(1, -24)
            ..lineTo(13, -4)
            ..lineTo(1, -4)
            ..close(),
          fill(0xFFFCFBF7),
        );
        c.restore();
      default:
        c.drawRect(const Rect.fromLTWH(0, 0, 390, 340), fill(0xFFE4E8EE));
        c.drawPath(_hill(120, 92, 112, 98), fill(0xFFD6D3C3));
        c.drawPath(_hill(190, 168, 200, 168), fill(0xFFE9E6DA));
        for (final (x, y, r) in const [
          (40.0, 112.0, 8.0),
          (56.0, 118.0, 6.0),
          (330.0, 98.0, 8.0),
          (348.0, 104.0, 6.0),
          (30.0, 236.0, 9.0),
          (360.0, 260.0, 9.0),
        ]) {
          c.drawCircle(Offset(x, y), r, fill(0xFF7C8A63));
        }
        for (final (x, y) in const [(300.0, 200.0), (40.0, 290.0)]) {
          c.drawRect(Rect.fromLTWH(x, y, 16, 12), fill(0xFFFCFBF7));
          c.drawPath(
            Path()
              ..moveTo(x - 2, y)
              ..lineTo(x + 8, y - 8)
              ..lineTo(x + 18, y)
              ..close(),
            fill(0xFF8E1B16),
          );
        }
    }
    // a cloud drifting over every country
    final x = -80 + ((s / 30) % 1) * 560;
    _CloudPainter._cloud(c, Offset(x, 150), 22, fill(0xD9FCFBF7));
  }

  Path _hill(double y0, double y1, double y2, double y3) => Path()
    ..moveTo(0, y0)
    ..cubicTo(80, y1, 160, y2, 220, y2 - 14)
    ..cubicTo(290, y3 - 14, 340, y3, 390, y3 - 6)
    ..lineTo(390, 340)
    ..lineTo(0, 340)
    ..close();

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.s != s || old.drawn != drawn || old.rank != rank || old.share != share || old.code != code;
}

// ---------------------------------------------------------------------------- the ladder of titles

class LadderPage extends StatelessWidget {
  const LadderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final app = App.I;
    final rank = app.engine.rank;
    final english = app.realm == 'en';
    return Leaf(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Press(
                onTap: () => Navigator.of(context).pop(),
                label: tr('Kembali', 'Back', 'Volver', 'Retour', 'Zurück', 'Voltar'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(
                  tr(
                    'Tangga gelar',
                    'The ladder of titles',
                    'La escala de títulos',
                    'L’échelle des titres',
                    'Die Titelleiter',
                    'A escada de títulos',
                  ),
                  style: T.display(26, pal.ink),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                Text(
                  tr(
                    'Tiap gelar berarti kosakata setara satu tingkat CEFR. Skor ujian juga ditentukan membaca, menyimak, menulis dan berbicara.',
                    'Each title means vocabulary at one CEFR level. A test score also depends on reading, listening, writing and speaking.',
                    'Cada título equivale al vocabulario de un nivel MCER. La nota de un examen también depende de leer, escuchar, escribir y hablar.',
                    'Chaque titre équivaut au vocabulaire d’un niveau CECRL. Un score dépend aussi de la lecture, de l’écoute, de l’écrit et de l’oral.',
                    'Jeder Titel steht für Wortschatz auf einer GER-Stufe. Ein Prüfungsergebnis hängt auch von Lesen, Hören, Schreiben und Sprechen ab.',
                    'Cada título significa vocabulário num nível do QECR. A nota de uma prova também depende de leitura, escuta, escrita e fala.',
                  ),
                  style: T.body(15.5, pal.muted, height: 1.45),
                ),
                const SizedBox(height: 12),
                for (var r = Engine.maxRank; r >= 0; r--)
                  Rise(
                    delay: Duration(milliseconds: 50 * (Engine.maxRank - r)),
                    child: _LadderRung(r, rank, english ? app.banner : ''),
                  ),
                const SizedBox(height: 12),
                if (english)
                  Text(
                    tr(
                      'TOEFL pada skala 1–6. Sumber: penyelarasan CEFR dari IELTS dan ETS. Tingkat kata dari Oxford 3000/5000.',
                      'TOEFL on the 1–6 scale. Sources: the CEFR alignments of IELTS and ETS. Word levels from the Oxford 3000/5000.',
                      'TOEFL en la escala de 1 a 6. Fuentes: las equivalencias MCER de IELTS y ETS. Niveles de palabras del Oxford 3000/5000.',
                      'TOEFL sur l’échelle de 1 à 6. Sources : les correspondances CECRL d’IELTS et d’ETS. Niveaux des mots selon l’Oxford 3000/5000.',
                      'TOEFL auf der Skala 1–6. Quellen: die GER-Zuordnungen von IELTS und ETS. Wortstufen aus den Oxford 3000/5000.',
                      'TOEFL na escala 1–6. Fontes: os alinhamentos ao QECR do IELTS e da ETS. Níveis das palavras do Oxford 3000/5000.',
                    ),
                    style: T.body(13.5, pal.muted, height: 1.4),
                  ),
                Press(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage())),
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(
                        'Dari mana angka ini?',
                        'Where do these numbers come from?',
                        '¿De dónde salen estos números?',
                        'D’où viennent ces chiffres ?',
                        'Woher kommen diese Zahlen?',
                        'De onde vêm esses números?',
                      ),
                      style: T.body(16, pal.ink, w: FontWeight.w500).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LadderRung extends StatelessWidget {
  final int r, rank;
  final String banner;
  const _LadderRung(this.r, this.rank, this.banner);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final info = Engine.ranks[r];
    final held = r <= rank, here = r == rank;
    final state = here
        ? '${tr('Gelarmu', 'Your title', 'Tu título', 'Ton titre', 'Dein Titel', 'Seu título')}${r < Engine.maxRank ? ' · ${stageName(App.I.engine.stage)}' : ''}'
        : (held
              ? tr('Sudah dilalui', 'Passed', 'Superado', 'Franchi', 'Bestanden', 'Superado')
              : (r == rank + 1 ? tr('Berikutnya', 'Next', 'Siguiente', 'Suivant', 'Als Nächstes', 'Próximo') : ''));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pal.field,
        border: Border.all(color: here ? pal.tincture(r) : pal.line, width: here ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Shield(r, width: 30, hollow: !held),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rankNames[r], style: T.display(19, held ? pal.ink : pal.muted)),
                Text('CEFR ${info.cefr}${state.isEmpty ? '' : ' · $state'}', style: T.body(12.5, pal.muted)),
              ],
            ),
          ),
          if (banner.isNotEmpty) ...[
            _Score('IELTS', info.ielts),
            const SizedBox(width: 10),
            _Score('TOEFL', info.toefl),
          ],
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  final String name, value;
  const _Score(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return SizedBox(
      width: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(name, style: T.body(11, pal.muted)),
          Text(value.replaceAll('<', '< '), style: T.body(14, pal.ink)),
        ],
      ),
    );
  }
}
