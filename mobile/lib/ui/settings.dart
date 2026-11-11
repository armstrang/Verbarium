/// Pengaturan: the banner, the daily load, sound, the look, and starting over.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
import '../app/lang.dart';
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
                    label: tr('Kembali', 'Back'),
                    child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
                  ),
                  Expanded(child: Text(tr('Pengaturan', 'Settings'), style: T.display(27, pal.ink))),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
                  children: [
                    _Head(tr('Bahasa belajar', 'Learning language')),
                    _Choice(options: const {'id': 'Indonesia', 'en': 'English'}, value: app.english ? 'en' : 'id', onPick: (v) => app.put('lang', v)),
                    _Note(
                      tr(
                        'Dalam English, arti kata dijelaskan dengan bahasa Inggris yang lebih sederhana dan seluruh aplikasi berbahasa Inggris. Nama gelar dan job selalu bahasa Inggris. Kemajuanmu tetap.',
                        'In English, a word is explained in simpler English and the whole app speaks English. Titles and jobs are English in either language. Your progress stays.',
                      ),
                    ),
                    _Head(tr('Panji', 'Banner')),
                    _Choice(options: const {'toefl': 'TOEFL', 'ielts': 'IELTS'}, value: app.banner, onPick: (v) => app.chooseBanner(v)),
                    _Note(
                      tr(
                        'Mengganti panji mengganti kata tambahan dan ejaan. Kemajuan dan gelarmu tetap.',
                        'Changing the banner changes the extra words and the spelling. Your progress and your title stay.',
                      ),
                    ),
                    _Head(tr('Kata baru tiap hari', 'New words each day')),
                    Row(
                      children: [
                        _Step(Icons.remove, tr('Kurangi', 'Fewer'), app.perDay > 5 ? () => app.put('perDay', app.perDay - 5) : null),
                        Expanded(
                          child: Center(child: Text('${app.perDay}', style: T.display(34, pal.ink))),
                        ),
                        _Step(Icons.add, tr('Tambah', 'More'), app.perDay < 40 ? () => app.put('perDay', app.perDay + 5) : null),
                      ],
                    ),
                    _Note(
                      tr(
                        'Lima belas kata sehari sudah cukup berat. Kata baru hari ini menjadi ulangan besok dan lusa.',
                        'Fifteen words a day is already a fair load. Today\'s new words are tomorrow\'s reviews.',
                      ),
                    ),
                    _Head(tr('Suara', 'Sound')),
                    _Toggle(tr('Musik latar', 'Background music'), app.musicOn, (v) => app.put('music', v ? 1 : 0)),
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
                          label: tr('Keras musik', 'Music volume'),
                          child: Slider(
                            value: app.musicVol.clamp(0.05, 1.0),
                            min: 0.05,
                            max: 1,
                            onChanged: (v) => app.put('musicVol', double.parse(v.toStringAsFixed(2))),
                          ),
                        ),
                      ),
                    _Toggle(tr('Efek suara', 'Sound effects'), app.sfxOn, (v) => app.put('sfx', v ? 1 : 0)),
                    _Head(tr('Tampilan', 'Look')),
                    _Choice(
                      options: {'system': tr('Ikut ponsel', 'Follow phone'), 'light': tr('Kertas', 'Paper'), 'dark': tr('Lilin', 'Candle')},
                      value: app.theme,
                      onPick: (v) => app.put('theme', v),
                    ),
                    const SizedBox(height: 8),
                    _Toggle(tr('Gerak tenang', 'Calm motion'), app.calm, (v) => app.put('calm', v ? 1 : 0)),
                    _Note(
                      tr(
                        'Mengurangi animasi. Pengaturan ponselmu untuk menghilangkan animasi juga diikuti.',
                        'Fewer animations. Your phone\'s own setting for removing animations is honoured too.',
                      ),
                    ),
                    _Head(tr('Tentang', 'About')),
                    _Link(
                      tr('Dari mana rentang skor berasal', 'Where the score ranges come from'),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage())),
                    ),
                    _Link(
                      tr('Lisensi huruf', 'Font licences'),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LicencesPage())),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Verbarium 0.4 (uji coba) · oleh Armstrang\nBekerja tanpa internet. Kemajuanmu hanya ada di ponsel ini.',
                        'Verbarium 0.4 (test build) · by Armstrang\nWorks without internet. Your progress lives only on this phone.',
                      ),
                      style: T.body(15, pal.muted, height: 1.5),
                    ),
                    _Head(tr('Mulai dari awal', 'Start over')),
                    InkButton(
                      tr('Hapus semua kemajuan', 'Erase all progress'),
                      outline: true,
                      onTap: () async {
                        final yes = await confirm(
                          context,
                          title: tr('Hapus semua kemajuan?', 'Erase all progress?'),
                          text: tr(
                            'Gelar, kata yang sudah kukuh dan seluruh kronikmu hilang. Ini tidak bisa dibatalkan.',
                            'Your title, your solid words and your whole chronicle will be gone. This cannot be undone.',
                          ),
                          yes: tr('Hapus', 'Erase'),
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
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Label(text));
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
                      child: Text(options[keys[i]]!, style: T.body(16, value == keys[i] ? pal.bg : pal.ink, w: FontWeight.w700)),
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
                child: Text(value ? tr('Nyala', 'On') : tr('Mati', 'Off'), textAlign: TextAlign.right, style: T.body(15, pal.muted)),
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
                label: tr('Kembali', 'Back'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(child: Text(tr('Lisensi huruf', 'Font licences'), style: T.display(25, pal.ink))),
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
