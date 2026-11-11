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
        Label(tr('Karakter', 'Character', 'Personaje', 'Personnage')),
        const SizedBox(height: 10),
        Rise(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Press(
                // the hero tapped: the story of who they are
                onTap: () => Navigator.of(context).push(runRoute(LorePage(job: job, rank: rank))),
                label: tr(
                  'Kisah ${job.name}',
                  'Story of the ${job.name}',
                  'Historia de ${job.name}',
                  'Histoire de ${job.name}',
                ),
                child: Container(
                  width: 132,
                  height: 150,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: pal.field,
                    border: Border.all(color: pal.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: HeroSprite(
                    garb: job.garb,
                    tier: job.tier,
                    weapon: g.tone('weapon'),
                    shield: g.tone('shield'),
                    cloak: g.tone('cloak'),
                    size: 108,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(job.name, style: T.display(30, pal.ink)),
                    ),
                    Text(
                      '${rankNames[rank]}${rank < Engine.maxRank ? ' ${stageName(e.stage)}' : ''}',
                      style: T.body(16.5, pal.ink, w: FontWeight.w500),
                    ),
                    if (g.title.isNotEmpty) Text(g.title, style: T.display(19, pal.muted, italic: true)),
                    const SizedBox(height: 8),
                    Text('Level ${g.level}', style: T.body(17, pal.ink, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Bar(g.levelShare, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        '${g.toNext} XP lagi ke level ${g.level + 1}',
                        '${g.toNext} XP to level ${g.level + 1}',
                        '${g.toNext} XP para el nivel ${g.level + 1}',
                        '${g.toNext} XP avant le niveau ${g.level + 1}',
                      ),
                      style: T.body(14.5, pal.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr(
              'Ketuk karakternya untuk membaca kisahnya.',
              'Tap the figure to read their story.',
              'Toca la figura para leer su historia.',
              'Touche le personnage pour lire son histoire.',
            ),
            style: T.body(14, pal.muted),
          ),
        ),
        const SizedBox(height: 22),
        Label(tr('Jalan dan perk', 'Path and perks', 'Camino y ventajas', 'Voie et atouts')),
        const SizedBox(height: 6),
        Text(g.path.map((j) => j.name).join('  ›  '), style: T.body(16.5, pal.ink, w: FontWeight.w500, height: 1.45)),
        const SizedBox(height: 4),
        if (perks.isEmpty)
          Text(
            tr(
              'Job pertamamu ditentukan saat kamu dinobatkan menjadi Squire. Bukan kamu yang memilih: cara belajarmu yang menentukan.',
              'Your first job is decided when you are crowned Squire. You do not choose it: the way you learn does.',
              'Tu primer oficio se decide cuando te coronan Squire. No lo eliges tú: lo decide tu manera de aprender.',
              'Ton premier métier se décide quand tu es couronné Squire. Tu ne le choisis pas : ta façon d’apprendre le fait.',
            ),
            style: T.body(15, pal.muted, height: 1.45),
          )
        else
          for (final j in perks)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${j.name}: ${j.perk.text}', style: T.body(15, pal.muted, height: 1.4)),
            ),
        const SizedBox(height: 22),
        const _BuildBlock(),
        const SizedBox(height: 22),
        Label(tr('Kemampuan', 'Figures', 'Cifras', 'Chiffres')),
        const SizedBox(height: 6),
        _Figure(
          tr('Ingatan', 'Memory', 'Memoria', 'Mémoire'),
          g.memory,
          tr(
            'kata kukuh dari ranah yang sudah kamu masuki',
            'solid words out of the lands you have entered',
            'palabras firmes de las tierras que ya pisaste',
            'mots ancrés des terres où tu es entré',
          ),
        ),
        _Figure(
          tr('Ketepatan', 'Accuracy', 'Precisión', 'Précision'),
          g.accuracy,
          tr(
            'jawaban benar dari 100 terakhir',
            'right answers out of the last 100',
            'respuestas correctas de las últimas 100',
            'bonnes réponses sur les 100 dernières',
          ),
        ),
        _Figure(
          tr('Kecepatan', 'Speed', 'Rapidez', 'Rapidité'),
          g.speed,
          tr(
            'dari waktu rata-rata mengisi celah',
            'from the average time to fill a gap',
            'según el tiempo medio para completar un hueco',
            'd’après le temps moyen pour remplir un trou',
          ),
        ),
        _Figure(
          tr('Ketekunan', 'Diligence', 'Constancia', 'Assiduité'),
          g.diligence,
          tr(
            '${g.activeDays14} dari 14 hari terakhir kamu belajar',
            'you studied on ${g.activeDays14} of the last 14 days',
            'estudiaste ${g.activeDays14} de los últimos 14 días',
            'tu as étudié ${g.activeDays14} des 14 derniers jours',
          ),
        ),
        const SizedBox(height: 22),
        Label(tr('Perlengkapan', 'Gear', 'Equipo', 'Équipement')),
        const SizedBox(height: 6),
        for (final slot in const ['weapon', 'shield', 'cloak']) _Slot(slot),
        const SizedBox(height: 22),
        Label(tr('Quest minggu ini', 'This week\'s quests', 'Misiones de la semana', 'Quêtes de la semaine')),
        const SizedBox(height: 4),
        for (final q in g.weekly) QuestRow(q),
        const SizedBox(height: 22),
        if (titled.isNotEmpty) ...[
          Label(tr('Gelar kehormatan', 'Honorary title', 'Título honorífico', 'Titre honorifique')),
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
                        f == null ? tr('Tanpa gelar', 'No title', 'Sin título', 'Aucun titre') : f.title!,
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
                        '${f.text}${f.title == null ? '' : tr(' · gelar "${f.title}"', ' · title "${f.title}"', ' · título «${f.title}»', ' · titre « ${f.title} »')}',
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
          tr('Arah build', 'Where your build leans', 'Hacia dónde se inclina tu estilo', 'Vers où penche ton style'),
        ),
        const SizedBox(height: 6),
        if (b.total < 20)
          Text(
            tr(
              'Belum cukup jawaban untuk dibaca. Tiap jawaban menambah salah satu dari empat sisi di bawah ini.',
              'Not enough answers to read yet. Every answer adds to one of the four sides below.',
              'Aún no hay respuestas suficientes. Cada respuesta suma a uno de los cuatro lados de abajo.',
              'Pas encore assez de réponses. Chaque réponse s’ajoute à l’un des quatre côtés ci-dessous.',
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
          ),
          style: T.body(14.5, pal.muted, height: 1.45),
        ),
        if (next.isNotEmpty) ...[
          const SizedBox(height: 18),
          Label(tr('Jalan berikutnya', 'The paths ahead', 'Los caminos por delante', 'Les voies à venir')),
          const SizedBox(height: 8),
          for (final j in next) _PathRow(j, known: known.contains(j.id), pointed: heading?.id == j.id),
          const SizedBox(height: 4),
          Text(
            tr(
              'Job ditentukan saat penobatan, dari build-mu waktu itu. Tidak bisa dipilih dan tidak bisa diganti.',
              'The job is decided at the coronation, from your build at that moment. It cannot be chosen and cannot be changed.',
              'El oficio se decide en la coronación, según tu estilo en ese momento. No se puede elegir ni cambiar.',
              'Le métier se décide au couronnement, d’après ton style à ce moment-là. Il ne peut être ni choisi ni changé.',
            ),
            style: T.body(14.5, pal.muted, height: 1.45),
          ),
        ],
        const SizedBox(height: 10),
        InkButton(
          tr('Peta job', 'Map of jobs', 'Mapa de oficios', 'Carte des métiers'),
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
                label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(
                  tr('Peta job', 'Map of jobs', 'Mapa de oficios', 'Carte des métiers'),
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
                Label(tr('Tersembunyi', 'Hidden', 'Oculto', 'Caché')),
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
      'weapon': tr('Senjata', 'Arms', 'Arma', 'Arme'),
      'shield': tr('Perisai', 'Shield', 'Escudo', 'Bouclier'),
      'cloak': tr('Jubah', 'Cloak', 'Capa', 'Cape'),
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
                  ),
                  style: T.body(14.5, pal.muted),
                ),
                Text(
                  worn?.name ?? tr('Belum punya', 'None yet', 'Aún nada', 'Rien encore'),
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
              label: tr('Ganti $name', 'Change $name', 'Cambiar $name', 'Changer $name'),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tr('Ganti', 'Change', 'Cambiar', 'Changer'),
                  style: T.body(15.5, pal.ink, w: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
