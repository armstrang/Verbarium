/// Lore in the app, and only two places for it: the introduction of the new character after a coronation (closed
/// by its button only), and the story page that opens when the hero is tapped in Karakter.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../engine/jobs.dart';
import '../engine/lore.dart';
import 'pixel.dart';
import 'run.dart' show runRoute;
import 'theme.dart';
import 'widgets.dart';

Widget _figure(BuildContext context, Job job, {double size = 132, HeroPose pose = HeroPose.idle}) {
  final pal = Look.of(context).pal;
  final g = App.I.game;
  return Container(
    width: size * 1.3,
    height: size * 1.4,
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
      pose: pose,
      size: size,
    ),
  );
}

/// The new character, introduced once after a coronation. Only its button closes it.
class JobIntro extends StatelessWidget {
  final Job job;
  final int rank;
  const JobIntro({super.key, required this.job, required this.rank});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final lore = LoreBook.job(job.id);
    return PopScope(
      canPop: false,
      child: Leaf(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Center(child: Label(tr('Tercatat dalam kronik', 'Entered in the chronicle', 'Registrado en la crónica', 'Consigné dans la chronique'))),
                  const SizedBox(height: 16),
                  Center(child: _figure(context, job, pose: HeroPose.cheer)),
                  const SizedBox(height: 18),
                  Text(job.name, textAlign: TextAlign.center, style: T.display(34, pal.ink)),
                  Text(
                    rankNames[rank],
                    textAlign: TextAlign.center,
                    style: T.body(16.5, pal.muted, w: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '“${lore.quote}”',
                    textAlign: TextAlign.center,
                    style: T.display(21, pal.ink, italic: true, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  Text(lore.story, textAlign: TextAlign.center, style: T.body(16.5, pal.ink, height: 1.5)),
                  const SizedBox(height: 6),
                  Text(lore.drive, textAlign: TextAlign.center, style: T.body(15.5, pal.muted, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            InkButton(
              tr('Lihat kisahnya', 'Read the story', 'Leer la historia', 'Lire l’histoire'),
              outline: true,
              onTap: () => Navigator.of(context).push(runRoute(LorePage(job: job, rank: rank))),
            ),
            const SizedBox(height: 10),
            InkButton(
              tr('Mulai sebagai ${job.name}', 'Begin as ${job.name}', 'Empezar como ${job.name}', 'Commencer en ${job.name}'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// The story of a character: who they are, where they come from, what drives them, and the realm of the title held.
class LorePage extends StatelessWidget {
  final Job job;
  final int rank;
  const LorePage({super.key, required this.job, required this.rank});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final lore = LoreBook.job(job.id);
    final realm = LoreBook.title(rank);
    Widget part(String head, String text) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(head),
          const SizedBox(height: 6),
          Text(text, style: T.body(16.5, pal.ink, height: 1.5)),
        ],
      ),
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
              Expanded(child: Text(tr('Kisah', 'Story', 'Historia', 'Histoire'), style: T.display(25, pal.ink))),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              children: [
                Center(child: _figure(context, job, size: 108)),
                const SizedBox(height: 14),
                Text(job.name, textAlign: TextAlign.center, style: T.display(30, pal.ink)),
                Text(
                  rankNames[rank],
                  textAlign: TextAlign.center,
                  style: T.body(16, pal.muted, w: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  '“${lore.quote}”',
                  textAlign: TextAlign.center,
                  style: T.display(20, pal.ink, italic: true, height: 1.3),
                ),
                part(tr('Kisah', 'Story', 'Historia', 'Histoire'), lore.story),
                part(tr('Sifat', 'Nature', 'Carácter', 'Caractère'), lore.nature),
                part(tr('Latar belakang', 'Background', 'Origen', 'Origines'), lore.past),
                part(tr('Motivasi', 'What drives them', 'Lo que le impulsa', 'Ce qui l’anime'), lore.drive),
                const SizedBox(height: 26),
                Divider(color: pal.line, height: 1),
                part(tr('Negeri ${rankNames[rank]}', 'The realm of the ${rankNames[rank]}', 'El reino de ${rankNames[rank]}', 'Le royaume du ${rankNames[rank]}'), realm.story),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('“${realm.quote}”', style: T.display(18, pal.muted, italic: true, height: 1.3)),
                ),
                part(tr('Dunia Verbarium', 'The world of Verbarium', 'El mundo de Verbarium', 'Le monde de Verbarium'), LoreBook.world),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
