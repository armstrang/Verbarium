import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/app/lang.dart' as lang;
import 'package:verbarium/data/deck.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/game.dart';
import 'package:verbarium/engine/jobs.dart';

import 'util.dart';

void main() {
  late int now;
  late Store store;
  late Engine e;
  late Game g;
  final d = Deck(coreWords(), Deck.parseCollocs(File('assets/deck/collocations.txt').readAsStringSync()));

  setUp(() {
    lang.english = false;
    now = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;
    store = Store(MemoryBackend());
    e = Engine(store, d, clock: () => now);
    g = Game(store, e);
  });
  tearDown(() => lang.english = false);

  /// crown the learner at [tier] the way a won trial does
  Job crown(int tier, {bool flawless = false}) {
    store.data['rank'] = tier;
    return g.onPromotion(tier, flawless).$1;
  }

  test('the tree: 37 jobs on the map, 6 hidden, every name and id once', () {
    expect(Jobs.visible.length, 37);
    expect(Jobs.secret.length, 6);
    expect(Jobs.all.map((j) => j.id).toSet().length, Jobs.all.length);
    expect(Jobs.all.map((j) => j.name).toSet().length, Jobs.all.length);
    expect([for (var t = 0; t <= 5; t++) Jobs.tier(t).length], [1, 4, 8, 12, 8, 4]);
    for (final j in Jobs.all) {
      expect(j.hint, isNotEmpty);
      expect(j.id == 'peasant' || j.perk.kind != 'none', isTrue, reason: j.id);
      if (j.id != 'peasant') expect(j.perk.text, isNot(contains('Belum ada')), reason: '${j.id} has a perk the app can describe');
    }
  });

  test('every job on the map can be reached by some build, and only through its own branch', () {
    final reached = <String>{'peasant'};
    final builds = [
      for (var a = 0; a < 4; a++)
        for (var b = 0; b < 4; b++)
          if (a != b)
            for (final gap in [40, 2]) Build([for (var i = 0; i < 4; i++) i == a ? 100 : (i == b ? 100 - gap : 10)]),
    ];
    void walk(Job parent, int tier) {
      if (tier > 5) return;
      for (final b in builds) {
        for (final c in builds) {
          final j = Jobs.natural(tier, parent, b, c);
          expect(j.tier, tier);
          expect(j.hidden, isFalse);
          expect(Jobs.children(parent).map((x) => x.id), contains(j.id), reason: '${parent.id} -> ${j.id}');
          if (reached.add(j.id)) walk(j, tier + 1);
        }
      }
    }

    walk(Jobs.byId('peasant'), 1);
    expect(reached, {for (final j in Jobs.visible) j.id});
  });

  test('the build decides the job: nobody picks it', () {
    final w = d.tier(1).first;
    // a careful learner: clean gaps, never fast
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000);
    }
    expect(g.build.top, 0);
    expect(g.heading!.id, 'blade');
    expect(g.nextJobs.map((j) => j.id), ['blade', 'scout', 'scribe', 'sentinel']);
    expect(g.job.id, 'peasant');
    expect(crown(1).id, 'blade');
    expect(g.job.id, 'blade');
    expect(g.build.total, 0, reason: 'the build starts again for the next title');
    expect(g.career.total, greaterThan(0));
    expect(e.events.first['k'], 'job');

    // as a Blade, fast answers lead to the Duelist; the other branch is the Crusader
    expect(g.nextJobs.map((j) => j.id), ['duelist', 'crusader']);
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 3000);
    }
    expect(crown(2).id, 'duelist');
    expect(g.path.map((j) => j.id), ['peasant', 'blade', 'duelist']);
  });

  test('a fast learner becomes a Scout, one with old words a Scribe, one who shows up a Sentinel', () {
    final w = d.tier(1).first;
    for (var i = 0; i < 30; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 2500);
    }
    expect(Jobs.natural(1, g.job, g.build, g.career).id, 'scout');

    store.map('game').remove('bp');
    for (var i = 0; i < 30; i++) {
      g.onAnswer(w, Quiz.choice, Grade.clean, 9000, stab: 20, hadLapses: true);
    }
    expect(Jobs.natural(1, g.job, g.build, g.career).id, 'scribe');

    store.map('game').remove('bp');
    for (var day = 0; day < 12; day++) {
      now += Engine.day;
      g.onAnswer(w, Quiz.cloze, Grade.wrong, 9000, err: 'm');
    }
    expect(Jobs.natural(1, g.job, g.build, g.career).id, 'sentinel');
  });

  test('the perks of the whole path add up, and only touch experience and the guards of the road', () {
    final w = d.tier(1).first;
    final plain = g.onAnswer(w, Quiz.cloze, Grade.clean, 14000).xp;
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000);
    }
    crown(1);
    g.combo = 0;
    expect(g.perk('xpCloze'), 1);
    expect(g.onAnswer(w, Quiz.cloze, Grade.clean, 14000).xp, plain + 1);
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000, stab: 1);
    }
    for (var i = 0; i < 30; i++) {
      now += Engine.day;
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000);
    }
    expect(crown(2).id, 'crusader');
    expect(g.perk('xpCloze'), 1, reason: 'the Blade perk stays');
    expect(g.perk('formXp'), 2);
    // a coronation trial is the same for everyone
    expect(Engine.trialSeconds, 25);
    expect(Engine.trialPass, 26);
  });

  test('a title won before jobs existed gets its path once, and keeps it', () {
    store.data['rank'] = 3;
    final first = g.path.map((j) => j.id).toList();
    expect(first.length, 4);
    expect(first.first, 'peasant');
    expect([for (final id in first) Jobs.byId(id).tier], [0, 1, 2, 3]);
    final again = Game(store, e);
    expect(again.path.map((j) => j.id).toList(), first);
  });

  test('a hidden job is given for a rare way of learning and keeps the branch underneath', () {
    final w = d.tier(1).first;
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000);
    }
    crown(1);
    for (var i = 0; i < 105; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 3000);
    }
    expect(g.bestCombo, greaterThanOrEqualTo(100));
    final job = crown(2);
    expect(job.id, 'berserker');
    expect(job.hidden, isTrue);
    expect(g.branch.id, 'duelist');
    expect(g.nextJobs.map((j) => j.id), ['blademaster', 'spellblade']);
    expect(g.earned, contains('secret'));
    expect(g.known, containsAll(['blade', 'berserker']));
  });

  test('a title lost and won again is decided afresh', () {
    final w = d.tier(1).first;
    for (var i = 0; i < 40; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 14000);
    }
    crown(1);
    store.data['rank'] = 0;
    expect(g.job.id, 'peasant');
    for (var i = 0; i < 60; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 2000);
    }
    expect(crown(1).id, 'scout');
    expect(g.known, containsAll(['blade', 'scout']));
  });

  test('in English everything the game layer says is English, and a word shows its definition', () {
    final q = g.daily.first;
    expect(g.enemy!.name, 'Serigala Hutan');
    final idText = q.text;
    lang.english = true;
    expect(g.enemy!.name, 'Forest Wolf');
    expect(q.text, isNot(idText));
    expect(g.advice().join(' '), isNot(contains('kata')));
    expect(Game.feats.first.name, 'The first step');
    const w = Word('abandon', ['abandon'], 'v', 'meninggalkan', 'They had to ___ the ship.', 2, [], 'to leave something for good');
    expect(w.gloss, 'to leave something for good');
    lang.english = false;
    expect(w.gloss, 'meninggalkan');
    expect(const Word('x', ['x'], 'n', 'arti', '___.', 1).gloss, 'arti');
  });

  test('an honorary title saved as words by an older build is still worn', () {
    store.map('game')['title'] = 'Penakluk';
    expect(g.title, 'Penakluk');
    lang.english = true;
    expect(g.title, 'the Conqueror');
    g.setTitle('streak7');
    expect(g.title, 'the Faithful');
  });

  test('words that look alike come first among the wrong meanings when learning through English', () {
    expect(Engine.looksLike('adapt', 'adopt'), isTrue);
    expect(Engine.looksLike('affect', 'effect'), isTrue);
    expect(Engine.looksLike('river', 'table'), isFalse);
    final w = d.byId['adapt']!;
    final close = e.distractors(w, 3, seed: 5, close: true);
    expect(close.length, 3);
    expect(close.where((x) => Engine.looksLike(w.id, x.id)).length, inInclusiveRange(1, 2));
    expect(close.map((x) => x.id), isNot(contains('adapt')));
  });
}
