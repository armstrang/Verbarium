/// The words. Core files hold one rank each (`word|pos|meaning|sentence`), banner files (TOEFL, IELTS) carry the
/// rank in front. A word with two spellings is written american/british; both are accepted, and the one shown
/// follows the banner.
///
/// Each word also has a plain English definition, kept beside the deck in `assets/deck/en/<same file name>` as
/// `word|definition`. It is what the learner sees when the learning language is English.
library;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../app/lang.dart';

class Word {
  final String id;
  final List<String> forms;
  final String pos;
  final String meaning;
  final String sentence;
  final int tier;

  /// what the gap wants when it is not the headword itself ("increased" for increase); empty = the headword
  final List<String> gap;

  /// the meaning in plain English; empty when none has been written yet
  final String def;

  /// from the banner's own layer (TOEFL or IELTS), not the core: such words come first among a rank's new ones
  final bool banner;
  const Word(
    this.id,
    this.forms,
    this.pos,
    this.meaning,
    this.sentence,
    this.tier, [
    this.gap = const [],
    this.def = '',
    this.banner = false,
  ]);

  Word withDef(String d) => Word(id, forms, pos, meaning, sentence, tier, gap, d, banner);
  Word asBanner() => Word(id, forms, pos, meaning, sentence, tier, gap, def, true);

  /// what the word means, in the language the learner learns through
  String get gloss => glossOf(id, def, meaning);

  bool get inflected => gap.isNotEmpty;
  List<String> get wanted => gap.isEmpty ? forms : gap;
  String answer(bool british) => british && wanted.length > 1 ? wanted[1] : wanted[0];
  bool accepts(String typed) {
    final t = typed.trim().toLowerCase();
    return wanted.any((f) => f.toLowerCase() == t);
  }

  /// the right word in the wrong form: the headword typed where another form is wanted
  bool wrongForm(String typed) {
    final t = typed.trim().toLowerCase();
    return inflected && forms.any((f) => f.toLowerCase() == t);
  }

  /// the sentence in the language the learner learns through (kingdoms of other languages only; empty otherwise)
  String get trans => transOf(id);

  /// the sentence before and after the gap
  List<String> get parts {
    final i = sentence.indexOf('___');
    return [sentence.substring(0, i), sentence.substring(i + 3)];
  }

  /// the whole sentence as chips for "susun kalimat": words, with the full stop kept on the last one
  List<String> tokens(bool british) =>
      sentence.replaceFirst('___', answer(british)).split(' ').where((t) => t.isNotEmpty).toList();
  bool get buildable {
    final n = sentence.split(' ').length;
    return n >= 4 && n <= 10;
  }
}

/// A collocation card: "[make] a decision" with wrong partners to choose from.
class Colloc {
  final int tier;
  final String before, correct, after, meaning, def;
  final List<String> wrong;
  const Colloc(this.tier, this.before, this.correct, this.after, this.wrong, this.meaning, [this.def = '']);
  String get id => 'c:$before$correct$after';
  String get gloss => glossOf(id, def, meaning);
}

/// Spanish, French, German and Portuguese meanings, from `assets/deck/es/`, `fr/`, `de/` and `pt/` (`word|meaning`;
/// for collocations `phrase with [answer]|meaning`), keyed by word id or collocation id: [es, fr, de, pt]
final glosses = <String, List<String>>{};

/// what a word means in the language meanings are shown in ([meaning]): Indonesian meaning, English definition, or
/// the Spanish, French, German or Portuguese meaning (the English definition stands in while one is missing)
String glossOf(String id, String def, String indonesian) {
  final m = meaning;
  final i = fourOf(m);
  if (i >= 0) {
    final g = glosses[id];
    if (g != null && i < g.length && g[i].isNotEmpty) return g[i];
  }
  return m != 'id' && def.isNotEmpty ? def : indonesian;
}

/// The sentence of a kingdom's word in the languages it is learned through, keyed by word id: Indonesian, English,
/// Spanish, French, German, Portuguese (empty where it is the language being learned)
final sentences = <String, List<String>>{};

String transOf(String id) {
  final s = sentences[id];
  if (s == null) return '';
  final m = meaning;
  final t = s[m == 'id' ? 0 : (fourOf(m) < 0 ? 1 : 2 + fourOf(m))];
  return t.isNotEmpty ? t : s[1];
}

/// A kingdom of another language, with its own road from Peasant to King. Aldmere is English (the main deck).
class Kingdom {
  final String code, name, language;
  final int tint, charge;

  /// the letters a phone keyboard may not offer at once, as buttons under the gap
  final List<String> letters;
  const Kingdom(this.code, this.name, this.language, this.tint, this.charge, this.letters);

  static const all = [
    Kingdom('en', 'Aldmere', 'English', 0xFF1F3F73, 0, []),
    Kingdom('de', 'Grauwacht', 'Deutsch', 0xFF5C574D, 1, ['ä', 'ö', 'ü', 'ß']),
    Kingdom('es', 'Valdoro', 'Español', 0xFF8E1B16, 2, ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'ü']),
    Kingdom('fr', 'Beaumarais', 'Français', 0xFF5A2A6B, 3, ['é', 'è', 'ê', 'à', 'ç', 'ô', 'î', 'û', 'ë', 'œ']),
    Kingdom('pt', 'Alvamar', 'Português', 0xFF2F5D3A, 4, ['ã', 'õ', 'á', 'é', 'ê', 'ó', 'ô', 'í', 'ú', 'ç']),
  ];
  static Kingdom of(String code) => all.firstWhere((k) => k.code == code, orElse: () => all[0]);
}

