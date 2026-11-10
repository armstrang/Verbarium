/// The game layer on top of the engine: experience and levels, combo, the four figures of the character, quests made
/// from the learner's own data, feats, gear, the enemies, and the daily advice. It never changes what the engine
/// knows about memory or rank: a title is still won only in a trial.
///
/// Everything is kept under the store key `game`:
///   xp, n (answers), cr (fast answers), bc (best combo), acc (last 100 answers), ms (average gap time),
///   wk {kind: [right, wrong]}, gear [ids], eq {slot: id}, feats [ids], title, dq/wq (daily and weekly quests)
library;

import 'dart:math';

import '../data/deck.dart';
import '../data/store.dart';
import 'engine.dart';

class Gear {
  final String id, slot, name, from;
  final int tone; // which colour the sprite takes (see ui/pixel.dart)
  const Gear(this.id, this.slot, this.name, this.from, this.tone);
}

class Feat {
  final String id, name, text;
  final String? title;
  const Feat(this.id, this.name, this.text, [this.title]);
}

class Enemy {
  final String name, sprite;
  final int tone;
  final bool boss;
  const Enemy(this.name, this.sprite, this.tone, this.boss);
}

class Quest {
  final String id, text;
  final int goal, xp;
  int prog;
  bool claimed;
  Quest(this.id, this.text, this.goal, this.xp, [this.prog = 0, this.claimed = false]);
  bool get done => prog >= goal;
  Map<String, dynamic> toJson() => {'id': id, 't': text, 'g': goal, 'x': xp, 'p': prog, 'c': claimed ? 1 : 0};
  static Quest from(Map<String, dynamic> m) =>
      Quest(m['id'] as String, m['t'] as String, (m['g'] as num).toInt(), (m['x'] as num).toInt(), (m['p'] as num).toInt(), m['c'] == 1);
}

/// what one answer earned, for the screen to show
class Reward {
  final int xp, combo;
  final bool crit, levelUp;
  final List<String> news;
  const Reward(this.xp, this.combo, this.crit, this.levelUp, this.news);
}

class Game {
  static const gear = [
    Gear('w0', 'weapon', 'Tongkat kayu', 'Bekal awal', 0),
    Gear('w1', 'weapon', 'Pedang besi', 'Rampasan dari Kepala Bandit', 1),
    Gear('w2', 'weapon', 'Pedang kesatria', 'Rampasan dari Ksatria Hitam', 2),
    Gear('w3', 'weapon', 'Pedang perak', 'Rampasan dari Baron Tiran', 3),
    Gear('w4', 'weapon', 'Pedang adipati', 'Rampasan dari Adipati Pengkhianat', 4),
    Gear('w5', 'weapon', 'Pedang raja', 'Rampasan dari Naga Tua', 5),
    Gear('s1', 'shield', 'Perisai kayu', 'Rampasan dari Serigala Hutan', 0),
    Gear('s2', 'shield', 'Perisai besi', 'Rampasan dari Bandit Jalanan', 1),
    Gear('s3', 'shield', 'Perisai baja', 'Rampasan dari Tengkorak Penjaga', 2),
    Gear('s4', 'shield', 'Perisai perak', 'Rampasan dari Gargoyle', 3),
    Gear('s5', 'shield', 'Perisai emas', 'Rampasan dari Penjaga Takhta', 5),
    Gear('c1', 'cloak', 'Jubah cokelat', 'Rampasan dari Babi Hutan', 0),
    Gear('c2', 'cloak', 'Jubah hijau', 'Rampasan dari Pemanah Liar', 1),
    Gear('c3', 'cloak', 'Jubah merah', 'Rampasan dari Penyihir Menara', 2),
    Gear('c4', 'cloak', 'Jubah biru', 'Rampasan dari Ksatria Bayangan', 3),
    Gear('c5', 'cloak', 'Jubah ungu', 'Rampasan dari Raja Bayangan', 4),
  ];

