/// Kitab kata: the words of the kingdom as loot. Each word's hold is a rarity (Common … Legendary, from its FSRS
/// stability), its ink fades as recall falls, and the words forgotten five times stand on the bounty board until
/// they are beaten. Reads the memory, never changes it.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../data/deck.dart';
import '../engine/engine.dart';
import 'theme.dart';
import 'widgets.dart';

/// the charge of each rarity: a shape of its own, so colour is never the only sign
class RarityMark extends StatelessWidget {
  final int r;
  final double size;
  const RarityMark(this.r, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return CustomPaint(size: Size.square(size), painter: _MarkPainter(r, look.pal.ink, look.accent));
  }
}

class _MarkPainter extends CustomPainter {
  final int r;
  final Color ink, accent;
  _MarkPainter(this.r, this.ink, this.accent);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final h = s.width / 2;
    final fill = Paint()..color = r >= 3 ? accent : ink;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    switch (r) {
      case 1: // a dot
        canvas.drawCircle(c, h * 0.35, fill);
      case 2: // a ring
        canvas.drawCircle(c, h * 0.6, line);
      case 3: // a lozenge
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - h * 0.85)
            ..lineTo(c.dx + h * 0.6, c.dy)
            ..lineTo(c.dx, c.dy + h * 0.85)
            ..lineTo(c.dx - h * 0.6, c.dy)
            ..close(),
          fill,
        );
      case 4: // a mullet (five points)
        canvas.drawPath(_star(c, h * 0.9, h * 0.4, 5), fill);
      case 5: // a sun: eight points in a ring
        canvas.drawPath(_star(c, h, h * 0.55, 8), fill);
        canvas.drawCircle(c, h * 0.3, Paint()..color = ink);
      default:
        canvas.drawCircle(c, h * 0.35, line);
    }
  }

  static Path _star(Offset c, double out, double inner, int n) {
    final p = Path();
    for (var i = 0; i < n * 2; i++) {
      final a = -pi / 2 + i * pi / n;
      final rr = i.isEven ? out : inner;
      final pt = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.r != r || o.ink != ink || o.accent != accent;
}

String rarityHint(int r) => switch (r) {
  1 => tr(
    'di bawah seminggu',
    'under a week',
    'menos de una semana',
    'moins d’une semaine',
    'unter einer Woche',
    'menos de uma semana',
  ),
  2 => tr(
    'di bawah 3 minggu',
    'under 3 weeks',
    'menos de 3 semanas',
    'moins de 3 semaines',
    'unter 3 Wochen',
    'menos de 3 semanas',
  ),
  3 => tr(
    'di bawah 2 bulan',
    'under 2 months',
    'menos de 2 meses',
    'moins de 2 mois',
    'unter 2 Monaten',
    'menos de 2 meses',
  ),
  4 => tr(
    'di bawah 6 bulan',
    'under 6 months',
    'menos de 6 meses',
    'moins de 6 mois',
    'unter 6 Monaten',
    'menos de 6 meses',
  ),
  _ => tr(
    'lebih lama, dan kata yang mudah',
    'longer, and not a hard word',
    'más, y no es difícil',
    'plus, et pas un mot difficile',
    'länger, und kein schweres Wort',
    'mais, e não é palavra difícil',
  ),
};

class CodexPage extends StatefulWidget {
  const CodexPage({super.key});

  @override
  State<CodexPage> createState() => _CodexPageState();
}

class _CodexPageState extends State<CodexPage> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final e = App.I.engine;
    final g = App.I.game;
    final n = e.rarities;
    final met = n.fold<int>(0, (a, b) => a + b);
    final nemeses = g.nemeses;
    final fading = e.dueCount;
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
                    'Kitab kata',
                    'Book of words',
                    'Libro de palabras',
                    'Livre des mots',
                    'Buch der Wörter',
                    'Livro das palavras',
                  ),
                  style: T.display(25, pal.ink),
                ),
              ),
              Text('$met', style: T.body(15.5, pal.muted)),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                Text(
                  tr(
                    'Tiap kata yang kamu temui tercatat di sini. Makin lama kata itu melekat, makin langka tingkatnya. Tintanya memudar saat kata mulai terlupa; mengulangnya menebalkan tinta lagi.',
                    'Every word you meet is written here. The longer it holds, the rarer it becomes. Its ink fades as the word begins to slip; a review darkens it again.',
                    'Cada palabra que conoces queda escrita aquí. Cuanto más dura, más rara se vuelve. Su tinta se apaga cuando empieza a olvidarse; un repaso la oscurece de nuevo.',
                    'Chaque mot rencontré s’inscrit ici. Plus il tient, plus il devient rare. Son encre pâlit quand il commence à s’effacer ; une révision la fonce à nouveau.',
                    'Jedes Wort, dem du begegnest, steht hier. Je länger es hält, desto seltener wird es. Seine Tinte verblasst, wenn es zu entgleiten beginnt; eine Wiederholung dunkelt sie wieder.',
                    'Cada palavra que você encontra fica escrita aqui. Quanto mais ela dura, mais rara fica. A tinta desbota quando ela começa a sumir; uma revisão a escurece de novo.',
                  ),
                  style: T.body(15, pal.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                for (var r = 5; r >= 1; r--) ...[
                  Press(
                    onTap: () => setState(() => _open = _open == r ? null : r),
                    label: '${Engine.rarityNames[r]} ${n[r]}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Center(child: RarityMark(r))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Engine.rarityNames[r], style: T.body(16, pal.ink, w: FontWeight.w600)),
                                Text(rarityHint(r), style: T.body(13.5, pal.muted)),
                              ],
                            ),
                          ),
                          Text('${n[r]}', style: T.body(17, pal.ink)),
                          Icon(_open == r ? Icons.expand_less : Icons.expand_more, color: pal.muted),
                        ],
                      ),
                    ),
                  ),
                  if (_open == r) _Words(r),
                ],
                const SizedBox(height: 22),
                Label(
                  tr(
                    'Halaman memudar',
                    'Fading pages',
                    'Páginas que se apagan',
                    'Pages qui pâlissent',
                    'Verblassende Seiten',
                    'Páginas desbotando',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fading == 0
                      ? tr(
                          'Tidak ada. Kabut di negerimu tipis.',
                          'None. The fog over your kingdom is thin.',
                          'Ninguna. La niebla sobre tu reino es fina.',
                          'Aucune. Le brouillard sur ton royaume est léger.',
                          'Keine. Der Nebel über deinem Reich ist dünn.',
                          'Nenhuma. A névoa sobre seu reino está fina.',
                        )
                      : tr(
                          '$fading kata menunggu untuk ditebalkan lagi.',
                          '$fading words are waiting to be inked again.',
                          '$fading palabras esperan a ser repasadas.',
                          '$fading mots attendent d’être repassés à l’encre.',
                          '$fading Wörter warten darauf, nachgezogen zu werden.',
                          '$fading palavras esperam ser reforçadas.',
                        ),
                  style: T.body(15.5, pal.ink, height: 1.45),
                ),
                const SizedBox(height: 22),
                Label(
                  tr(
                    'Papan Buronan',
                    'Bounty board',
                    'Tablón de recompensas',
                    'Tableau des primes',
                    'Kopfgeldbrett',
                    'Quadro de recompensas',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'Kata yang sudah lima kali terlupa menjadi Nemesis. Artinya muncul lagi sebagai petunjuk. Isi celahnya bersih dua kali, di dua hari ulangan, untuk mengalahkannya. Sudah dikalahkan: ${g.beaten.length}.',
                    'A word forgotten five times becomes a Nemesis. Its meaning shows again as a hint. Fill its gap cleanly twice, on two days of review, to beat it. Beaten so far: ${g.beaten.length}.',
                    'Una palabra olvidada cinco veces se vuelve Némesis. Su significado vuelve como pista. Complétala sin fallo dos veces, en dos días de repaso, para vencerla. Vencidas: ${g.beaten.length}.',
                    'Un mot oublié cinq fois devient une Némésis. Son sens revient en indice. Remplis son trou sans faute deux fois, sur deux jours de révision, pour la vaincre. Vaincues : ${g.beaten.length}.',
                    'Ein fünfmal vergessenes Wort wird zur Nemesis. Seine Bedeutung erscheint wieder als Hinweis. Füll seine Lücke an zwei Wiederholungstagen zweimal fehlerfrei, um sie zu besiegen. Besiegt: ${g.beaten.length}.',
                    'Uma palavra esquecida cinco vezes vira Nêmesis. O sentido volta como dica. Preencha a lacuna sem erro duas vezes, em dois dias de revisão, para vencê-la. Vencidas: ${g.beaten.length}.',
                  ),
                  style: T.body(15, pal.muted, height: 1.45),
                ),
                const SizedBox(height: 8),
                for (final w in nemeses.take(30))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 18, color: look.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(w.answer(App.I.british), style: T.body(16, pal.ink, w: FontWeight.w600)),
                        ),
                        Flexible(
                          child: Text(w.gloss, style: T.body(14.5, pal.muted), textAlign: TextAlign.right),
                        ),
                      ],
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

/// the words of one rarity, their ink as dark as their recall
class _Words extends StatelessWidget {
  final int r;
  const _Words(this.r);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final e = App.I.engine;
    final words = <Word>[
      for (final w in e.deck.words)
        if (e.seen(w) && e.rarity(w) == r) w,
    ]..sort((a, b) => e.recall(a).compareTo(e.recall(b)));
    if (words.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(38, 0, 0, 10),
        child: Text(
          tr('Belum ada.', 'None yet.', 'Ninguna aún.', 'Aucun pour l’instant.', 'Noch keine.', 'Nenhuma ainda.'),
          style: T.body(14.5, pal.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 0, 0, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final w in words.take(200))
            Semantics(
              label: '${w.answer(App.I.british)}, ${(e.recall(w) * 100).round()}%',
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (0.35 + 0.65 * e.recall(w)).clamp(0.35, 1.0),
                  child: Text(w.answer(App.I.british), style: T.body(15.5, pal.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