class Deck {
  static const coreFiles = ['1-squire', '2-knight', '3-baron', '4-count', '5-duke', '6-king'];
  static const tiers = 6;

  final List<Word> words;
  final List<Colloc> collocs;
  final Map<String, Word> byId;
  final List<List<Word>> _tier;

  /// 'toefl' or 'ielts'; empty in tests that build a deck by hand
  final String banner;

  Deck(this.words, [this.collocs = const [], this.banner = ''])
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
    // a rank's words may be spread over several files: 1-squire.txt, 1-squire-b.txt, …; 1 Squire … 6 King
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final all = manifest.listAssets();
    final files = all.where((a) => RegExp(r'^assets/deck/[1-6]-[^/]+$').hasMatch(a)).toList()..sort();
    for (final f in files) {
      words.addAll(parse(await rootBundle.loadString(f), tier: int.parse(f.split('/').last[0])));
    }
    final seen = <String>{};
    words.retainWhere((w) => seen.add(w.id));
    for (final w in parse(await rootBundle.loadString('assets/deck/$banner.txt'))) {
      if (seen.add(w.id)) words.add(w.asBanner());
    }
    final defs = <String, String>{};
    for (final f in all.where((a) => a.startsWith('assets/deck/en/'))) {
      defs.addAll(parseDefs(await rootBundle.loadString(f)));
    }
    glosses.clear();
    for (final (i, l) in const [(0, 'es'), (1, 'fr'), (2, 'de'), (3, 'pt')]) {
      for (final f in all.where((a) => a.startsWith('assets/deck/$l/'))) {
        final text = await rootBundle.loadString(f);
        final m = f.endsWith('/collocations.txt')
            ? parseDefs(text).map((k, v) => MapEntry('c:${k.replaceAll('[', '').replaceAll(']', '')}', v))
            : parseDefs(text);
        m.forEach((k, v) => (glosses[k] ??= ['', '', '', ''])[i] = v);
      }
    }
    return Deck(
      [for (final w in words) defs.containsKey(w.id) ? w.withDef(defs[w.id]!) : w],
      parseCollocs(await rootBundle.loadString('assets/deck/collocations.txt')),
      banner,
    );
  }

  /// The deck of a kingdom of another language, from `assets/realm/`: one line per word with every language in it
  /// (`pos|id|en|es|fr|de|pt|` and the sentence in each, the taught form in brackets). A field starting with `~`
  /// only glosses: that language does not teach the word. Files 1-peasant (A1) and 2-squire (A2) both lead to the
  /// Squire, as in Aldmere; the rest follow one title each.
  static Future<Deck> loadRealm(String lang) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest.listAssets().where((a) => RegExp(r'^assets/realm/[1-7]-[^/]+$').hasMatch(a)).toList()
      ..sort();
    final words = <Word>[];
    for (final f in files) {
      final n = int.parse(f.split('/').last[0]);
      words.addAll(parseRealm(await rootBundle.loadString(f), lang, n <= 2 ? 1 : n - 1));
    }
    final seen = <String>{};
    words.retainWhere((w) => seen.add(w.id));
    return Deck(words, const [], '');
  }

  static List<Word> parseRealm(String text, String lang, int tier) {
    const cols = {'es': 3, 'fr': 4, 'de': 5, 'pt': 6};
    final col = cols[lang]!;
    String plain(String s) => s.replaceAll('[', '').replaceAll(']', '').replaceAll('~', '').trim();
    final out = <Word>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final f = line.split('|');
      if (f.length != 13 || f[col].startsWith('~')) continue;
      final sent = f[col + 6];
      final m = RegExp(r'\[([^\]]+)\]').firstMatch(sent);
      if (m == null) continue;
      final id = f[col].trim();
      // every language's sentence and word, but not the one being learned
      String other(int i, String l) => lang == l ? '' : plain(f[i]);
      sentences[id] = [plain(f[7]), plain(f[8]), other(9, 'es'), other(10, 'fr'), other(11, 'de'), other(12, 'pt')];
      glosses[id] = [other(3, 'es'), other(4, 'fr'), other(5, 'de'), other(6, 'pt')];
      out.add(
        Word(
          id,
          [m.group(1)!.trim()],
          f[0],
          plain(f[1]),
          sent.replaceFirst(m.group(0)!, '___'),
          tier,
          const [],
          plain(f[2]),
        ),
      );
    }
    return out;
  }

  /// `word|definition` lines
  static Map<String, String> parseDefs(String text) {
    final out = <String, String>{};
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      final i = line.indexOf('|');
      if (line.isEmpty || line.startsWith('#') || i < 1) continue;
      out[line.substring(0, i).split('/')[0]] = line.substring(i + 1).trim();
    }
    return out;
  }

  /// `tier|[make] a decision|do,take,give|mengambil keputusan[|to decide]`
  static List<Colloc> parseCollocs(String text) {
    final out = <Colloc>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final f = line.split('|');
      final a = f.length >= 4 ? f[1].indexOf('[') : -1, b = f.length >= 4 ? f[1].indexOf(']') : -1;
      final t = int.tryParse(f[0]);
      if (t == null || a < 0 || b < a) continue;
      out.add(
        Colloc(
          t,
          f[1].substring(0, a),
          f[1].substring(a + 1, b),
          f[1].substring(b + 1),
          f[2].split(','),
          f[3],
          f.length > 4 ? f[4] : '',
        ),
      );
    }
    return out;
  }
}
