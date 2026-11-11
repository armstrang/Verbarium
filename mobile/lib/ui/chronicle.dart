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
const _monthsEs = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${(switch (code) { 'id' => _months, 'es' => _monthsEs, 'fr' => _monthsFr, _ => _monthsEn })[d.month - 1]} ${d.year}';
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
        Label(tr('Kronik', 'Chronicle', 'Crónica', 'Chronique')),
        const SizedBox(height: 6),
        Text(
          today[0] + today[1] == 0
              ? tr('Hari ini belum ada catatan.', 'Nothing is noted for today yet.', 'Hoy aún no hay nada anotado.', 'Rien n’est encore noté aujourd’hui.')
              : tr('Tercatat hari ini, ${today[2]} kata dijawab benar.', 'Noted today: ${today[2]} words answered right.', 'Anotado hoy: ${today[2]} palabras respondidas bien.', 'Noté aujourd’hui : ${today[2]} mots bien répondus.'),
          style: T.display(27, pal.ink),
        ),
        const SizedBox(height: 20),
        Rise(
          child: Row(
            children: [
              Expanded(child: _Figure(e.streak, tr('hari beruntun', 'days in a row', 'días seguidos', 'jours d’affilée'))),
              Expanded(child: _Figure(e.solidTotal, tr('kata kukuh', 'solid words', 'palabras firmes', 'mots ancrés'))),
              Expanded(child: _Figure(e.seenTotal, tr('kata dikenal', 'words met', 'palabras vistas', 'mots rencontrés'))),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        Label(tr('Empat belas hari terakhir', 'The last fourteen days', 'Los últimos catorce días', 'Les quatorze derniers jours')),
        const SizedBox(height: 12),
        Semantics(
          label: tr(
            'Jawaban per hari selama empat belas hari. Hari ini ${counts.last}, paling banyak ${counts.reduce(max)}.',
            'Answers per day over fourteen days. Today ${counts.last}, at most ${counts.reduce(max)}.', 'Respuestas por día en catorce días. Hoy ${counts.last}, como máximo ${counts.reduce(max)}.', 'Réponses par jour sur quatorze jours. Aujourd’hui ${counts.last}, au plus ${counts.reduce(max)}.',
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
            Text(tr('hari ini · ${counts.last} jawaban', 'today · ${counts.last} answers', 'hoy · ${counts.last} respuestas', 'aujourd’hui · ${counts.last} réponses'), style: T.body(14, pal.muted)),
          ],
        ),
        const SizedBox(height: 22),
        const Rule(),
        const SizedBox(height: 18),
        Label(tr('Peristiwa', 'Events', 'Sucesos', 'Événements')),
        const SizedBox(height: 4),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                'Belum ada ujian yang tercatat. Kronikmu mulai ditulis saat kamu pertama kali diuji.',
                'No trial is on record yet. Your chronicle begins when you are first put to the test.', 'Aún no consta ninguna prueba. Tu crónica empieza la primera vez que te pongan a prueba.', 'Aucune épreuve n’est encore consignée. Ta chronique commence à ta première épreuve.',
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
            ? tr('Sebuah jalan tersembunyi terbuka: engkau kini ${job.name}.', 'A hidden path opened: you are now a ${job.name}.', 'Se abrió un camino oculto: ahora eres ${job.name}.', 'Une voie cachée s’est ouverte : tu es désormais ${job.name}.')
            : tr('Engkau menempuh jalan ${job.name}.', 'You took the path of the ${job.name}.', 'Tomaste el camino de ${job.name}.', 'Tu as pris la voie de ${job.name}.'),
      'crown' => tr('Dinobatkan sebagai $name. $a dari $b kata benar.', 'Crowned $name. $a of $b words right.', 'Coronado $name. $a de $b palabras bien.', 'Couronné $name. $a mots justes sur $b.'),
      'fail' => tr('Ujian penobatan $name belum lulus. $a dari $b kata benar.', 'The coronation trial for $name was not passed. $a of $b words right.', 'No superaste la prueba de coronación de $name. $a de $b palabras bien.', 'L’épreuve de couronnement de $name n’est pas réussie. $a mots justes sur $b.'),
      'place' => tr('Ujian penempatan. Mulai sebagai $name.', 'Placement test. Started as $name.', 'Prueba de nivel. Empezaste como $name.', 'Test de niveau. Début en tant que $name.'),
      'drop' => tr('Gelar turun menjadi $name karena tidak dipertahankan.', 'The title fell to $name because it was not defended.', 'El título cayó a $name por no defenderlo.', 'Le titre est retombé à $name faute d’avoir été défendu.'),
      'hold' => tr('Gelar $name dipertahankan. $a dari $b kata benar.', 'The title of $name was defended. $a of $b words right.', 'El título de $name fue defendido. $a de $b palabras bien.', 'Le titre de $name a été défendu. $a mots justes sur $b.'),
      'sub' => tr('Seorang penjaga jalan tumbang. $name naik satu tingkat.', 'A guard of the road fell. $name rose one stage.', 'Cayó un guardián del camino. $name subió una etapa.', 'Un gardien de la route est tombé. $name monte d’une étape.'),
      'subfail' => tr('Dipukul mundur oleh penjaga jalan. $a dari $b pukulan masuk.', 'Beaten back by a guard of the road. $a of $b blows landed.', 'Rechazado por un guardián del camino. $a de $b golpes acertados.', 'Repoussé par un gardien de la route. $a coups portés sur $b.'),
      _ => tr('Gelar $name belum berhasil dipertahankan. $a dari $b kata benar.', 'The title of $name was not defended yet. $a of $b words right.', 'El título de $name aún no está defendido. $a de $b palabras bien.', 'Le titre de $name n’est pas encore défendu. $a mots justes sur $b.'),
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
