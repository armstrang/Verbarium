/// The learning engine: spaced repetition on typed answers, the daily plan, the ranks and their trials.
/// Pure Dart on top of the [Store]; the clock is passed in, so tests can move time.
///
/// Memory: each word has a stability in days. A clean answer (typed right, no help) multiplies it, a helped answer
/// barely moves it, a wrong answer cuts it to a quarter and brings the word back within minutes. A word is *kukuh*
/// (solid) once its stability reaches a week and its last answer was clean.
///
/// Ranks: 0 Peasant, then one rank per deck tier (1 Squire, 2 Knight, 3 Baron, 4 Count, 5 Duke, 6 King), each one
/// CEFR level (docs/riset-skor.md). Only trials change the rank. The coronation
/// trial of a tier opens when 80 % of its words are solid; it asks 30 of them against the clock, without help, and
/// passes at 26. A rank already held wavers when recent reviews of its words fall under 60 %; it is then kept by a
/// short defence trial, or lost after seven days.
library;

import 'dart:math';

import '../data/deck.dart';
import '../data/store.dart';

enum Grade { clean, helped, wrong }

/// The three kinds of question. The gap (cloze) is the main one and the only one that can make a word solid;
/// building the sentence counts for less, choosing the meaning for least.
enum Quiz { cloze, build, choice }

const quizWeight = {Quiz.cloze: 1.0, Quiz.build: 0.6, Quiz.choice: 0.3};

/// one question of a sitting
class Card {
  final Word w;
  final Quiz quiz;
  final bool fresh;
  const Card(this.w, this.quiz, this.fresh);
}

class Mem {
  double s;
  int due;
  int reps;
  int lapses;
  int last;
  bool clean;
  Mem(this.s, this.due, this.reps, this.lapses, this.last, this.clean);

  static Mem? from(Object? v) {
    if (v is! List || v.length < 6) return null;
    return Mem(
      (v[0] as num).toDouble(),
      (v[1] as num).toInt(),
      (v[2] as num).toInt(),
      (v[3] as num).toInt(),
      (v[4] as num).toInt(),
      v[5] == 1,
    );
  }

  List<Object> toJson() => [double.parse(s.toStringAsFixed(3)), due, reps, lapses, last, clean ? 1 : 0];
}

class TierStat {
  final int total, seen, solid;
  const TierStat(this.total, this.seen, this.solid);
  double get share => total == 0 ? 0 : solid / total;
}

class Plan {
  final int reviews, fresh, doneToday;
  const Plan(this.reviews, this.fresh, this.doneToday);
  bool get empty => reviews == 0 && fresh == 0;
}

class RankInfo {
  final String title;
  final String cefr;
  final String ielts;
  final String toefl;
  final String toeflOld;
  const RankInfo(this.title, this.cefr, this.ielts, this.toefl, this.toeflOld);
}

class Engine {
  static const day = 86400000;
  static const solidDays = 7.0;
  static const openShare = 0.8;
  static const trialSize = 30;
  static const trialPass = 26;
  static const defenceSize = 15;
  static const defencePass = 12;
  static const placementPerTier = 8;
  static const placementPass = 6;
  static const placementTop = 3;
  static const trialSeconds = 25;

  /// below half its life a boss rages: this many seconds fewer per word, for the rest of the fight
  static const rageCut = 5;
  static const maxRank = 6;

  /// Score ranges per rank, from the test owners' own CEFR alignments (docs/riset-skor.md).
  static const ranks = [
    RankInfo('Peasant', 'A1', '–', '–', '–'),
    RankInfo('Squire', 'A2', '<4.0', '<3', '<42'),
    RankInfo('Knight', 'B1', '4.0–5.0', '3–3.5', '42–71'),
    RankInfo('Baron', 'B2', '5.5–6.5', '4–4.5', '72–94'),
    RankInfo('Count', 'C1', '7.0', '5', '95–106'),
    RankInfo('Duke', 'C1', '7.5–8.0', '5.5', '107–113'),
    RankInfo('King', 'C2', '8.5–9.0', '6', '114–120'),
  ];

