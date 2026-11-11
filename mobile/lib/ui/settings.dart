/// Pengaturan: the banner, the daily load, sound, the look, and starting over.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
import '../app/lang.dart';
import '../app/native.dart';
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
                    label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                    child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
                  ),
                  Expanded(
                    child: Text(tr('Pengaturan', 'Settings', 'Ajustes', 'Réglages'), style: T.display(27, pal.ink)),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
                  children: [
                    _Head(tr('Bahasa belajar', 'Learning language', 'Idioma de aprendizaje', 'Langue d’apprentissage')),
                    _Choice(
                      options: const {'id': 'Indonesia', 'en': 'English', 'es': 'Español', 'fr': 'Français'},
                      value: app.langCode,
                      onPick: (v) => app.put('lang', v),
                    ),
                    _Note(
                      tr(
                        'Dalam English, arti kata dijelaskan dengan bahasa Inggris yang lebih sederhana dan seluruh aplikasi berbahasa Inggris. Nama gelar dan job selalu bahasa Inggris. Kemajuanmu tetap.',
                        'In English, a word is explained in simpler English and the whole app speaks English. Titles and jobs are English in either language. Your progress stays.',
                        'En español, cada palabra se explica en español y toda la aplicación habla español. Los títulos y oficios quedan en inglés en todos los idiomas. Tu progreso se conserva.',
                        'En français, chaque mot est expliqué en français et toute l’application parle français. Les titres et les métiers restent en anglais dans toutes les langues. Ta progression est conservée.',
                      ),
                    ),
                    _Head(tr('Panji', 'Banner', 'Estandarte', 'Bannière')),
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
                      ),
                    ),
                    _Head(
                      tr(
                        'Kata baru tiap hari',
                        'New words each day',
                        'Palabras nuevas al día',
                        'Nouveaux mots par jour',
                      ),
                    ),
                    Row(
                      children: [
                        _Step(
                          Icons.remove,
                          tr('Kurangi', 'Fewer', 'Menos', 'Moins'),
                          app.perDay > 5 ? () => app.put('perDay', app.perDay - 5) : null,
                        ),
                        Expanded(
                          child: Center(child: Text('${app.perDay}', style: T.display(34, pal.ink))),
                        ),
                        _Step(
                          Icons.add,
                          tr('Tambah', 'More', 'Más', 'Plus'),
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
                      ),
                    ),
                    _Head(tr('Suara', 'Sound', 'Sonido', 'Son')),
                    _Toggle(
                      tr('Musik latar', 'Background music', 'Música de fondo', 'Musique de fond'),
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
                          label: tr('Keras musik', 'Music volume', 'Volumen de la música', 'Volume de la musique'),
                          child: Slider(
                            value: app.musicVol.clamp(0.05, 1.0),
                            min: 0.05,
                            max: 1,
                            onChanged: (v) => app.put('musicVol', double.parse(v.toStringAsFixed(2))),
                          ),
                        ),
                      ),
                    _Toggle(
                      tr('Efek suara', 'Sound effects', 'Efectos de sonido', 'Effets sonores'),
                      app.sfxOn,
                      (v) => app.put('sfx', v ? 1 : 0),
                    ),
                    _Head(tr('Tampilan', 'Look', 'Aspecto', 'Apparence')),
                    _Choice(
                      options: {
                        'system': tr('Ikut ponsel', 'Follow phone', 'Como el teléfono', 'Comme le téléphone'),
                        'light': tr('Kertas', 'Paper', 'Papel', 'Papier'),
                        'dark': tr('Lilin', 'Candle', 'Vela', 'Bougie'),
                      },
                      value: app.theme,
                      onPick: (v) => app.put('theme', v),
                    ),
                    const SizedBox(height: 8),
                    _Toggle(
                      tr('Gerak tenang', 'Calm motion', 'Movimiento sereno', 'Mouvement apaisé'),
                      app.calm,
                      (v) => app.put('calm', v ? 1 : 0),
                    ),
                    _Note(
                      tr(
                        'Mengurangi animasi. Pengaturan ponselmu untuk menghilangkan animasi juga diikuti.',
                        'Fewer animations. Your phone\'s own setting for removing animations is honoured too.',
                        'Menos animaciones. También se respeta el ajuste del teléfono para quitar animaciones.',
                        'Moins d’animations. Le réglage du téléphone qui retire les animations est aussi respecté.',
                      ),
                    ),
                    _Head(tr('Tentang', 'About', 'Acerca de', 'À propos')),
                    _Link(
                      tr(
                        'Dari mana rentang skor berasal',
                        'Where the score ranges come from',
                        'De dónde salen los rangos de nota',
                        'D’où viennent les fourchettes de score',
                      ),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage())),
                    ),
                    _Link(
                      tr('Lisensi huruf', 'Font licences', 'Licencias de las fuentes', 'Licences des polices'),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LicencesPage())),
                    ),
                    _Link(
                      tr(
                        'Lisensi perangkat lunak',
                        'Software licences',
                        'Licencias de software',
                        'Licences des logiciels',
                      ),
                      () => showLicensePage(context: context, applicationName: 'Verbarium', applicationVersion: '0.4'),
                    ),
                    const _SupportLink(),
                    _Link(
                      tr('Privasi', 'Privacy', 'Privacidad', 'Confidentialité'),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage())),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Verbarium 0.4 (uji coba) · oleh Armstrang\nBekerja tanpa internet. Kemajuanmu hanya ada di ponsel ini.\nMusik dimainkan dengan sampel instrumen CC0 dari VSCO 2 CE dan VCSL (Versilian Studios).',
                        'Verbarium 0.4 (test build) · by Armstrang\nWorks without internet. Your progress lives only on this phone.\nThe music is played on CC0 instrument samples from VSCO 2 CE and VCSL (Versilian Studios).',
                        'Verbarium 0.4 (versión de prueba) · por Armstrang\nFunciona sin internet. Tu progreso vive solo en este teléfono.\nLa música se toca con muestras de instrumentos CC0 de VSCO 2 CE y VCSL (Versilian Studios).',
                        'Verbarium 0.4 (version de test) · par Armstrang\nFonctionne sans internet. Ta progression ne vit que sur ce téléphone.\nLa musique est jouée avec des échantillons d’instruments CC0 de VSCO 2 CE et VCSL (Versilian Studios).',
                      ),
                      style: T.body(15, pal.muted, height: 1.5),
                    ),
                    _Head(tr('Mulai dari awal', 'Start over', 'Empezar de cero', 'Tout recommencer')),
                    InkButton(
                      tr(
                        'Hapus semua kemajuan',
                        'Erase all progress',
                        'Borrar todo el progreso',
                        'Effacer toute la progression',
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
                          ),
                          text: tr(
                            'Gelar, kata yang sudah kukuh dan seluruh kronikmu hilang. Ini tidak bisa dibatalkan.',
                            'Your title, your solid words and your whole chronicle will be gone. This cannot be undone.',
                            'Tu título, tus palabras firmes y toda tu crónica desaparecerán. No se puede deshacer.',
                            'Ton titre, tes mots ancrés et toute ta chronique disparaîtront. C’est irréversible.',
                          ),
                          yes: tr('Hapus', 'Erase', 'Borrar', 'Effacer'),
                        );
                        if (yes) await app.resetProgress();
                      },
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
    final keys = options.keys.toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.ink, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
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
      ),
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
                  value ? tr('Nyala', 'On', 'Sí', 'Oui') : tr('Mati', 'Off', 'No', 'Non'),
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
                label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(
                  tr('Lisensi huruf', 'Font licences', 'Licencias de las fuentes', 'Licences des polices'),
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
      tr('Yang disimpan', 'What is kept', 'Qué se guarda', 'Ce qui est conservé'),
      tr(
        'Kemajuanmu (kata, gelar, kronik, pengaturan) disimpan dalam satu berkas di ponsel ini saja. Tidak ada akun, tidak ada nama, tidak ada email.',
        'Your progress (words, title, chronicle, settings) is kept in one file on this phone only. There is no account, no name, no email.',
        'Tu progreso (palabras, título, crónica, ajustes) se guarda en un solo archivo, solo en este teléfono. No hay cuenta, ni nombre, ni correo.',
        'Ta progression (mots, titre, chronique, réglages) est conservée dans un seul fichier, sur ce téléphone uniquement. Pas de compte, pas de nom, pas d’e-mail.',
      ),
    ),
    (
      tr('Yang dikirim', 'What is sent', 'Qué se envía', 'Ce qui est envoyé'),
      tr(
        'Tidak ada. Verbarium tidak memakai iklan, analitik, atau pelacak, dan tidak mengirim apa pun ke server.',
        'Nothing. Verbarium has no ads, no analytics and no trackers, and sends nothing to any server.',
        'Nada. Verbarium no tiene anuncios, ni analíticas, ni rastreadores, y no envía nada a ningún servidor.',
        'Rien. Verbarium n’a ni publicité, ni statistiques, ni traceurs, et n’envoie rien à aucun serveur.',
      ),
    ),
    (
      tr('Dukungan', 'Support', 'Apoyo', 'Soutien'),
      tr(
        'Jika suatu saat ada pilihan untuk mendukung Verbarium, pembayarannya diurus sepenuhnya oleh Google Play. Verbarium tidak pernah melihat data pembayaranmu, dan dukungan tidak membuka apa pun: aplikasinya tetap sama untuk semua orang.',
        'If there is ever a way to support Verbarium, the payment is handled entirely by Google Play. Verbarium never sees your payment details, and support unlocks nothing: the app is the same for everyone.',
        'Si algún día hay una forma de apoyar a Verbarium, el pago lo gestiona por completo Google Play. Verbarium nunca ve tus datos de pago, y el apoyo no desbloquea nada: la aplicación es igual para todos.',
        'Si un jour il est possible de soutenir Verbarium, le paiement est entièrement géré par Google Play. Verbarium ne voit jamais tes données de paiement, et le soutien ne débloque rien : l’application est la même pour tous.',
      ),
    ),
    (
      tr('Menghapus', 'Erasing', 'Borrar', 'Effacer'),
      tr(
        'Hapus semua kemajuan di Pengaturan, atau hapus aplikasinya: berkas itu ikut hilang.',
        'Erase all progress in Settings, or uninstall the app: the file goes with it.',
        'Borra todo el progreso en Ajustes, o desinstala la aplicación: el archivo desaparece con ella.',
        'Efface toute la progression dans les Réglages, ou désinstalle l’application : le fichier disparaît avec elle.',
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
                label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(tr('Privasi', 'Privacy', 'Privacidad', 'Confidentialité'), style: T.display(25, pal.ink)),
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
  List<({String id, String price})>? items;

  @override
  void initState() {
    super.initState();
    Native.donProducts(App.donIds).then((r) {
      if (r == null || !mounted) return;
      App.I.donAdd(r.done);
      setState(() => items = r.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final it = items;
    if (it == null || it.isEmpty) return const SizedBox.shrink();
    return _Link(
      tr('Dukung Verbarium', 'Support Verbarium', 'Apoya a Verbarium', 'Soutenir Verbarium'),
      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SupportPage(it))),
    );
  }
}

/// Voluntary support through Google Play. It unlocks nothing: Verbarium is the same for everyone.
class SupportPage extends StatefulWidget {
  final List<({String id, String price})> items;
  const SupportPage(this.items, {super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool busy = false;
  String? msg; // ok | pending | error

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
    ),
    'donasi_sedang' => tr(
      'Lilin untuk menara',
      'Candles for the tower',
      'Velas para la torre',
      'Des bougies pour la tour',
    ),
    _ => tr('Tinta untuk Kronik', 'Ink for the Chronicle', 'Tinta para la Crónica', 'De l’encre pour la Chronique'),
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
                label: tr('Kembali', 'Back', 'Volver', 'Retour'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(
                  tr('Dukung Verbarium', 'Support Verbarium', 'Apoya a Verbarium', 'Soutenir Verbarium'),
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
                  ),
                  style: T.body(16, pal.ink, height: 1.5),
                ),
                const SizedBox(height: 16),
                for (final it in widget.items) ...[
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
                    ),
                    'pending' => tr(
                      'Pembayaran sedang diproses oleh Google Play.',
                      'Google Play is still processing the payment.',
                      'Google Play aún está procesando el pago.',
                      'Google Play traite encore le paiement.',
                    ),
                    _ => tr(
                      'Belum berhasil. Coba lagi nanti.',
                      'That did not go through. Try again later.',
                      'No se pudo completar. Inténtalo más tarde.',
                      'Cela n’a pas abouti. Réessaie plus tard.',
                    ),
                  }, style: T.body(15, pal.muted, height: 1.5)),
                if (n > 0)
                  Text(
                    tr(
                      'Kamu sudah mendukung $n kali.',
                      'You have supported Verbarium $n times.',
                      'Has apoyado a Verbarium $n veces.',
                      'Tu as soutenu Verbarium $n fois.',
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
