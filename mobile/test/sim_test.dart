// Simulated learners: ninety days of sittings with a made-up memory, to see that the scheduler keeps its promises
// for different kinds of people (the fog stays in check, recall stays near 90 %, nobody is buried).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/deck.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/fsrs.dart';

import 'util.dart';

class Learner {
  final String name;

  /// how their true memory compares with what FSRS expects (0.6: forgets faster)
  final double memory;

  /// the chance they open the app on a given day
  final double presence;

  /// the chance a new word's first gap is right
  final double first;
  const Learner(this.name, this.memory, this.presence, this.first);
}

class Outcome {
  int maxDue = 0, reviews = 0, recalled = 0, met = 0, days = 0;
  double get retention => reviews == 0 ? 0 : recalled / reviews;
}

Outcome simulate(Deck deck, Learner l, {int days = 90, int seed = 7}) {
  var now = DateTime(2026, 1, 5, 19).millisecondsSinceEpoch;
  final store = Store(MemoryBackend());
  final e = Engine(store, deck, clock: () => now);
  final rnd = Random(seed);
  final out = Outcome();
  for (var d = 0; d < days; d++) {
    if (rnd.nextDouble() < l.presence) {
      out.days++;
      // one or two sittings a day, like a real learner
      for (var s = 0; s < 1 + rnd.nextInt(2); s++) {
        for (final c in e.sitting()) {
          final m = e.mem(c.w);
          bool right;
          if (m == null || m.reps == 0) {
            right = c.quiz == Quiz.choice || rnd.nextDouble() < l.first;
            if (c.quiz == Quiz.cloze) out.met++;
          } else {
            final p = Fsrs.r((now - m.last) / Engine.day, m.s * l.memory);
            right = rnd.nextDouble() < p;
            if (Engine.studyDay(m.last) != Engine.studyDay(now) && c.quiz == Quiz.cloze) {
              out.reviews++;
              if (right) out.recalled++;
            }
          }
          e.answer(c.w, right ? Grade.clean : Grade.wrong, quiz: c.quiz, ms: 6000);
          now += 20000;
        }
      }
    }
    out.maxDue = max(out.maxDue, e.dueCount);
    now = Engine.studyStart(now) + Engine.day + 15 * 3600000 + rnd.nextInt(5 * 3600000);
  }
  return out;
}

void main() {
  final deck = Deck(coreWords());
  const learners = [
    Learner('steady', 1.0, 0.95, 0.85),
    Learner('forgetful', 0.6, 0.9, 0.7),
    Learner('irregular', 1.0, 0.45, 0.8),
    Learner('strong', 1.6, 0.9, 0.95),
  ];
  final results = {for (final l in learners) l.name: simulate(deck, l)};
  for (final r in results.entries) {
    // ignore: avoid_print
    print('${r.key}: maxDue ${r.value.maxDue}, retention ${r.value.retention.toStringAsFixed(3)}, met ${r.value.met}, days ${r.value.days}, reviews ${r.value.reviews}');
  }

  test('every kind of learner keeps the reviews within reach', () {
    for (final r in results.entries) {
      // a sitting takes 48 reviews at most; the gate stops new words at 100 waiting
      expect(r.value.maxDue, lessThan(220), reason: '${r.key}: the fog never buries them');
    }
  });

  test('recall on reviews stays near the 90 % aimed at for a learner FSRS fits', () {
    expect(results['steady']!.retention, inInclusiveRange(0.82, 0.96));
    expect(results['strong']!.retention, greaterThan(results['forgetful']!.retention));
  });

  test('the ease follows a learner who forgets faster or slower than expected', () {
    expect(results['forgetful']!.retention, greaterThan(0.6), reason: 'the ease shortens their intervals');
  });

  test('a steady learner meets new words at the pace set; an irregular one is not punished for coming back', () {
    expect(results['steady']!.met, greaterThan(700));
    expect(results['irregular']!.met, greaterThan(300));
  });
}