  final Store store;
  final Deck deck;
  final int Function() now;
  final Map<String, Mem> _mem = {};
  final List<List<Word>> _order = [];

  Engine(this.store, this.deck, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    store.map('mem').forEach((k, v) {
      final m = Mem.from(v);
      if (m != null && deck.byId.containsKey(k)) _mem[k] = m;
    });
    // new words arrive in a fixed shuffled order, not alphabetically; the banner's own words come early, one in
    // every two, until they run out
    for (var t = 0; t <= Deck.tiers; t++) {
      final l = List<Word>.of(deck.tier(t))..shuffle(Random(1215 + t));
      final own = l.where((w) => w.banner).toList(), core = l.where((w) => !w.banner).toList();
      final mixed = <Word>[];
      for (var i = 0; i < max(own.length, core.length); i++) {
        if (i < own.length) mixed.add(own[i]);
        if (i < core.length) mixed.add(core[i]);
      }
      _order.add(mixed);
    }
  }

  // ---------------------------------------------------------------- memory

  Mem? mem(Word w) => _mem[w.id];
  bool seen(Word w) => _mem.containsKey(w.id);
  bool solid(Word w) {
    final m = _mem[w.id];
    return m != null && m.clean && m.s >= solidDays;
  }

  void _put(Word w, Mem m) {
    _mem[w.id] = m;
    store.map('mem')[w.id] = m.toJson();
    store.touch();
  }

  /// How fast memory grows for this learner: 1 is the starting point; it rises when on-time reviews are nearly
  /// always right (the intervals were too short) and falls when too many are missed.
  double get ease => ((store.data['ease'] as num?)?.toDouble() ?? 1.0).clamp(0.7, 1.3);

  void _tune(bool right) {
    final r = store.list('ret');
    r.add(right ? 1 : 0);
    if (r.length > 60) r.removeRange(0, r.length - 60);
    if (r.length >= 30 && r.length % 10 == 0) {
      final rate = r.where((x) => x == 1).length / r.length;
      if (rate > 0.93) store.data['ease'] = min(1.3, ease + 0.05);
      if (rate < 0.8) store.data['ease'] = max(0.7, ease - 0.05);
    }
  }

  /// Records one answer. [count] = false keeps it out of the daily log (placement).
  void answer(Word w, Grade g, {bool count = true, Quiz quiz = Quiz.cloze}) {
    final t = now();
    final old = _mem[w.id];
    final fresh = old == null;
    final m = old ?? Mem(0, t, 0, 0, t, false);
    final elapsed = (t - m.last) / day;
    final weight = quizWeight[quiz]!;
    final onTime = elapsed >= m.s * 0.5;
    switch (g) {
      case Grade.clean:
        if (fresh) {
          m.s = quiz == Quiz.cloze ? 3 : (quiz == Quiz.build ? 2 : 0.003);
        } else {
          final grow = onTime ? 1 + 1.3 * weight * ease : 1 + 0.3 * weight;
          m.s = min(365, max(quiz == Quiz.choice ? m.s : 1.0, m.s) * grow);
        }
        if (quiz == Quiz.cloze) m.clean = true;
      case Grade.helped:
        m.s = fresh ? (quiz == Quiz.cloze ? 1 : 0.003) : max(quiz == Quiz.cloze ? 1.0 : m.s, m.s * 1.1);
        m.clean = false;
      case Grade.wrong:
        m.s = fresh ? 0.01 : max(0.01, m.s * (quiz == Quiz.cloze ? 0.25 : (quiz == Quiz.build ? 0.5 : 0.6)));
        m.clean = false;
        if (!fresh) m.lapses++;
    }
    m.reps++;
    m.last = t;
    m.due = t + (m.s * day).round();
    _put(w, m);
    if (count) _log(fresh, g != Grade.wrong);
    if (!fresh && onTime && quiz == Quiz.cloze && count) _tune(g != Grade.wrong);
    if (!fresh && w.tier <= rank && rank > 0) _window(g != Grade.wrong);
  }

  /// what kind of slip a word last suffered: 'm' meaning, 's' spelling, 'f' form, 'o' order (see Game)
  String lastError(Word w) => store.map('er')[w.id] as String? ?? '';

