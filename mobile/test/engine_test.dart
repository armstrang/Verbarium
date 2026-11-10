import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/deck.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';

Deck deck() =>
    Deck([for (var i = 0; i < Deck.coreFiles.length; i++) ...Deck.parse(File('assets/deck/${Deck.coreFiles[i]}.txt').readAsStringSync(), tier: i + 1)]);

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
    expect(e.sitting().length, 15);
    expect(e.sitting().every((w) => w.tier == 1), isTrue);
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
    for (final w in e.sitting()) {
      e.answer(w, Grade.clean);
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
}
