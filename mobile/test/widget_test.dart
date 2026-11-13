// The practice widget on the home screen: today's questions, and its answers read back into memory, XP and the streak.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/app/home_widget.dart';
import 'package:verbarium/data/deck.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/game.dart';

import 'util.dart';

void main() {
  final d = Deck(coreWords(), Deck.parseCollocs(File('assets/deck/collocations.txt').readAsStringSync()));
  late int now;
  late Store store;
  late Engine e;
  late Game g;
  final en = Kingdom.of('en');

  setUp(() {
    now = DateTime(2026, 11, 13, 9).millisecondsSinceEpoch;
    store = Store(MemoryBackend());
    e = Engine(store, d, clock: () => now);
    g = Game(store, e);
  });

  void meet(Iterable<Word> ws) {
    for (final w in ws) {
      e.answer(w, Grade.clean);
    }
  }

  test('nothing to ask before any word is met', () {
    final deck = HomeWidget.deckFor(e, d, en, '20261113');
    expect(deck['items'], isEmpty);
    expect((deck['say'] as Map)['empty'], isNotEmpty);
  });

  test('today’s questions: words already met, sentences only, four words of the same kind, the answer among them', () {
    meet(d.tier(1).take(8));
    meet(d.tier(3).take(8));
    final deck = HomeWidget.deckFor(e, d, en, '20261113');
    final items = (deck['items'] as List).cast<Map<String, dynamic>>();
    expect(items.length, HomeWidget.perDay);
    for (final it in items) {
      final opts = (it['opt'] as List).cast<String>();
      expect(opts.length, 4);
      expect(opts.toSet().length, 4);
      expect(opts, contains(it['ans']));
      final w = d.words.firstWhere((x) => x.id == it['id']);
      expect(it['show'], w.tier <= 1, reason: 'the meaning shows from the start below B1 only');
      expect('${it['a']} ${it['ans']} ${it['b']}'.contains('___'), isFalse);
    }
    expect(json.decode(json.encode(deck)), deck, reason: 'the widget reads it as plain JSON');
  });

  test('answers count lightly for memory, 1–5 XP when right, and ten a day keep the streak', () {
    final ws = d.tier(3).take(10).toList();
    meet(ws);
    final before = e.mem(ws[0])!.s;
    now += 3 * Engine.day;
    final xp0 = g.xp;
    final answers = [
      for (var i = 0; i < 10; i++) {'k': 'en', 'id': ws[i].id, 'ok': i != 1, 't': now - 60000 * (10 - i)},
      {'k': 'de', 'id': 'haus', 'ok': true, 't': now},
    ];
    final got = HomeWidget.applyTo(root: store, realm: 'en', deck: d, engine: e, game: g, answers: answers);
    expect(got, 9 * HomeWidget.xpFor(ws[0]));
    expect(g.xp - xp0, got);
    expect(HomeWidget.xpFor(ws[0]), inInclusiveRange(1, 5));
    expect(e.mem(ws[0])!.s, greaterThan(before), reason: 'a right answer helps the memory');
    expect(e.mem(ws[0])!.s, lessThan(before * 2), reason: 'but less than typing it would');
    expect(e.mem(ws[1])!.lapses, 1, reason: 'a wrong one counts as a lapse');
    expect((store.map('set')['wd'] as Map)[Engine.dayKey(now)], 11, reason: 'every kingdom counts for the streak');
    expect(e.streak, greaterThanOrEqualTo(1), reason: 'ten answers in the widget keep the day');
  });

  test('fewer than ten widget answers do not keep a day', () {
    store.map('set')['wd'] = {Engine.dayKey(now): 9};
    expect(e.streak, 0);
    store.map('set')['wd'] = {Engine.dayKey(now): 10};
    expect(e.streak, 1);
  });

  test('lines the widget wrote that cannot be read are skipped', () {
    final got = HomeWidget.parseAnswers('{"k":"en","id":"x","ok":true,"t":1}\nnot json\n{"k":"en"}\n\n');
    expect(got.length, 1);
  });
}
