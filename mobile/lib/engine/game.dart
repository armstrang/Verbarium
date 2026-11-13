/// The game layer on top of the engine: experience and levels, combo, the four figures of the character, quests made
/// from the learner's own data, feats, gear, the enemies, and the daily advice. It never changes what the engine
/// knows about memory or rank: a title is still won only in a trial.
///
/// Everything is kept under the store key `game`:
///   xp, n (answers), cr (fast answers), bc (best combo), acc (last 100 answers), ms (average gap time),
///   wk {kind: [right, wrong]}, gear [ids], eq {slot: id}, feats [ids], title, dq/wq (daily and weekly quests),
///   jobs [job id per title held], hid {title: hidden job id}, bp (the build of the title being won: p, s, i, e and
///   what the hidden jobs look at), bt (the build of the whole journey), ld (day of the last answer)
library;

import 'dart:math';

import '../app/lang.dart';
import '../data/deck.dart';
import '../data/store.dart';
import 'engine.dart';
import 'jobs.dart';

class Gear {
  final String id, slot, _id, _en, _fromId, _fromEn;
  final int tone; // which colour the sprite takes (see ui/pixel.dart)
  const Gear(this.id, this.slot, this._id, this._en, this._fromId, this._fromEn, this.tone);
  String get name => tr(_id, _en);
  String get from => _fromId.isEmpty
      ? tr(
          'Bekal awal',
          'What you set out with',
          'Con lo que partiste',
          'Ce avec quoi tu es parti',
          'Womit du aufgebrochen bist',
          'Com o que você partiu',
        )
      : tr(
          'Rampasan dari $_fromId',
          'Taken from the $_fromEn',
          'Botín: ${tx(_fromEn)}',
          'Butin : ${tx(_fromEn)}',
          'Erbeutet von: $_fromEn',
          'Tomado de: $_fromEn',
        );
}

class Feat {
  final String id, _nameId, _nameEn, _textId, _textEn;
  final String? _titleId, _titleEn;
  const Feat(this.id, this._nameId, this._nameEn, this._textId, this._textEn, [this._titleId, this._titleEn]);
  String get name => tr(_nameId, _nameEn);
  String get text => tr(_textId, _textEn);
  String? get title => _titleId == null ? null : tr(_titleId, _titleEn!);
  bool named(String s) => s == id || s == _titleId || s == _titleEn;
}

class Enemy {
  final String _id, _en, sprite;
  final int tone;
  final bool boss;
  final String _threatId, _threatEn;
  const Enemy(this._id, this._en, this.sprite, this.tone, this.boss, [this._threatId = '', this._threatEn = '']);
  String get name => tr(_id, _en);

  /// one line of menace under the name
  String get threat => tr(_threatId, _threatEn);
}

class Quest {
  final String id;
  final int goal, xp;
  int prog;
  bool claimed;
  Quest(this.id, this.goal, this.xp, [this.prog = 0, this.claimed = false]);
  bool get done => prog >= goal;

