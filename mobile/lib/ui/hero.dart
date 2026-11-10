/// Karakter: the hero and everything that belongs to them — level, the four figures, gear, the week's quests,
/// feats and the honorary title worn.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import 'pixel.dart';
import 'root.dart';
import 'run.dart' show stageName;
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
    final earned = g.earned;
    final titles = ['', ...Game.feats.where((f) => f.title != null && earned.contains(f.id)).map((f) => f.title!)];
    return TabBody(
      children: [
        const Label('Karakter'),
        const SizedBox(height: 10),
        Rise(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 132,
                height: 150,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: pal.field,
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: HeroSprite(rank: rank, weapon: g.tone('weapon'), shield: g.tone('shield'), cloak: g.tone('cloak'), size: 108),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${rankNames[rank]}${rank < Engine.maxRank ? ' ${stageName(e.stage)}' : ''}', style: T.display(30, pal.ink)),
                    if (g.title.isNotEmpty) Text(g.title, style: T.display(19, pal.muted, italic: true)),
                    const SizedBox(height: 8),
                    Text('Level ${g.level}', style: T.body(17, pal.ink, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Bar(g.levelShare, height: 6),
                    const SizedBox(height: 4),
                    Text('${g.toNext} XP lagi ke level ${g.level + 1}', style: T.body(14.5, pal.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Label('Kemampuan'),
        const SizedBox(height: 6),
        _Figure('Ingatan', g.memory, 'kata kukuh dari ranah yang sudah kamu masuki'),
        _Figure('Ketepatan', g.accuracy, 'jawaban benar dari 100 terakhir'),
        _Figure('Kecepatan', g.speed, 'dari waktu rata-rata mengisi celah'),
        _Figure('Ketekunan', g.diligence, '${g.activeDays14} dari 14 hari terakhir kamu belajar'),
        const SizedBox(height: 22),
        const Label('Perlengkapan'),
        const SizedBox(height: 6),
        for (final slot in const ['weapon', 'shield', 'cloak']) _Slot(slot),
        const SizedBox(height: 22),
        const Label('Quest minggu ini'),
        const SizedBox(height: 4),
        for (final q in g.weekly) QuestRow(q),
        const SizedBox(height: 22),
        if (titles.length > 1) ...[
          const Label('Gelar kehormatan'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in titles)
                Press(
                  onTap: () {
                    g.setTitle(t);
                    App.I.changed();
                  },
                  child: Semantics(
                    selected: g.title == t,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: g.title == t ? pal.ink : Colors.transparent,
                        border: Border.all(color: pal.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(t.isEmpty ? 'Tanpa gelar' : t, style: T.body(15.5, g.title == t ? pal.bg : pal.ink, w: FontWeight.w500)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        Label('Pencapaian · ${earned.length} dari ${Game.feats.length}'),
        const SizedBox(height: 4),
        for (final f in Game.feats)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pal.line)),
            ),
            child: Row(
              children: [
                Icon(earned.contains(f.id) ? Icons.check_circle_outline : Icons.circle_outlined, size: 22, color: earned.contains(f.id) ? pal.good : pal.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: T.body(16.5, earned.contains(f.id) ? pal.ink : pal.muted, w: FontWeight.w500)),
                      Text('${f.text}${f.title == null ? '' : ' · gelar "${f.title}"'}', style: T.body(14.5, pal.muted)),
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
        label: '$name $value dari 100. $note',
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
    final name = const {'weapon': 'Senjata', 'shield': 'Perisai', 'cloak': 'Jubah'}[slot]!;
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
                Text('$name · ${mine.length} dari $all', style: T.body(14.5, pal.muted)),
                Text(worn?.name ?? 'Belum punya', style: T.body(17, worn == null ? pal.muted : pal.ink, w: FontWeight.w500)),
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
              label: 'Ganti $name',
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('Ganti', style: T.body(15.5, pal.ink, w: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
