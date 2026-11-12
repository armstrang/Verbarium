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
const _monthsDe = ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'];
const _monthsPt = ['jan.', 'fev.', 'mar.', 'abr.', 'maio', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'];

String dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}${code == 'de' ? '.' : ''} ${(switch (code) {
    'id' => _months,
    'es' => _monthsEs,
    'fr' => _monthsFr,
    'de' => _monthsDe,
    'pt' => _monthsPt,
    _ => _monthsEn,
  })[d.month - 1]} ${d.year}';
}

class ChronicleTab extends StatelessWidget {
  const ChronicleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final e = App.I.engine;
    final now = e.now();
    final days = [for (var i = 27; i >= 0; i--) e.dayLog(Engine.dayKey(now - i * Engine.day))];
    final counts = [for (final d in days) d[0] + d[1]];
    final today = days.last;
    final events = e.events;
    return TabBody(
      children: [
        Label(tr('Kronik', 'Chronicle', 'Crónica', 'Chronique', 'Chronik', 'Crônica')),
        const SizedBox(height: 6),
        Text(
          today[0] + today[1] == 0
              ? tr(
                  'Hari ini belum ada catatan.',
                  'Nothing is noted for today yet.',
                  'Hoy aún no hay nada anotado.',
                  'Rien n’est encore noté aujourd’hui.',
                  'Für heute ist noch nichts verzeichnet.',
                  'Nada registrado hoje ainda.',
                )
              : tr(
                  'Tercatat hari ini, ${today[2]} kata dijawab benar.',
                  'Noted today: ${today[2]} words answered right.',
                  'Anotado hoy: ${today[2]} palabras respondidas bien.',
                  'Noté aujourd’hui : ${today[2]} mots bien répondus.',
                  'Heute verzeichnet: ${today[2]} Wörter richtig beantwortet.',
                  'Registrado hoje: ${today[2]} palavras respondidas certo.',
                ),
          style: T.display(27, pal.ink),
        ),
        const SizedBox(height: 16),
        Rise(
          child: Row(
            children: [
              _Figure(
                e.streak,
                tr(
                  'hari beruntun',
                  'days in a row',
                  'días seguidos',
                  'jours d’affilée',
                  'Tage in Folge',
                  'dias seguidos',
                ),
              ),
              const SizedBox(width: 8),
              _Figure(
                e.solidTotal,
                tr(
                  'kata kukuh',
                  'solid words',
                  'palabras firmes',
                  'mots ancrés',
                  'gefestigte Wörter',
                  'palavras firmes',
                ),
              ),
              const SizedBox(width: 8),
              _Figure(
                e.seenTotal,
                tr(
                  'kata dikenal',
                  'words met',
                  'palabras vistas',
                  'mots rencontrés',
                  'bekannte Wörter',
                  'palavras vistas',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Label(
          tr(
            'Empat minggu terakhir',
            'The last four weeks',
            'Las últimas cuatro semanas',
            'Les quatre dernières semaines',
            'Die letzten vier Wochen',
            'As últimas quatro semanas',
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: tr(
            'Kalender empat minggu. Hari ini ${counts.last} jawaban, paling banyak ${counts.reduce(max)}.',
            'Four weeks of days. Today ${counts.last} answers, at most ${counts.reduce(max)}.',
            'Cuatro semanas de días. Hoy ${counts.last} respuestas, como máximo ${counts.reduce(max)}.',
            'Quatre semaines de jours. Aujourd’hui ${counts.last} réponses, au plus ${counts.reduce(max)}.',
            'Vier Wochen voller Tage. Heute ${counts.last} Antworten, höchstens ${counts.reduce(max)}.',
            'Quatro semanas de dias. Hoje ${counts.last} respostas, no máximo ${counts.reduce(max)}.',
          ),
          child: ExcludeSemantics(child: _Calendar(counts)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(dateText(now - 27 * Engine.day), style: T.body(14, pal.muted)),
            const Spacer(),
            Text(
              tr(
                'hari ini · ${counts.last} jawaban',
                'today · ${counts.last} answers',
                'hoy · ${counts.last} respuestas',
                'aujourd’hui · ${counts.last} réponses',
                'heute · ${counts.last} Antworten',
                'hoje · ${counts.last} respostas',
              ),
              style: T.body(14, pal.muted),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Label(tr('Peristiwa', 'Events', 'Sucesos', 'Événements', 'Ereignisse', 'Acontecimentos')),
        const SizedBox(height: 4),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                'Belum ada ujian yang tercatat. Kronikmu mulai ditulis saat kamu pertama kali diuji.',
                'No trial is on record yet. Your chronicle begins when you are first put to the test.',
                'Aún no consta ninguna prueba. Tu crónica empieza la primera vez que te pongan a prueba.',
                'Aucune épreuve n’est encore consignée. Ta chronique commence à ta première épreuve.',
                'Noch keine Prüfung verzeichnet. Deine Chronik beginnt, wenn du zum ersten Mal geprüft wirst.',
                'Nenhuma prova registrada ainda. Sua crônica começa quando você for posto à prova pela primeira vez.',
              ),
              style: T.body(16, pal.muted, height: 1.45),
            ),
          )
        else
          for (final (i, ev) in events.take(40).indexed)
            Rise(
              delay: Duration(milliseconds: min(i, 8) * 45),
              child: _EventRow(ev, last: i == min(events.length, 40) - 1),
            ),
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
    final look = Look.of(context);
    final pal = look.pal;
    return Expanded(
      child: Semantics(
        label: '$n $what',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: pal.field,
              border: Border.all(color: pal.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: n.toDouble()),
                  duration: look.calm ? Duration.zero : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${v.round()}', style: T.display(30, pal.ink, height: 1.1)),
                  ),
                ),
                Text(what, style: T.body(13, pal.muted), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> ev;
  final bool last;
  const _EventRow(this.ev, {this.last = false});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final r = ((ev['r'] as num?)?.toInt() ?? 0).clamp(0, Engine.maxRank);
    final a = (ev['a'] as num?)?.toInt() ?? 0, b = (ev['b'] as num?)?.toInt() ?? 0;
    final name = rankNames[r];
    final kind = ev['k'] as String? ?? '';
    final job = Jobs.byId(ev['j'] as String?);
    final text = switch (kind) {
      'job' =>
        job.hidden
            ? tr(
                'Sebuah jalan tersembunyi terbuka: engkau kini ${job.name}.',
                'A hidden path opened: you are now a ${job.name}.',
                'Se abrió un camino oculto: ahora eres ${job.name}.',
                'Une voie cachée s’est ouverte : tu es désormais ${job.name}.',
                'Ein verborgener Weg hat sich geöffnet: Du bist jetzt ${job.name}.',
                'Um caminho oculto se abriu: agora você é ${job.name}.',
              )
            : tr(
                'Engkau menempuh jalan ${job.name}.',
                'You took the path of the ${job.name}.',
                'Tomaste el camino de ${job.name}.',
                'Tu as pris la voie de ${job.name}.',
                'Du hast den Weg des ${job.name} eingeschlagen.',
                'Você tomou o caminho de ${job.name}.',
              ),
      'crown' => tr(
        'Dinobatkan sebagai $name. $a dari $b kata benar.',
        'Crowned $name. $a of $b words right.',
        'Coronado $name. $a de $b palabras bien.',
        'Couronné $name. $a mots justes sur $b.',
        'Gekrönt zum $name. $a von $b Wörtern richtig.',
        'Coroado $name. $a de $b palavras certas.',
      ),
      'fail' => tr(
        'Ujian penobatan $name belum lulus. $a dari $b kata benar.',
        'The coronation trial for $name was not passed. $a of $b words right.',
        'No superaste la prueba de coronación de $name. $a de $b palabras bien.',
        'L’épreuve de couronnement de $name n’est pas réussie. $a mots justes sur $b.',
        'Die Krönungsprüfung zum $name wurde nicht bestanden. $a von $b Wörtern richtig.',
        'A prova de coroação de $name não foi superada. $a de $b palavras certas.',
      ),
      'place' => tr(
        'Ujian penempatan. Mulai sebagai $name.',
        'Placement test. Started as $name.',
        'Prueba de nivel. Empezaste como $name.',
        'Test de niveau. Début en tant que $name.',
        'Einstufungstest. Start als $name.',
        'Teste de nivelamento. Começou como $name.',
      ),
      'drop' => tr(
        'Gelar turun menjadi $name karena tidak dipertahankan.',
        'The title fell to $name because it was not defended.',
        'El título cayó a $name por no defenderlo.',
        'Le titre est retombé à $name faute d’avoir été défendu.',
        'Der Titel fiel auf $name, weil er nicht verteidigt wurde.',
        'O título caiu para $name por não ter sido defendido.',
      ),
      'hold' => tr(
        'Gelar $name dipertahankan. $a dari $b kata benar.',
        'The title of $name was defended. $a of $b words right.',
        'El título de $name fue defendido. $a de $b palabras bien.',
        'Le titre de $name a été défendu. $a mots justes sur $b.',
        'Der Titel $name wurde verteidigt. $a von $b Wörtern richtig.',
        'O título de $name foi defendido. $a de $b palavras certas.',
      ),
      'sub' => tr(
        'Seorang penjaga jalan tumbang. $name naik satu tingkat.',
        'A guard of the road fell. $name rose one stage.',
        'Cayó un guardián del camino. $name subió una etapa.',
        'Un gardien de la route est tombé. $name monte d’une étape.',
        'Ein Wächter der Straße ist gefallen. $name stieg eine Stufe auf.',
        'Um guardião da estrada caiu. $name subiu uma etapa.',
      ),
      'subfail' => tr(
        'Dipukul mundur oleh penjaga jalan. $a dari $b pukulan masuk.',
        'Beaten back by a guard of the road. $a of $b blows landed.',
        'Rechazado por un guardián del camino. $a de $b golpes acertados.',
        'Repoussé par un gardien de la route. $a coups portés sur $b.',
        'Von einem Wächter der Straße zurückgeschlagen. $a von $b Hieben trafen.',
        'Repelido por um guardião da estrada. $a de $b golpes acertaram.',
      ),
      _ => tr(
        'Gelar $name belum berhasil dipertahankan. $a dari $b kata benar.',
        'The title of $name was not defended yet. $a of $b words right.',
        'El título de $name aún no está defendido. $a de $b palabras bien.',
        'Le titre de $name n’est pas encore défendu. $a mots justes sur $b.',
        'Der Titel $name ist noch nicht verteidigt. $a von $b Wörtern richtig.',
        'O título de $name ainda não foi defendido. $a de $b palavras certas.',
      ),
    };
    final won = kind == 'crown' || kind == 'place' || kind == 'hold' || kind == 'sub' || kind == 'job';
    // a line of the chronicle: the date, then what happened, in the chronicle's own voice, on a thread of time
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!last) Positioned(top: 14, bottom: 0, child: Container(width: 2, color: pal.line)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Shield(r, width: 22, hollow: !won),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateText((ev['t'] as num?)?.toInt() ?? 0), style: T.body(13.5, pal.muted)),
                  Text(text, style: T.display(18, pal.ink, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// four weeks as a grid of days: the more answered, the deeper the colour; today is ringed; the squares come in
/// one after another
class _Calendar extends StatelessWidget {
  final List<int> counts;
  const _Calendar(this.counts);

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final top = max(1, counts.reduce(max));
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      children: [
        for (var i = 0; i < counts.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: look.calm ? Duration.zero : Duration(milliseconds: 260 + i * 22),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
            child: Container(
              decoration: BoxDecoration(
                color: counts[i] == 0 ? pal.deep : Color.lerp(pal.field, look.accent, 0.25 + 0.75 * counts[i] / top),
                borderRadius: BorderRadius.circular(5),
                border: i == counts.length - 1 ? Border.all(color: pal.ink, width: 2) : null,
              ),
            ),
          ),
      ],
    );
  }
}
