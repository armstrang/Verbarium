/// The words. Core files hold one rank each (`word|pos|meaning|sentence`), banner files (TOEFL, IELTS) carry the
/// rank in front. A word with two spellings is written american/british; both are accepted, and the one shown
/// follows the banner.
library;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class Word {
  final String id;
  final List<String> forms;
  final String pos;
  final String meaning;
  final String sentence;
  final int tier;

  /// what the gap wants when it is not the headword itself ("increased" for increase); empty = the headword
  final List<String> gap;
  const Word(this.id, this.forms, this.pos, this.meaning, this.sentence, this.tier, [this.gap = const []]);

  bool get inflected => gap.isNotEmpty;
  List<String> get wanted => gap.isEmpty ? forms : gap;
  String answer(bool british) => british && wanted.length > 1 ? wanted[1] : wanted[0];
  bool accepts(String typed) => wanted.contains(typed.trim().toLowerCase());

  /// the right word in the wrong form: the headword typed where another form is wanted
  bool wrongForm(String typed) => inflected && forms.contains(typed.trim().toLowerCase());

  /// the sentence before and after the gap
  List<String> get parts {
    final i = sentence.indexOf('___');
    return [sentence.substring(0, i), sentence.substring(i + 3)];
  }

  /// the whole sentence as chips for "susun kalimat": words, with the full stop kept on the last one
  List<String> tokens(bool british) => sentence.replaceFirst('___', answer(british)).split(' ').where((t) => t.isNotEmpty).toList();
  bool get buildable {
    final n = sentence.split(' ').length;
    return n >= 4 && n <= 10;
  }
}

/// A collocation card: "[make] a decision" with wrong partners to choose from.
class Colloc {
  final int tier;
  final String before, correct, after, meaning;
  final List<String> wrong;
  const Colloc(this.tier, this.before, this.correct, this.after, this.wrong, this.meaning);
  String get id => 'c:$before$correct$after';
}

class Deck {
  static const coreFiles = ['1-squire', '2-knight', '3-baron', '4-duke', '5-raja'];
  static const tiers = 5;

  final List<Word> words;
  final List<Colloc> collocs;
  final Map<String, Word> byId;
  final List<List<Word>> _tier;

  Deck(this.words, [this.collocs = const []])
    : byId = {for (final w in words) w.id: w},
      _tier = [for (var t = 0; t <= tiers; t++) words.where((w) => w.tier == t).toList()];

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
      if (t == null || f.length < 4 || !f[3].contains('___')) continue;
      final forms = f[0].split('/');
      var gap = const <String>[];
      if (f.length > 4 && f[4].startsWith('=')) gap = f[4].substring(1).split('/');
      out.add(Word(forms[0], forms, f[1], f[2], f[3], t, gap));
    }
    return out;
  }

  static Future<Deck> load(String banner) async {
    final words = <Word>[];
    // a rank's words may be spread over several files: 1-squire.txt, 1-squire-b.txt, …
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest.listAssets().where((a) => a.startsWith('assets/deck/') && RegExp(r'/[1-5]-').hasMatch(a)).toList()..sort();
    for (final f in files) {
      words.addAll(parse(await rootBundle.loadString(f), tier: int.parse(f.split('/').last[0])));
    }
    final seen = <String>{};
    words.retainWhere((w) => seen.add(w.id));
    for (final w in parse(await rootBundle.loadString('assets/deck/$banner.txt'))) {
      if (seen.add(w.id)) words.add(w);
    }
    return Deck(words, parseCollocs(await rootBundle.loadString('assets/deck/collocations.txt')));
  }

  /// `tier|[make] a decision|do,take,give|mengambil keputusan`
  static List<Colloc> parseCollocs(String text) {
    final out = <Colloc>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final f = line.split('|');
      final a = f.length == 4 ? f[1].indexOf('[') : -1, b = f.length == 4 ? f[1].indexOf(']') : -1;
      final t = int.tryParse(f[0]);
      if (t == null || a < 0 || b < a) continue;
      out.add(Colloc(t, f[1].substring(0, a), f[1].substring(a + 1, b), f[1].substring(b + 1), f[2].split(','), f[3]));
    }
    return out;
  }
}
