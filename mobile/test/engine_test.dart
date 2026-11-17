import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/deck.dart';

import 'util.dart';

import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/fsrs.dart';

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
      if (cards[i].quiz == Quiz.cloze) {
        expect(
          cards.sublist(0, i).any((c) => c.w.id == cards[i].w.id),
          isTrue,
          reason: 'the gap follows the introduction',
        );
      }
    }
  });

  /// a new word: its meaning chosen, then its first gap in the same sitting
  void meet(Word w, [Grade g = Grade.clean]) {
    e.answer(w, Grade.clean, quiz: Quiz.choice);
    e.answer(w, g);
  }

  test('a word becomes solid once its stability passes a week; it comes back at the start of its day', () {
    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean, quiz: Quiz.choice);
    expect(e.isNew(w), isTrue, reason: 'met, its first gap still to come');
    e.answer(w, Grade.clean);
    expect(e.isNew(w), isFalse);
    expect(e.mem(w)!.s, closeTo(Fsrs.s0(Fsrs.good), 0.01));
    expect(e.solid(w), isFalse);
    expect(e.dueWords(), isEmpty);
    days(1);
    expect(e.dueWords(), isEmpty);
    days(1);
    expect(e.dueWords(), contains(w), reason: 'due from 04:00 of its day');
    e.answer(w, Grade.clean);
    expect(e.mem(w)!.s, greaterThan(Engine.solidDays));
    expect(e.solid(w), isTrue);
  });

  test('only the first answer of a day moves memory; a miss brings the word back the next day', () {
    final w = e.freshWords(1).single;
    meet(w);
    final s = e.mem(w)!.s;
    for (var i = 0; i < 3; i++) {
      e.answer(w, Grade.clean);
      expect(e.lastCounted, isFalse);
    }
    expect(e.mem(w)!.s, s, reason: 'cramming the same day is practice');
    expect(e.mem(w)!.reps, 1);
    days(20);
    e.answer(w, Grade.clean);
    expect(e.solid(w), isTrue);
    days(40);
    final before = e.mem(w)!.s;
    e.answer(w, Grade.wrong);
    expect(e.solid(w), isFalse);
    expect(e.mem(w)!.lapses, 1);
    expect(e.mem(w)!.s, lessThan(before));
    expect(e.mem(w)!.d, greaterThan(Fsrs.d0(Fsrs.good)), reason: 'a lapse makes the word harder');
    days(e.mem(w)!.s.ceil() + 1);
    expect(e.dueWords(), contains(w));
  });

  test('a quick unaided gap is easy and grows the word more than a slow one', () {
    final a = e.freshWords(2)[0], b = e.freshWords(2)[1];
    meet(a);
    meet(b);
    days(3);
    e.answer(a, Grade.clean, ms: 1500);
    e.answer(b, Grade.clean, ms: 20000);
    expect(e.mem(a)!.s, greaterThan(e.mem(b)!.s));
    expect(Engine.rating(Grade.clean, Quiz.cloze, ms: 1500, first: true), Fsrs.good, reason: 'never easy at first');
  });

  test('intervals spread a little, and never pass the exam day', () {
    final ws = e.freshWords(15);
    for (final w in ws) {
      meet(w);
    }
    days(2);
    for (final w in ws) {
      e.answer(w, Grade.clean);
    }
    final dues = {for (final w in ws) e.mem(w)!.due};
    expect(dues.length, greaterThan(1), reason: 'words learned together are not all due together');
    final exam = DateTime.fromMillisecondsSinceEpoch(now).add(const Duration(days: 30));
    store.map('set')['exam'] =
        '${exam.year}${exam.month.toString().padLeft(2, '0')}${exam.day.toString().padLeft(2, '0')}';
    expect(e.examDays, 30);
    days(10);
    e.answer(ws[0], Grade.clean);
    expect(e.mem(ws[0])!.due, lessThanOrEqualTo(e.examAt!));
  });

  test('new words wait when the reviews pile up, and stop two weeks before the exam', () {
    expect(e.freshToday, 15);
    final ws = e.freshWords(120);
    for (final w in ws.take(60)) {
      meet(w);
    }
    days(30);
    expect(e.dueCount, 60);
    expect(e.freshToday, 7, reason: 'over 50 waiting: half the pace');
    for (final w in ws.skip(60)) {
      store.map('mem')[w.id] = [2.0, now - Engine.day, 1, 0, now - 3 * Engine.day, 1, 5.0];
    }
    e = Engine(store, d, clock: () => now);
    expect(e.dueCount, 120);
    expect(e.freshToday, 0);
    expect(e.gateReason, 'fog');
    store.map('mem').clear();
    e = Engine(store, d, clock: () => now);
    final exam = DateTime.fromMillisecondsSinceEpoch(now).add(const Duration(days: 10));
    store.map('set')['exam'] =
        '${exam.year}${exam.month.toString().padLeft(2, '0')}${exam.day.toString().padLeft(2, '0')}';
    expect(e.raidPrep, isTrue);
    expect(e.freshToday, 0);
    expect(e.gateReason, 'raid');
  });

  test('a memory saved before FSRS is read with a difficulty from its lapses', () {
    final w = d.tier(1).first;
    store.map('mem')[w.id] = [12.0, now + Engine.day, 4, 2, now - 5 * Engine.day, 1];
    e = Engine(store, d, clock: () => now);
    expect(e.mem(w)!.s, 12.0);
    expect(e.mem(w)!.d, Mem.legacyD(2, true));
    expect(e.solid(w), isTrue);
    days(1);
    e.answer(w, Grade.clean);
    expect((store.map('mem')[w.id] as List).length, 7, reason: 'written back with its difficulty');
  });

  test('help keeps a word from counting as solid', () {
    final w = e.freshWords(1).single;
    meet(w);
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

  test('one streak is kept across the kingdoms: a day in Grauwacht carries Aldmere’s streak on', () {
    e.answer(e.freshWords(1).single, Grade.clean);
    days(1);
    final de = Engine(store.realm('de'), d, clock: () => now);
    de.answer(de.freshWords(1).single, Grade.clean);
    days(1);
    e.answer(e.freshWords(1).single, Grade.clean);
    expect(e.streak, 3);
    expect(de.streak, 3);
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
    meet(w);
    store.flush();
    final again = Engine(Store(MemoryBackend((store.backend as MemoryBackend).text)), d, clock: () => now);
    expect(again.seen(w), isTrue);
    expect(again.mem(w)!.s, closeTo(Fsrs.s0(Fsrs.good), 0.01));
    expect(again.dayLog(Engine.dayKey(now))[0], 1);
  });

  test('the gap counts most, building and choosing less; only the gap makes a word solid', () {
    final ws = e.freshWords(3);
    for (final w in ws) {
      meet(w);
    }
    days(4);
    e.answer(ws[0], Grade.clean, quiz: Quiz.cloze);
    e.answer(ws[1], Grade.clean, quiz: Quiz.build);
    e.answer(ws[2], Grade.clean, quiz: Quiz.choice);
    expect(e.mem(ws[0])!.s, greaterThan(e.mem(ws[1])!.s));
    expect(e.mem(ws[1])!.s, closeTo(e.mem(ws[2])!.s, 0.001), reason: 'recognising is at most "hard"');

    final w = e.freshWords(1).single;
    e.answer(w, Grade.clean, quiz: Quiz.choice);
    e.answer(w, Grade.clean, quiz: Quiz.choice);
    expect(e.isNew(w), isTrue, reason: 'a word only chosen has not been rated yet');
    expect(e.dueWords(), contains(w), reason: 'its gap is still owed');
    e.answer(w, Grade.helped);
    for (var i = 0; i < 6; i++) {
      days(9);
      e.answer(w, Grade.clean, quiz: Quiz.choice);
    }
    expect(e.solid(w), isFalse);
    days(9);
    e.answer(w, Grade.clean);
    expect(e.solid(w), isTrue, reason: 'a clean gap');
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
      meet(w);
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

  test('banner words come early among the new words of a rank, one in every two', () {
    final words = coreWords();
    final own = [for (final w in words.where((w) => w.tier == 1).take(6)) w.asBanner()];
    final ids = {for (final w in own) w.id};
    final mixed = Deck([...own, ...words.where((w) => !ids.contains(w.id))], const [], 'ielts');
    final eb = Engine(Store(MemoryBackend()), mixed, clock: () => now);
    final first = eb.sitting().where((c) => c.fresh).map((c) => c.w).take(12).toList();
    expect(first.where((w) => w.banner).length, 6, reason: 'all six banner words are among the first twelve');
    expect(first[0].banner, isTrue);
  });

  test('under the TOEFL banner the build question comes more often', () {
    int builds(String banner) {
      final dk = Deck(coreWords(), const [], banner);
      final en = Engine(Store(MemoryBackend()), dk, clock: () => now);
      var n = 0;
      for (final w in dk.words.where((w) => w.buildable).take(300)) {
        en.answer(w, Grade.clean);
        days(3);
        en.answer(w, Grade.clean);
        if (en.pickQuiz(w) == Quiz.build) n++;
      }
      return n;
    }

    expect(builds('toefl'), greaterThan(builds('ielts')));
  });
}
