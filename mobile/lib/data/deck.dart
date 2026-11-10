/// The words. Core files hold one rank each (`word|pos|meaning|sentence`), banner files (TOEFL, IELTS) carry the
/// rank in front. A word with two spellings is written american/british; both are accepted, and the one shown
/// follows the banner.
library;

import 'package:flutter/services.dart' show rootBundle;

class Word {
  final String id;
  final List<String> forms;
  final String pos;
  final String meaning;
  final String sentence;
  final int tier;
  const Word(this.id, this.forms, this.pos, this.meaning, this.sentence, this.tier);

  String answer(bool british) => british && forms.length > 1 ? forms[1] : forms[0];
  bool accepts(String typed) => forms.contains(typed.trim().toLowerCase());

  /// the sentence before and after the gap
  List<String> get parts {
    final i = sentence.indexOf('___');
    return [sentence.substring(0, i), sentence.substring(i + 3)];
  }
}

class Deck {
  static const coreFiles = ['1-squire', '2-knight', '3-baron', '4-duke', '5-raja'];
  static const tiers = 5;

  final List<Word> words;
  final Map<String, Word> byId;
  final List<List<Word>> _tier;

  Deck(this.words) : byId = {for (final w in words) w.id: w}, _tier = [for (var t = 0; t <= tiers; t++) words.where((w) => w.tier == t).toList()];

  List<Word> tier(int t) => t < 1 || t > tiers ? const [] : _tier[t];

  static List<Word> parse(String text, {int? tier}) {
    final out = <Word>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      var f = line.split('|');
      var t = tier;
      if (t == null) {
        t = int.tryParse(f[0]);
        f = f.sublist(1);
      }
      if (t == null || f.length != 4 || !f[3].contains('___')) continue;
      final forms = f[0].split('/');
      out.add(Word(forms[0], forms, f[1], f[2], f[3], t));
    }
    return out;
  }

  static Future<Deck> load(String banner) async {
    final words = <Word>[];
    for (var i = 0; i < coreFiles.length; i++) {
      words.addAll(parse(await rootBundle.loadString('assets/deck/${coreFiles[i]}.txt'), tier: i + 1));
    }
    final seen = {for (final w in words) w.id};
    for (final w in parse(await rootBundle.loadString('assets/deck/$banner.txt'))) {
      if (seen.add(w.id)) words.add(w);
    }
    return Deck(words);
  }
}
