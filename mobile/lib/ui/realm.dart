/// Negeri: the realm as a map (one land per rank, inked in as its words become solid) and the ladder of titles
/// with the test scores each one's vocabulary is on a par with.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/engine.dart';
import 'pixel.dart';
import 'root.dart';
import 'run.dart' show stageName;
import 'theme.dart';
import 'widgets.dart';

List<String> get landNames => [tr('Desa', 'Village', 'Aldea', 'Village'), tr('Kota', 'Town', 'Ciudad', 'Ville'), tr('Kastel', 'Castle', 'Castillo', 'Château'), tr('Kadipaten', 'Duchy', 'Ducado', 'Duché'), tr('Takhta', 'Throne', 'Trono', 'Trône')];

class RealmTab extends StatelessWidget {
  const RealmTab({super.key});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    final e = app.engine;
    final rank = e.rank;
    final shares = [for (var t = 1; t <= 5; t++) e.stat(t).share];
    return TabBody(
      children: [
        Label(tr('Negerimu', 'Your realm', 'Tu reino', 'Ton royaume')),
        const SizedBox(height: 6),
        Text(
          tr('${rankNames[rank]} di bawah panji ${bannerName(app.banner)}', '${rankNames[rank]} under the banner of ${bannerName(app.banner)}', '${rankNames[rank]} bajo el estandarte de ${bannerName(app.banner)}', '${rankNames[rank]} sous la bannière de ${bannerName(app.banner)}'),
          style: T.display(31, pal.ink),
        ),
        const SizedBox(height: 16),
        Rise(
          child: _World(rank: rank, shares: shares),
        ),
        const SizedBox(height: 18),
        const FightCard(),
        const SizedBox(height: 20),
        const Rule(),
        for (var r = 0; r <= Engine.maxRank; r++) _Rung(r, rank, app.banner),
        const SizedBox(height: 12),
        Text(
          tr(
            'Gelar mengukur kosakata, bukan menjamin skor ujian. Skor juga ditentukan oleh membaca, menyimak, menulis dan berbicara.',
            'A title measures vocabulary; it does not promise a test score. A score also depends on reading, listening, writing and speaking.', 'Un título mide el vocabulario; no promete una nota. La nota también depende de leer, escuchar, escribir y hablar.', 'Un titre mesure le vocabulaire ; il ne promet pas de score. Le score dépend aussi de la lecture, de l’écoute, de l’écriture et de l’oral.',
          ),
          style: T.body(15, pal.muted, height: 1.45),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Press(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage())),
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              child: Text(
                tr('Dari mana angka ini?', 'Where do these numbers come from?', '¿De dónde salen estos números?', 'D’où viennent ces chiffres ?'),
                style: T.body(16, pal.ink, w: FontWeight.w500).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The map with life on it: the hero walks in from the land already held and stops before the one being won,
/// where the enemy of the hour stands.
class _World extends StatelessWidget {
  final int rank;
  final List<double> shares;
  const _World({required this.rank, required this.shares});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final g = App.I.game;
    final en = g.enemy;
    const towns = _MapPainter._towns;
    final from = rank <= 1 ? const Offset(20, 176) : towns[rank - 2];
    final at = rank == 0 ? const Offset(26, 170) : towns[rank - 1];
    final foe = rank < 5 ? towns[rank] : null;
    return Semantics(
      label:
          '${tr('Peta negeri.', 'Map of the realm.', 'Mapa del reino.', 'Carte du royaume.')} ${[for (var t = 1; t <= 5; t++) '${landNames[t - 1]} ${t <= rank ? tr('dikuasai', 'held', 'dominado', 'conquis') : (t == rank + 1 ? tr('sedang direbut', 'being won', 'en conquista', 'en cours de conquête') : tr('belum terbuka', 'not open yet', 'aún cerrado', 'pas encore ouvert'))}'].join(', ')}.${en == null ? '' : tr(' ${en.name} menghadang.', ' The ${en.name} bars the way.', ' ${en.name} cierra el paso.', ' ${en.name} barre la route.')}',
      child: AspectRatio(
        aspectRatio: 342 / 214,
        child: LayoutBuilder(
          builder: (context, box) {
            final k = box.maxWidth / 342;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: look.calm ? Duration.zero : const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, t, _) {
                final p = Offset.lerp(from, at, t)!;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _MapPainter(look.pal, rank, shares, t))),
                    if (foe != null && en != null)
                      Positioned(
                        left: (foe.dx + 12) * k,
                        top: (foe.dy - 30) * k,
                        child: EnemySprite(sprite: en.sprite, tone: en.tone, size: (en.boss ? 34 : 28) * k),
                      ),
                    Positioned(
                      left: (p.dx - 12) * k,
                      top: (p.dy - 30) * k,
                      child: HeroSprite(
                        garb: g.job.garb,
                        tier: g.job.tier,
                        weapon: g.tone('weapon'),
                        shield: g.tone('shield'),
                        cloak: g.tone('cloak'),
                        pose: t < 1 ? HeroPose.walk : HeroPose.idle,
                        size: 26 * k,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  final int r, rank;
  final String banner;
  const _Rung(this.r, this.rank, this.banner);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final info = Engine.ranks[r];
    final held = r <= rank;
    final state = r < rank
        ? tr('Dilewati', 'Passed', 'Superado', 'Franchi')
        : (r == rank
              ? '${tr('Gelarmu kini', 'Your title now', 'Tu título ahora', 'Ton titre actuel')}${r < Engine.maxRank ? tr(' · tingkat ${stageName(App.I.engine.stage)}', ' · stage ${stageName(App.I.engine.stage)}', ' · etapa ${stageName(App.I.engine.stage)}', ' · étape ${stageName(App.I.engine.stage)}') : ''}'
              : (r == rank + 1 ? tr('Berikutnya', 'Next', 'Siguiente', 'Suivant') : tr('Belum terbuka', 'Not open yet', 'Aún cerrado', 'Pas encore ouvert')));
    final score = banner == 'ielts'
        ? 'IELTS ${below(info.ielts)}'
        : tr('TOEFL iBT ${below(info.toefl)} (skala lama ${below(info.toeflOld)})', 'TOEFL iBT ${below(info.toefl)} (old scale ${below(info.toeflOld)})', 'TOEFL iBT ${below(info.toefl)} (escala antigua ${below(info.toeflOld)})', 'TOEFL iBT ${below(info.toefl)} (ancienne échelle ${below(info.toeflOld)})');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          Shield(r, width: 30, hollow: !held),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rankNames[r], style: T.display(22, held ? pal.ink : pal.muted)),
                    const SizedBox(width: 10),
                    Text(state, style: T.body(14.5, pal.muted, w: r == rank ? FontWeight.w700 : FontWeight.w400)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('$score · CEFR ${info.cefr}', style: T.body(15, pal.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Five lands along a road. A land already held is filled, the one being won fills from the bottom as its words
/// become solid, the rest are dotted outlines.
class _MapPainter extends CustomPainter {
  final Pal pal;
  final int rank;
  final List<double> shares;
  final double t;
  _MapPainter(this.pal, this.rank, this.shares, this.t);

  static const _lands = [
    [Offset(14, 150), Offset(52, 104), Offset(98, 122), Offset(92, 190), Offset(28, 196)],
    [Offset(98, 122), Offset(120, 66), Offset(176, 78), Offset(170, 150), Offset(92, 190)],
    [Offset(176, 78), Offset(206, 26), Offset(262, 40), Offset(250, 118), Offset(170, 150)],
    [Offset(170, 150), Offset(250, 118), Offset(292, 150), Offset(262, 200), Offset(180, 200)],
    [Offset(262, 40), Offset(326, 30), Offset(330, 132), Offset(292, 150), Offset(250, 118)],
  ];
  static const _towns = [Offset(54, 152), Offset(134, 124), Offset(214, 84), Offset(226, 164), Offset(292, 86)];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 342;
    canvas.save();
    canvas.scale(k);
    const frame = Rect.fromLTWH(1, 1, 340, 212);
    canvas.drawRect(frame, Paint()..color = pal.deep);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..color = pal.ink;

    for (var i = 0; i < 5; i++) {
      final tier = i + 1;
      final path = Path()..addPolygon(_lands[i], true);
      final tint = pal.tincture(tier);
      if (tier <= rank) {
        canvas.drawPath(path, Paint()..color = Color.lerp(pal.deep, tint, pal.dark ? 0.34 : 0.26)!);
        canvas.drawPath(path, ink);
      } else if (tier == rank + 1) {
        canvas.drawPath(path, Paint()..color = pal.field);
        final b = path.getBounds();
        final h = b.height * shares[i] * t;
        canvas.save();
        canvas.clipPath(path);
        canvas.drawRect(Rect.fromLTRB(b.left, b.bottom - h, b.right, b.bottom), Paint()..color = Color.lerp(pal.field, tint, pal.dark ? 0.4 : 0.3)!);
        canvas.restore();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeJoin = StrokeJoin.round
            ..color = tint,
        );
      } else {
        _dashed(
          canvas,
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = pal.muted,
        );
      }
    }

    // the road, drawn as far as the land being won
    final road = Path()..moveTo(_towns[0].dx, _towns[0].dy);
    final reach = min(rank + 1, 5);
    for (var i = 1; i < reach; i++) {
      final a = _towns[i - 1], b = _towns[i];
      road.quadraticBezierTo((a.dx + b.dx) / 2, min(a.dy, b.dy) - 6, b.dx, b.dy);
    }
    if (reach > 1) {
      for (final m in road.computeMetrics()) {
        _dashed(
          canvas,
          m.extractPath(0, m.length * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = pal.ink,
          on: 2,
          off: 5,
        );
      }
    }

    for (var i = 0; i < 5; i++) {
      final tier = i + 1;
      final p = _towns[i];
      final open = tier <= rank + 1;
      if (tier == rank + 1) {
        // a keep with battlements on the land being won
        final tint = pal.tincture(tier);
        final keep = Path()
          ..moveTo(p.dx - 11, p.dy + 6)
          ..lineTo(p.dx - 11, p.dy - 10)
          ..lineTo(p.dx - 6, p.dy - 10)
          ..lineTo(p.dx - 6, p.dy - 5)
          ..lineTo(p.dx - 2, p.dy - 5)
          ..lineTo(p.dx - 2, p.dy - 10)
          ..lineTo(p.dx + 2, p.dy - 10)
          ..lineTo(p.dx + 2, p.dy - 5)
          ..lineTo(p.dx + 6, p.dy - 5)
          ..lineTo(p.dx + 6, p.dy - 10)
          ..lineTo(p.dx + 11, p.dy - 10)
          ..lineTo(p.dx + 11, p.dy + 6)
          ..close();
        canvas.drawPath(keep, Paint()..color = tint);
      } else if (open) {
        canvas.drawCircle(p, 4, Paint()..color = pal.ink);
      } else {
        canvas.drawCircle(
          p,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = pal.muted,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: landNames[i],
          style: TextStyle(
            fontFamily: T.sans,
            fontSize: 12.5,
            fontWeight: tier == rank + 1 ? FontWeight.w700 : FontWeight.w500,
            color: open ? pal.ink : pal.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy + 10));
    }
    canvas.drawRect(frame, ink..strokeWidth = 1.5);
    canvas.restore();
  }

  void _dashed(Canvas canvas, Path path, Paint paint, {double on = 5, double off = 4}) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, min(d + on, m.length)), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.t != t || old.rank != rank || old.pal != pal || old.shares.toString() != shares.toString();
}

/// Where the score ranges come from (docs/riset-skor.md has the same, with links).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    Widget p(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(s, style: T.body(16.5, pal.ink, height: 1.5)),
    );
    Widget h(String s) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(s, style: T.display(23, pal.ink)),
    );
    return Leaf(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Press(
                onTap: () => Navigator.of(context).pop(),
                label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(child: Text(tr('Dari mana angka ini?', 'Where do these numbers come from?', '¿De dónde salen estos números?', 'D’où viennent ces chiffres ?'), style: T.display(25, pal.ink))),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                p(
                  tr(
                    'Tiap gelar dipasangkan dengan satu tingkat CEFR, kerangka Eropa yang dipakai kedua ujian untuk menjelaskan skornya. Rentang skor di tangga gelar diambil dari penyelarasan CEFR milik penyelenggara ujian sendiri.',
                    'Each title is paired with one CEFR level, the European framework both tests use to explain their scores. The score ranges on the ladder of titles are taken from the test owners\' own CEFR alignments.', 'Cada título se empareja con un nivel del MCER, el marco europeo que ambos exámenes usan para explicar sus notas. Los rangos de la escala de títulos salen de las equivalencias MCER publicadas por los propios dueños de los exámenes.', 'Chaque titre correspond à un niveau du CECRL, le cadre européen que les deux tests utilisent pour expliquer leurs scores. Les fourchettes de l’échelle des titres viennent des correspondances CECRL publiées par les organismes des tests eux-mêmes.',
                  ),
                ),
                h('IELTS'),
                p(
                  tr(
                    'B1 = band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 berada di perbatasan C1 dan C2. Sumber: halaman "IELTS and the CEFR" di ielts.org, berdasarkan kajian Cambridge English.',
                    'B1 = band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 sits on the border of C1 and C2. Source: the page "IELTS and the CEFR" on ielts.org, based on studies by Cambridge English.', 'B1 = banda 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. La banda 8.0 está en el límite entre C1 y C2. Fuente: la página «IELTS and the CEFR» de ielts.org, basada en estudios de Cambridge English.', 'B1 = bande 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. La bande 8.0 se situe à la limite entre C1 et C2. Source : la page « IELTS and the CEFR » sur ielts.org, fondée sur des études de Cambridge English.',
                  ),
                ),
                h('TOEFL iBT'),
                p(
                  tr(
                    'Sejak 21 Januari 2026 skor dilaporkan pada skala 1–6. Menurut ETS: 6 = 114 ke atas pada skala lama, 5.5 = 107 ke atas, 5 = 95 ke atas, 4.5 = 86 ke atas, 4 = 72 ke atas, 3.5 = 58 ke atas, 3 = 44 ke atas.',
                    'Since 21 January 2026 scores are reported on a scale of 1–6. According to ETS: 6 = 114 and above on the old scale, 5.5 = 107 and above, 5 = 95 and above, 4.5 = 86 and above, 4 = 72 and above, 3.5 = 58 and above, 3 = 44 and above.', 'Desde el 21 de enero de 2026 las notas se dan en una escala de 1 a 6. Según ETS: 6 = 114 o más en la escala antigua, 5.5 = 107 o más, 5 = 95 o más, 4.5 = 86 o más, 4 = 72 o más, 3.5 = 58 o más, 3 = 44 o más.', 'Depuis le 21 janvier 2026, les scores sont donnés sur une échelle de 1 à 6. Selon ETS : 6 = 114 et plus sur l’ancienne échelle, 5.5 = 107 et plus, 5 = 95 et plus, 4.5 = 86 et plus, 4 = 72 et plus, 3.5 = 58 et plus, 3 = 44 et plus.',
                  ),
                ),
                p(
                  tr(
                    'Padanan CEFR pada skala lama, juga dari ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'The CEFR levels on the old scale, also from ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.', 'Los niveles MCER en la escala antigua, también de ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.', 'Les niveaux CECRL sur l’ancienne échelle, également selon ETS : B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                  ),
                ),
                h(tr('Yang kami putuskan sendiri', 'What we decided ourselves', 'Lo que decidimos nosotros', 'Ce que nous avons décidé nous-mêmes')),
                p(
                  tr(
                    'C1 dibagi menjadi dua gelar, Baron dan Duke, supaya jarak antargelar tidak terlalu jauh. Pada TOEFL pembagian itu mengikuti setengah band (5 dan 5.5). Pada IELTS pembagian 7.0 lalu 7.5–8.0 adalah keputusan Verbarium, bukan ketetapan resmi.',
                    'C1 is split into two titles, Baron and Duke, so that the step between titles is not too large. On TOEFL the split follows the half bands (5 and 5.5). On IELTS the split into 7.0 and then 7.5–8.0 is Verbarium\'s decision, not an official one.', 'El C1 se divide en dos títulos, Baron y Duke, para que el salto entre títulos no sea demasiado grande. En TOEFL la división sigue las medias bandas (5 y 5.5). En IELTS, la división en 7.0 y luego 7.5–8.0 es decisión de Verbarium, no oficial.', 'Le C1 est partagé en deux titres, Baron et Duke, pour que le pas entre titres ne soit pas trop grand. Au TOEFL, le partage suit les demi-bandes (5 et 5.5). À l’IELTS, le partage en 7.0 puis 7.5–8.0 est un choix de Verbarium, non officiel.',
                  ),
                ),
                p(
                  tr(
                    'Pemilihan kata untuk tiap ranah juga keputusan Verbarium. Daftar katanya disusun sendiri menurut tingkat kesulitan, bukan salinan daftar resmi mana pun.',
                    'The choice of words for each land is Verbarium\'s decision as well. The lists were written by us in order of difficulty; they are not copies of any official list.', 'La elección de palabras de cada tierra también es decisión de Verbarium. Las listas las escribimos nosotros por orden de dificultad; no son copias de ninguna lista oficial.', 'Le choix des mots de chaque terre est aussi un choix de Verbarium. Nous avons écrit les listes nous-mêmes, par ordre de difficulté ; ce ne sont des copies d’aucune liste officielle.',
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
