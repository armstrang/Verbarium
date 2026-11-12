/// Karakter: the hero and everything that belongs to them — the job and the path that led to it, the build that
/// decides the next one, level, the four figures, gear, the week's quests, feats and the honorary title worn.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import '../engine/jobs.dart';
import 'pixel.dart';
import 'root.dart';
import 'lore.dart';
import 'run.dart' show runRoute, stageName;
import 'theme.dart';
import 'widgets.dart';

class HeroTab extends StatelessWidget {
  const HeroTab({super.key});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final e = App.I.engine, g = App.I.game;
    final rank = e.rank;
    final job = g.job;
    final earned = g.earned;
    final titled = Game.feats.where((f) => f.title != null && earned.contains(f.id)).toList();
    final perks = [for (final j in g.path.skip(1)) j];
    return TabBody(
      children: [
        Label(tr('Karakter', 'Character', 'Personaje', 'Personnage', 'Figur', 'Personagem')),
        const SizedBox(height: 10),
        Rise(
          child: Press(
            // the hero tapped: the story of who they are
            onTap: () => Navigator.of(context).push(runRoute(LorePage(job: job, rank: rank))),
            label: tr(
              'Kisah ${job.name}',
              'Story of the ${job.name}',
              'Historia de ${job.name}',
              'Histoire de ${job.name}',
              'Geschichte des ${job.name}',
              'História de ${job.name}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 236,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _Land(App.I.realm, pal.dark))),
                    Positioned(
                      bottom: 22,
                      child: Container(
                        width: 110,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.all(Radius.elliptical(55, 6)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: HeroSprite(
                        garb: job.garb,
                        tier: job.tier,
                        weapon: g.tone('weapon'),
                        shield: g.tone('shield'),
                        cloak: g.tone('cloak'),
                        size: 150,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFBF7),
                          border: Border.all(color: const Color(0xFFCFC9BA)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tr(
                            'Ketuk sosok untuk kisahnya',
                            'Tap the figure for its story',
                            'Toca la figura para su historia',
                            'Touche le personnage pour son histoire',
                            'Tippe auf die Figur für ihre Geschichte',
                            'Toque na figura para ver sua história',
                          ),
                          style: T.body(13, const Color(0xFF1C1B19)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(job.name, style: T.display(32, pal.ink)),
              ),
            ),
            Text(
              '${rankNames[rank]}${rank < Engine.maxRank ? ' ${stageName(e.stage)}' : ''} · Level ${g.level}',
              style: T.body(15, pal.muted),
            ),
          ],
        ),
        Text(job.hint, style: T.display(16.5, pal.ink, italic: true)),
        if (g.title.isNotEmpty) Text(g.title, style: T.display(16, pal.muted, italic: true)),
        const SizedBox(height: 8),
        Bar(g.levelShare, height: 6),
        const SizedBox(height: 4),
        Text(
          tr(
            '${g.toNext} XP lagi ke level ${g.level + 1}',
            '${g.toNext} XP to level ${g.level + 1}',
            '${g.toNext} XP para el nivel ${g.level + 1}',
            '${g.toNext} XP avant le niveau ${g.level + 1}',
            '${g.toNext} XP bis Stufe ${g.level + 1}',
            '${g.toNext} XP até o nível ${g.level + 1}',
          ),
          style: T.body(13.5, pal.muted),
        ),
        const SizedBox(height: 18),
        Label(
          tr(
            'Jalan job',
            'The path of jobs',
            'El camino de oficios',
            'La voie des métiers',
            'Der Weg der Berufe',
            'O caminho das profissões',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, j) in g.path.indexed) ...[
              if (i > 0) Text('›', style: T.body(16, pal.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: j == job ? look.accent : pal.field,
                  border: Border.all(color: j == job ? look.accent : pal.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(j.name, style: T.body(14.5, j == job ? pal.onAccent : pal.ink, w: FontWeight.w500)),
              ),
            ],
            if (rank < Engine.maxRank) ...[
              Text('›', style: T.body(16, pal.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: pal.muted),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('?', style: T.body(14.5, pal.muted)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: pal.field,
            border: Border.all(color: pal.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  'Perk yang terkumpul',
                  'Perks gathered',
                  'Ventajas reunidas',
                  'Atouts réunis',
                  'Gesammelte Vorteile',
                  'Vantagens reunidas',
                ),
                style: T.body(13.5, pal.muted),
              ),
              const SizedBox(height: 4),
              if (perks.isEmpty)
                Text(
                  tr(
                    'Job pertamamu ditentukan saat kamu dinobatkan menjadi Squire. Bukan kamu yang memilih: cara belajarmu yang menentukan.',
                    'Your first job is decided when you are crowned Squire. You do not choose it: the way you learn does.',
                    'Tu primer oficio se decide cuando te coronan Squire. No lo eliges tú: lo decide tu manera de aprender.',
                    'Ton premier métier se décide quand tu es couronné Squire. Tu ne le choisis pas : ta façon d’apprendre le fait.',
                    'Dein erster Beruf wird entschieden, wenn du zum Squire gekrönt wirst. Du wählst ihn nicht: Deine Art zu lernen tut es.',
                    'Sua primeira profissão é decidida quando você é coroado Squire. Você não a escolhe: seu jeito de aprender escolhe.',
                  ),
                  style: T.body(15, pal.ink, height: 1.45),
                )
              else
                for (final j in perks)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('${j.name}: ${j.perk.text}', style: T.body(15, pal.ink, height: 1.4)),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _BuildBlock(),
        const SizedBox(height: 22),
        Label(tr('Kemampuan', 'Figures', 'Cifras', 'Chiffres', 'Kennzahlen', 'Números')),
        const SizedBox(height: 6),
        _Figure(
          tr('Ingatan', 'Memory', 'Memoria', 'Mémoire', 'Gedächtnis', 'Memória'),
          g.memory,
          tr(
            'kata kukuh dari ranah yang sudah kamu masuki',
            'solid words out of the lands you have entered',
            'palabras firmes de las tierras que ya pisaste',
            'mots ancrés des terres où tu es entré',
            'gefestigte Wörter aus den Ländern, die du betreten hast',
            'palavras firmes das terras em que você entrou',
          ),
        ),
        _Figure(
          tr('Ketepatan', 'Accuracy', 'Precisión', 'Précision', 'Genauigkeit', 'Precisão'),
          g.accuracy,
          tr(
            'jawaban benar dari 100 terakhir',
            'right answers out of the last 100',
            'respuestas correctas de las últimas 100',
            'bonnes réponses sur les 100 dernières',
            'richtige Antworten von den letzten 100',
            'respostas certas entre as últimas 100',
          ),
        ),
        _Figure(
          tr('Kecepatan', 'Speed', 'Rapidez', 'Rapidité', 'Tempo', 'Rapidez'),
          g.speed,
          tr(
            'dari waktu rata-rata mengisi celah',
            'from the average time to fill a gap',
            'según el tiempo medio para completar un hueco',
            'd’après le temps moyen pour remplir un trou',
            'aus der durchschnittlichen Zeit pro Lücke',
            'pelo tempo médio para preencher uma lacuna',
          ),
        ),
        _Figure(
          tr('Ketekunan', 'Diligence', 'Constancia', 'Assiduité', 'Fleiß', 'Constância'),
          g.diligence,
          tr(
            '${g.activeDays14} dari 14 hari terakhir kamu belajar',
            'you studied on ${g.activeDays14} of the last 14 days',
            'estudiaste ${g.activeDays14} de los últimos 14 días',
            'tu as étudié ${g.activeDays14} des 14 derniers jours',
            'du hast an ${g.activeDays14} der letzten 14 Tage gelernt',
            'você estudou em ${g.activeDays14} dos últimos 14 dias',
          ),
        ),
        const SizedBox(height: 22),
        Label(tr('Perlengkapan', 'Gear', 'Equipo', 'Équipement', 'Ausrüstung', 'Equipamento')),
        const SizedBox(height: 6),
        for (final slot in const ['weapon', 'shield', 'cloak']) _Slot(slot),
        const SizedBox(height: 22),
        Label(
          tr(
            'Quest minggu ini',
            'This week\'s quests',
            'Misiones de la semana',
            'Quêtes de la semaine',
            'Aufgaben dieser Woche',
            'Missões da semana',
          ),
        ),
        const SizedBox(height: 4),
        for (final q in g.weekly) QuestRow(q),
        const SizedBox(height: 22),
        if (titled.isNotEmpty) ...[
          Label(
            tr(
              'Gelar kehormatan',
              'Honorary title',
              'Título honorífico',
              'Titre honorifique',
              'Ehrentitel',
              'Título honorário',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in <Feat?>[null, ...titled])
                Press(
                  onTap: () {
                    g.setTitle(f?.id ?? '');
                    App.I.changed();
                  },
                  child: Semantics(
                    selected: g.titleFeat?.id == f?.id,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: g.titleFeat?.id == f?.id ? pal.ink : Colors.transparent,
                        border: Border.all(color: pal.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        f == null
                            ? tr('Tanpa gelar', 'No title', 'Sin título', 'Aucun titre', 'Kein Titel', 'Sem título')
                            : f.title!,
                        style: T.body(15.5, g.titleFeat?.id == f?.id ? pal.bg : pal.ink, w: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        Label(
          tr(
            'Pencapaian · ${earned.length} dari ${Game.feats.length}',
            'Feats · ${earned.length} of ${Game.feats.length}',
            'Hazañas · ${earned.length} de ${Game.feats.length}',
            'Exploits · ${earned.length} sur ${Game.feats.length}',
            'Taten · ${earned.length} von ${Game.feats.length}',
            'Feitos · ${earned.length} de ${Game.feats.length}',
          ),
        ),
        const SizedBox(height: 4),
        for (final f in Game.feats)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pal.line)),
            ),
            child: Row(
              children: [
                Icon(
                  earned.contains(f.id) ? Icons.check_circle_outline : Icons.circle_outlined,
                  size: 22,
                  color: earned.contains(f.id) ? pal.good : pal.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: T.body(16.5, earned.contains(f.id) ? pal.ink : pal.muted, w: FontWeight.w500),
                      ),
                      Text(
                        '${f.text}${f.title == null ? '' : tr(' · gelar "${f.title}"', ' · title "${f.title}"', ' · título «${f.title}»', ' · titre « ${f.title} »', ' · Titel „${f.title}“', ' · título “${f.title}”')}',
                        style: T.body(14.5, pal.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The build of the title being won, the branches it can lead to, and the way to the map of all jobs. A branch not
/// yet reached is a shadow without a name.
class _BuildBlock extends StatelessWidget {
  const _BuildBlock();

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final g = App.I.game;
    final b = g.build;
    final shares = b.shares;
    final next = g.nextJobs;
    final heading = g.heading;
    final known = g.known;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Label(
          tr(
            'Arah build',
            'Where your build leans',
            'Hacia dónde se inclina tu estilo',
            'Vers où penche ton style',
            'Wohin dein Build neigt',
            'Para onde seu build pende',
          ),
        ),
        const SizedBox(height: 6),
        if (b.total < 20)
          Text(
            tr(
              'Belum cukup jawaban untuk dibaca. Tiap jawaban menambah salah satu dari empat sisi di bawah ini.',
              'Not enough answers to read yet. Every answer adds to one of the four sides below.',
              'Aún no hay respuestas suficientes. Cada respuesta suma a uno de los cuatro lados de abajo.',
              'Pas encore assez de réponses. Chaque réponse s’ajoute à l’un des quatre côtés ci-dessous.',
              'Noch zu wenige Antworten. Jede Antwort zählt zu einer der vier Seiten unten.',
              'Ainda não há respostas suficientes. Cada resposta soma a um dos quatro lados abaixo.',
            ),
            style: T.body(15, pal.muted, height: 1.45),
          ),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label: '${statNames[i]} ${(shares[i] * 100).round()}%',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(statNames[i], style: T.body(15.5, pal.ink, w: FontWeight.w500)),
                    ),
                    Expanded(child: Bar(b.total == 0 ? 0 : shares[i], height: 6)),
                    SizedBox(
                      width: 46,
                      child: Text(
                        b.total == 0 ? '–' : '${(shares[i] * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: T.body(15, pal.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          tr(
            'Precision dari celah yang diisi bersih dan bentuk kata yang tepat. Swiftness dari jawaban cepat. Insight dari kata lama yang masih kamu ingat. Endurance dari hari-hari kamu datang.',
            'Precision comes from gaps filled cleanly and the right form of a word. Swiftness from quick answers. Insight from old words you still remember. Endurance from the days you show up.',
            'La precisión viene de los huecos completados sin fallo y de la forma correcta. La rapidez, de responder rápido. La perspicacia, de las palabras antiguas que aún recuerdas. La resistencia, de los días que vienes.',
            'La précision vient des trous remplis sans faute et de la bonne forme du mot. La rapidité, des réponses vives. La perspicacité, des vieux mots dont tu te souviens encore. L’endurance, des jours où tu reviens.',
            'Precision kommt von sauber gefüllten Lücken und der richtigen Wortform. Swiftness von schnellen Antworten. Insight von alten Wörtern, die du noch weißt. Endurance von den Tagen, an denen du da bist.',
            'Precision vem de lacunas preenchidas sem erro e da forma certa da palavra. Swiftness, de respostas rápidas. Insight, de palavras antigas que você ainda lembra. Endurance, dos dias em que você aparece.',
          ),
          style: T.body(14.5, pal.muted, height: 1.45),
        ),
        if (next.isNotEmpty) ...[
          const SizedBox(height: 18),
          Label(
            tr(
              'Jalan berikutnya',
              'The paths ahead',
              'Los caminos por delante',
              'Les voies à venir',
              'Die Wege vor dir',
              'Os caminhos à frente',
            ),
          ),
          const SizedBox(height: 8),
          for (final j in next) _PathRow(j, known: known.contains(j.id), pointed: heading?.id == j.id),
          const SizedBox(height: 4),
          Text(
            tr(
              'Job ditentukan saat penobatan, dari build-mu waktu itu. Tidak bisa dipilih dan tidak bisa diganti.',
              'The job is decided at the coronation, from your build at that moment. It cannot be chosen and cannot be changed.',
              'El oficio se decide en la coronación, según tu estilo en ese momento. No se puede elegir ni cambiar.',
              'Le métier se décide au couronnement, d’après ton style à ce moment-là. Il ne peut être ni choisi ni changé.',
              'Der Beruf wird bei der Krönung entschieden, nach deinem Build in diesem Moment. Er lässt sich weder wählen noch ändern.',
              'A profissão é decidida na coroação, pelo seu build naquele momento. Não pode ser escolhida nem trocada.',
            ),
            style: T.body(14.5, pal.muted, height: 1.45),
          ),
        ],
        const SizedBox(height: 10),
        InkButton(
          tr(
            'Peta job',
            'Map of jobs',
            'Mapa de oficios',
            'Carte des métiers',
            'Karte der Berufe',
            'Mapa das profissões',
          ),
          outline: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JobMapPage())),
        ),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  final Job job;
  final bool known, pointed;
  const _PathRow(this.job, {required this.known, required this.pointed});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pointed ? pal.field : Colors.transparent,
        border: Border.all(color: pointed ? pal.ink : pal.line, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          HeroSprite(garb: job.garb, tier: job.tier, shadow: !known, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(known ? job.name : '? ? ?', style: T.display(21, known ? pal.ink : pal.muted)),
                Text(job.hint, style: T.body(15, pal.muted, height: 1.35)),
                if (pointed)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      tr(
                        'Build-mu kini mengarah ke sini',
                        'Your build points here now',
                        'Tu estilo apunta aquí ahora',
                        'Ton style mène ici en ce moment',
                        'Hierhin zeigt dein Build jetzt',
                        'Seu build aponta para cá agora',
                      ),
                      style: T.body(14.5, pal.ink, w: FontWeight.w700),
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

/// Every job on one page, title by title. What has been held is drawn in colour with its name and perk; the rest
/// are shadows. The hidden ones only give a riddle.
class JobMapPage extends StatelessWidget {
  const JobMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final g = App.I.game;
    final known = g.known;
    final mine = {for (final j in g.path) j.id};
    final seenAll = Jobs.all.where((j) => known.contains(j.id)).length;
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
                    'Peta job',
                    'Map of jobs',
                    'Mapa de oficios',
                    'Carte des métiers',
                    'Karte der Berufe',
                    'Mapa das profissões',
                  ),
                  style: T.display(25, pal.ink),
                ),
              ),
              Text('$seenAll / ${Jobs.all.length}', style: T.body(15.5, pal.muted)),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                Text(
                  tr(
                    '${Jobs.visible.length} job terlihat di peta, ${Jobs.secret.length} lagi tersembunyi. Yang pernah kamu pegang tampil berwarna; sisanya bayangan sampai kamu sendiri tiba di sana.',
                    '${Jobs.visible.length} jobs are on the map, ${Jobs.secret.length} more are hidden. Those you have held are in colour; the rest stay shadows until you get there yourself.',
                    'Hay ${Jobs.visible.length} oficios en el mapa y ${Jobs.secret.length} más ocultos. Los que has tenido aparecen en color; el resto son sombras hasta que llegues allí.',
                    '${Jobs.visible.length} métiers sont sur la carte, ${Jobs.secret.length} autres sont cachés. Ceux que tu as tenus sont en couleur ; les autres restent des ombres jusqu’à ce que tu y arrives.',
                    '${Jobs.visible.length} Berufe stehen auf der Karte, ${Jobs.secret.length} weitere sind verborgen. Was du schon hattest, ist farbig; der Rest bleibt Schatten, bis du selbst dort ankommst.',
                    '${Jobs.visible.length} profissões estão no mapa, outras ${Jobs.secret.length} estão ocultas. As que você já teve aparecem em cor; o resto fica na sombra até você chegar lá.',
                  ),
                  style: T.body(15.5, pal.muted, height: 1.45),
                ),
                for (var t = 0; t <= Engine.maxRank; t++) ...[
                  const SizedBox(height: 18),
                  Label(rankNames[t]),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (final j in Jobs.tier(t)) _JobTile(j, known: known.contains(j.id), mine: mine.contains(j.id)),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Label(tr('Tersembunyi', 'Hidden', 'Oculto', 'Caché', 'Verborgen', 'Oculta')),
                const SizedBox(height: 6),
                for (final j in Jobs.secret)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: pal.line)),
                    ),
                    child: Row(
                      children: [
                        HeroSprite(garb: j.garb, tier: j.tier, shadow: !known.contains(j.id), size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                known.contains(j.id) ? j.name : '? ? ?',
                                style: T.display(20, known.contains(j.id) ? pal.ink : pal.muted),
                              ),
                              Text(
                                known.contains(j.id) ? j.perk.text : j.hint,
                                style: T.body(15, pal.muted, height: 1.35),
                              ),
                            ],
                          ),
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

class _JobTile extends StatelessWidget {
  final Job job;
  final bool known, mine;
  const _JobTile(this.job, {required this.known, required this.mine});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Semantics(
      label: known
          ? '${job.name}. ${job.perk.text}'
          : tr(
              'Job yang belum dikenal',
              'A job not yet known',
              'Un oficio aún desconocido',
              'Un métier encore inconnu',
              'Ein noch unbekannter Beruf',
              'Uma profissão ainda desconhecida',
            ),
      child: ExcludeSemantics(
        child: Container(
          width: 106,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            color: mine ? pal.field : Colors.transparent,
            border: Border.all(color: mine ? pal.ink : pal.line, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            children: [
              HeroSprite(garb: job.garb, tier: job.tier, shadow: !known, size: 44),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  known ? job.name : '? ? ?',
                  style: T.body(14.5, known ? pal.ink : pal.muted, w: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String name, note;
  final int value;
  const _Figure(this.name, this.value, this.note);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Semantics(
        label: tr(
          '$name $value dari 100. $note',
          '$name $value out of 100. $note',
          '$name $value de 100. $note',
          '$name $value sur 100. $note',
          '$name $value von 100. $note',
          '$name $value de 100. $note',
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: T.body(16.5, pal.ink, w: FontWeight.w500)),
                  ),
                  Text('$value', style: T.display(22, pal.ink, height: 1)),
                ],
              ),
              const SizedBox(height: 5),
              Bar(value / 100, height: 6),
              const SizedBox(height: 3),
              Text(note, style: T.body(14, pal.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final String slot;
  const _Slot(this.slot);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final g = App.I.game;
    final name = {
      'weapon': tr('Senjata', 'Arms', 'Arma', 'Arme', 'Waffen', 'Armas'),
      'shield': tr('Perisai', 'Shield', 'Escudo', 'Bouclier', 'Schild', 'Escudo'),
      'cloak': tr('Jubah', 'Cloak', 'Capa', 'Cape', 'Umhang', 'Capa'),
    }[slot]!;
    final mine = Game.gear.where((x) => x.slot == slot && g.owned.contains(x.id)).toList();
    final worn = g.gearOf(g.equipped(slot));
    final all = Game.gear.where((x) => x.slot == slot).length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    '$name · ${mine.length} dari $all',
                    '$name · ${mine.length} of $all',
                    '$name · ${mine.length} de $all',
                    '$name · ${mine.length} sur $all',
                    '$name · ${mine.length} von $all',
                    '$name · ${mine.length} de $all',
                  ),
                  style: T.body(14.5, pal.muted),
                ),
                Text(
                  worn?.name ?? tr('Belum punya', 'None yet', 'Aún nada', 'Rien encore', 'Noch nichts', 'Nada ainda'),
                  style: T.body(17, worn == null ? pal.muted : pal.ink, w: FontWeight.w500),
                ),
                if (worn != null) Text(worn.from, style: T.body(14, pal.muted)),
              ],
            ),
          ),
          if (mine.length > 1)
            Press(
              onTap: () {
                final i = mine.indexWhere((x) => x.id == worn?.id);
                g.equip(slot, mine[(i + 1) % mine.length].id);
                App.I.changed();
              },
              label: tr(
                'Ganti $name',
                'Change $name',
                'Cambiar $name',
                'Changer $name',
                '$name wechseln',
                'Trocar $name',
              ),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tr('Ganti', 'Change', 'Cambiar', 'Changer', 'Wechseln', 'Trocar'),
                  style: T.body(15.5, pal.ink, w: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// the country behind the figure: the kingdom being played, by day or by candlelight
class _Land extends CustomPainter {
  final String code;
  final bool night;
  _Land(this.code, this.night);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final (sky, far, near, ground, tree) = switch (code) {
      'de' => (0xFFE2E3E6, 0xFF9A9488, 0xFFC9C6BC, 0xFFE6E4DE, 0xFF4E5A4A),
      'es' => (0xFFF3E7CC, 0xFFE0C79A, 0xFFEADCB8, 0xFFF0E4C6, 0xFF6E7F4E),
      'fr' => (0xFFE9E4EC, 0xFFC9BFD3, 0xFFDCD6CF, 0xFFE6E1DA, 0xFF5A2A6B),
      'pt' => (0xFFD2DEDB, 0xFFA9C1BD, 0xFFDAD7C9, 0xFFE7E3D6, 0xFF4E6B5A),
      _ => (0xFFE4E8EE, 0xFFB9C2B0, 0xFFD6D3C3, 0xFFE9E6DA, 0xFF7C8A63),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(sky));
    Path hill(double y0, double y1, double y2) => Path()
      ..moveTo(0, h * y0)
      ..cubicTo(w * .3, h * y1, w * .6, h * y2, w, h * y1)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    if (code == 'de') {
      final m = Path()..moveTo(0, h * .62);
      for (final (x, y) in const [(.12, .3), (.24, .52), (.4, .18), (.56, .46), (.7, .24), (.86, .5), (1.0, .36)]) {
        m.lineTo(w * x, h * y);
      }
      m
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(m, Paint()..color = Color(far));
    } else {
      canvas.drawPath(hill(.62, .5, .58), Paint()..color = Color(far));
    }
    canvas.drawPath(hill(.72, .66, .74), Paint()..color = Color(near));
    canvas.drawPath(hill(.86, .84, .88), Paint()..color = Color(ground));
    for (final (x, y, r) in const [(.1, .7, 9.0), (.16, .73, 6.0), (.88, .66, 9.0), (.93, .7, 6.0)]) {
      canvas.drawCircle(Offset(w * x, h * y), r, Paint()..color = Color(tree));
    }
    if (night) canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x40101820));
  }

  @override
  bool shouldRepaint(_Land old) => old.code != code || old.night != night;
}
