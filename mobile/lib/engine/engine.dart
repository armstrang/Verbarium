/// The learning engine: spaced repetition on typed answers, the daily plan, the ranks and their trials.
/// Pure Dart on top of the [Store]; the clock is passed in, so tests can move time.
///
/// Memory: FSRS-6 (fsrs.dart). Each word has a stability in days and a difficulty 1–10. Only the first answer of a
/// study day (which turns at 04:00) moves them: a gap typed unaided is "good" (or "easy" when quick), with the hint
/// button or a slip "hard", wrong or "I don't know" "again"; choosing the meaning or building the sentence is at
/// most "hard", since recognising is easier than recalling. Later answers the same day are practice. The interval
/// is the time until recall falls to 90 %, times the learner's own `ease`, spread a little and never past the exam
/// day. A word is *kukuh* (solid) once its stability reaches a week and its last answer was clean.
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
import 'fsrs.dart';

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

/// One word's memory. Stored as `[s, due, reps, lapses, last, clean, d]`; files from before FSRS have no `d`, which
/// is then read from the lapses (a word forgotten often starts harder). `reps` counts the days it was rated; a word
/// met but not yet rated (its first gap still to come) has reps 0 and stability 0.
class Mem {
  double s;
  int due;
  int reps;
  int lapses;
  int last;
  bool clean;
  double d;
  Mem(this.s, this.due, this.reps, this.lapses, this.last, this.clean, [this.d = 5]);

  static Mem? from(Object? v) {
    if (v is! List || v.length < 6) return null;
    final lapses = (v[3] as num).toInt();
    return Mem(
      (v[0] as num).toDouble(),
      (v[1] as num).toInt(),
      (v[2] as num).toInt(),
      lapses,
      (v[4] as num).toInt(),
      v[5] == 1,
      v.length >= 7 ? (v[6] as num).toDouble() : legacyD(lapses, v[5] == 1),
    );
  }

  /// the difficulty given to a word remembered before FSRS: 4.5, one more for each lapse, half a point less after
  /// a clean answer
  static double legacyD(int lapses, bool clean) => (4.5 + lapses - (clean ? 0.5 : 0)).clamp(1.0, 10.0);

  List<Object> toJson() => [
    double.parse(s.toStringAsFixed(3)),
    due,
    reps,
    lapses,
    last,
    clean ? 1 : 0,
    double.parse(d.toStringAsFixed(2)),
  ];
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

  /// The learner's own pace: intervals are multiplied by it. 1 is the starting point; it rises when on-time
  /// reviews are nearly always right (the intervals were too short) and falls when too many are missed.
  double get ease => ((store.data['ease'] as num?)?.toDouble() ?? 1.0).clamp(0.7, 1.3);

  void _tune(bool right) {
    final r = store.list('ret');
    r.add(right ? 1 : 0);
    if (r.length > 60) r.removeRange(0, r.length - 60);
    if (r.length >= 30 && r.length % 10 == 0) {
      final rate = r.where((x) => x == 1).length / r.length;
      if (rate > 0.93) store.data['ease'] = min(1.3, ease + 0.05);
      if (rate < 0.85) store.data['ease'] = max(0.7, ease - 0.05);
    }
  }

  /// the study day of a moment: days turn at 04:00, so a late night still belongs to the evening before
  static const dayTurn = 4 * 3600000;
  static String studyDay(int ms) => dayKey(ms - dayTurn);

