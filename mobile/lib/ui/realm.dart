/// Negeri: the realm as a map (one land per rank, inked in as its words become solid) and the ladder of titles
/// with the test scores each one's vocabulary is on a par with.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../engine/engine.dart';
import 'root.dart';
import 'theme.dart';
import 'widgets.dart';

const landNames = ['Desa', 'Kota', 'Kastel', 'Kadipaten', 'Takhta'];

class RealmTab extends StatelessWidget {
  const RealmTab({super.key});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    final e = app.engine;
    final rank = e.rank;
    final next = min(rank + 1, Engine.maxRank);
    final st = e.stat(next);
    final shares = [for (var t = 1; t <= 5; t++) e.stat(t).share];
    final need = (st.total * Engine.openShare).ceil();
    return TabBody(
      children: [
        const Label('Negerimu'),
        const SizedBox(height: 6),
        Text('${rankNames[rank]} di bawah panji ${bannerName(app.banner)}', style: T.display(31, pal.ink)),
        const SizedBox(height: 16),
        Rise(
          child: Semantics(
            label:
                'Peta negeri. ${[for (var t = 1; t <= 5; t++) '${landNames[t - 1]} ${t <= rank ? 'dikuasai' : (t == rank + 1 ? 'sedang direbut' : 'belum terbuka')}'].join(', ')}.',
            child: AspectRatio(
              aspectRatio: 342 / 214,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: look.calm ? Duration.zero : const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(painter: _MapPainter(pal, rank, shares, t)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (rank < Engine.maxRank) ...[
          Row(
            children: [
              Expanded(
                child: Text('Menuju ${rankNames[next]}', style: T.body(16.5, pal.ink, w: FontWeight.w500)),
              ),
              Text('${st.solid} dari ${st.total} kata kukuh', style: T.body(15.5, pal.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Bar(st.share, height: 6),
          const SizedBox(height: 6),
          Text('Ujian penobatan terbuka pada $need kata kukuh.', style: T.body(15, pal.muted)),
          const SizedBox(height: 20),
        ],
        const Rule(),
        for (var r = 0; r <= Engine.maxRank; r++) _Rung(r, rank, app.banner),
        const SizedBox(height: 12),
        Text(
          'Gelar mengukur kosakata, bukan menjamin skor ujian. Skor juga ditentukan oleh membaca, menyimak, menulis dan berbicara.',
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
                'Dari mana angka ini?',
                style: T.body(16, pal.ink, w: FontWeight.w500).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
      ],
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
    final state = r < rank ? 'Dilewati' : (r == rank ? 'Gelarmu kini' : (r == rank + 1 ? 'Berikutnya' : 'Belum terbuka'));
    final score = banner == 'ielts' ? 'IELTS ${info.ielts}' : 'TOEFL iBT ${info.toefl} (skala lama ${info.toeflOld})';
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
                label: 'Kembali',
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(child: Text('Dari mana angka ini?', style: T.display(25, pal.ink))),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                p(
                  'Tiap gelar dipasangkan dengan satu tingkat CEFR, kerangka Eropa yang dipakai kedua ujian untuk menjelaskan skornya. Rentang skor di tangga gelar diambil dari penyelarasan CEFR milik penyelenggara ujian sendiri.',
                ),
                h('IELTS'),
                p(
                  'B1 = band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 berada di perbatasan C1 dan C2. Sumber: halaman "IELTS and the CEFR" di ielts.org, berdasarkan kajian Cambridge English.',
                ),
                h('TOEFL iBT'),
                p(
                  'Sejak 21 Januari 2026 skor dilaporkan pada skala 1–6. Menurut ETS: 6 = 114 ke atas pada skala lama, 5.5 = 107 ke atas, 5 = 95 ke atas, 4.5 = 86 ke atas, 4 = 72 ke atas, 3.5 = 58 ke atas, 3 = 44 ke atas.',
                ),
                p('Padanan CEFR pada skala lama, juga dari ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.'),
                h('Yang kami putuskan sendiri'),
                p(
                  'C1 dibagi menjadi dua gelar, Baron dan Duke, supaya jarak antargelar tidak terlalu jauh. Pada TOEFL pembagian itu mengikuti setengah band (5 dan 5.5). Pada IELTS pembagian 7.0 lalu 7.5–8.0 adalah keputusan Verbarium, bukan ketetapan resmi.',
                ),
                p(
                  'Pemilihan kata untuk tiap ranah juga keputusan Verbarium. Daftar katanya disusun sendiri menurut tingkat kesulitan, bukan salinan daftar resmi mana pun.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
