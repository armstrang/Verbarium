/// The banner of a kingdom of another language: tapped, it tells which exam its road leads towards (a suggestion
/// only, never a score) and, where the kingdom's language is the learning language itself, lets the learner choose
/// the language its meanings are shown in.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../data/deck.dart';
import 'theme.dart';
import 'widgets.dart';
import 'crest.dart' show KingdomArms;

/// the exams a kingdom's road leads towards, as the test owners name them
String examOf(String code) => switch (code) {
  'de' => tr(
    'Goethe-Zertifikat dari Goethe-Institut: satu ujian untuk tiap tingkat, A1 sampai C2.',
    'The Goethe-Zertifikat of the Goethe-Institut: one exam for each level, A1 to C2.',
    'El Goethe-Zertifikat del Goethe-Institut: un examen por nivel, de A1 a C2.',
    'Le Goethe-Zertifikat du Goethe-Institut : un examen par niveau, de A1 à C2.',
    'Das Goethe-Zertifikat des Goethe-Instituts: eine Prüfung für jede Stufe, A1 bis C2.',
    'O Goethe-Zertifikat do Goethe-Institut: uma prova para cada nível, de A1 a C2.',
  ),
  'es' => tr(
    'DELE dari Instituto Cervantes: satu diploma untuk tiap tingkat, A1 sampai C2. SIELE: satu ujian di komputer yang hasilnya menunjukkan tingkat A1 sampai C1.',
    'DELE from the Instituto Cervantes: one diploma for each level, A1 to C2. SIELE: a single computer test whose result shows a level from A1 to C1.',
    'El DELE del Instituto Cervantes: un diploma por nivel, de A1 a C2. El SIELE: un único examen por ordenador cuyo resultado indica un nivel de A1 a C1.',
    'Le DELE de l’Instituto Cervantes : un diplôme par niveau, de A1 à C2. Le SIELE : un seul test sur ordinateur dont le résultat indique un niveau de A1 à C1.',
    'DELE vom Instituto Cervantes: ein Diplom für jede Stufe, A1 bis C2. SIELE: ein einziger Test am Computer, dessen Ergebnis eine Stufe von A1 bis C1 zeigt.',
    'O DELE do Instituto Cervantes: um diploma para cada nível, de A1 a C2. O SIELE: uma única prova no computador cujo resultado indica um nível de A1 a C1.',
  ),
  'fr' => tr(
    'DELF (A1 sampai B2) dan DALF (C1 dan C2) dari France Éducation international: satu diploma untuk tiap tingkat.',
    'DELF (A1 to B2) and DALF (C1 and C2) from France Éducation international: one diploma for each level.',
    'El DELF (de A1 a B2) y el DALF (C1 y C2) de France Éducation international: un diploma por nivel.',
    'Le DELF (de A1 à B2) et le DALF (C1 et C2) de France Éducation international : un diplôme par niveau.',
    'DELF (A1 bis B2) und DALF (C1 und C2) von France Éducation international: ein Diplom für jede Stufe.',
    'O DELF (de A1 a B2) e o DALF (C1 e C2) da France Éducation international: um diploma para cada nível.',
  ),
  'pt' => tr(
    'CAPLE dari Universidade de Lisboa, untuk bahasa Portugis Portugal: CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). Celpe-Bras dari Brasil: satu ujian dengan tingkatnya sendiri, Intermediário sampai Avançado Superior.',
    'CAPLE of the University of Lisbon, for European Portuguese: CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). Celpe-Bras of Brazil: a single exam with levels of its own, Intermediário to Avançado Superior.',
    'El CAPLE de la Universidad de Lisboa, para el portugués europeo: CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). El Celpe-Bras de Brasil: un único examen con niveles propios, de Intermediário a Avançado Superior.',
    'Le CAPLE de l’Université de Lisbonne, pour le portugais européen : CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). Le Celpe-Bras du Brésil : un seul examen avec ses propres niveaux, d’Intermediário à Avançado Superior.',
    'CAPLE der Universität Lissabon, für europäisches Portugiesisch: CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). Celpe-Bras aus Brasilien: eine einzige Prüfung mit eigenen Stufen, Intermediário bis Avançado Superior.',
    'O CAPLE da Universidade de Lisboa, para o português europeu: CIPLE (A2), DEPLE (B1), DIPLE (B2), DAPLE (C1), DUPLE (C2). O Celpe-Bras do Brasil: uma única prova com níveis próprios, de Intermediário a Avançado Superior.',
  ),
  _ => '',
};

const _names = {
  'id': 'Indonesia',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
};

