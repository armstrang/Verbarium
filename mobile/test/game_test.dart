import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/deck.dart';

import 'util.dart';

import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/game.dart';

Deck deck() => Deck(coreWords(), Deck.parseCollocs(File('assets/deck/collocations.txt').readAsStringSync()));

void main() {
  late int now;
  late Store store;
  late Engine e;
  late Game g;
  final d = deck();

  setUp(() {
    now = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;
    store = Store(MemoryBackend());
    e = Engine(store, d, clock: () => now);
    g = Game(store, e);
  });

  test('collocations parse with one right partner and three wrong ones', () {
    expect(d.collocs.length, greaterThan(70));
    for (final c in d.collocs) {
      expect(c.wrong.length, 3, reason: c.id);
      expect(c.wrong.contains(c.correct), isFalse, reason: c.id);
      expect(c.tier, inInclusiveRange(1, Deck.tiers));
    }
  });

  test('experience: the gap pays most, a combo and a fast answer add to it, levels follow', () {
    final w = e.freshWords(1).single;
    expect(g.level, 1);
    final choice = g.onAnswer(w, Quiz.choice, Grade.clean, 3000, fresh: true);
    final cloze = g.onAnswer(w, Quiz.cloze, Grade.clean, 9000);
    final fast = g.onAnswer(w, Quiz.cloze, Grade.clean, 3000);
    expect(choice.xp, 3);
    expect(cloze.xp, 10);
    expect(fast.crit, isTrue);
    expect(fast.xp, greaterThan(cloze.xp));
    expect(g.onAnswer(w, Quiz.cloze, Grade.wrong, 3000, err: 'm').xp, 0);
    expect(g.combo, 0);
    for (var i = 0; i < 10; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.clean, 9000);
    }
    expect(g.level, greaterThan(1));
    expect(g.bestCombo, 10);
    expect(g.earned, contains('first'));
  });

  test('a day has three quests made from what is in front of the learner; rewards are claimed once', () {
    final qs = g.daily;
    expect(qs.length, 3);
    expect(qs.any((q) => q.id == 'new'), isTrue, reason: 'a beginner has new words and nothing to review');
    expect(qs.any((q) => q.id == 'rev'), isFalse);
    final q = qs.firstWhere((q) => q.id == 'new');
    final ws = e.freshWords(q.goal);
    for (final w in ws) {
      e.answer(w, Grade.clean, quiz: Quiz.choice);
      g.onAnswer(w, Quiz.choice, Grade.clean, 2000, fresh: true);
    }
    expect(g.daily.firstWhere((x) => x.id == 'new').done, isTrue);
    final before = g.xp;
    g.claim(g.daily.firstWhere((x) => x.id == 'new'));
    expect(g.xp, before + q.xp);
    g.claim(g.daily.firstWhere((x) => x.id == 'new'));
    expect(g.xp, before + q.xp);

    // survives a restart, and a new day brings new quests
    store.flush();
    final again = Game(store, e);
    expect(again.daily.firstWhere((x) => x.id == 'new').claimed, isTrue);
    now += Engine.day;
    expect(again.daily.every((x) => !x.claimed), isTrue);
  });

  test('every stage has its enemy; a win drops gear that is worn at once', () {
    expect(g.enemy!.name, 'Serigala Hutan');
    expect(g.enemyIsBoss, isFalse);
    expect(g.owned, ['w0']);
    final news = g.onVictory(0, 0, false, false);
    expect(news.any((n) => n.contains('Perisai kayu')), isTrue);
    expect(g.equipped('shield'), 's1');
    expect(g.tone('shield'), 0);
    store.data['stage'] = 2;
    expect(g.enemy!.name, 'Kepala Bandit');
    expect(g.enemyIsBoss, isTrue);
    final boss = g.onVictory(0, 2, true, true);
    expect(boss.any((n) => n.contains('Senjata besi')), isTrue);
    expect(g.earned, containsAll(['boss1', 'perfect']));
    store.data['rank'] = Engine.maxRank;
    expect(g.enemy, isNull);
    for (final row in Game.enemies) {
      expect(row.length, 3);
      expect(row[2].boss, isTrue);
    }
  });

  test('the weakest side is named once there is enough to go on', () {
    expect(g.weakness(), isNull);
    final w = d.tier(1).first;
    for (var i = 0; i < 10; i++) {
      g.onAnswer(w, Quiz.cloze, Grade.helped, 8000, err: 's');
    }
    expect(g.weakness(), contains('Ejaan'));
    expect(g.advice(), isNotEmpty);
    expect(g.winChance(), inInclusiveRange(1, 99));
  });

  test('the figures stay between 0 and 100', () {
    for (final v in [g.memory, g.accuracy, g.speed, g.diligence]) {
      expect(v, inInclusiveRange(0, 100));
    }
    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean);
    g.onAnswer(w, Quiz.cloze, Grade.clean, 4000, fresh: true);
    expect(g.accuracy, 100);
    expect(g.speed, 100);
    expect(g.diligence, greaterThan(0));
  });
}
