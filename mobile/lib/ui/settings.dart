/// Pengaturan: the banner, the daily load, sound, the look, and starting over.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
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
                    label: 'Kembali',
                    child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
                  ),
                  Expanded(child: Text('Pengaturan', style: T.display(27, pal.ink))),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
                  children: [
                    const _Head('Panji'),
                    _Choice(options: const {'toefl': 'TOEFL', 'ielts': 'IELTS'}, value: app.banner, onPick: (v) => app.chooseBanner(v)),
                    const _Note('Mengganti panji mengganti kata tambahan dan ejaan. Kemajuanmu tetap.'),
                    const _Head('Kata baru tiap hari'),
                    Row(
                      children: [
                        _Step(Icons.remove, 'Kurangi', app.perDay > 5 ? () => app.put('perDay', app.perDay - 5) : null),
                        Expanded(
                          child: Center(child: Text('${app.perDay}', style: T.display(34, pal.ink))),
                        ),
                        _Step(Icons.add, 'Tambah', app.perDay < 40 ? () => app.put('perDay', app.perDay + 5) : null),
                      ],
                    ),
                    const _Note('Lima belas kata sehari sudah cukup berat. Kata baru hari ini menjadi ulangan besok dan lusa.'),
                    const _Head('Suara'),
                    _Toggle('Musik latar', app.musicOn, (v) => app.put('music', v ? 1 : 0)),
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
                          label: 'Keras musik',
                          child: Slider(
                            value: app.musicVol.clamp(0.05, 1.0),
                            min: 0.05,
                            max: 1,
                            onChanged: (v) => app.put('musicVol', double.parse(v.toStringAsFixed(2))),
                          ),
                        ),
                      ),
                    _Toggle('Efek suara', app.sfxOn, (v) => app.put('sfx', v ? 1 : 0)),
                    const _Head('Tampilan'),
                    _Choice(options: const {'system': 'Ikut ponsel', 'light': 'Kertas', 'dark': 'Lilin'}, value: app.theme, onPick: (v) => app.put('theme', v)),
                    const SizedBox(height: 8),
                    _Toggle('Gerak tenang', app.calm, (v) => app.put('calm', v ? 1 : 0)),
                    const _Note('Mengurangi animasi. Pengaturan ponselmu untuk menghilangkan animasi juga diikuti.'),
                    const _Head('Tentang'),
                    _Link('Dari mana rentang skor berasal', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesPage()))),
                    _Link('Lisensi huruf', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LicencesPage()))),
                    const SizedBox(height: 8),
                    Text(
                      'Verbarium 0.1 (uji coba) · oleh Armstrang\nBekerja tanpa internet. Kemajuanmu hanya ada di ponsel ini.',
                      style: T.body(15, pal.muted, height: 1.5),
                    ),
                    const _Head('Mulai dari awal'),
                    InkButton(
                      'Hapus semua kemajuan',
                      outline: true,
                      onTap: () async {
                        final yes = await confirm(
                          context,
                          title: 'Hapus semua kemajuan?',
                          text: 'Gelar, kata yang sudah kukuh dan seluruh kronikmu hilang. Ini tidak bisa dibatalkan.',
                          yes: 'Hapus',
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
                child: Text(value ? 'Nyala' : 'Mati', textAlign: TextAlign.right, style: T.body(15, pal.muted)),
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
                label: 'Kembali',
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(child: Text('Lisensi huruf', style: T.display(25, pal.ink))),
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