  /// per rank held (0..4): sub-boss I, sub-boss II, the boss of the coronation
  static const enemies = [
    [Enemy('Serigala Hutan', 'wolf', 0, false), Enemy('Babi Hutan', 'boar', 0, false), Enemy('Kepala Bandit', 'bandit', 0, true)],
    [Enemy('Bandit Jalanan', 'bandit', 1, false), Enemy('Pemanah Liar', 'bandit', 2, false), Enemy('Ksatria Hitam', 'knight', 0, true)],
    [Enemy('Tengkorak Penjaga', 'skeleton', 0, false), Enemy('Penyihir Menara', 'mage', 0, false), Enemy('Baron Tiran', 'knight', 1, true)],
    [Enemy('Gargoyle', 'gargoyle', 0, false), Enemy('Ksatria Bayangan', 'knight', 2, false), Enemy('Adipati Pengkhianat', 'mage', 1, true)],
    [Enemy('Penjaga Takhta', 'knight', 3, false), Enemy('Raja Bayangan', 'skeleton', 1, false), Enemy('Naga Tua', 'dragon', 0, true)],
  ];
  static const _subDrops = ['s1', 'c1', 's2', 'c2', 's3', 'c3', 's4', 'c4', 's5', 'c5'];

  static const feats = [
    Feat('first', 'Langkah pertama', 'Menjawab kata pertamamu'),
    Feat('n1000', 'Seribu jawaban', 'Menjawab 1.000 kali', 'Si Rajin'),
    Feat('s100', 'Seratus kata kukuh', '100 kata kukuh', 'Si Tekun'),
    Feat('s500', 'Lima ratus kata kukuh', '500 kata kukuh', 'Penjaga Kata'),
    Feat('s1000', 'Seribu kata kukuh', '1.000 kata kukuh', 'Empu Kata'),
    Feat('streak7', 'Tujuh hari', 'Belajar 7 hari beruntun', 'Si Setia'),
    Feat('streak30', 'Tiga puluh hari', 'Belajar 30 hari beruntun', 'Yang Tak Tergoyahkan'),
    Feat('combo20', 'Dua puluh beruntun', 'Combo 20 jawaban benar', 'Si Teliti'),
    Feat('crit50', 'Tangan cepat', '50 jawaban di bawah enam detik', 'Si Cepat'),
    Feat('boss1', 'Penakluk pertama', 'Mengalahkan boss pertamamu', 'Penakluk'),
    Feat('perfect', 'Tanpa cela', 'Mengalahkan boss tanpa satu pun salah', 'Tanpa Cela'),
  ];

  static const critMs = 6000;

  final Store store;
  final Engine e;
  int combo = 0;

  Game(this.store, this.e);

  Map<String, dynamic> get _g => store.map('game');
  int _int(String k) => (_g[k] as num?)?.toInt() ?? 0;

  // ---------------------------------------------------------------- level

  int get xp => _int('xp');
  static int xpFor(int level) => 30 * (level - 1) * level;
  int get level {
    var l = 1;
    while (xpFor(l + 1) <= xp) {
      l++;
    }
    return l;
  }

  double get levelShare => (xp - xpFor(level)) / (xpFor(level + 1) - xpFor(level));
  int get toNext => xpFor(level + 1) - xp;

  bool _gain(int n) {
    final before = level;
    _g['xp'] = xp + n;
    store.touch();
    return level > before;
  }

  // ---------------------------------------------------------------- answers