/// the kingdom's banner as a small tappable pill beside its name
class BannerPill extends StatelessWidget {
  final Kingdom k;
  const BannerPill(this.k, {super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: () => showBanner(context),
      label: tr(
        'Panji ${k.name}',
        'Banner of ${k.name}',
        'Estandarte de ${k.name}',
        'Bannière de ${k.name}',
        'Banner von ${k.name}',
        'Estandarte de ${k.name}',
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
        decoration: BoxDecoration(
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(20),
          color: pal.field,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KingdomArms(k.code, height: 28),
            const SizedBox(width: 6),
            Text(k.language, style: T.body(14.5, pal.ink, w: FontWeight.w700)),
            Icon(Icons.chevron_right, size: 18, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

/// what the banner tells: the exam to aim for, and the language of meanings where it must be chosen
Future<void> showBanner(BuildContext context) async {
  final look = Look.of(context);
  final app = App.I;
  final k = app.kingdom;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Look(
      pal: look.pal,
      rank: look.rank,
      calm: look.calm,
      child: ListenableBuilder(
        listenable: app,
        builder: (ctx, _) {
          final pal = look.pal;
          return Dialog(
            backgroundColor: pal.field,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: BorderSide(color: pal.ink, width: 1.5),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      KingdomArms(k.code, height: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k.name, style: T.display(25, pal.ink)),
                            Text(k.language, style: T.body(14.5, pal.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      'UJIAN YANG BISA JADI TUJUAN',
                      'AN EXAM TO AIM FOR',
                      'UN EXAMEN COMO META',
                      'UN EXAMEN POUR CIBLE',
                      'EINE PRÜFUNG ALS ZIEL',
                      'UMA PROVA COMO META',
                    ),
                    style: T.label(pal.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(examOf(k.code), style: T.body(16.5, pal.ink, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Ini hanya saran. Gelar di sini mengukur kosakata, bukan nilai ujian.',
                      'This is only a suggestion. A title here measures vocabulary, not an exam score.',
                      'Es solo una sugerencia. Aquí un título mide vocabulario, no la nota de un examen.',
                      'Ce n’est qu’une suggestion. Ici, un titre mesure le vocabulaire, pas une note d’examen.',
                      'Das ist nur ein Vorschlag. Ein Titel misst hier den Wortschatz, kein Prüfungsergebnis.',
                      'É só uma sugestão. Aqui um título mede vocabulário, não a nota de uma prova.',
                    ),
                    style: T.body(14.5, pal.muted, height: 1.4),
                  ),
                  if (app.clash) ...[
                    const SizedBox(height: 18),
                    Text(
                      tr(
                        'ARTI DITAMPILKAN DALAM',
                        'MEANINGS ARE SHOWN IN',
                        'LOS SIGNIFICADOS SE MUESTRAN EN',
                        'LES SENS SONT AFFICHÉS EN',
                        'BEDEUTUNGEN ERSCHEINEN AUF',
                        'OS SENTIDOS APARECEM EM',
                      ),
                      style: T.label(pal.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'Kamu belajar ${k.language} lewat ${k.language}, jadi arti kata dan terjemahan kalimat ditampilkan dalam bahasa lain.',
                        'You learn ${k.language} through ${k.language}, so meanings and sentence translations are shown in another language.',
                        'Aprendes ${k.language.toLowerCase()} a través de ${k.language.toLowerCase()}, así que los significados y las traducciones se muestran en otro idioma.',
                        'Tu apprends le ${k.language.toLowerCase()} en ${k.language.toLowerCase()} : les sens et les traductions s’affichent donc dans une autre langue.',
                        'Du lernst ${k.language} über ${k.language}, darum erscheinen Bedeutungen und Übersetzungen in einer anderen Sprache.',
                        'Você aprende ${k.language.toLowerCase()} por meio de ${k.language.toLowerCase()}, então os sentidos e as traduções aparecem em outro idioma.',
                      ),
                      style: T.body(14.5, pal.muted, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _names.keys)
                          if (c != k.code) _ViaChip(c, _names[c]!, app.via == c, () => app.chooseVia(c)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  InkButton(
                    tr('Tutup', 'Close', 'Cerrar', 'Fermer', 'Schließen', 'Fechar'),
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// asks once, on entering a kingdom whose language is the learning language, which language to explain it in
void askViaOnce(BuildContext context) {
  final app = App.I;
  if (!app.clash || app.viaChosen) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted || app.viaChosen) return;
    // the question is asked once: closing it keeps English
    app.chooseVia(app.via);
    await showBanner(context);
  });
}

class _ViaChip extends StatelessWidget {
  final String code, name;
  final bool on;
  final VoidCallback onTap;
  const _ViaChip(this.code, this.name, this.on, this.onTap);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      label: name,
      child: Semantics(
        selected: on,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: on ? pal.ink : Colors.transparent,
              border: Border.all(color: pal.ink, width: 1.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(name, style: T.body(15, on ? pal.bg : pal.ink, w: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
