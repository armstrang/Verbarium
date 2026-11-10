/// Kronik: what has been done, told the way a chronicle would — days in a row, words held, the last two weeks,
/// and every trial with its date.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/engine.dart';
import '../engine/jobs.dart';
import 'root.dart';
import 'theme.dart';
import 'widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${(english ? _monthsEn : _months)[d.month - 1]} ${d.year}';
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
        Label(tr('Kronik', 'Chronicle')),
        const SizedBox(height: 6),
        Text(
          today[0] + today[1] == 0
              ? tr('Hari ini belum ada catatan.', 'Nothing is noted for today yet.')
              : tr('Tercatat hari ini, ${today[2]} kata dijawab benar.', 'Noted today: ${today[2]} words answered right.'),
          style: T.display(27, pal.ink),
        ),
        const SizedBox(height: 20),
        Rise(
          child: Row(
            children: [
              Expanded(child: _Figure(e.streak, tr('hari beruntun', 'days in a row'))),
              Expanded(child: _Figure(e.solidTotal, tr('kata kukuh', 'solid words'))),
              Expanded(child: _Figure(e.seenTotal, tr('kata dikenal', 'words met'))),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        Label(tr('Empat belas hari terakhir', 'The last fourteen days')),
        const SizedBox(height: 12),
        Semantics(
          label: tr(
            'Jawaban per hari selama empat belas hari. Hari ini ${counts.last}, paling banyak ${counts.reduce(max)}.',
            'Answers per day over fourteen days. Today ${counts.last}, at most ${counts.reduce(max)}.',
          ),
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
            Text(tr('hari ini · ${counts.last} jawaban', 'today · ${counts.last} answers'), style: T.body(14, pal.muted)),
          ],
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        Label(tr('Peristiwa', 'Events')),
        const SizedBox(height: 4),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                'Belum ada ujian yang tercatat. Kronikmu mulai ditulis saat kamu pertama kali diuji.',
                'No trial is on record yet. Your chronicle begins when you are first put to the test.',
              ),
              style: T.body(16, pal.muted, height: 1.45),
            ),
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
    final job = Jobs.byId(ev['j'] as String?);
    final text = switch (kind) {
      'job' =>
        job.hidden
            ? tr('Sebuah jalan tersembunyi terbuka: engkau kini ${job.name}.', 'A hidden path opened: you are now a ${job.name}.')
            : tr('Engkau menempuh jalan ${job.name}.', 'You took the path of the ${job.name}.'),
      'crown' => tr('Dinobatkan sebagai $name. $a dari $b kata benar.', 'Crowned $name. $a of $b words right.'),
      'fail' => tr('Ujian penobatan $name belum lulus. $a dari $b kata benar.', 'The coronation trial for $name was not passed. $a of $b words right.'),
      'place' => tr('Ujian penempatan. Mulai sebagai $name.', 'Placement test. Started as $name.'),
      'drop' => tr('Gelar turun menjadi $name karena tidak dipertahankan.', 'The title fell to $name because it was not defended.'),
      'hold' => tr('Gelar $name dipertahankan. $a dari $b kata benar.', 'The title of $name was defended. $a of $b words right.'),
      'sub' => tr('Seorang penjaga jalan tumbang. $name naik satu tingkat.', 'A guard of the road fell. $name rose one stage.'),
      'subfail' => tr('Dipukul mundur oleh penjaga jalan. $a dari $b pukulan masuk.', 'Beaten back by a guard of the road. $a of $b blows landed.'),
      _ => tr('Gelar $name belum berhasil dipertahankan. $a dari $b kata benar.', 'The title of $name was not defended yet. $a of $b words right.'),
    };
    final won = kind == 'crown' || kind == 'place' || kind == 'hold' || kind == 'sub' || kind == 'job';
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