  /// Which question a word gets now. A new word is introduced by choosing its meaning (the gap follows in the
  /// same sitting); after that the gap is the rule, with the other two mixed in where they help.
  Quiz pickQuiz(Word w) {
    final m = _mem[w.id];
    if (m == null) return Quiz.choice;
    final h = (w.id.codeUnits.fold<int>(0, (a, b) => a * 31 + b) + m.reps * 7) & 0x7fffffff;
    final err = lastError(w);
    if (err == 'm' && m.s < 2) return Quiz.choice;
    if (err == 'o' && w.buildable) return Quiz.build;
    // the TOEFL has a build-a-sentence task, so under its banner the build comes more often
    if (w.buildable && m.s >= 2 && h % (deck.banner == 'toefl' ? 3 : 5) == 0) return Quiz.build;
    if (m.s < 1 && h % 4 == 0) return Quiz.choice;
    return Quiz.cloze;
  }

  /// Wrong meanings to offer beside the right one: same part of speech, and the stronger the learner, the closer.
  /// With [close] (learning through English) words that look like the right one come first, at most two of them:
  /// telling "adapt" from "adopt" by their definitions is the point of the monolingual way.
  List<Word> distractors(Word w, int n, {int? seed, bool close = false}) {
    final r = Random(seed ?? now());
    final hard = (_mem[w.id]?.s ?? 0) >= 4;
    final pool = deck.tier(w.tier).where((x) => x.id != w.id && x.meaning != w.meaning && x.gloss != w.gloss).toList()
      ..shuffle(r);
    pool.sort((a, b) {
      int score(Word x) => (x.pos == w.pos ? 0 : 2) + (hard && x.id[0] != w.id[0] ? 1 : 0);
      return score(a).compareTo(score(b));
    });
    if (!close) return pool.take(n).toList();
    final alike = pool.where((x) => looksLike(w.id, x.id)).take(2).toList();
    return [...alike, ...pool.where((x) => !alike.contains(x)).take(n - alike.length)];
  }

  /// two words easily taken for each other: one slip apart, or the same first or last four letters
  static bool looksLike(String a, String b) {
    if (a.length < 5 || b.length < 5) return false;
    if ((a.length - b.length).abs() <= 1 && slip(a, b) == 1) return true;
    return a.substring(0, 4) == b.substring(0, 4) || a.substring(a.length - 4) == b.substring(b.length - 4);
  }

  // ---------------------------------------------------------------- daily log