  void _wk(String kind, bool right) {
    final wk = (_g['wk'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    final l = (wk[kind] as List?)?.map((x) => (x as num).toInt()).toList() ?? [0, 0];
    l[right ? 0 : 1]++;
    if (l[0] + l[1] > 60) {
      l[0] = (l[0] * 0.8).round();
      l[1] = (l[1] * 0.8).round();
    }
    wk[kind] = l;
  }

  /// Call once per graded answer. [err]: '' none, 's' a spelling slip, 'f' the wrong form, 'm' meaning not known,
  /// 'o' wrong order. [ms] = time taken. Returns what to show.
  Reward onAnswer(Word w, Quiz quiz, Grade g, int ms, {String err = '', bool fresh = false, bool hadLapses = false}) {
    final right = g != Grade.wrong;
    final news = <String>[];
    _g['n'] = _int('n') + 1;
    final acc = (_g['acc'] ??= <dynamic>[]) as List;
    acc.add(right ? 1 : 0);
    if (acc.length > 100) acc.removeRange(0, acc.length - 100);

    if (quiz == Quiz.cloze) {
      _wk('s', err != 's');
      if (w.inflected) _wk('f', err != 'f');
      _wk('m', err != 'm' && right);
      if (right && ms > 0) _g['ms'] = _int('ms') == 0 ? ms : (_int('ms') * 0.9 + ms * 0.1).round();
    } else if (quiz == Quiz.build) {
      _wk('o', right);
    } else {
      _wk('m', right);
    }
    final er = store.map('er');
    if (err.isEmpty && g == Grade.clean) {
      er.remove(w.id);
    } else if (err.isNotEmpty) {
      er[w.id] = err;
    }

    combo = right ? combo + 1 : 0;
    if (combo > _int('bc')) _g['bc'] = combo;
    final crit = right && quiz == Quiz.cloze && g == Grade.clean && ms > 0 && ms < critMs;
    if (crit) _g['cr'] = _int('cr') + 1;

    var gain = 0;
    if (right) {
      gain = switch (quiz) {
        Quiz.cloze => g == Grade.clean ? 10 : 5,
        Quiz.build => 6,
        Quiz.choice => 3,
      };
      gain += min(5, combo ~/ 3);
      if (crit) gain += 3;
    }

    // quests
    for (final q in [...daily, ...weekly]) {
      if (q.done) continue;
      final before = q.prog;
      switch (q.id) {
        case 'rev':
          if (!fresh) q.prog++;
        case 'new':
          if (fresh) q.prog++;
        case 'combo':
          q.prog = max(q.prog, min(q.goal, combo));
        case 'clean':
          if (quiz == Quiz.cloze && g == Grade.clean) q.prog++;
        case 'weak':
          if (hadLapses && g == Grade.clean && quiz == Quiz.cloze) q.prog++;
        case 'fast':
          if (crit) q.prog++;
        case 'ans150':
          q.prog++;
      }
      if (q.prog != before && q.done) news.add('Quest selesai: ${q.text}');
    }
    _saveQuests();

    final up = gain > 0 && _gain(gain);
    if (up) news.add('Naik ke level $level');
    news.addAll(_checkFeats());
    store.touch();
    return Reward(gain, combo, crit, up, news);
  }

  /// a collocation card: counts for experience and the collocation figure only
  Reward onColloc(bool right) {
    _wk('c', right);
    combo = right ? combo + 1 : 0;
    final up = right && _gain(4);
    store.touch();
    return Reward(right ? 4 : 0, combo, false, up, up ? ['Naik ke level $level'] : const []);
  }

  // ---------------------------------------------------------------- figures (0..100)

  int get accuracy {
    final acc = (_g['acc'] as List?) ?? const [];
    if (acc.isEmpty) return 0;
    return (100 * acc.where((x) => x == 1).length / acc.length).round();
  }

  int get memory {
    var total = 0;
    for (var t = 1; t <= e.learning; t++) {
      total += e.deck.tier(t).length;
    }
    return total == 0 ? 0 : min(100, (100 * e.solidTotal / total).round());
  }

  int get speed {
    final ms = _int('ms');
    if (ms == 0) return 0;
    return ((16000 - ms) / 120).round().clamp(0, 100);
  }

  int get activeDays14 {
    var n = 0;
    for (var i = 0; i < 14; i++) {
      final l = e.dayLog(Engine.dayKey(e.now() - i * Engine.day));
      if (l[0] + l[1] > 0) n++;
    }
    return n;
  }

  int get diligence => (100 * activeDays14 / 14).round();
  int get answers => _int('n');
  int get bestCombo => _int('bc');

  // ---------------------------------------------------------------- gear

  List<String> get owned => ['w0', ...((_g['gear'] as List?) ?? const []).cast<String>()];
  String equipped(String slot) => ((_g['eq'] as Map?)?[slot] as String?) ?? (slot == 'weapon' ? 'w0' : '');
  Gear? gearOf(String id) {
    for (final x in gear) {
      if (x.id == id) return x;
    }
    return null;
  }

  int tone(String slot) => gearOf(equipped(slot))?.tone ?? -1;

  void equip(String slot, String id) {
    ((_g['eq'] ??= <String, dynamic>{}) as Map)[slot] = id;
    store.touch();
  }

  Gear? _grant(String id) {
    final l = (_g['gear'] ??= <dynamic>[]) as List;
    if (l.contains(id)) return null;
    l.add(id);
    final it = gearOf(id)!;
    equip(it.slot, id);
    return it;
  }

  // ---------------------------------------------------------------- enemies and fights

  /// the enemy now standing in the way (sub-boss of the stage, or the boss), null at the top
  Enemy? get enemy => e.rank >= Engine.maxRank ? null : enemies[e.rank][e.stage < 2 && !_bossNext ? e.stage : 2];
  bool get _bossNext => e.stage >= 2;
  bool get enemyIsBoss => e.stage >= 2;
  bool get fightOpen => enemyIsBoss ? e.trialOpen : e.subOpen;

  /// share of solid words the next fight needs
  double get fightNeeds => enemyIsBoss ? Engine.openShare : Engine.stageShare[e.stage];

  /// rough chance to win the next fight from recent accuracy (binomial)
  int winChance() {
    final p = max(0.05, min(0.99, accuracy / 100));
    final n = enemyIsBoss ? Engine.trialSize : Engine.subSize;
    final need = enemyIsBoss ? Engine.trialPass : Engine.subPass;
    double c(int n, int k) {
      var r = 1.0;
      for (var i = 1; i <= k; i++) {
        r = r * (n - k + i) / i;
      }
      return r;
    }

    var sum = 0.0;
    for (var k = need; k <= n; k++) {
      sum += c(n, k) * pow(p, k) * pow(1 - p, n - k);
    }
    return (sum * 100).round().clamp(1, 99);
  }

  /// after a fight is won: experience, loot, feats. [rankBefore]/[stageBefore] = where the learner stood.
  List<String> onVictory(int rankBefore, int stageBefore, bool boss, bool flawless) {
    final news = <String>[];
    if (_gain(boss ? 120 : 50)) news.add('Naik ke level $level');
    final id = boss ? 'w${rankBefore + 1}' : _subDrops[min(_subDrops.length - 1, rankBefore * 2 + stageBefore)];
    final it = _grant(id);
    if (it != null) news.add('Rampasan: ${it.name}');
    final f = (_g['feats'] ??= <dynamic>[]) as List;
    if (boss && !f.contains('boss1')) {
      f.add('boss1');
      news.add('Pencapaian: Penakluk pertama');
    }
    if (boss && flawless && !f.contains('perfect')) {
      f.add('perfect');
      news.add('Pencapaian: Tanpa cela');
    }
    store.touch();
    return news;
  }

  // ---------------------------------------------------------------- feats and titles

  List<String> get earned => ((_g['feats'] as List?) ?? const []).cast<String>();
  String get title => _g['title'] as String? ?? '';
  void setTitle(String t) {
    _g['title'] = t;
    store.touch();
  }

  List<String> _checkFeats() {
    final f = (_g['feats'] ??= <dynamic>[]) as List;
    final solid = e.solidTotal, streak = e.streak;
    final want = <String, bool>{
      'first': answers >= 1,
      'n1000': answers >= 1000,
      's100': solid >= 100,
      's500': solid >= 500,
      's1000': solid >= 1000,
      'streak7': streak >= 7,
      'streak30': streak >= 30,
      'combo20': bestCombo >= 20,
      'crit50': _int('cr') >= 50,
    };
    final news = <String>[];
    want.forEach((id, ok) {
      if (ok && !f.contains(id)) {
        f.add(id);
        news.add('Pencapaian: ${feats.firstWhere((x) => x.id == id).name}');
      }
    });
    return news;
  }

  // ---------------------------------------------------------------- quests

  List<Quest>? _daily, _weekly;

  String get _weekKey {
    final d = DateTime.fromMillisecondsSinceEpoch(e.now());
    return Engine.dayKey(d.subtract(Duration(days: d.weekday - 1)).millisecondsSinceEpoch);
  }

  List<Quest> _load(String key, String stamp, List<Quest> Function() make) {
    final m = _g[key];
    if (m is Map<String, dynamic> && m['k'] == stamp && m['q'] is List) {
      return [for (final x in m['q'] as List) Quest.from(x as Map<String, dynamic>)];
    }
    final l = make();
    _g[key] = {
      'k': stamp,
      'q': [for (final q in l) q.toJson()],
    };
    store.touch();
    return l;
  }

  /// three quests a day, made from what the learner has in front of them today
  List<Quest> get daily {
    final key = Engine.dayKey(e.now());
    if (_daily != null && (_g['dq'] as Map?)?['k'] == key) return _daily!;
    return _daily = _load('dq', key, () {
      final due = e.dueWords().length, fresh = e.plan().fresh;
      var lapsed = 0;
      for (final w in e.deck.words) {
        if ((e.mem(w)?.lapses ?? 0) > 0) lapsed++;
      }
      final pool = <Quest>[
        if (due >= 5) Quest('rev', 'Ulang ${due.clamp(5, 20)} kata', due.clamp(5, 20), 30),
        if (fresh > 0) Quest('new', 'Pelajari $fresh kata baru', fresh, 40),
        if (lapsed >= 5) Quest('weak', 'Rebut kembali 5 kata yang pernah kamu lupa', 5, 45),
        Quest('clean', 'Isi 10 celah tanpa bantuan', 10, 35),
        Quest('combo', 'Raih combo 8', 8, 30),
        Quest('fast', 'Jawab 5 celah di bawah enam detik', 5, 35),
      ];
      final r = Random(int.parse(key));
      final head = pool.take(pool.length - 3).toList();
      final tail = pool.skip(pool.length - 3).toList()..shuffle(r);
      return [...head, ...tail].take(3).toList();
    });
  }

  List<Quest> get weekly {
    final key = _weekKey;
    if (_weekly != null && (_g['wq'] as Map?)?['k'] == key) return _weekly!;
    return _weekly = _load('wq', key, () => [Quest('days5', 'Belajar 5 hari dalam minggu ini', 5, 150), Quest('ans150', 'Jawab 150 pertanyaan', 150, 120)]);
  }

  void _saveQuests() {
    if (_daily != null) (_g['dq'] as Map)['q'] = [for (final q in _daily!) q.toJson()];
    if (_weekly != null) {
      // days this week with at least one answer
      final days = _weekly!.where((q) => q.id == 'days5');
      if (days.isNotEmpty) {
        final d = DateTime.fromMillisecondsSinceEpoch(e.now());
        var n = 0;
        for (var i = 0; i < d.weekday; i++) {
          final l = e.dayLog(Engine.dayKey(d.subtract(Duration(days: i)).millisecondsSinceEpoch));
          if (l[0] + l[1] > 0) n++;
        }
        days.first.prog = max(days.first.prog, min(5, n));
      }
      (_g['wq'] as Map)['q'] = [for (final q in _weekly!) q.toJson()];
    }
  }

  /// takes a finished quest's reward; returns news (level up)
  List<String> claim(Quest q) {
    if (!q.done || q.claimed) return const [];
    q.claimed = true;
    final up = _gain(q.xp);
    _saveQuests();
    store.touch();
    return [if (up) 'Naik ke level $level'];
  }

  // ---------------------------------------------------------------- advice

  List<int> _w(String k) => (((_g['wk'] as Map?)?[k]) as List?)?.map((x) => (x as num).toInt()).toList() ?? [0, 0];

  /// the weakest side of the learner right now, as a sentence; null when nothing stands out
  String? weakness() {
    const text = {
      's': 'Ejaanmu sering meleset satu huruf. Pelan sedikit saat mengetik kata panjang.',
      'f': 'Artinya sudah kamu pegang, bentuk katanya yang sering meleset. Perhatikan kata sebelum celah.',
      'm': 'Banyak arti yang belum melekat. Hari ini kata baru dikurangi, ulangan diperbanyak.',
      'o': 'Susunan kalimatmu masih goyah. Kalimat pendek akan lebih sering muncul untuk disusun.',
      'c': 'Pasangan kata (kolokasi) perlu diasah. Kartu kolokasi akan lebih sering muncul.',
    };
    String? worst;
    var rate = 0.25;
    for (final k in text.keys) {
      final l = _w(k);
      final n = l[0] + l[1];
      if (n >= 8 && l[1] / n > rate) {
        rate = l[1] / n;
        worst = k;
      }
    }
    return worst == null ? null : text[worst];
  }

  /// how often a collocation card is slipped into a sitting: more when collocations are weak
  int get collocEvery {
    final l = _w('c');
    final n = l[0] + l[1];
    return n >= 6 && l[1] / n > 0.3 ? 6 : 10;
  }

  /// today's advice: what to do first, and why
  List<String> advice() {
    final p = e.plan();
    final out = <String>[];
    final en = enemy;
    if (e.shaky) {
      out.add('Gelarmu goyah. Pertahankan dulu sebelum hal lain.');
    } else if (en != null && fightOpen) {
      out.add('${en.name} bisa dilawan sekarang. Peluang menangmu sekitar ${winChance()}%.');
    }
    if (p.reviews > 0 && p.fresh > 0) {
      out.add('Mulai dari ${p.reviews} ulangan, lalu ${p.fresh} kata baru.');
    } else if (p.reviews > 0) {
      out.add('${p.reviews} kata menunggu diulang.');
    } else if (p.fresh > 0) {
      out.add('Tidak ada ulangan. Waktu yang baik untuk ${p.fresh} kata baru.');
    }
    final w = weakness();
    if (w != null) out.add(w);
    if (out.isEmpty) out.add('Semua tugas hari ini selesai. Kembalilah besok.');
    return out;
  }
}
