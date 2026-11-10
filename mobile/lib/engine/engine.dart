/// The learning engine: spaced repetition on typed answers, the daily plan, the ranks and their trials.
/// Pure Dart on top of the [Store]; the clock is passed in, so tests can move time.
///
/// Memory: each word has a stability in days. A clean answer (typed right, no help) multiplies it, a helped answer
/// barely moves it, a wrong answer cuts it to a quarter and brings the word back within minutes. A word is *kukuh*
/// (solid) once its stability reaches a week and its last answer was clean.
///
/// Ranks: 0 Petani, then one rank per deck tier (1 Squire … 5 Raja). Only trials change the rank. The coronation
/// trial of a tier opens when 80 % of its words are solid; it asks 30 of them against the clock, without help, and
/// passes at 26. A rank already held wavers when recent reviews of its words fall under 60 %; it is then kept by a
/// short defence trial, or lost after seven days.
library;

import 'dart:math';

import '../data/deck.dart';
import '../data/store.dart';

enum Grade { clean, helped, wrong }

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
    return Mem((v[0] as num).toDouble(), (v[1] as num).toInt(), (v[2] as num).toInt(), (v[3] as num).toInt(), (v[4] as num).toInt(), v[5] == 1);
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
  static const maxRank = 5;

  /// Score ranges per rank, from the test owners' own CEFR alignments (docs/riset-skor.md).
  static const ranks = [
    RankInfo('Petani', 'A2', 'di bawah 4.0', 'di bawah 3', 'di bawah 42'),
    RankInfo('Squire', 'B1', '4.0–5.0', '3–3.5', '42–71'),
    RankInfo('Knight', 'B2', '5.5–6.5', '4–4.5', '72–94'),
    RankInfo('Baron', 'C1', '7.0', '5', '95–106'),
    RankInfo('Duke', 'C1', '7.5–8.0', '5.5', '107–113'),
    RankInfo('Raja', 'C2', '8.5–9.0', '6', '114–120'),
  ];

  final Store store;
  final Deck deck;
  final int Function() now;
  final Map<String, Mem> _mem = {};
  final List<List<Word>> _order = [];

  Engine(this.store, this.deck, {int Function()? clock}) : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    store.map('mem').forEach((k, v) {
      final m = Mem.from(v);
      if (m != null && deck.byId.containsKey(k)) _mem[k] = m;
    });
    // new words arrive in a fixed shuffled order, not alphabetically
    for (var t = 0; t <= Deck.tiers; t++) {
      final l = List<Word>.of(deck.tier(t))..shuffle(Random(1215 + t));
      _order.add(l);
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

  /// Records one answer. [count] = false keeps it out of the daily log (placement).
  void answer(Word w, Grade g, {bool count = true}) {
    final t = now();
    final old = _mem[w.id];
    final fresh = old == null;
    final m = old ?? Mem(0, t, 0, 0, t, false);
    final elapsed = (t - m.last) / day;
    switch (g) {
      case Grade.clean:
        if (fresh) {
          m.s = 3;
        } else {
          final onTime = elapsed >= m.s * 0.5;
          m.s = min(365, max(1.0, m.s) * (onTime ? 2.3 : 1.3));
        }
        m.clean = true;
      case Grade.helped:
        m.s = fresh ? 1 : max(1.0, m.s * 1.1);
        m.clean = false;
      case Grade.wrong:
        m.s = fresh ? 0.01 : max(0.01, m.s * 0.25);
        m.clean = false;
        if (!fresh) m.lapses++;
    }
    m.reps++;
    m.last = t;
    m.due = t + (m.s * day).round();
    _put(w, m);
    if (count) _log(fresh, g != Grade.wrong);
    if (!fresh && w.tier <= rank && rank > 0) _window(g != Grade.wrong);
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

  /// today's sitting: reviews first, a new word after every third one. At most 60 items.
  List<Word> sitting({int extraFresh = 0}) {
    final today = dayLog(dayKey(now()));
    final reviews = dueWords().take(48).toList();
    final fresh = freshWords(max(0, perDay - today[0]) + extraFresh);
    final out = <Word>[];
    var r = 0, f = 0;
    while (r < reviews.length || f < fresh.length) {
      for (var i = 0; i < 3 && r < reviews.length; i++) {
        out.add(reviews[r++]);
      }
      if (f < fresh.length) out.add(fresh[f++]);
      if (out.length >= 60) break;
    }
    return out;
  }

  // ---------------------------------------------------------------- trials

  int get cooldownUntil => store.integer('cool');
  bool get cooling => cooldownUntil > now();

  /// the coronation trial for the next rank is open
  bool get trialOpen => rank < maxRank && !cooling && stat(rank + 1).share >= openShare;

  List<Word> trialWords(int tier, int size) {
    final l = List<Word>.of(deck.tier(tier))..shuffle(Random(now()));
    return l.take(size).toList();
  }

  void _event(String kind, int r, int a, int b) {
    final ev = store.list('ev');
    ev.add({'t': now(), 'k': kind, 'r': r, 'a': a, 'b': b});
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

  /// start again from nothing (Settings)
  void reset() {
    _mem.clear();
    final set = store.map('set');
    store.data
      ..clear()
      ..['v'] = Store.schema
      ..['set'] = set;
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