  static String dayKey(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  List<int> dayLog(String key) {
    final v = store.map('log')[key];
    if (v is List && v.length >= 4) return [for (final x in v) (x as num).toInt()];
    return [0, 0, 0, 0];
  }

  void _log(bool fresh, bool right) {
    final key = dayKey(now());
    final l = dayLog(key);
    if (fresh) {
      l[0]++;
    } else {
      l[1]++;
    }
    if (right) {
      l[2]++;
    } else {
      l[3]++;
    }
    store.map('log')[key] = l;
    store.touch();
  }

  /// days in a row with at least one answer, counting today or yesterday as the latest
  int get streak {
    var n = 0;
    var d = DateTime.fromMillisecondsSinceEpoch(now());
    bool active(DateTime x) {
      final l = dayLog(dayKey(x.millisecondsSinceEpoch));
      return l[0] + l[1] > 0;
    }

    if (!active(d)) d = d.subtract(const Duration(days: 1));
    while (active(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------------------------------------------------------------- settings the engine needs

  int get perDay => (store.map('set')['perDay'] as num?)?.toInt() ?? 15;
  int get rank => store.integer('rank').clamp(0, maxRank);

  /// the tier being learned: the one above the rank held
  int get learning => min(rank + 1, Deck.tiers);

  TierStat stat(int tier) {
    var seenN = 0, solidN = 0;
    final l = deck.tier(tier);
    for (final w in l) {
      if (seen(w)) seenN++;
      if (solid(w)) solidN++;
    }
    return TierStat(l.length, seenN, solidN);
  }

  int get solidTotal => deck.words.where(solid).length;
  int get seenTotal => _mem.length;

  // ---------------------------------------------------------------- the plan and a sitting

  List<Word> dueWords() {
    final t = now();
    final l = [
      for (final w in deck.words)
        if ((_mem[w.id]?.due ?? t + 1) <= t) w,
    ];
    l.sort((a, b) => _mem[a.id]!.due.compareTo(_mem[b.id]!.due));
    return l;
  }

  List<Word> freshWords(int limit) {
    if (limit <= 0 || rank >= maxRank) return const [];
    final out = <Word>[];
    for (final w in _order[learning]) {
      if (!seen(w)) {
        out.add(w);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  Plan plan() {
    final today = dayLog(dayKey(now()));
    final left = max(0, perDay - today[0]);
    return Plan(dueWords().length, freshWords(left).length, today[0] + today[1]);
  }

  /// today's sitting: reviews first, a new word after every third one. A new word is met by choosing its meaning
  /// and returns a few cards later as a gap. At most 70 cards.
  List<Card> sitting({int extraFresh = 0}) {
    final today = dayLog(dayKey(now()));
    final reviews = dueWords().take(48).toList();
    final fresh = freshWords(max(0, perDay - today[0]) + extraFresh);
    final out = <Card>[];
    final later = <int, Word>{};
    var r = 0, f = 0;
    void add(Card c) {
      out.add(c);
      final w = later.remove(out.length);
      if (w != null) out.add(Card(w, Quiz.cloze, false));
    }

    while (r < reviews.length || f < fresh.length) {
      for (var i = 0; i < 3 && r < reviews.length; i++) {
        final w = reviews[r++];
        add(Card(w, pickQuiz(w), false));
      }
      if (f < fresh.length) {
        final w = fresh[f++];
        add(Card(w, Quiz.choice, true));
        later[out.length + 3] = w;
      }
      if (out.length >= 70) break;
    }
    for (final w in later.values) {
      out.add(Card(w, Quiz.cloze, false));
    }
    return out;
  }

  // ---------------------------------------------------------------- trials

  int get cooldownUntil => store.integer('cool');
  bool get cooling => cooldownUntil > now();

  /// the coronation trial for the next rank is open
  bool get trialOpen => rank < maxRank && !cooling && stage >= 2 && stat(rank + 1).share >= openShare;

  // -- the three stages inside a rank (I, II, III) and their sub-bosses

  static const stageShare = [0.27, 0.54];
  static const subSize = 12;
  static const subPass = 10;

  /// 0, 1, 2 = I, II, III on the way to the next rank
  int get stage => store.integer('stage').clamp(0, 2);
  int get subCooldown => store.integer('subcool');

  /// the sub-boss guarding the next stage can be fought
  bool get subOpen => rank < maxRank && stage < 2 && subCooldown <= now() && stat(rank + 1).share >= stageShare[stage];

  /// words for a sub-boss: the ones already met in the tier being learned
  List<Word> subWords() {
    final l = deck.tier(learning).where(seen).toList()..shuffle(Random(now()));
    return l.take(subSize).toList();
  }

  bool finishSub(int right, int total) {
    final pass = right >= subPass;
    if (pass) {
      store.set('stage', stage + 1);
      _event('sub', rank, right, total);
    } else {
      store.set('subcool', now() + 4 * 3600000);
      _event('subfail', rank, right, total);
    }
    return pass;
  }

  List<Word> trialWords(int tier, int size) {
    final l = List<Word>.of(deck.tier(tier))..shuffle(Random(now()));
    return l.take(size).toList();
  }

  /// a line for the chronicle from outside the engine (a new job)
  void note(String kind, int r, {Map<String, Object> extra = const {}}) => _event(kind, r, 0, 0, extra);

  void _event(String kind, int r, int a, int b, [Map<String, Object> extra = const {}]) {
    final ev = store.list('ev');
    ev.add({'t': now(), 'k': kind, 'r': r, 'a': a, 'b': b, ...extra});
    if (ev.length > 200) ev.removeRange(0, ev.length - 200);
    store.touch();
  }

  List<Map<String, dynamic>> get events => [
    for (final e in store.list('ev').reversed)
      if (e is Map<String, dynamic>) e,
  ];

  /// The result of a coronation trial for [tier]. Returns true when the learner is crowned.
  bool finishTrial(int tier, int right, int total) {
    final pass = right >= (total * trialPass / trialSize).ceil();
    if (pass) {
      store.set('rank', tier);
      store.set('stage', 0);
      store.set('cool', 0);
      store.set('shaky', 0);
      store.set('win', <int>[]);
      _event('crown', tier, right, total);
    } else {
      store.set('cool', now() + 20 * 3600000);
      _event('fail', tier, right, total);
    }
    return pass;
  }

  // -- placement: tiers 1..3, eight words each, stop at the first tier failed

  List<Word> placementWords(int tier) => trialWords(tier, placementPerTier);

  /// Sets the rank after placement: [passed] tiers were passed. Their unseen words count as known for now and
  /// come back for review over the next weeks, so the title still has to be kept.
  void finishPlacement(int passed, int right, int total) {
    final r = Random(now());
    for (var t = 1; t <= passed; t++) {
      for (final w in deck.tier(t)) {
        if (seen(w)) continue;
        final t0 = now();
        _put(w, Mem(10, t0 + ((2 + r.nextInt(38)) * day), 1, 0, t0, true));
      }
    }
    store.set('rank', passed);
    store.set('stage', 0);
    store.set('placed', 1);
    _event('place', passed, right, total);
  }

  bool get placed => store.integer('placed') == 1;

  // -- keeping a title

  void _window(bool right) {
    final w = store.list('win');
    w.add(right ? 1 : 0);
    if (w.length > 40) w.removeRange(0, w.length - 40);
    if (shakySince == 0 && w.length >= 30) {
      final ok = w.where((x) => x == 1).length;
      if (ok / w.length < 0.6) store.set('shaky', now());
    }
    store.touch();
  }

  int get shakySince => store.integer('shaky');
  bool get shaky => shakySince > 0 && rank > 0;
  int get shakyDaysLeft => max(0, 7 - ((now() - shakySince) / day).floor());

  /// Called when the app opens: a wavering title that was not defended in seven days is lost.
  bool checkDemotion() {
    if (!shaky || now() - shakySince < 7 * day) return false;
    final r = rank - 1;
    store.set('rank', r);
    store.set('stage', 2);
    store.set('shaky', 0);
    store.set('win', <int>[]);
    _event('drop', r, 0, 0);
    return true;
  }

  bool finishDefence(int right, int total) {
    final pass = right >= (total * defencePass / defenceSize).ceil();
    if (pass) {
      store.set('shaky', 0);
      store.set('win', <int>[]);
      _event('hold', rank, right, total);
    } else {
      _event('holdfail', rank, right, total);
    }
    return pass;
  }

  /// start again from nothing in this kingdom (Settings); the other kingdoms keep their road
  void reset() {
    _mem.clear();
    final set = store.map('set');
    final realms = store.data['realms'];
    store.data
      ..clear()
      ..['v'] = Store.schema
      ..['set'] = set;
    if (realms != null) store.data['realms'] = realms;
    store.flush();
  }
}

/// how close a typed answer is: 0 exact, 1 one slip (a letter missing, extra, wrong or two swapped), 2 further
int slip(String typed, String answer) {
  final a = typed.trim().toLowerCase(), b = answer.toLowerCase();
  if (a == b) return 0;
  if ((a.length - b.length).abs() > 1 || b.length < 5) return 2;
  if (a.length == b.length) {
    final diff = [
      for (var i = 0; i < a.length; i++)
        if (a[i] != b[i]) i,
    ];
    if (diff.length == 1) return 1;
    if (diff.length == 2 && diff[1] == diff[0] + 1 && a[diff[0]] == b[diff[1]] && a[diff[1]] == b[diff[0]]) return 1;
    return 2;
  }
  final long = a.length > b.length ? a : b, short = a.length > b.length ? b : a;
  for (var i = 0; i < long.length; i++) {
    if (long.substring(0, i) + long.substring(i + 1) == short) return 1;
  }
  return 2;
}