  /// said in the language that is on now, so a quest made yesterday in another language still reads right
  String get text => switch (id) {
    'rev' => tr(
      'Ulang $goal kata',
      'Review $goal words',
      'Repasa $goal palabras',
      'Révise $goal mots',
      'Wiederhole $goal Wörter',
      'Revise $goal palavras',
    ),
    'new' => tr(
      'Pelajari $goal kata baru',
      'Learn $goal new words',
      'Aprende $goal palabras nuevas',
      'Apprends $goal nouveaux mots',
      'Lerne $goal neue Wörter',
      'Aprenda $goal palavras novas',
    ),
    'weak' => tr(
      'Rebut kembali $goal kata yang pernah kamu lupa',
      'Win back $goal words you once forgot',
      'Recupera $goal palabras que olvidaste',
      'Reconquiers $goal mots oubliés',
      'Hol $goal Wörter zurück, die du einmal vergessen hast',
      'Recupere $goal palavras que você esqueceu',
    ),
    'clean' => tr(
      'Isi $goal celah tanpa bantuan',
      'Fill $goal gaps without help',
      'Completa $goal huecos sin ayuda',
      'Remplis $goal trous sans aide',
      'Fülle $goal Lücken ohne Hilfe',
      'Preencha $goal lacunas sem ajuda',
    ),
    'combo' => tr(
      'Raih combo $goal',
      'Reach a combo of $goal',
      'Llega a un combo de $goal',
      'Atteins un combo de $goal',
      'Erreiche eine Kombo von $goal',
      'Chegue a um combo de $goal',
    ),
    'fast' => tr(
      'Jawab $goal celah di bawah enam detik',
      'Answer $goal gaps in under six seconds',
      'Responde $goal huecos en menos de seis segundos',
      'Réponds à $goal trous en moins de six secondes',
      'Beantworte $goal Lücken in unter sechs Sekunden',
      'Responda $goal lacunas em menos de seis segundos',
    ),
    'days5' => tr(
      'Belajar $goal hari dalam minggu ini',
      'Study on $goal days this week',
      'Estudia $goal días esta semana',
      'Étudie $goal jours cette semaine',
      'Lerne diese Woche an $goal Tagen',
      'Estude em $goal dias nesta semana',
    ),
    _ => tr(
      'Jawab $goal pertanyaan',
      'Answer $goal questions',
      'Responde $goal preguntas',
      'Réponds à $goal questions',
      'Beantworte $goal Fragen',
      'Responda $goal perguntas',
    ),
  };
  Map<String, dynamic> toJson() => {'id': id, 'g': goal, 'x': xp, 'p': prog, 'c': claimed ? 1 : 0};
  static Quest from(Map<String, dynamic> m) =>
      Quest(m['id'] as String, (m['g'] as num).toInt(), (m['x'] as num).toInt(), (m['p'] as num).toInt(), m['c'] == 1);
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
    Gear('w0', 'weapon', 'Tongkat kayu', 'Wooden stick', '', '', 0),
    Gear('w1', 'weapon', 'Senjata besi', 'Iron arms', 'Kepala Bandit', 'Bandit Chief', 1),
    Gear('w2', 'weapon', 'Senjata kesatria', 'Knightly arms', 'Ksatria Hitam', 'Black Knight', 2),
    Gear('w3', 'weapon', 'Senjata perak', 'Silver arms', 'Baron Tiran', 'Tyrant Baron', 3),
    Gear('w4', 'weapon', 'Senjata adipati', 'Ducal arms', 'Adipati Pengkhianat', 'Traitor Duke', 4),
    Gear('w5', 'weapon', 'Senjata raja', 'Royal arms', 'Naga Tua', 'Old Dragon', 5),
    Gear('w6', 'weapon', 'Senjata terkutuk', 'Cursed arms', 'Count Terkutuk', 'Cursed Count', 6),
    Gear('s1', 'shield', 'Perisai kayu', 'Wooden shield', 'Serigala Hutan', 'Forest Wolf', 0),
    Gear('s2', 'shield', 'Perisai besi', 'Iron shield', 'Bandit Jalanan', 'Highwayman', 1),
    Gear('s3', 'shield', 'Perisai baja', 'Steel shield', 'Tengkorak Penjaga', 'Skeleton Guard', 2),
    Gear('s4', 'shield', 'Perisai perak', 'Silver shield', 'Gargoyle', 'Gargoyle', 3),
    Gear('s5', 'shield', 'Perisai emas', 'Golden shield', 'Penjaga Takhta', 'Throne Guard', 5),
    Gear('s6', 'shield', 'Perisai tulang', 'Bone shield', 'Serigala Kelam', 'Dire Wolf', 6),
    Gear('c1', 'cloak', 'Jubah cokelat', 'Brown cloak', 'Babi Hutan', 'Wild Boar', 0),
    Gear('c2', 'cloak', 'Jubah hijau', 'Green cloak', 'Pemanah Liar', 'Wild Archer', 1),
    Gear('c3', 'cloak', 'Jubah merah', 'Red cloak', 'Penyihir Menara', 'Tower Sorcerer', 2),
    Gear('c4', 'cloak', 'Jubah biru', 'Blue cloak', 'Ksatria Bayangan', 'Shadow Knight', 3),
    Gear('c5', 'cloak', 'Jubah ungu', 'Purple cloak', 'Raja Bayangan', 'Shadow King', 4),
    Gear('c6', 'cloak', 'Jubah malam', 'Night cloak', 'Kelelawar Raksasa', 'Giant Bat', 6),
  ];

  /// per rank held (0..5): sub-boss I, sub-boss II, the boss of the coronation
  static const enemies = [
    [
      Enemy('Serigala Hutan', 'Forest Wolf', 'wolf', 0, false, 'Memburu yang ragu.', 'Hunts what hesitates.'),
      Enemy('Babi Hutan', 'Wild Boar', 'boar', 0, false, 'Menerjang setiap celah.', 'Charges through every gap.'),
      Enemy(
        'Kepala Bandit',
        'Bandit Chief',
        'bandit',
        0,
        true,
        'Merampas kata dari yang lengah.',
        'Robs the careless of their words.',
      ),
    ],
    [
      Enemy(
        'Bandit Jalanan',
        'Highwayman',
        'bandit',
        1,
        false,
        'Menunggu di tikungan jalan.',
        'Waits at the bend of the road.',
      ),
      Enemy('Pemanah Liar', 'Wild Archer', 'bandit', 2, false, 'Tak pernah meleset dua kali.', 'Never misses twice.'),
      Enemy(
        'Ksatria Hitam',
        'Black Knight',
        'knight',
        0,
        true,
        'Belum pernah mundur selangkah pun.',
        'Has never yielded a single step.',
      ),
    ],
    [
      Enemy(
        'Tengkorak Penjaga',
        'Skeleton Guard',
        'skeleton',
        0,
        false,
        'Masih berjaga setelah mati.',
        'Still on watch after death.',
      ),
      Enemy(
        'Penyihir Menara',
        'Tower Sorcerer',
        'mage',
        0,
        false,
        'Mengutuk setiap ejaan yang salah.',
        'Curses every wrong spelling.',
      ),
      Enemy(
        'Baron Tiran',
        'Tyrant Baron',
        'knight',
        1,
        true,
        'Menagih upeti dalam kata.',
        'Takes his tribute in words.',
      ),
    ],
    [
      Enemy('Serigala Kelam', 'Dire Wolf', 'wolf', 1, false, 'Lebih besar dari kudamu.', 'Larger than your horse.'),
      Enemy('Kelelawar Raksasa', 'Giant Bat', 'bat', 0, false, 'Datang bersama gelap.', 'Comes with the dark.'),
      Enemy(
        'Count Terkutuk',
        'Cursed Count',
        'count',
        0,
        true,
        'Tak tidur sejak seabad lalu.',
        'Has not slept for a century.',
      ),
    ],
    [
      Enemy(
        'Gargoyle',
        'Gargoyle',
        'gargoyle',
        0,
        false,
        'Batu yang menunggu kamu lengah.',
        'Stone that waits for you to slip.',
      ),
      Enemy(
        'Ksatria Bayangan',
        'Shadow Knight',
        'knight',
        2,
        false,
        'Meniru setiap gerakmu.',
        'Mirrors every move you make.',
      ),
      Enemy(
        'Adipati Pengkhianat',
        'Traitor Duke',
        'mage',
        1,
        true,
        'Bersumpah setia, lalu menikam.',
        'Swears loyalty, then strikes.',
      ),
    ],
    [
      Enemy(
        'Penjaga Takhta',
        'Throne Guard',
        'knight',
        3,
        false,
        'Pernah menjaga raja yang lebih hebat.',
        'Has guarded greater kings.',
      ),
      Enemy(
        'Raja Bayangan',
        'Shadow King',
        'skeleton',
        1,
        false,
        'Duduk di takhta yang kau incar.',
        'Sits on the throne you seek.',
      ),
      Enemy(
        'Naga Tua',
        'Old Dragon',
        'dragon',
        0,
        true,
        'Lebih tua dari bahasa itu sendiri.',
        'Older than language itself.',
      ),
    ],
  ];
  // what each fight leaves behind, rank by rank (the Count's road was added later, hence the sixes)
  static const _subDrops = ['s1', 'c1', 's2', 'c2', 's3', 'c3', 's6', 'c6', 's4', 'c4', 's5', 'c5'];
  static const _bossDrops = ['w1', 'w2', 'w3', 'w6', 'w4', 'w5'];

  static const feats = [
    Feat('first', 'Langkah pertama', 'The first step', 'Menjawab kata pertamamu', 'Answered your first word'),
    Feat(
      'n1000',
      'Seribu jawaban',
      'A thousand answers',
      'Menjawab 1.000 kali',
      'Answered 1,000 times',
      'Si Rajin',
      'the Diligent',
    ),
    Feat(
      's100',
      'Seratus kata kukuh',
      'A hundred solid words',
      '100 kata kukuh',
      '100 solid words',
      'Si Tekun',
      'the Steady',
    ),
    Feat(
      's500',
      'Lima ratus kata kukuh',
      'Five hundred solid words',
      '500 kata kukuh',
      '500 solid words',
      'Penjaga Kata',
      'Keeper of Words',
    ),
    Feat(
      's1000',
      'Seribu kata kukuh',
      'A thousand solid words',
      '1.000 kata kukuh',
      '1,000 solid words',
      'Empu Kata',
      'Master of Words',
    ),
    Feat(
      'streak7',
      'Tujuh hari',
      'Seven days',
      'Belajar 7 hari beruntun',
      'Studied 7 days in a row',
      'Si Setia',
      'the Faithful',
    ),
    Feat(
      'streak30',
      'Tiga puluh hari',
      'Thirty days',
      'Belajar 30 hari beruntun',
      'Studied 30 days in a row',
      'Yang Tak Tergoyahkan',
      'the Unshaken',
    ),
    Feat(
      'combo20',
      'Dua puluh beruntun',
      'Twenty in a row',
      'Combo 20 jawaban benar',
      'A combo of 20 right answers',
      'Si Teliti',
      'the Careful',
    ),
    Feat('crit50', 'Tangan cepat', 'Quick hand', '50 jawaban kritis', '50 critical answers', 'Si Cepat', 'the Swift'),
    Feat(
      'boss1',
      'Penakluk pertama',
      'First conquest',
      'Mengalahkan boss pertamamu',
      'Beat your first boss',
      'Penakluk',
      'the Conqueror',
    ),
    Feat(
      'perfect',
      'Tanpa cela',
      'Flawless',
      'Mengalahkan boss tanpa satu pun salah',
      'Beat a boss without a single miss',
      'Tanpa Cela',
      'the Flawless',
    ),
    Feat(
      'jobs3',
      'Tiga jalan',
      'Three paths',
      'Memegang tiga job berturut-turut',
      'Held three jobs in turn',
      'Sang Pengelana',
      'the Wayfarer',
    ),
    Feat(
      'secret',
      'Jalan tersembunyi',
      'A hidden path',
      'Menemukan satu job tersembunyi',
      'Found a hidden job',
      'Sang Penemu',
      'the Finder',
    ),
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
  Reward onAnswer(
    Word w,
    Quiz quiz,
    Grade g,
    int ms, {
    String err = '',
    bool fresh = false,
    bool hadLapses = false,
    double stab = 0,
    bool hinted = false,
  }) {
    final right = g != Grade.wrong;
    final news = <String>[];
    _g['n'] = _int('n') + 1;
    final today = Engine.dayKey(e.now());
    final firstToday = _g['ld'] != today;
    _g['ld'] = today;
    final hour = DateTime.fromMillisecondsSinceEpoch(e.now()).hour;
    final night = hour >= 22 || hour < 5;
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
    final crit = right && quiz == Quiz.cloze && g == Grade.clean && ms > 0 && ms < critMs + 1000 * perk('critWin');
    if (crit) _g['cr'] = _int('cr') + 1;
    final cleanGap = quiz == Quiz.cloze && g == Grade.clean;
    final longHeld = right && !fresh && stab >= Engine.solidDays;

    var gain = 0;
    if (right) {
      gain = switch (quiz) {
        // 10 unaided, 7 after the hint button, 5 after a slip
        Quiz.cloze => g == Grade.clean ? 10 + perk('xpCloze') : (hinted ? 7 : 5),
        Quiz.build => 6 + perk('xpBuild'),
        Quiz.choice => 3 + perk('xpChoice'),
      };
      gain += min(5 + perk('comboCap'), combo ~/ 3);
      if (crit) gain += 3 + perk('critXp');
      if (cleanGap && w.inflected) gain += perk('formXp');
      if (longHeld) gain += perk('solidXp');
      if (hadLapses && cleanGap) gain += perk('lapseXp');
      if (night) gain += perk('nightXp');
      if (firstToday) gain += perk('dayXp');
      gain += perk('xpAll');
    }

    // the build: what kind of learner this answer shows
    _add('n', 1);
    if (night) _add('nt', 1);
    if (combo > _b('bc')) _bp['bc'] = combo;
    if (right) {
      if (quiz == Quiz.cloze) {
        _add('p', g == Grade.clean ? 2 : 1);
        if (cleanGap && w.inflected) _add('p', 1);
        if (crit) {
          _add('s', 4);
        } else if (cleanGap && ms > 0 && ms < 10000) {
          _add('s', 1);
        }
        if (ms > 0) {
          _add('cz', 1);
          _add('czms', ms);
        }
      } else if (quiz == Quiz.build) {
        _add('s', ms > 0 && ms < 15000 ? 3 : 1);
      } else {
        _add('i', 1);
        if (ms > 0 && ms < 4000) _add('s', 1);
      }
      if (longHeld) _add('i', 4);
      if (hadLapses) _add('i', 2);
    }
    if (!fresh) _add('e', 1);
    if (firstToday) _add('e', e.streak >= 3 ? 12 : 8);
    final dayAnswers = e.dayLog(today);
    if (dayAnswers[0] + dayAnswers[1] > 30) _add('e', 1);

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
      if (q.prog != before && q.done) {
        news.add(
          tr(
            'Quest selesai: ${q.text}',
            'Quest done: ${q.text}',
            'Misión cumplida: ${q.text}',
            'Quête accomplie : ${q.text}',
            'Aufgabe erfüllt: ${q.text}',
            'Missão cumprida: ${q.text}',
          ),
        );
      }
    }
    _saveQuests();

    final up = gain > 0 && _gain(gain);
    if (up) news.add(_levelNews);
    news.addAll(_checkFeats());
    store.touch();
    return Reward(gain, combo, crit, up, news);
  }

  /// a flat reward outside the table: a gap got right after one miss (5), the answer typed once it was shown (1),
  /// the widget on the home screen (1-5). Touches nothing but experience.
  Reward bonus(int n) {
    if (n <= 0) return Reward(0, combo, false, false, const []);
    final up = _gain(n);
    store.touch();
    return Reward(n, combo, false, up, up ? [_levelNews] : const []);
  }

  /// a collocation card: counts for experience and the collocation figure only
  Reward onColloc(bool right) {
    _wk('c', right);
    combo = right ? combo + 1 : 0;
    final gain = right ? 4 + perk('xpColloc') + perk('xpAll') : 0;
    if (right) _add('p', 2);
    _add('n', 1);
    final up = right && _gain(gain);
    store.touch();
    return Reward(gain, combo, false, up, up ? [_levelNews] : const []);
  }

  String get _levelNews => tr(
    'Naik ke level $level',
    'Level $level reached',
    'Nivel $level alcanzado',
    'Niveau $level atteint',
    'Stufe $level erreicht',
    'Nível $level alcançado',
  );

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
    if (_gain((boss ? 120 : 50) * (100 + perk('winXp')) ~/ 100)) news.add(_levelNews);
    final id = boss
        ? _bossDrops[min(_bossDrops.length - 1, rankBefore)]
        : _subDrops[min(_subDrops.length - 1, rankBefore * 2 + stageBefore)];
    final it = _grant(id);
    if (it != null) {
      news.add(
        tr(
          'Rampasan: ${it.name}',
          'Loot: ${it.name}',
          'Botín: ${it.name}',
          'Butin : ${it.name}',
          'Beute: ${it.name}',
          'Espólio: ${it.name}',
        ),
      );
    }
    if (boss) news.addAll(_feat('boss1'));
    if (boss && flawless) news.addAll(_feat('perfect'));
    store.touch();
    return news;
  }

  List<String> _feat(String id) {
    final f = (_g['feats'] ??= <dynamic>[]) as List;
    if (f.contains(id)) return const [];
    f.add(id);
    final name = feats.firstWhere((x) => x.id == id).name;
    return [tr('Pencapaian: $name', 'Feat: $name', 'Hazaña: $name', 'Exploit : $name', 'Tat: $name', 'Feito: $name')];
  }

  // ---------------------------------------------------------------- the build and the jobs

  Map<String, dynamic> get _bp => (_g['bp'] ??= <String, dynamic>{}) as Map<String, dynamic>;
  int _b(String k) => (_bp[k] as num?)?.toInt() ?? 0;
  void _add(String k, int n) => _bp[k] = _b(k) + n;

  /// the build of the title being won now
  Build get build => Build([_b('p'), _b('s'), _b('i'), _b('e')]);

  /// the build of the whole journey
  Build get career {
    final t = (_g['bt'] as List?)?.map((x) => (x as num).toInt()).toList();
    return build + Build(t != null && t.length == 4 ? t : const [0, 0, 0, 0]);
  }

  /// what decides a job when no build has been gathered (a title won before jobs existed, or by placement
  /// before the first answer): the four figures of the character
  Build get _basis {
    final b = build;
    return b.total >= 20 ? b : Build([accuracy + 1, speed, memory, diligence]);
  }

  List<dynamic> get _jobs {
    final l = (_g['jobs'] ??= <dynamic>['peasant']) as List;
    if (l.isEmpty) l.add('peasant');
    return l;
  }

  void _fill(int upTo) {
    final l = _jobs;
    while (l.length <= upTo) {
      l.add(Jobs.natural(l.length, Jobs.byId(l.last as String), _basis, career).id);
      store.touch();
    }
  }

  /// the job held at title [t]: the hidden one when one was earned there, otherwise the tree's
  Job jobAt(int t) {
    _fill(t);
    final h = (_g['hid'] as Map?)?['$t'] as String?;
    return Jobs.byId(h ?? _jobs[t] as String);
  }

  Job get job => jobAt(e.rank);

  /// the tree's own job at the title held (a hidden job keeps the branch underneath it)
  Job get branch {
    _fill(e.rank);
    return Jobs.byId(_jobs[e.rank] as String);
  }

  /// the jobs of the path so far, Peasant first
  List<Job> get path => [for (var t = 0; t <= e.rank; t++) jobAt(t)];

  /// every job ever held, for the map (a title lost keeps what was seen)
  Set<String> get known => {...((_g['seen'] as List?) ?? const []).cast<String>(), for (final j in path) j.id};

  /// the perks of the whole path add up
  int perk(String kind) {
    var n = 0;
    for (var t = 1; t <= e.rank; t++) {
      final p = jobAt(t).perk;
      if (p.kind == kind) n += p.v;
    }
    return n;
  }

  /// the branches open at the next title, and the one the build points to now (null before any answer)
  List<Job> get nextJobs => e.rank >= Engine.maxRank ? const [] : Jobs.children(branch);
  Job? get heading =>
      e.rank >= Engine.maxRank || build.total < 20 ? null : Jobs.natural(e.rank + 1, branch, build, career);

  bool _letterHeld(int tier) {
    final by = <String, List<Word>>{};
    for (final w in e.deck.tier(tier)) {
      by.putIfAbsent(w.id[0], () => []).add(w);
    }
    return by.values.any((l) => l.length >= 12 && l.every((w) => e.solid(w) && (e.mem(w)?.lapses ?? 1) == 0));
  }

  /// Right after a coronation: the build of the title just won decides the job. Returns it, with news lines.
  (Job, List<String>) onPromotion(int tier, bool flawless) {
    final l = _jobs;
    _fill(tier - 1);
    if (l.length > tier) l.removeRange(tier, l.length);
    final hid = (_g['hid'] ??= <String, dynamic>{}) as Map;
    hid.removeWhere((k, _) => (int.tryParse('$k') ?? 0) >= tier);
    final b = _basis, c = career;
    final natural = Jobs.natural(tier, Jobs.byId(l.last as String), b, c);
    l.add(natural.id);
    final secret = Jobs.hiddenFor(tier, build, c, {
      'n': _b('n'),
      'nt': _b('nt'),
      'bc': _b('bc'),
      'cz': _b('cz'),
      'czms': _b('czms'),
      'letter': tier == 3 && _letterHeld(tier) ? 1 : 0,
      'flawless': flawless ? 1 : 0,
    });
    if (secret != null) hid['$tier'] = secret.id;
    final got = secret ?? natural;
    final seen = (_g['seen'] ??= <dynamic>[]) as List;
    for (final j in path) {
      if (!seen.contains(j.id)) seen.add(j.id);
    }
    // the build starts again for the next title; the journey keeps the sum
    _g['bt'] = c.v;
    _g['bp'] = <String, dynamic>{};
    e.note('job', tier, extra: {'j': got.id});
    final news = <String>[
      tr(
        'Jalan baru: ${got.name}',
        'A new path: ${got.name}',
        'Un nuevo camino: ${got.name}',
        'Une nouvelle voie : ${got.name}',
        'Ein neuer Weg: ${got.name}',
        'Um novo caminho: ${got.name}',
      ),
      got.perk.text,
    ];
    if (tier >= 3) news.addAll(_feat('jobs3'));
    if (secret != null) news.addAll(_feat('secret'));
    store.touch();
    return (got, news);
  }

  // ---------------------------------------------------------------- feats and titles

  List<String> get earned => ((_g['feats'] as List?) ?? const []).cast<String>();

  /// the honorary title worn, in the language that is on (kept as the feat's id; older saves hold the words)
  String get title => titleFeat?.title ?? '';
  Feat? get titleFeat {
    final t = _g['title'] as String? ?? '';
    if (t.isEmpty) return null;
    for (final f in feats) {
      if (f.title != null && f.named(t)) return f;
    }
    return null;
  }

  void setTitle(String featId) {
    _g['title'] = featId;
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
        final name = feats.firstWhere((x) => x.id == id).name;
        news.add(
          tr('Pencapaian: $name', 'Feat: $name', 'Hazaña: $name', 'Exploit : $name', 'Tat: $name', 'Feito: $name'),
        );
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
        if (due >= 5) Quest('rev', due.clamp(5, 20), 30),
        if (fresh > 0) Quest('new', fresh, 40),
        if (lapsed >= 5) Quest('weak', 5, 45),
        Quest('clean', 10, 35),
        Quest('combo', 8, 30),
        Quest('fast', 5, 35),
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
    return _weekly = _load('wq', key, () => [Quest('days5', 5, 150), Quest('ans150', 150, 120)]);
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

  /// what a quest pays, with the perks of the path
  int questXp(Quest q) => q.xp * (100 + perk('questXp')) ~/ 100;

  /// takes a finished quest's reward; returns news (level up)
  List<String> claim(Quest q) {
    if (!q.done || q.claimed) return const [];
    q.claimed = true;
    final up = _gain(questXp(q));
    _saveQuests();
    store.touch();
    return [if (up) _levelNews];
  }

  // ---------------------------------------------------------------- advice

  List<int> _w(String k) => (((_g['wk'] as Map?)?[k]) as List?)?.map((x) => (x as num).toInt()).toList() ?? [0, 0];

  /// the weakest side of the learner right now, as a sentence; null when nothing stands out
  String? weakness() {
    final text = {
      's': tr(
        'Ejaanmu sering meleset satu huruf. Pelan sedikit saat mengetik kata panjang.',
        'Your spelling is often one letter off. Slow down a little on long words.',
        'A menudo fallas por una letra. Ve un poco más despacio con las palabras largas.',
        'Ton orthographe dérape souvent d’une lettre. Ralentis un peu sur les mots longs.',
        'Deine Schreibung liegt oft um einen Buchstaben daneben. Nimm dir bei langen Wörtern etwas mehr Zeit.',
        'Sua grafia costuma errar por uma letra. Vá um pouco mais devagar nas palavras longas.',
      ),
      'f': tr(
        'Artinya sudah kamu pegang, bentuk katanya yang sering meleset. Perhatikan kata sebelum celah.',
        'You have the meaning; it is the form of the word that slips. Look at the words before the gap.',
        'Ya sabes el significado; lo que se escapa es la forma. Mira las palabras antes del hueco.',
        'Tu connais le sens ; c’est la forme du mot qui t’échappe. Regarde les mots avant le trou.',
        'Die Bedeutung sitzt, die Form des Wortes rutscht. Sieh dir die Wörter vor der Lücke an.',
        'O sentido você tem; é a forma da palavra que escapa. Olhe as palavras antes da lacuna.',
      ),
      'm': tr(
        'Banyak arti yang belum melekat. Ulangi dulu sebelum menambah kata baru.',
        'Many meanings have not settled yet. Review before taking on new words.',
        'Muchos significados aún no se han asentado. Repasa antes de aprender palabras nuevas.',
        'Beaucoup de sens ne sont pas encore ancrés. Révise avant d’aborder de nouveaux mots.',
        'Viele Bedeutungen sitzen noch nicht. Wiederhole, bevor du neue Wörter angehst.',
        'Muitos sentidos ainda não se firmaram. Revise antes de pegar palavras novas.',
      ),
      'o': tr(
        'Susunan kalimatmu masih goyah. Kalimat pendek akan lebih sering muncul untuk disusun.',
        'Your word order still wavers. Short sentences will come up more often to be built.',
        'El orden de las palabras aún vacila. Aparecerán más frases cortas para construir.',
        'L’ordre des mots hésite encore. Des phrases courtes à construire reviendront plus souvent.',
        'Deine Wortstellung schwankt noch. Kurze Sätze kommen öfter zum Bauen.',
        'Sua ordem das palavras ainda vacila. Frases curtas vão aparecer mais vezes para montar.',
      ),
      'c': tr(
        'Pasangan kata (kolokasi) perlu diasah. Kartu kolokasi akan lebih sering muncul.',
        'Partner words (collocations) need work. Collocation cards will come up more often.',
        'Las palabras compañeras (colocaciones) necesitan trabajo. Aparecerán más a menudo.',
        'Les mots compagnons (collocations) demandent du travail. Ils reviendront plus souvent.',
        'Partnerwörter (Kollokationen) brauchen Übung. Kollokationskarten kommen öfter.',
        'As palavras parceiras (colocações) precisam de treino. Os cartões de colocação vão aparecer mais vezes.',
      ),
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
      out.add(
        tr(
          'Gelarmu goyah. Pertahankan dulu sebelum hal lain.',
          'Your title wavers. Defend it before anything else.',
          'Tu título se tambalea. Defiéndelo antes que nada.',
          'Ton titre vacille. Défends-le avant toute chose.',
          'Dein Titel wankt. Verteidige ihn vor allem anderen.',
          'Seu título vacila. Defenda-o antes de qualquer coisa.',
        ),
      );
    } else if (en != null && fightOpen) {
      out.add(
        tr(
          '${en.name} bisa dilawan sekarang. Peluang menangmu sekitar ${winChance()}%.',
          'The ${en.name} can be fought now. Your chance of winning is about ${winChance()}%.',
          'Ya puedes enfrentarte a ${en.name}. Tu probabilidad de ganar ronda el ${winChance()} %.',
          'Tu peux affronter ${en.name}. Tes chances de victoire sont d’environ ${winChance()} %.',
          'Gegen ${en.name} kannst du jetzt kämpfen. Deine Siegchance liegt bei etwa ${winChance()} %.',
          'Já dá para lutar contra ${en.name}. Sua chance de vencer é de cerca de ${winChance()}%.',
        ),
      );
    }
    if (p.reviews > 0 && p.fresh > 0) {
      out.add(
        tr(
          'Mulai dari ${p.reviews} ulangan, lalu ${p.fresh} kata baru.',
          'Start with ${p.reviews} reviews, then ${p.fresh} new words.',
          'Empieza con ${p.reviews} repasos y luego ${p.fresh} palabras nuevas.',
          'Commence par ${p.reviews} révisions, puis ${p.fresh} nouveaux mots.',
          'Beginne mit ${p.reviews} Wiederholungen, dann ${p.fresh} neue Wörter.',
          'Comece com ${p.reviews} revisões, depois ${p.fresh} palavras novas.',
        ),
      );
    } else if (p.reviews > 0) {
      out.add(
        tr(
          '${p.reviews} kata menunggu diulang.',
          '${p.reviews} words are waiting for review.',
          '${p.reviews} palabras esperan repaso.',
          '${p.reviews} mots attendent une révision.',
          '${p.reviews} Wörter warten auf Wiederholung.',
          '${p.reviews} palavras esperam revisão.',
        ),
      );
    } else if (p.fresh > 0) {
      out.add(
        tr(
          'Tidak ada ulangan. Waktu yang baik untuk ${p.fresh} kata baru.',
          'Nothing to review. A good time for ${p.fresh} new words.',
          'Nada que repasar. Buen momento para ${p.fresh} palabras nuevas.',
          'Rien à réviser. Bon moment pour ${p.fresh} nouveaux mots.',
          'Nichts zu wiederholen. Eine gute Zeit für ${p.fresh} neue Wörter.',
          'Nada para revisar. Boa hora para ${p.fresh} palavras novas.',
        ),
      );
    }
    final w = weakness();
    if (w != null) out.add(w);
    final h = heading;
    if (h != null && e.rank >= 1) {
      final s = build.shares, o = build.order;
      out.add(
        tr(
          'Build-mu condong ke ${statNames[o[0]]} (${(s[o[0]] * 100).round()}%), lalu ${statNames[o[1]]}.',
          'Your build leans to ${statNames[o[0]]} (${(s[o[0]] * 100).round()}%), then ${statNames[o[1]]}.',
          'Tu estilo se inclina hacia ${statNames[o[0]]} (${(s[o[0]] * 100).round()} %), luego ${statNames[o[1]]}.',
          'Ton style penche vers ${statNames[o[0]]} (${(s[o[0]] * 100).round()} %), puis ${statNames[o[1]]}.',
          'Dein Build neigt zu ${statNames[o[0]]} (${(s[o[0]] * 100).round()} %), dann ${statNames[o[1]]}.',
          'Seu build pende para ${statNames[o[0]]} (${(s[o[0]] * 100).round()}%), depois ${statNames[o[1]]}.',
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        tr(
          'Semua tugas hari ini selesai. Kembalilah besok.',
          'All of today\'s tasks are done. Come back tomorrow.',
          'Todas las tareas de hoy están hechas. Vuelve mañana.',
          'Toutes les tâches du jour sont faites. Reviens demain.',
          'Alle Aufgaben für heute sind erledigt. Komm morgen wieder.',
          'Todas as tarefas de hoje estão feitas. Volte amanhã.',
        ),
      );
    }
    return out;
  }
}
