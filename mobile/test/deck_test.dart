import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/app/lang.dart' as lang;
import 'package:verbarium/data/deck.dart';

import 'util.dart';

import 'package:verbarium/engine/engine.dart';

List<Word> core() => coreWords();

void main() {
  formsAndChips();
  test('every core word parses, is unique and fits its own gap', () {
    final words = core();
    expect(words.length, greaterThan(1000));
    expect({for (final w in words) w.id}.length, words.length);
    for (final w in words) {
      expect(w.parts.length, 2, reason: w.id);
      expect(w.accepts(w.answer(false)), isTrue, reason: w.id);
      expect(w.accepts(' ${w.answer(true).toUpperCase()} '), isTrue, reason: w.id);
      expect(w.meaning.trim(), isNotEmpty, reason: w.id);
    }
    for (var t = 1; t <= 5; t++) {
      expect(words.where((w) => w.tier == t).length, greaterThan(Engine.trialSize * 3), reason: 'tier $t');
    }
  });

  test('banner files carry their rank and add to the core without clashing', () {
    final ids = {for (final w in core()) w.id};
    for (final b in ['toefl', 'ielts']) {
      final extra = Deck.parse(File('assets/deck/$b.txt').readAsStringSync());
      expect(extra.length, greaterThan(450), reason: b);
      for (final w in extra) {
        expect(w.tier, inInclusiveRange(1, 5), reason: w.id);
        expect(ids.contains(w.id), isFalse, reason: '${w.id} is already in the core');
      }
    }
  });

  test('the deck holds more than 6,000 words and every one has a plain English definition', () {
    final defs = <String, String>{};
    for (final f in Directory('assets/deck/en').listSync().whereType<File>().where((f) => f.path.endsWith('.txt'))) {
      defs.addAll(Deck.parseDefs(f.readAsStringSync()));
    }
    final all = [
      ...core(),
      for (final b in ['toefl', 'ielts']) ...Deck.parse(File('assets/deck/$b.txt').readAsStringSync()),
    ];
    expect(all.length, greaterThan(6000));
    for (final w in all) {
      final d = defs[w.id];
      expect(d, isNotNull, reason: '${w.id} has no definition');
      expect(d!.length, greaterThan(2), reason: w.id);
      for (final form in w.forms) {
        expect(RegExp('\\b$form\\b', caseSensitive: false).hasMatch(d), isFalse, reason: 'the definition of ${w.id} uses the word itself');
      }
    }
    for (final c in Deck.parseCollocs(File('assets/deck/collocations.txt').readAsStringSync())) {
      expect(c.def, isNotEmpty, reason: c.id);
      expect(RegExp('\\b${c.correct}\\b').hasMatch(c.def), isFalse, reason: '${c.id}: the English meaning gives the answer away');
    }
  });

  test('two spellings: both accepted, the banner decides which is shown', () {
    final w = core().firstWhere((w) => w.id == 'organize');
    expect(w.answer(false), 'organize');
    expect(w.answer(true), 'organise');
    expect(w.accepts('organise'), isTrue);
    expect(w.accepts('organize'), isTrue);
  });

  test('a slip is one letter off; short words get no second chance', () {
    expect(slip('consensus', 'consensus'), 0);
    expect(slip('consenus', 'consensus'), 1);
    expect(slip('consenssus', 'consensus'), 1);
    expect(slip('consensys', 'consensus'), 1);
    expect(slip('conesnsus', 'consensus'), 1);
    expect(slip('consent', 'consensus'), 2);
    expect(slip('aim', 'air'), 2);
  });
}

// appended: forms and chips
void formsAndChips() {
  test('a gap can ask for another form of the word; the headword then counts as the right word in the wrong form', () {
    final w = Deck.parse('increase|v|menaikkan|The company has ___ its prices.|=increased', tier: 2).single;
    expect(w.inflected, isTrue);
    expect(w.answer(false), 'increased');
    expect(w.accepts('increased'), isTrue);
    expect(w.accepts('increase'), isFalse);
    expect(w.wrongForm('increase'), isTrue);
    expect(w.tokens(false).join(' '), 'The company has increased its prices.');
    expect(w.buildable, isTrue);
  });

  test('every word and collocation has a Spanish and a French meaning, and the gloss follows the language', () {
    final all = [
      ...core(),
      for (final b in ['toefl', 'ielts']) ...Deck.parse(File('assets/deck/$b.txt').readAsStringSync()),
    ];
    final collocs = Deck.parseCollocs(File('assets/deck/collocations.txt').readAsStringSync());
    for (final l in ['es', 'fr']) {
      final m = <String, String>{};
      for (final f in Directory('assets/deck/$l').listSync().whereType<File>().where((f) => f.path.endsWith('.txt') && !f.path.endsWith('collocations.txt'))) {
        m.addAll(Deck.parseDefs(f.readAsStringSync()));
      }
      for (final w in all) {
        expect(m[w.id] ?? '', isNotEmpty, reason: '$l: ${w.id}');
      }
      final c = Deck.parseDefs(File('assets/deck/$l/collocations.txt').readAsStringSync());
      for (final x in collocs) {
        expect(c['${x.before}[${x.correct}]${x.after}'] ?? '', isNotEmpty, reason: '$l: ${x.id}');
      }
    }
    glosses['tide'] = ['marea', 'marée'];
    const w = Word('tide', ['tide'], 'n', 'pasang surut', 'The ___ came in.', 1, [], 'the rise and fall of the sea');
    for (final (code, want) in const [('id', 'pasang surut'), ('en', 'the rise and fall of the sea'), ('es', 'marea'), ('fr', 'marée')]) {
      lang.code = code;
      expect(w.gloss, want, reason: code);
    }
    lang.code = 'id';
    glosses.remove('tide');
  });
}
