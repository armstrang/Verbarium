/// Pengaturan: the banner, the daily load, sound, the look, and starting over.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
import '../app/lang.dart';
import '../app/native.dart';
import '../data/deck.dart';
import '../data/store.dart';
import 'realm.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final look = Look.of(context);
        final pal = look.pal;
        final app = App.I;
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
                      tr('Pengaturan', 'Settings', 'Ajustes', 'Réglages', 'Einstellungen', 'Configurações'),
                      style: T.display(27, pal.ink),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
                  children: [
                    _Group(
                      tr(
                        'Bahasa belajar',
                        'Learning language',
                        'Idioma de aprendizaje',
                        'Langue d’apprentissage',
                        'Lernsprache',
                        'Idioma de aprendizagem',
                      ),
                      [
                        _Choice(
                          options: const {
                            'id': 'Indonesia',
                            'en': 'English',
                            'es': 'Español',
                            'fr': 'Français',
                            'de': 'Deutsch',
                            'pt': 'Português',
                          },
                          value: app.langCode,
                          onPick: (v) => app.put('lang', v),
                        ),
                        _Note(
                          tr(
                            'Dalam English, arti kata dijelaskan dengan bahasa Inggris yang lebih sederhana dan seluruh aplikasi berbahasa Inggris. Nama gelar dan job selalu bahasa Inggris. Kemajuanmu tetap.',
                            'In English, a word is explained in simpler English and the whole app speaks English. Titles and jobs are English in either language. Your progress stays.',
                            'En español, cada palabra se explica en español y toda la aplicación habla español. Los títulos y oficios quedan en inglés en todos los idiomas. Tu progreso se conserva.',
                            'En français, chaque mot est expliqué en français et toute l’application parle français. Les titres et les métiers restent en anglais dans toutes les langues. Ta progression est conservée.',
                            'Auf Deutsch wird jedes Wort auf Deutsch erklärt, und die ganze App spricht Deutsch. Titel und Berufe bleiben in jeder Sprache englisch. Dein Fortschritt bleibt.',
                            'Em português, cada palavra é explicada em português, e o app inteiro fala português. Títulos e profissões ficam em inglês em qualquer idioma. Seu progresso continua.',
                          ),
                        ),
                      ],
                    ),
                    _Group(tr('Panji', 'Banner', 'Estandarte', 'Bannière', 'Banner', 'Estandarte'), [
                      _Choice(
                        options: const {'toefl': 'TOEFL', 'ielts': 'IELTS'},
                        value: app.banner,
                        onPick: (v) => app.chooseBanner(v),
                      ),
                      _Note(
                        tr(
                          'Mengganti panji mengganti kata tambahan dan ejaan. Kemajuan dan gelarmu tetap.',
                          'Changing the banner changes the extra words and the spelling. Your progress and your title stay.',
                          'Cambiar el estandarte cambia las palabras extra y la ortografía. Tu progreso y tu título se conservan.',
                          'Changer de bannière change les mots en plus et l’orthographe. Ta progression et ton titre restent.',
                          'Ein anderes Banner ändert die zusätzlichen Wörter und die Schreibung. Fortschritt und Titel bleiben.',
                          'Trocar o estandarte muda as palavras extras e a grafia. Seu progresso e seu título continuam.',
                        ),
                      ),
                    ]),
                    _Group(
                      tr(
                        'Kata baru tiap hari',
                        'New words each day',
                        'Palabras nuevas al día',
                        'Nouveaux mots par jour',
                        'Neue Wörter pro Tag',
                        'Palavras novas por dia',
                      ),
                      [
                        Row(
                          children: [
                            _Step(
                              Icons.remove,
                              tr('Kurangi', 'Fewer', 'Menos', 'Moins', 'Weniger', 'Menos'),
                              app.perDay > 5 ? () => app.put('perDay', app.perDay - 5) : null,
                            ),
                            Expanded(
                              child: Center(child: Text('${app.perDay}', style: T.display(34, pal.ink))),
                            ),
                            _Step(
                              Icons.add,
                              tr('Tambah', 'More', 'Más', 'Plus', 'Mehr', 'Mais'),
                              app.perDay < 40 ? () => app.put('perDay', app.perDay + 5) : null,
                            ),
                          ],
                        ),
                        _Note(
                          tr(
                            'Lima belas kata sehari sudah cukup berat. Kata baru hari ini menjadi ulangan besok dan lusa.',
                            'Fifteen words a day is already a fair load. Today\'s new words are tomorrow\'s reviews.',
                            'Quince palabras al día ya es buena carga. Las palabras nuevas de hoy son los repasos de mañana.',
                            'Quinze mots par jour, c’est déjà une bonne charge. Les nouveaux mots d’aujourd’hui sont les révisions de demain.',
                            'Fünfzehn Wörter am Tag sind schon ein ordentliches Pensum. Die neuen Wörter von heute sind die Wiederholungen von morgen.',
                            'Quinze palavras por dia já é uma boa carga. As palavras novas de hoje são as revisões de amanhã.',
                          ),
                        ),
                      ],
                    ),
                    _Group(tr('Suara', 'Sound', 'Sonido', 'Son', 'Ton', 'Som'), [
                      _Toggle(
                        tr(
                          'Musik latar',
                          'Background music',
                          'Música de fondo',
                          'Musique de fond',
                          'Hintergrundmusik',
                          'Música de fundo',
                        ),
                        app.musicOn,
                        (v) => app.put('music', v ? 1 : 0),
                      ),
                      if (app.musicOn)
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: pal.ink,
                            inactiveTrackColor: pal.line,
                            thumbColor: pal.ink,
                            overlayColor: pal.ink.withValues(alpha: 0.1),
                            trackHeight: 3,
                          ),
                          child: Semantics(
                            label: tr(
                              'Keras musik',
                              'Music volume',
                              'Volumen de la música',
                              'Volume de la musique',
                              'Musiklautstärke',
                              'Volume da música',
                            ),
                            child: Slider(
                              value: app.musicVol.clamp(0.05, 1.0),
                              min: 0.05,
                              max: 1,
                              onChanged: (v) => app.put('musicVol', double.parse(v.toStringAsFixed(2))),
                            ),
                          ),
                        ),
                      _Toggle(
                        tr(
                          'Efek suara',
                          'Sound effects',
                          'Efectos de sonido',
                          'Effets sonores',
                          'Soundeffekte',
                          'Efeitos sonoros',
                        ),
                        app.sfxOn,
                        (v) => app.put('sfx', v ? 1 : 0),
                      ),
                    ]),
                    _Group(tr('Tampilan', 'Look', 'Aspecto', 'Apparence', 'Aussehen', 'Aparência'), [
                      _Choice(
                        options: {
                          'system': tr(
                            'Ikut ponsel',
                            'Follow phone',
                            'Como el teléfono',
                            'Comme le téléphone',
                            'Wie das Handy',
                            'Igual ao celular',
                          ),
                          'light': tr('Kertas', 'Paper', 'Papel', 'Papier', 'Papier', 'Papel'),
                          'dark': tr('Lilin', 'Candle', 'Vela', 'Bougie', 'Kerze', 'Vela'),
                        },
                        value: app.theme,
                        onPick: (v) => app.put('theme', v),
                      ),
                      const SizedBox(height: 8),
                      _Toggle(
                        tr(
                          'Gerak tenang',
                          'Calm motion',
                          'Movimiento sereno',
                          'Mouvement apaisé',
                          'Ruhige Bewegung',
                          'Movimento calmo',
                        ),
                        app.calm,
                        (v) => app.put('calm', v ? 1 : 0),
                      ),
                      _Note(
                        tr(
                          'Mengurangi animasi. Pengaturan ponselmu untuk menghilangkan animasi juga diikuti.',
                          'Fewer animations. Your phone\'s own setting for removing animations is honoured too.',
                          'Menos animaciones. También se respeta el ajuste del teléfono para quitar animaciones.',
                          'Moins d’animations. Le réglage du téléphone qui retire les animations est aussi respecté.',
                          'Weniger Animationen. Die Einstellung deines Handys zum Entfernen von Animationen wird ebenfalls beachtet.',
                          'Menos animações. A configuração do seu celular para remover animações também é respeitada.',
                        ),
                      ),
                    ]),
                    _Group(tr('Cadangan', 'Backup', 'Copia de seguridad', 'Sauvegarde', 'Sicherung', 'Backup'), [
                      _Link(
                        tr(
                          'Simpan cadangan',
                          'Save a backup',
                          'Guardar una copia',
                          'Enregistrer une sauvegarde',
                          'Sicherung speichern',
                          'Salvar um backup',
                        ),
                        () => saveBackup(context),
                      ),
                      _Link(
                        tr(
                          'Pulihkan cadangan',
                          'Restore a backup',
                          'Restaurar una copia',
                          'Restaurer une sauvegarde',
                          'Sicherung wiederherstellen',
                          'Restaurar um backup',
                        ),
                        () => restoreBackup(context),
                      ),
                      _Note(
                        tr(
                          'Satu berkas berisi semua negeri, gelar, kronik dan pengaturanmu. Kamu yang memilih tempatnya: folder Download, Drive atau kartu memori. Android juga mencadangkan kemajuanmu ke akun Google-mu sendiri bila cadangan ponselmu menyala.',
                          'One file with every kingdom, title, chronicle and setting. You choose where it goes: Download, Drive or a memory card. Android also backs up your progress to your own Google account when your phone\'s backup is on.',
                          'Un archivo con todos tus reinos, títulos, crónica y ajustes. Tú eliges dónde va: Descargas, Drive o una tarjeta de memoria. Android también guarda tu progreso en tu propia cuenta de Google si la copia del teléfono está activada.',
                          'Un fichier avec tous tes royaumes, titres, chronique et réglages. Tu choisis où il va : Téléchargements, Drive ou une carte mémoire. Android sauvegarde aussi ta progression sur ton propre compte Google si la sauvegarde du téléphone est activée.',
                          'Eine Datei mit allen Königreichen, Titeln, deiner Chronik und den Einstellungen. Du wählst, wohin sie kommt: Download, Drive oder eine Speicherkarte. Android sichert deinen Fortschritt außerdem in deinem eigenen Google-Konto, wenn die Sicherung des Handys an ist.',
                          'Um arquivo com todos os reinos, títulos, crônica e configurações. Você escolhe onde ele fica: Download, Drive ou um cartão de memória. O Android também faz backup do seu progresso na sua própria conta Google se o backup do celular estiver ativado.',
                        ),
                      ),
                    ]),
                    _Group(tr('Tentang', 'About', 'Acerca de', 'À propos', 'Über', 'Sobre'), [
                      _Link(
                        tr(
                          'Dari mana rentang skor berasal',
                          'Where the score ranges come from',
                          'De dónde salen los rangos de nota',
                          'D’où viennent les fourchettes de score',
                          'Woher die Spannen kommen',
                          'De onde vêm as faixas de nota',
                        ),
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage())),
                      ),
                      _Link(
                        tr(
                          'Lisensi huruf',
                          'Font licences',
                          'Licencias de las fuentes',
                          'Licences des polices',
                          'Schriftlizenzen',
                          'Licenças das fontes',
                        ),
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LicencesPage())),
                      ),
                      _Link(
                        tr(
                          'Lisensi perangkat lunak',
                          'Software licences',
                          'Licencias de software',
                          'Licences des logiciels',
                          'Softwarelizenzen',
                          'Licenças de software',
                        ),
                        () =>
                            showLicensePage(context: context, applicationName: 'Verbarium', applicationVersion: '0.5'),
                      ),
                      const _SupportLink(),
                      _Link(
                        tr('Privasi', 'Privacy', 'Privacidad', 'Confidentialité', 'Datenschutz', 'Privacidade'),
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage())),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'Verbarium 0.5 (uji coba) · oleh Armstrang\nBekerja tanpa internet. Kemajuanmu hanya ada di ponsel ini.\nMusik dimainkan dengan sampel instrumen CC0 dari VSCO 2 CE dan VCSL (Versilian Studios).',
                          'Verbarium 0.5 (test build) · by Armstrang\nWorks without internet. Your progress lives only on this phone.\nThe music is played on CC0 instrument samples from VSCO 2 CE and VCSL (Versilian Studios).',
                          'Verbarium 0.5 (versión de prueba) · por Armstrang\nFunciona sin internet. Tu progreso vive solo en este teléfono.\nLa música se toca con muestras de instrumentos CC0 de VSCO 2 CE y VCSL (Versilian Studios).',
                          'Verbarium 0.5 (version de test) · par Armstrang\nFonctionne sans internet. Ta progression ne vit que sur ce téléphone.\nLa musique est jouée avec des échantillons d’instruments CC0 de VSCO 2 CE et VCSL (Versilian Studios).',
                          'Verbarium 0.5 (Testversion) · von Armstrang\nFunktioniert ohne Internet. Dein Fortschritt liegt nur auf diesem Handy.\nDie Musik wird mit CC0-Instrumentensamples aus VSCO 2 CE und VCSL (Versilian Studios) gespielt.',
                          'Verbarium 0.5 (versão de teste) · por Armstrang\nFunciona sem internet. Seu progresso fica só neste celular.\nA música é tocada com amostras de instrumentos CC0 do VSCO 2 CE e do VCSL (Versilian Studios).',
                        ),
                        style: T.body(15, pal.muted, height: 1.5),
                      ),
                    ]),
                    _Group(
                      tr(
                        'Mulai dari awal',
                        'Start over',
                        'Empezar de cero',
                        'Tout recommencer',
                        'Neu beginnen',
                        'Recomeçar',
                      ),
                      [
                        InkButton(
                          tr(
                            'Hapus semua kemajuan',
                            'Erase all progress',
                            'Borrar todo el progreso',
                            'Effacer toute la progression',
                            'Allen Fortschritt löschen',
                            'Apagar todo o progresso',
                          ),
                          outline: true,
                          onTap: () async {
                            final yes = await confirm(
                              context,
                              title: tr(
                                'Hapus semua kemajuan?',
                                'Erase all progress?',
                                '¿Borrar todo el progreso?',
                                'Effacer toute la progression ?',
                                'Allen Fortschritt löschen?',
                                'Apagar todo o progresso?',
                              ),
                              text: tr(
                                'Gelar, kata yang sudah kukuh dan seluruh kronikmu hilang. Ini tidak bisa dibatalkan.',
                                'Your title, your solid words and your whole chronicle will be gone. This cannot be undone.',
                                'Tu título, tus palabras firmes y toda tu crónica desaparecerán. No se puede deshacer.',
                                'Ton titre, tes mots ancrés et toute ta chronique disparaîtront. C’est irréversible.',
                                'Dein Titel, deine gefestigten Wörter und deine ganze Chronik sind dann weg. Das lässt sich nicht rückgängig machen.',
                                'Seu título, suas palavras firmes e toda a sua crônica vão sumir. Não dá para desfazer.',
                              ),
                              yes: tr('Hapus', 'Erase', 'Borrar', 'Effacer', 'Löschen', 'Apagar'),
                            );
                            if (yes) await app.resetProgress();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cadangan: the whole save written to a file the learner chooses, through Android's own file picker
Future<void> saveBackup(BuildContext context) async {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final name = 'verbarium-${now.year}-${two(now.month)}-${two(now.day)}.json';
  App.I.root.flush();
  final r = await Native.backupSave(name, App.I.root.backupText(now));
  if (!context.mounted || r == 'cancel') return;
  await notice(
    context,
    title: r == 'ok'
        ? tr(
            'Cadangan tersimpan',
            'Backup saved',
            'Copia guardada',
            'Sauvegarde enregistrée',
            'Sicherung gespeichert',
            'Backup salvo',
          )
        : tr(
            'Gagal menyimpan',
            'Could not save',
            'No se pudo guardar',
            'Échec de l’enregistrement',
            'Speichern fehlgeschlagen',
            'Não foi possível salvar',
          ),
    text: r == 'ok'
        ? tr(
            'Simpan berkas $name baik-baik. Di ponsel baru, pasang Verbarium lalu pilih Pulihkan cadangan.',
            'Keep $name somewhere safe. On a new phone, install Verbarium and choose Restore a backup.',
            'Guarda $name en un lugar seguro. En un teléfono nuevo, instala Verbarium y elige Restaurar una copia.',
            'Garde $name en lieu sûr. Sur un nouveau téléphone, installe Verbarium et choisis Restaurer une sauvegarde.',
            'Bewahre $name gut auf. Auf einem neuen Handy installierst du Verbarium und wählst Sicherung wiederherstellen.',
            'Guarde $name num lugar seguro. Num celular novo, instale o Verbarium e escolha Restaurar um backup.',
          )
        : tr(
            'Berkasnya tidak bisa ditulis di sana. Coba tempat lain.',
            'The file could not be written there. Try another place.',
            'No se pudo escribir el archivo ahí. Prueba otro lugar.',
            'Le fichier n’a pas pu être écrit là. Essaie un autre endroit.',
            'Die Datei ließ sich dort nicht schreiben. Versuch einen anderen Ort.',
            'Não foi possível gravar o arquivo aí. Tente outro lugar.',
          ),
  );
}

/// what a backup holds, one line per kingdom: its title and the words met
String backupSummary(Map<String, dynamic> d) {
  String line(Kingdom k, Map m) {
    final r = ((m['rank'] as num?)?.toInt() ?? 0).clamp(0, rankNames.length - 1);
    final seen = m['mem'] is Map ? (m['mem'] as Map).length : 0;
    return '${k.name}: ${rankNames[r]} · $seen ${tr('kata', 'words', 'palabras', 'mots', 'Wörter', 'palavras')}';
  }

  final realms = d['realms'] is Map ? d['realms'] as Map : const {};
  return [
    for (final k in Kingdom.all)
      if (k.code == 'en' ? d['mem'] is Map && (d['mem'] as Map).isNotEmpty : realms[k.code] is Map)
        line(k, k.code == 'en' ? d : realms[k.code] as Map),
  ].join('\n');
}

/// Cadangan: a backup file read back, checked, and put in place of this phone's progress after a yes
Future<void> restoreBackup(BuildContext context) async {
  final text = await Native.backupOpen();
  if (!context.mounted || text == null) return;
  final d = Store.fromBackup(text);
  if (d == null) {
    await notice(
      context,
      title: tr(
        'Bukan cadangan Verbarium',
        'Not a Verbarium backup',
        'No es una copia de Verbarium',
        'Pas une sauvegarde de Verbarium',
        'Keine Verbarium-Sicherung',
        'Não é um backup do Verbarium',
      ),
      text: tr(
        'Berkas ini tidak bisa dibaca sebagai cadangan, atau dibuat oleh Verbarium yang lebih baru. Kemajuanmu tidak diubah.',
        'This file cannot be read as a backup, or was made by a newer Verbarium. Your progress was not changed.',
        'Este archivo no se puede leer como copia, o lo hizo un Verbarium más nuevo. Tu progreso no ha cambiado.',
        'Ce fichier ne peut pas être lu comme sauvegarde, ou vient d’un Verbarium plus récent. Ta progression n’a pas changé.',
        'Diese Datei lässt sich nicht als Sicherung lesen oder stammt von einem neueren Verbarium. Dein Fortschritt bleibt unverändert.',
        'Este arquivo não pode ser lido como backup, ou foi feito por um Verbarium mais novo. Seu progresso não mudou.',
      ),
    );
    return;
  }
  final sum = backupSummary(d);
  final yes = await confirm(
    context,
    title: tr(
      'Pulihkan cadangan ini?',
      'Restore this backup?',
      '¿Restaurar esta copia?',
      'Restaurer cette sauvegarde ?',
      'Diese Sicherung wiederherstellen?',
      'Restaurar este backup?',
    ),
    text:
        '${sum.isEmpty ? '' : '$sum\n\n'}${tr('Semua kemajuan di ponsel ini akan diganti isi cadangan. Ini tidak bisa dibatalkan.', 'All progress on this phone will be replaced by the backup. This cannot be undone.', 'Todo el progreso de este teléfono se sustituirá por la copia. No se puede deshacer.', 'Toute la progression de ce téléphone sera remplacée par la sauvegarde. C’est irréversible.', 'Aller Fortschritt auf diesem Handy wird durch die Sicherung ersetzt. Das lässt sich nicht rückgängig machen.', 'Todo o progresso deste celular será substituído pelo backup. Não dá para desfazer.')}',
    yes: tr('Pulihkan', 'Restore', 'Restaurar', 'Restaurer', 'Wiederherstellen', 'Restaurar'),
  );
  if (!yes) return;
  await App.I.restore(d);
}

/// a group of settings on its own card, with its name above it
class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Rise(
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Label(title)),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: pal.field,
                border: Border.all(color: pal.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Label(text));
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: T.body(15, Look.of(context).pal.muted, height: 1.45)),
  );
}

class _Choice extends StatelessWidget {
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onPick;
  const _Choice({required this.options, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final all = options.keys.toList();
    // more than four choices go on rows of three
    final per = all.length > 4 ? 3 : all.length;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.ink, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        children: [
          for (var r = 0; r * per < all.length; r++)
            Container(
              decoration: BoxDecoration(
                border: r == 0 ? null : Border(top: BorderSide(color: pal.ink, width: 1.5)),
              ),
              child: _row(pal, all.skip(r * per).take(per).toList()),
            ),
        ],
      ),
    );
  }

  Widget _row(Pal pal, List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++)
          Expanded(
            child: Press(
              onTap: () => onPick(keys[i]),
              child: Semantics(
                selected: value == keys[i],
                child: AnimatedContainer(
                  duration: Dur.out,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == keys[i] ? pal.ink : Colors.transparent,
                    border: i == 0 ? null : Border(left: BorderSide(color: pal.ink, width: 1.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      options[keys[i]]!,
                      style: T.body(16, value == keys[i] ? pal.bg : pal.ink, w: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Step(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      label: label,
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: onTap == null ? pal.line : pal.ink, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, color: onTap == null ? pal.muted : pal.ink),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.text, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: () => onChanged(!value),
      child: Semantics(
        toggled: value,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Expanded(child: Text(text, style: T.body(17.5, pal.ink))),
              // a small switch drawn in ink: a frame, and a block that slides to the right when on
              AnimatedContainer(
                duration: Dur.out,
                width: 52,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? pal.ink : Colors.transparent,
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Container(width: 20, height: 20, color: value ? pal.bg : pal.ink),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 54,
                child: Text(
                  value
                      ? tr('Nyala', 'On', 'Sí', 'Oui', 'An', 'Ligado')
                      : tr('Mati', 'Off', 'No', 'Non', 'Aus', 'Desligado'),
                  textAlign: TextAlign.right,
                  style: T.body(15, pal.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Link(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pal.line)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: T.body(17.5, pal.ink))),
            Icon(Icons.chevron_right, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

class LicencesPage extends StatelessWidget {
  const LicencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
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
                    'Lisensi huruf',
                    'Font licences',
                    'Licencias de las fuentes',
                    'Licences des polices',
                    'Schriftlizenzen',
                    'Licenças das fontes',
                  ),
                  style: T.display(25, pal.ink),
                ),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: rootBundle.loadString('assets/legal/licenses.txt'),
              builder: (context, snap) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                child: Text(snap.data ?? '', style: T.body(14, pal.ink, height: 1.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What Verbarium does with the learner's data: nothing leaves the phone. Kept in step with docs/privasi.md.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static List<(String, String)> get parts => [
    (
      tr(
        'Yang disimpan',
        'What is kept',
        'Qué se guarda',
        'Ce qui est conservé',
        'Was gespeichert wird',
        'O que é guardado',
      ),
      tr(
        'Kemajuanmu (kata, gelar, kronik, pengaturan) disimpan dalam satu berkas di ponsel ini saja. Tidak ada akun, tidak ada nama, tidak ada email.',
        'Your progress (words, title, chronicle, settings) is kept in one file on this phone only. There is no account, no name, no email.',
        'Tu progreso (palabras, título, crónica, ajustes) se guarda en un solo archivo, solo en este teléfono. No hay cuenta, ni nombre, ni correo.',
        'Ta progression (mots, titre, chronique, réglages) est conservée dans un seul fichier, sur ce téléphone uniquement. Pas de compte, pas de nom, pas d’e-mail.',
        'Dein Fortschritt (Wörter, Titel, Chronik, Einstellungen) liegt in einer einzigen Datei nur auf diesem Handy. Es gibt kein Konto, keinen Namen, keine E-Mail.',
        'Seu progresso (palavras, título, crônica, configurações) fica num único arquivo, só neste celular. Não há conta, nome nem e-mail.',
      ),
    ),
    (
      tr('Yang dikirim', 'What is sent', 'Qué se envía', 'Ce qui est envoyé', 'Was gesendet wird', 'O que é enviado'),
      tr(
        'Tidak ada. Verbarium tidak memakai iklan, analitik, atau pelacak, dan tidak mengirim apa pun ke server.',
        'Nothing. Verbarium has no ads, no analytics and no trackers, and sends nothing to any server.',
        'Nada. Verbarium no tiene anuncios, ni analíticas, ni rastreadores, y no envía nada a ningún servidor.',
        'Rien. Verbarium n’a ni publicité, ni statistiques, ni traceurs, et n’envoie rien à aucun serveur.',
        'Nichts. Verbarium hat keine Werbung, keine Analyse und keine Tracker und sendet nichts an einen Server.',
        'Nada. O Verbarium não tem anúncios, análises nem rastreadores, e não envia nada para nenhum servidor.',
      ),
    ),
    (
      tr('Cadangan', 'Backups', 'Copias de seguridad', 'Sauvegardes', 'Sicherungen', 'Backups'),
      tr(
        'Simpan cadangan menulis satu berkas ke tempat yang kamu pilih sendiri lewat pemilih berkas Android; Verbarium tidak mengirimnya ke mana pun. Cadangan otomatis Android (bila menyala di ponselmu) menyimpan berkas kemajuan ke akun Google-mu sendiri; itu diurus oleh Android, bukan oleh Verbarium, dan bisa dimatikan di pengaturan ponsel.',
        'Save a backup writes one file to a place you choose yourself through Android\'s file picker; Verbarium sends it nowhere. Android\'s own backup (when it is on in your phone) keeps the progress file in your own Google account; that is done by Android, not by Verbarium, and can be turned off in the phone\'s settings.',
        'Guardar una copia escribe un archivo en el lugar que tú eliges con el selector de archivos de Android; Verbarium no lo envía a ningún sitio. La copia automática de Android (si está activada en tu teléfono) guarda el archivo de progreso en tu propia cuenta de Google; eso lo hace Android, no Verbarium, y se puede desactivar en los ajustes del teléfono.',
        'Enregistrer une sauvegarde écrit un fichier à l’endroit que tu choisis toi-même avec le sélecteur de fichiers d’Android ; Verbarium ne l’envoie nulle part. La sauvegarde d’Android (si elle est activée sur ton téléphone) garde le fichier de progression dans ton propre compte Google ; c’est Android qui s’en charge, pas Verbarium, et on peut la désactiver dans les réglages du téléphone.',
        'Sicherung speichern schreibt eine Datei an einen Ort, den du selbst in der Dateiauswahl von Android wählst; Verbarium schickt sie nirgendwohin. Die Android-Sicherung (wenn sie auf deinem Handy an ist) legt die Fortschrittsdatei in deinem eigenen Google-Konto ab; das macht Android, nicht Verbarium, und es lässt sich in den Einstellungen des Handys ausschalten.',
        'Salvar um backup grava um arquivo no lugar que você mesmo escolhe pelo seletor de arquivos do Android; o Verbarium não o envia para lugar nenhum. O backup do próprio Android (se estiver ativado no celular) guarda o arquivo de progresso na sua própria conta Google; isso é feito pelo Android, não pelo Verbarium, e pode ser desligado nas configurações do celular.',
      ),
    ),
    (
      tr(
        'Izin internet',
        'Internet permission',
        'Permiso de internet',
        'Autorisation internet',
        'Internetberechtigung',
        'Permissão de internet',
      ),
      tr(
        'Verbarium meminta izin internet hanya karena Google Play membutuhkannya untuk donasi. Koneksi itu hanya dibuka saat halaman Dukung Verbarium terbuka, dan hanya ke Google Play. Verbarium sendiri tidak mengirim atau mengambil data apa pun.',
        'Verbarium asks for internet access only because Google Play needs it for donations. The connection is opened only while the Support Verbarium page is open, and only to Google Play. Verbarium itself sends and collects nothing.',
        'Verbarium pide acceso a internet solo porque Google Play lo necesita para las donaciones. La conexión solo se abre mientras la página Apoya a Verbarium está abierta, y solo con Google Play. Verbarium por sí mismo no envía ni recoge ningún dato.',
        'Verbarium demande l’accès à internet uniquement parce que Google Play en a besoin pour les dons. La connexion n’est ouverte que pendant que la page Soutenir Verbarium est ouverte, et seulement vers Google Play. Verbarium lui-même n’envoie et ne collecte aucune donnée.',
        'Verbarium fragt nur nach Internetzugang, weil Google Play ihn für Spenden braucht. Die Verbindung wird nur geöffnet, solange die Seite Verbarium unterstützen offen ist, und nur zu Google Play. Verbarium selbst sendet und sammelt nichts.',
        'O Verbarium só pede acesso à internet porque o Google Play precisa dele para doações. A conexão só é aberta enquanto a página Apoiar o Verbarium está aberta, e só com o Google Play. O próprio Verbarium não envia nem coleta nada.',
      ),
    ),
    (
      tr('Dukungan', 'Support', 'Apoyo', 'Soutien', 'Unterstützen', 'Apoio'),
      tr(
        'Untuk versi dari Play Store ada pilihan mendukung Verbarium; pembayarannya diurus sepenuhnya oleh Google Play. Verbarium tidak pernah melihat data pembayaranmu, dan dukungan tidak membuka apa pun: aplikasinya tetap sama untuk semua orang.',
        'The Play Store version offers a way to support Verbarium; the payment is handled entirely by Google Play. Verbarium never sees your payment details, and support unlocks nothing: the app is the same for everyone.',
        'La versión de Play Store ofrece una forma de apoyar a Verbarium; el pago lo gestiona por completo Google Play. Verbarium nunca ve tus datos de pago, y el apoyo no desbloquea nada: la aplicación es igual para todos.',
        'La version du Play Store permet de soutenir Verbarium ; le paiement est entièrement géré par Google Play. Verbarium ne voit jamais tes données de paiement, et le soutien ne débloque rien : l’application est la même pour tous.',
        'Die Version aus dem Play Store bietet eine Möglichkeit, Verbarium zu unterstützen; die Zahlung wickelt allein Google Play ab. Verbarium sieht deine Zahlungsdaten nie, und Unterstützung schaltet nichts frei: Die App ist für alle gleich.',
        'A versão da Play Store oferece um jeito de apoiar o Verbarium; o pagamento é todo feito pelo Google Play. O Verbarium nunca vê seus dados de pagamento, e o apoio não desbloqueia nada: o app é igual para todos.',
      ),
    ),
    (
      tr('Menghapus', 'Erasing', 'Borrar', 'Effacer', 'Löschen', 'Apagar'),
      tr(
        'Hapus semua kemajuan di Pengaturan, atau hapus aplikasinya: berkas itu ikut hilang.',
        'Erase all progress in Settings, or uninstall the app: the file goes with it.',
        'Borra todo el progreso en Ajustes, o desinstala la aplicación: el archivo desaparece con ella.',
        'Efface toute la progression dans les Réglages, ou désinstalle l’application : le fichier disparaît avec elle.',
        'Lösche allen Fortschritt in den Einstellungen oder deinstalliere die App: Die Datei geht mit ihr.',
        'Apague todo o progresso nas Configurações ou desinstale o app: o arquivo vai junto.',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
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
                  tr('Privasi', 'Privacy', 'Privacidad', 'Confidentialité', 'Datenschutz', 'Privacidade'),
                  style: T.display(25, pal.ink),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                for (final (head, body) in parts) ...[_Head(head), Text(body, style: T.body(16, pal.ink, height: 1.5))],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Dukung Verbarium": shown only when Google Play has the donation products (never in the test APK from GitHub)
class _SupportLink extends StatefulWidget {
  const _SupportLink();
  @override
  State<_SupportLink> createState() => _SupportLinkState();
}

class _SupportLinkState extends State<_SupportLink> {
  bool play = false;

  @override
  void initState() {
    super.initState();
    // read on the phone: no connection to Google Play is made until the page is opened
    Native.fromPlay().then((v) {
      if (v && mounted) setState(() => play = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!play) return const SizedBox.shrink();
    return _Link(
      tr(
        'Dukung Verbarium',
        'Support Verbarium',
        'Apoya a Verbarium',
        'Soutenir Verbarium',
        'Verbarium unterstützen',
        'Apoiar o Verbarium',
      ),
      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportPage())),
    );
  }
}

/// Voluntary support through Google Play. It unlocks nothing: Verbarium is the same for everyone.
class SupportPage extends StatefulWidget {
  /// the products, when already known (tests); otherwise the page asks Google Play for them while it is open
  final List<({String id, String price})>? items;
  const SupportPage({this.items, super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool busy = false;
  String? msg; // ok | pending | error
  late List<({String id, String price})>? items = widget.items;
  bool asked = false;

  @override
  void initState() {
    super.initState();
    if (items != null) return;
    Native.donProducts(App.donIds).then((r) {
      if (!mounted) return;
      if (r != null) App.I.donAdd(r.done);
      setState(() {
        asked = true;
        items = r?.items ?? const [];
      });
    });
  }

  @override
  void dispose() {
    if (widget.items == null) Native.donEnd(); // the connection to Google Play lives only as long as this page
    super.dispose();
  }

  Future<void> _buy(String id) async {
    if (busy) return;
    setState(() {
      busy = true;
      msg = null;
    });
    final r = await Native.donBuy(id);
    if (!mounted) return;
    if (r == 'ok') App.I.donAdd(1);
    setState(() {
      busy = false;
      msg = r == 'cancel' ? null : r;
    });
  }

  String _name(String id) => switch (id) {
    'donasi_kecil' => tr(
      'Secangkir teh untuk juru tulis',
      'A cup of tea for the scribe',
      'Una taza de té para el escriba',
      'Une tasse de thé pour le scribe',
      'Eine Tasse Tee für den Schreiber',
      'Uma xícara de chá para o escriba',
    ),
    'donasi_sedang' => tr(
      'Lilin untuk menara',
      'Candles for the tower',
      'Velas para la torre',
      'Des bougies pour la tour',
      'Kerzen für den Turm',
      'Velas para a torre',
    ),
    _ => tr(
      'Tinta untuk Kronik',
      'Ink for the Chronicle',
      'Tinta para la Crónica',
      'De l’encre pour la Chronique',
      'Tinte für die Chronik',
      'Tinta para a Crônica',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final n = App.I.donations;
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
                    'Dukung Verbarium',
                    'Support Verbarium',
                    'Apoya a Verbarium',
                    'Soutenir Verbarium',
                    'Verbarium unterstützen',
                    'Apoiar o Verbarium',
                  ),
                  style: T.display(25, pal.ink),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                Text(
                  tr(
                    'Verbarium gratis untuk semua orang dan akan tetap begitu. Dukungan tidak membuka apa pun; ia membantu kata-kata baru tetap ditulis.',
                    'Verbarium is free for everyone and will stay that way. Support unlocks nothing; it helps new words keep being written.',
                    'Verbarium es gratis para todos y seguirá siéndolo. El apoyo no desbloquea nada; ayuda a que se sigan escribiendo palabras nuevas.',
                    'Verbarium est gratuit pour tous et le restera. Le soutien ne débloque rien ; il aide à continuer d’écrire de nouveaux mots.',
                    'Verbarium ist für alle kostenlos und bleibt es. Unterstützung schaltet nichts frei; sie hilft, dass weiter neue Wörter geschrieben werden.',
                    'O Verbarium é gratuito para todos e vai continuar assim. O apoio não desbloqueia nada; ajuda a continuar escrevendo palavras novas.',
                  ),
                  style: T.body(16, pal.ink, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (items == null)
                  Text(
                    tr(
                      'Menghubungi Google Play…',
                      'Asking Google Play…',
                      'Consultando Google Play…',
                      'Connexion à Google Play…',
                      'Frage Google Play …',
                      'Consultando o Google Play…',
                    ),
                    style: T.body(15, pal.muted, height: 1.5),
                  )
                else if (items!.isEmpty && asked)
                  Text(
                    tr(
                      'Belum tersedia. Coba lagi nanti.',
                      'Not available yet. Try again later.',
                      'Aún no está disponible. Inténtalo más tarde.',
                      'Pas encore disponible. Réessaie plus tard.',
                      'Noch nicht verfügbar. Versuch es später noch einmal.',
                      'Ainda não disponível. Tente de novo mais tarde.',
                    ),
                    style: T.body(15, pal.muted, height: 1.5),
                  ),
                for (final it in items ?? const <({String id, String price})>[]) ...[
                  InkButton('${_name(it.id)} · ${it.price}', outline: true, onTap: busy ? null : () => _buy(it.id)),
                  const SizedBox(height: 10),
                ],
                if (msg != null)
                  Text(switch (msg) {
                    'ok' => tr(
                      'Terima kasih. Tercatat di hati juru tulis.',
                      'Thank you. The scribe will remember.',
                      'Gracias. El escriba lo recordará.',
                      'Merci. Le scribe s’en souviendra.',
                      'Danke. Der Schreiber wird es nicht vergessen.',
                      'Obrigado. O escriba vai se lembrar.',
                    ),
                    'pending' => tr(
                      'Pembayaran sedang diproses oleh Google Play.',
                      'Google Play is still processing the payment.',
                      'Google Play aún está procesando el pago.',
                      'Google Play traite encore le paiement.',
                      'Google Play bearbeitet die Zahlung noch.',
                      'O Google Play ainda está processando o pagamento.',
                    ),
                    _ => tr(
                      'Belum berhasil. Coba lagi nanti.',
                      'That did not go through. Try again later.',
                      'No se pudo completar. Inténtalo más tarde.',
                      'Cela n’a pas abouti. Réessaie plus tard.',
                      'Das hat nicht geklappt. Versuch es später noch einmal.',
                      'Não deu certo. Tente de novo mais tarde.',
                    ),
                  }, style: T.body(15, pal.muted, height: 1.5)),
                if (n > 0)
                  Text(
                    tr(
                      'Kamu sudah mendukung $n kali.',
                      'You have supported Verbarium $n times.',
                      'Has apoyado a Verbarium $n veces.',
                      'Tu as soutenu Verbarium $n fois.',
                      'Du hast Verbarium $n-mal unterstützt.',
                      'Você apoiou o Verbarium $n vezes.',
                    ),
                    style: T.body(15, pal.muted, height: 1.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The coin on Today, left of the settings: opens Dukung Verbarium when the app came from the Play Store; anywhere
/// else it only says where donations can be made (no connection is opened)
class DonateButton extends StatelessWidget {
  const DonateButton({super.key});

  static String get label => tr(
    'Dukung Verbarium',
    'Support Verbarium',
    'Apoya a Verbarium',
    'Soutenir Verbarium',
    'Verbarium unterstützen',
    'Apoiar o Verbarium',
  );

  Future<void> _open(BuildContext context) async {
    final play = await Native.fromPlay();
    if (!context.mounted) return;
    if (play) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportPage()));
      return;
    }
    await notice(
      context,
      title: label,
      text: tr(
        'Donasi hanya bisa lewat Verbarium yang dipasang dari Play Store. Versi ini tetap lengkap dan gratis, dan dukungan memang tidak membuka apa pun.',
        'Donations work only in Verbarium installed from the Play Store. This version is just as complete and free, and support unlocks nothing anyway.',
        'Las donaciones solo funcionan en el Verbarium instalado desde Play Store. Esta versión está igual de completa y es gratis, y el apoyo no desbloquea nada de todos modos.',
        'Les dons ne fonctionnent que dans le Verbarium installé depuis le Play Store. Cette version est tout aussi complète et gratuite, et le soutien ne débloque rien de toute façon.',
        'Spenden gehen nur im Verbarium aus dem Play Store. Diese Version ist genauso vollständig und kostenlos, und Unterstützung schaltet ohnehin nichts frei.',
        'As doações só funcionam no Verbarium instalado pela Play Store. Esta versão é igualmente completa e gratuita, e o apoio não desbloqueia nada mesmo.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: () => _open(context),
      label: label,
      child: SizedBox(width: 44, height: 48, child: Icon(Icons.monetization_on_outlined, color: pal.gold, size: 24)),
    );
  }
}
