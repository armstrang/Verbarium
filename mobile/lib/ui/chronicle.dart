/// Kronik: what has been done, told the way a chronicle would — days in a row, words held, the last two weeks,
/// and every trial with its date.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../engine/engine.dart';
import 'root.dart';
import 'theme.dart';
import 'widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class ChronicleTab extends StatelessWidget {
  const ChronicleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final e = App.I.engine;
    final now = e.now();
    final days = [for (var i = 13; i >= 0; i--) e.dayLog(Engine.dayKey(now - i * Engine.day))];
    final counts = [for (final d in days) d[0] + d[1]];
    final today = days.last;
    final events = e.events;
    return TabBody(
      children: [
        const Label('Kronik'),
        const SizedBox(height: 6),
        Text(today[0] + today[1] == 0 ? 'Hari ini belum ada catatan.' : 'Tercatat hari ini, ${today[2]} kata dijawab benar.', style: T.display(27, pal.ink)),
        const SizedBox(height: 20),
        Rise(
          child: Row(
            children: [
              Expanded(child: _Figure(e.streak, 'hari beruntun')),
              Expanded(child: _Figure(e.solidTotal, 'kata kukuh')),
              Expanded(child: _Figure(e.seenTotal, 'kata dikenal')),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        const Label('Empat belas hari terakhir'),
        const SizedBox(height: 12),
        Semantics(
          label: 'Jawaban per hari selama empat belas hari. Hari ini ${counts.last}, paling banyak ${counts.reduce(max)}.',
          child: SizedBox(
            height: 96,
            child: CustomPaint(size: const Size(double.infinity, 96), painter: _DaysPainter(counts, pal, Look.of(context).accent)),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(dateText(now - 13 * Engine.day), style: T.body(14, pal.muted)),
            const Spacer(),
            Text('hari ini · ${counts.last} jawaban', style: T.body(14, pal.muted)),
          ],
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        const Label('Peristiwa'),
        const SizedBox(height: 4),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Belum ada ujian yang tercatat. Kronikmu mulai ditulis saat kamu pertama kali diuji.', style: T.body(16, pal.muted, height: 1.45)),
          )
        else
          for (final ev in events.take(40)) _EventRow(ev),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final int n;
  final String what;
  const _Figure(this.n, this.what);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Semantics(
      label: '$n $what',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: T.display(40, pal.ink, height: 1)),
            const SizedBox(height: 2),
            Text(what, style: T.body(15, pal.muted)),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> ev;
  const _EventRow(this.ev);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final r = ((ev['r'] as num?)?.toInt() ?? 0).clamp(0, 5);
    final a = (ev['a'] as num?)?.toInt() ?? 0, b = (ev['b'] as num?)?.toInt() ?? 0;
    final name = rankNames[r];
    final kind = ev['k'] as String? ?? '';
    final text = switch (kind) {
      'crown' => 'Dinobatkan sebagai $name. $a dari $b kata benar.',
      'fail' => 'Ujian penobatan $name belum lulus. $a dari $b kata benar.',
      'place' => 'Ujian penempatan. Mulai sebagai $name.',
      'drop' => 'Gelar turun menjadi $name karena tidak dipertahankan.',
      'hold' => 'Gelar $name dipertahankan. $a dari $b kata benar.',
      _ => 'Gelar $name belum berhasil dipertahankan. $a dari $b kata benar.',
    };
    final won = kind == 'crown' || kind == 'place' || kind == 'hold';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Shield(r, width: 22, hollow: !won),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: T.body(16.5, pal.ink, height: 1.4)),
                Text(dateText((ev['t'] as num?)?.toInt() ?? 0), style: T.body(14, pal.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysPainter extends CustomPainter {
  final List<int> counts;
  final Pal pal;
  final Color accent;
  _DaysPainter(this.counts, this.pal, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final top = max(1, counts.reduce(max));
    final n = counts.length;
    final gap = 5.0;
    final w = (size.width - gap * (n - 1)) / n;
    final base = size.height - 1;
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = pal.ink
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i < n; i++) {
      final h = (size.height - 6) * counts[i] / top;
      final x = i * (w + gap);
      final last = i == n - 1;
      if (counts[i] == 0) {
        canvas.drawRect(Rect.fromLTWH(x, base - 3, w, 2), Paint()..color = pal.line);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, base - h, w, h), Paint()..color = last ? accent : pal.muted);
      }
    }
  }

  @override
  bool shouldRepaint(_DaysPainter old) => old.counts.toString() != counts.toString() || old.pal != pal || old.accent != accent;
}
