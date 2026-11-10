import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/deck.dart';

import 'util.dart';

import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';

Deck deck() => Deck(coreWords());

void main() {
  late int now;
  late Store store;
  late Engine e;
  final d = deck();

  setUp(() {
    now = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;
    store = Store(MemoryBackend());
    e = Engine(store, d, clock: () => now);
  });

  void days(num n) => now += (n * Engine.day).round();

  test('a new learner is a Petani with a day of new words and nothing to review', () {
    expect(e.rank, 0);
    final p = e.plan();
    expect(p.reviews, 0);
    expect(p.fresh, 15);
    final cards = e.sitting();
    expect(cards.length, 30, reason: 'each new word is met by choosing its meaning, then comes back as a gap');
    expect(cards.where((c) => c.quiz == Quiz.choice && c.fresh).length, 15);
    expect(cards.where((c) => c.quiz == Quiz.cloze).length, 15);
    expect(cards.every((c) => c.w.tier == 1), isTrue);
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].quiz == Quiz.cloze) expect(cards.sublist(0, i).any((c) => c.w.id == cards[i].w.id), isTrue, reason: 'the gap follows the introduction');
    }
  });

  test('a word becomes solid after clean answers spread over more than a week', () {
    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean);
    expect(e.solid(w), isFalse);
    expect(e.dueWords(), isEmpty);
    days(3.1);
    expect(e.dueWords(), contains(w));
    e.answer(w, Grade.clean);
    expect(e.solid(w), isFalse, reason: '6.9 days is not a week yet');
    days(7);
    e.answer(w, Grade.clean);
    expect(e.solid(w), isTrue);
  });

  test('cramming does not make a word solid, and a miss brings it back within the hour', () {
    final w = e.freshWords(1).single;
    for (var i = 0; i < 3; i++) {
      e.answer(w, Grade.clean);
    }
    expect(e.solid(w), isFalse);
    days(20);
    e.answer(w, Grade.clean);
    expect(e.solid(w), isTrue);
    e.answer(w, Grade.wrong);
    expect(e.solid(w), isFalse);
    expect(e.mem(w)!.lapses, 1);
    days(8);
    expect(e.dueWords(), contains(w));
  });

  test('help keeps a word from counting as solid', () {
    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean);
    days(4);
    e.answer(w, Grade.clean);
    days(8);
    e.answer(w, Grade.helped);
    expect(e.solid(w), isFalse);
  });

  test('the daily limit holds, and the log and streak follow the days', () {
    for (final c in e.sitting()) {
      e.answer(c.w, Grade.clean, quiz: c.quiz);
    }
    expect(e.plan().fresh, 0);
    expect(e.streak, 1);
    days(1);
    expect(e.plan().fresh, 15);
    e.answer(e.freshWords(1).single, Grade.wrong);
    expect(e.streak, 2);
    days(2);
    expect(e.streak, 0);
  });

  test('the coronation trial opens at 80 % solid, crowns at 26 of 30 and cools down after a failure', () {
    final tier1 = d.tier(1);
    final need = (tier1.length * Engine.openShare).ceil();
    for (final w in tier1.take(need - 1)) {
      store.map('mem')[w.id] = [10.0, now + 5 * Engine.day, 3, 0, now, 1];
    }
    store.data['stage'] = 2;
    e = Engine(store, d, clock: () => now);
    expect(e.trialOpen, isFalse);
    store.map('mem')[tier1[need - 1].id] = [10.0, now + 5 * Engine.day, 3, 0, now, 1];
    e = Engine(store, d, clock: () => now);
    expect(e.trialOpen, isTrue);
    expect(e.trialWords(1, Engine.trialSize).length, 30);

    expect(e.finishTrial(1, 25, 30), isFalse);
    expect(e.rank, 0);
    expect(e.trialOpen, isFalse, reason: 'cooling down');
    days(1);
    expect(e.trialOpen, isTrue);
    expect(e.finishTrial(1, 26, 30), isTrue);
    expect(e.rank, 1);
    expect(e.stage, 0, reason: 'a new title starts at stage I');
    expect(e.events.first['k'], 'crown');
    expect(e.learning, 2);
    expect(e.freshWords(3).every((w) => w.tier == 2), isTrue);
  });

  test('placement sets the rank and spreads the skipped words over the coming weeks', () {
    e.finishPlacement(2, 14, 20);
    expect(e.rank, 2);
    expect(e.placed, isTrue);
    expect(e.stat(1).seen, d.tier(1).length);
    expect(e.dueWords(), isEmpty);
    days(41);
    expect(e.dueWords().length, d.tier(1).length + d.tier(2).length);
  });

  test('a title wavers when its reviews go badly and is lost if not defended in seven days', () {
    e.finishPlacement(1, 8, 8);
    days(45);
    final due = e.dueWords();
    for (final w in due.take(30)) {
      e.answer(w, Grade.wrong);
    }
    expect(e.shaky, isTrue);
    expect(e.checkDemotion(), isFalse);
    days(3);
    expect(e.shakyDaysLeft, 4);
    expect(e.finishDefence(11, 15), isFalse);
    expect(e.shaky, isTrue);
    expect(e.finishDefence(12, 15), isTrue);
    expect(e.shaky, isFalse);

    for (final w in e.dueWords().take(40)) {
      e.answer(w, Grade.wrong);
    }
    expect(e.shaky, isTrue);
    days(7.1);
    expect(e.checkDemotion(), isTrue);
    expect(e.rank, 0);
    expect(e.events.first['k'], 'drop');
  });

  test('progress survives a restart', () {
    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean);
    store.flush();
    final again = Engine(Store(MemoryBackend((store.backend as MemoryBackend).text)), d, clock: () => now);
    expect(again.seen(w), isTrue);
    expect(again.mem(w)!.s, 3);
    expect(again.dayLog(Engine.dayKey(now))[0], 1);
  });

  test('the gap counts most, building less, choosing least; only the gap makes a word solid', () {
    final ws = e.freshWords(3);
    for (final w in ws) {
      e.answer(w, Grade.clean);
    }
    days(4);
    e.answer(ws[0], Grade.clean, quiz: Quiz.cloze);
    e.answer(ws[1], Grade.clean, quiz: Quiz.build);
    e.answer(ws[2], Grade.clean, quiz: Quiz.choice);
    expect(e.mem(ws[0])!.s, greaterThan(e.mem(ws[1])!.s));
    expect(e.mem(ws[1])!.s, greaterThan(e.mem(ws[2])!.s));

    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean, quiz: Quiz.choice);
    expect(e.dueWords(), isEmpty);
    now += 10 * 60000;
    expect(e.dueWords(), contains(w), reason: 'a word only chosen comes back within minutes');
    for (var i = 0; i < 6; i++) {
      days(9);
      e.answer(w, Grade.clean, quiz: Quiz.choice);
    }
    expect(e.solid(w), isFalse);
    for (final gap in [9, 3, 6]) {
      days(gap);
      e.answer(w, Grade.clean);
    }
    expect(e.solid(w), isTrue, reason: 'three gaps over more than a week');
  });

  test('three stages to a title: two sub-bosses, then the boss', () {
    final tier1 = d.tier(1);
    void solidUpTo(double share) {
      for (final w in tier1.take((tier1.length * share).ceil())) {
        store.map('mem')[w.id] = [10.0, now + 5 * Engine.day, 3, 0, now, 1];
      }
      e = Engine(store, d, clock: () => now);
    }

    expect(e.subOpen, isFalse);
    solidUpTo(0.27);
    expect(e.subOpen, isTrue);
    expect(e.subWords().length, Engine.subSize);
    expect(e.finishSub(9, 12), isFalse);
    expect(e.subOpen, isFalse, reason: 'four hours to recover');
    now += 4 * 3600000 + 1;
    expect(e.finishSub(10, 12), isTrue);
    expect(e.stage, 1);
    expect(e.subOpen, isFalse, reason: 'the second one waits for 54 %');
    solidUpTo(0.85);
    expect(e.trialOpen, isFalse, reason: 'the boss waits behind the second sub-boss');
    expect(e.finishSub(12, 12), isTrue);
    expect(e.stage, 2);
    expect(e.trialOpen, isTrue);
  });

  test('memory growth tunes itself to the learner', () {
    expect(e.ease, 1.0);
    final ws = e.freshWords(40);
    for (final w in ws) {
      e.answer(w, Grade.clean);
    }
    days(4);
    for (final w in ws) {
      e.answer(w, Grade.clean);
    }
    expect(e.ease, greaterThan(1.0), reason: 'everything remembered: the gaps were too short');
    final strong = e.ease;
    for (var round = 0; round < 3; round++) {
      days(30);
      for (final w in ws) {
        e.answer(w, Grade.wrong);
      }
    }
    expect(e.ease, lessThan(strong));
  });
}