  /// 04:00 of the study day of [ms], in ms
  static int studyStart(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms - dayTurn);
    return DateTime(d.year, d.month, d.day, 4).millisecondsSinceEpoch;
  }

  /// met, but its first gap not yet answered: it still gets its meaning
  bool isNew(Word w) => (_mem[w.id]?.reps ?? 0) == 0;

  /// the chance this word is recalled now (1 when never rated)
  double recall(Word w) {
    final m = _mem[w.id];
    if (m == null || m.reps == 0) return 0;
    return Fsrs.r((now() - m.last) / day, m.s);
  }

  /// How rare a word's hold is, like loot: 0 not yet rated, 1 Common (under a week), 2 Uncommon (under three
  /// weeks), 3 Rare (under two months), 4 Epic (under half a year), 5 Legendary (longer, and not a hard word)
  int rarity(Word w) {
    final m = _mem[w.id];
    if (m == null || m.reps == 0) return 0;
    if (m.s < 7) return 1;
    if (m.s < 21) return 2;
    if (m.s < 60) return 3;
    if (m.s < 180 || m.d > 7) return 4;
    return 5;
  }

  static const rarityNames = ['–', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];

  /// words met in this kingdom by rarity, [0] unrated … [5] Legendary
  List<int> get rarities {
    final n = List<int>.filled(6, 0);
    for (final w in deck.words) {
      if (_mem.containsKey(w.id)) n[rarity(w)]++;
    }
    return n;
  }

  /// An estimate of the words held now: those rated whose chance of recall is still 85 % or more. Recorded at each
  /// coronation, so the learner sees it grow (Kronik).
  int get vocabSize {
    var n = 0;
    final t = now();
    for (final m in _mem.values) {
      if (m.reps > 0 && Fsrs.r((t - m.last) / day, m.s) >= 0.85) n++;
    }
    return n;
  }

  /// a word forgotten five times or more: a Nemesis on the bounty board (Game decides when it is beaten)
  static const nemesisLapses = 5;
  bool hard(Word w) => (_mem[w.id]?.lapses ?? 0) >= nemesisLapses;

  /// the exam day (`set.exam`, yyyymmdd) for the English kingdom: no interval goes past it
  int? get examAt {
    if (store.isRealm) return null;
    final v = '${store.map('set')['exam'] ?? ''}';
    if (v.length != 8) return null;
    final y = int.tryParse(v.substring(0, 4)), mo = int.tryParse(v.substring(4, 6)), d = int.tryParse(v.substring(6));
    if (y == null || mo == null || d == null) return null;
    final at = DateTime(y, mo, d, 4).millisecondsSinceEpoch;
    return at > now() ? at : null;
  }

  /// days until the exam (null without one)
  int? get examDays {
    final at = examAt;
    return at == null ? null : ((at - studyStart(now())) / day).round();
  }

  /// the last two weeks before the exam: no new words, the weak ones first
  bool get raidPrep => (examDays ?? 99) <= 14;

  /// The FSRS rating of one answer: 1 again, 2 hard, 3 good, 4 easy. A quick unaided gap on a word already known
  /// is easy; choosing and building are at most hard.
  static int rating(Grade g, Quiz quiz, {int ms = 0, int length = 6, bool first = false}) {
    if (g == Grade.wrong) return Fsrs.again;
    if (quiz != Quiz.cloze || g == Grade.helped) return Fsrs.hard;
    if (!first && ms > 0 && ms < 2500 + 180 * length) return Fsrs.easy;
    return Fsrs.good;
  }

  /// whether the last call of [answer] moved the memory (false: practice, or a word only met)
  bool lastCounted = false;

  /// Records one answer. [count] = false keeps it out of the daily log (placement). [ms] is the time taken.
  void answer(Word w, Grade g, {bool count = true, Quiz quiz = Quiz.cloze, int ms = 0}) {
    final t = now();
    final old = _mem[w.id];
    lastCounted = false;
    if (old == null) {
      // a word met for the first time (its meaning is chosen): not rated yet, its gap comes later
      _put(w, Mem(0, t, 0, 0, t, false, 5));
      if (count) _log(true, g != Grade.wrong);
      return;
    }
    final m = old;
    final first = m.reps == 0;
    // the same study day again: practice, the memory stays as it was
    if (!first && studyDay(m.last) == studyDay(t)) {
      if (count) _log(false, g != Grade.wrong);
      return;
    }
    // the first rating of a word is never easy (its meaning was shown minutes ago), and comes from a gap
    if (first && quiz != Quiz.cloze) {
      if (count) _log(false, g != Grade.wrong);
      return;
    }
    final elapsed = max(0.0, (t - m.last) / day);
    final onTime = elapsed >= m.s * 0.5;
    final r = rating(g, quiz, ms: ms, length: w.id.length, first: first);
    final (ns, nd) = Fsrs.next(m.s, m.d, elapsed, r);
    m.s = ns;
    m.d = nd;
    if (r == Fsrs.again && !first) m.lapses++;
    if (quiz == Quiz.cloze) m.clean = r >= Fsrs.good;
    if (r == Fsrs.again) m.clean = false;
    m.reps++;
    m.last = t;
    m.due = _dueAfter(w, m, t);
    _put(w, m);
    lastCounted = true;
    if (count) _log(false, g != Grade.wrong);
    if (!first && onTime && quiz == Quiz.cloze && count) _tune(g != Grade.wrong);
    if (!first && w.tier <= rank && rank > 0) _window(g != Grade.wrong);
  }

  /// the start of the study day the word is due: the FSRS interval times [ease], spread by up to 8 % either way
  /// (the same word and day always get the same spread), at least the next day, never past the exam
  int _dueAfter(Word w, Mem m, int t) {
    var ivl = Fsrs.interval(m.s) * ease;
    if (ivl >= 3) {
      final h = (w.id.codeUnits.fold<int>(m.reps, (a, b) => (a * 31 + b) & 0x7fffffff)) % 1000;
      ivl *= 0.92 + 0.16 * h / 999;
    }
    var days = max(1, ivl.round());
    final exam = examDays;
    if (exam != null && exam > 1) days = min(days, exam - 1);
    days = min(days, 36500);
    return studyStart(t) + days * day;
  }

  /// what of the meaning a gap shows before it is answered: 0 the meaning, 1 the first letter and the length,
  /// 2 the length only. A new word always gets its meaning; then A1–A2 keep it, B1–B2 lose it, C1–C2 keep only
  /// the length (or the English definition, when learning through English).
  static int hintLevel(Word w, bool fresh, bool english) {
    if (fresh || w.tier <= 1) return 0;
    if (w.tier <= 3) return 1;
    return english ? 0 : 2;
  }

  /// what kind of slip a word last suffered: 'm' meaning, 's' spelling, 'f' form, 'o' order (see Game)
  String lastError(Word w) => store.map('er')[w.id] as String? ?? '';

  /// Which question a word gets now. A new word is introduced by choosing its meaning (the gap follows in the
  /// same sitting); after that the gap is the rule, with the other two mixed in where they help.
  Quiz pickQuiz(Word w) {
    final m = _mem[w.id];
    if (m == null) return Quiz.choice;
    if (m.reps == 0) return Quiz.cloze;
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

  /// answers in the home-screen widget that keep a day of the streak (HomeWidget.forStreak)
  static const widgetStreak = 10;

  /// days in a row with at least one answer in any kingdom, counting today or yesterday as the latest: one streak
  /// for the whole realm, whichever language was learned that day
  int get streak {
    var n = 0;
    var d = DateTime.fromMillisecondsSinceEpoch(now());
    final logs = store.allLogs();
    final widget = store.widgetDays();
    bool active(DateTime x) {
      final key = dayKey(x.millisecondsSinceEpoch);
      // ten answers in the home-screen widget keep a day too
      if (((widget[key] as num?) ?? 0) >= widgetStreak) return true;
      for (final m in logs) {
        final v = m[key];
        if (v is List && v.length >= 2 && (v[0] as num) + (v[1] as num) > 0) return true;
      }
      return false;
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

  /// the words due now, the most likely to be forgotten first (a word met but not yet rated counts as forgotten)
  List<Word> dueWords() {
    final t = now();
    final l = [
      for (final w in deck.words)
        if ((_mem[w.id]?.due ?? t + 1) <= t) w,
    ];
    final r = {for (final w in l) w.id: recall(w)};
    l.sort((a, b) => r[a.id]!.compareTo(r[b.id]!));
    return l;
  }

  /// how many reviews are waiting: the fog over the kingdom
  int get dueCount {
    final t = now();
    var n = 0;
    for (final m in _mem.values) {
      if (m.due <= t) n++;
    }
    return n;
  }

  static const gateHalf = 50, gateShut = 100;

  /// new words allowed today: the pace set (`perDay`), halved over 50 waiting reviews, none over 100 and none in
  /// the two weeks before the exam
  int get freshToday {
    final today = dayLog(dayKey(now()));
    final due = dueCount;
    if (due > gateShut || raidPrep) return 0;
    final pace = due > gateHalf ? perDay ~/ 2 : perDay;
    return max(0, pace - today[0]);
  }

  /// why no new words come today, when that is the reason: 'fog' (too many reviews), 'raid' (the exam is near)
  String get gateReason {
    if (raidPrep) return 'raid';
    if (dueCount > gateShut) return 'fog';
    return '';
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
    return Plan(dueCount, freshWords(freshToday).length, today[0] + today[1]);
  }

  /// Today's sitting. The reviews go like a sandwich: two likely wins first, the hardest in the middle, two wins to
  /// close; a new word comes after every third review, met by choosing its meaning, and returns three cards later
  /// as a gap. [focus] is the week's focus (Game.focus): 'p' gives words that change their form and long words as
  /// gaps; 'i' puts the words forgotten before first among the hard ones. [maxCards] keeps the sitting to the
  /// length this learner usually manages. At least six in ten questions are gaps.
  List<Card> sitting({int extraFresh = 0, String focus = '', int maxCards = 70}) {
    final cap = maxCards.clamp(10, 70);
    final due = dueWords().take(min(48, cap)).toList();
    final fresh = freshWords(min(freshToday + extraFresh, max(0, (cap - due.length) ~/ 2)));
    final reviews = _sandwich(due, focus);
    final out = <Card>[];
    final later = <int, Word>{};
    var r = 0, f = 0;
    void add(Card c) {
      out.add(c);
      final w = later.remove(out.length);
      if (w != null) out.add(Card(w, Quiz.cloze, false));
    }

    Quiz quizFor(Word w) {
      final q = pickQuiz(w);
      if (focus == 'p' && (w.inflected || w.id.length >= 9)) return Quiz.cloze;
      return q;
    }

    while (r < reviews.length || f < fresh.length) {
      for (var i = 0; i < 3 && r < reviews.length; i++) {
        final w = reviews[r++];
        add(Card(w, quizFor(w), false));
      }
      if (f < fresh.length) {
        final w = fresh[f++];
        add(Card(w, Quiz.choice, true));
        later[out.length + 3] = w;
      }
      if (out.length >= cap) break;
    }
    for (final w in later.values) {
      out.add(Card(w, Quiz.cloze, false));
    }
    // gaps keep at least six in ten of the reviews
    final asked = out.where((c) => !c.fresh).toList();
    var other = asked.where((c) => c.quiz != Quiz.cloze).length;
    for (var i = out.length - 1; i >= 0 && other > asked.length * 0.4; i--) {
      final c = out[i];
      if (!c.fresh && c.quiz != Quiz.cloze) {
        out[i] = Card(c.w, Quiz.cloze, false);
        other--;
      }
    }
    return out;
  }

  /// due words (most at risk first) put in sitting order: two likely wins, then the rest from the hardest, then the
  /// two likeliest wins to close
  List<Word> _sandwich(List<Word> due, String focus) {
    if (due.length < 6) return due;
    final l = List<Word>.of(due);
    final easy = l.reversed.take(4).toList();
    l.removeWhere(easy.contains);
    if (focus == 'i') {
      final lapsed = l.where((w) => (_mem[w.id]?.lapses ?? 0) >= 2).toList();
      l
        ..removeWhere(lapsed.contains)
        ..insertAll(0, lapsed);
    }
    return [easy[2], easy[3], ...l, easy[1], easy[0]];
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
      _event('crown', tier, right, total, {'vs': vocabSize});
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
        _put(w, Mem(10, t0 + ((2 + r.nextInt(38)) * day), 1, 0, t0, true, 4));
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
