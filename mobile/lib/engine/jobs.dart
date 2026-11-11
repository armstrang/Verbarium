/// Jobs: what the learner's character becomes. Nobody picks a job from a menu. While a title is being won, every
/// answer adds to one of four sides of the build (precision, swiftness, insight, endurance); at the coronation the
/// build decides which branch of the tree is taken. 37 jobs can be seen on the map, 6 more are hidden and are
/// given for rare ways of learning.
///
/// A job never touches memory or rank. It gives a perk (experience, a little room in the fights against the
/// guards of the road), a look for the sprite, and a line in the chronicle. The perks of every job on the path
/// held add up.
library;

import '../app/lang.dart';

const statNames = ['Precision', 'Swiftness', 'Insight', 'Endurance'];

/// the four sides of a build, as points
class Build {
  final List<int> v;
  const Build(this.v);

  int get total => v[0] + v[1] + v[2] + v[3];
  List<double> get shares => total == 0 ? const [0.25, 0.25, 0.25, 0.25] : [for (final x in v) x / total];

  /// the sides from the strongest down; equal sides keep their order
  List<int> get order {
    final l = [0, 1, 2, 3];
    l.sort((a, b) => v[b] != v[a] ? v[b].compareTo(v[a]) : a.compareTo(b));
    return l;
  }

  int get top => order[0];

  /// the strongest side other than [stat]
  int other(int stat) => order.firstWhere((x) => x != stat);

  /// the two strongest sides are close: the hybrid branch
  bool get balanced {
    final s = shares, o = order;
    return total > 0 && s[o[0]] - s[o[1]] < 0.06;
  }

  /// all four sides close together
  bool get even {
    final s = shares;
    final hi = s.reduce((a, b) => a > b ? a : b), lo = s.reduce((a, b) => a < b ? a : b);
    return total > 0 && hi - lo < 0.05;
  }

  Build operator +(Build o) => Build([for (var i = 0; i < 4; i++) v[i] + o.v[i]]);
}

class Perk {
  final String kind;
  final int v;
  const Perk(this.kind, this.v);

  String get text => switch (kind) {
    'xpCloze' => tr('+$v XP untuk tiap celah yang diisi bersih', '+$v XP for every gap filled cleanly', '+$v XP por cada hueco completado sin fallo', '+$v XP pour chaque trou rempli sans faute'),
    'xpBuild' => tr('+$v XP untuk tiap kalimat yang tersusun benar', '+$v XP for every sentence built right', '+$v XP por cada frase bien construida', '+$v XP pour chaque phrase bien construite'),
    'xpChoice' => tr('+$v XP untuk tiap arti yang dipilih benar', '+$v XP for every meaning chosen right', '+$v XP por cada significado bien elegido', '+$v XP pour chaque sens bien choisi'),
    'xpColloc' => tr('+$v XP untuk tiap pasangan kata yang benar', '+$v XP for every right partner word', '+$v XP por cada palabra compañera correcta', '+$v XP pour chaque mot compagnon juste'),
    'xpAll' => tr('+$v XP untuk setiap jawaban benar', '+$v XP for every right answer', '+$v XP por cada respuesta correcta', '+$v XP pour chaque bonne réponse'),
    'critWin' => tr('Jawaban kritis sampai ${6 + v} detik, bukan 6', 'Critical answers up to ${6 + v} seconds instead of 6', 'Respuestas críticas hasta ${6 + v} segundos en vez de 6', 'Réponses critiques jusqu’à ${6 + v} secondes au lieu de 6'),
    'critXp' => tr('+$v XP untuk tiap jawaban kritis', '+$v XP for every critical answer', '+$v XP por cada respuesta crítica', '+$v XP pour chaque réponse critique'),
    'comboCap' => tr('Bonus combo naik sampai +${5 + v} XP', 'The combo bonus grows up to +${5 + v} XP', 'El bonus de combo crece hasta +${5 + v} XP', 'Le bonus de combo monte jusqu’à +${5 + v} XP'),
    'subTime' => tr('+$v detik tiap kata saat melawan penjaga jalan', '+$v seconds per word against a guard of the road', '+$v segundos por palabra contra un guardián del camino', '+$v secondes par mot contre un gardien de la route'),
    'subHp' => tr('+$v nyawa saat melawan penjaga jalan', '+$v life against a guard of the road', '+$v vida contra un guardián del camino', '+$v vie contre un gardien de la route'),
    'questXp' => tr('+$v% XP dari quest', '+$v% XP from quests', '+$v % de XP en misiones', '+$v % d’XP des quêtes'),
    'dayXp' => tr('+$v XP untuk jawaban pertama tiap hari', '+$v XP for the first answer of each day', '+$v XP por la primera respuesta de cada día', '+$v XP pour la première réponse de chaque jour'),
    'nightXp' => tr('+$v XP untuk jawaban benar di malam hari', '+$v XP for right answers at night', '+$v XP por respuestas correctas de noche', '+$v XP pour les bonnes réponses la nuit'),
    'solidXp' => tr('+$v XP saat mengingat kata yang sudah lama', '+$v XP for recalling a word held for long', '+$v XP por recordar una palabra guardada mucho tiempo', '+$v XP pour un mot retenu depuis longtemps'),
    'lapseXp' => tr('+$v XP saat merebut kembali kata yang pernah lupa', '+$v XP for winning back a word once lost', '+$v XP por recuperar una palabra perdida', '+$v XP pour un mot perdu puis reconquis'),
    'winXp' => tr('+$v% XP dari pertarungan yang dimenangi', '+$v% XP from fights won', '+$v % de XP en combates ganados', '+$v % d’XP des combats gagnés'),
    'formXp' => tr('+$v XP untuk bentuk kata yang tepat', '+$v XP for the right form of a word', '+$v XP por la forma correcta de una palabra', '+$v XP pour la bonne forme d’un mot'),
    _ => tr('Belum ada perk', 'No perk yet', 'Aún sin ventaja', 'Pas encore d’atout'),
  };
}

/// how a job looks on the sprite: headgear, what is carried, the colour of the tunic (see ui/pixel.dart)
class Garb {
  final int head, arm, tint;
  const Garb(this.head, this.arm, this.tint);
}

class Job {
  final String id, name;
  final int tier, line;
  final Perk perk;
  final Garb garb;
  final String _hintId, _hintEn;
  final bool hidden;
  const Job(this.id, this.name, this.tier, this.line, this.perk, this.garb, this._hintId, this._hintEn, {this.hidden = false});

  /// how this job is reached, told without giving everything away
  String get hint => tr(_hintId, _hintEn);
}

class Jobs {
  // head: 0 bare, 1 hood, 2 helm, 3 pointed hat, 4 crown, 5 band, 6 straw hat
  // arm:  0 stick, 1 sword, 2 spear, 3 bow, 4 dagger, 5 staff, 6 mace, 7 book
  static const all = [
    Job('peasant', 'Peasant', 0, 0, Perk('none', 0), Garb(6, 0, 0), 'Semua orang mulai dari ladang.', 'Everyone starts in the fields.'),

    // ---- Squire: the strongest side of the build
    Job(
      'blade',
      'Blade',
      1,
      0,
      Perk('xpCloze', 1),
      Garb(0, 1, 2),
      'Bagi yang paling sering mengisi celah tanpa cela.',
      'For those who most often fill the gap without a fault.',
    ),
    Job(
      'scout',
      'Scout',
      1,
      1,
      Perk('critWin', 1),
      Garb(1, 4, 1),
      'Bagi yang tangannya lebih cepat dari ragunya.',
      'For those whose hand is quicker than their doubt.',
    ),
    Job('scribe', 'Scribe', 1, 2, Perk('solidXp', 2), Garb(0, 7, 3), 'Bagi yang ingatannya bertahan paling lama.', 'For those whose memory lasts the longest.'),
    Job('sentinel', 'Sentinel', 1, 3, Perk('dayXp', 10), Garb(5, 2, 0), 'Bagi yang datang setiap hari.', 'For those who come every day.'),

    // ---- Knight: the line, and the next strongest side
    Job('duelist', 'Duelist', 2, 0, Perk('critXp', 2), Garb(5, 1, 5), 'Bagi Blade yang tangannya juga cepat.', 'For a Blade whose hand is quick as well.'),
    Job('crusader', 'Crusader', 2, 0, Perk('formXp', 2), Garb(2, 1, 6), 'Bagi Blade yang sabar dan tekun.', 'For a Blade who is patient and steady.'),
    Job('ranger', 'Ranger', 2, 1, Perk('xpBuild', 2), Garb(1, 3, 1), 'Bagi Scout yang jarang meleset.', 'For a Scout who seldom misses.'),
    Job(
      'rogue',
      'Rogue',
      2,
      1,
      Perk('comboCap', 2),
      Garb(1, 4, 5),
      'Bagi Scout yang mengandalkan ingatan dan napas panjang.',
      'For a Scout who leans on memory and a long breath.',
    ),
    Job('mage', 'Mage', 2, 2, Perk('xpChoice', 1), Garb(3, 5, 3), 'Bagi Scribe yang tepat atau cepat.', 'For a Scribe who is exact or quick.'),
    Job('cleric', 'Cleric', 2, 2, Perk('lapseXp', 3), Garb(0, 6, 6), 'Bagi Scribe yang tak pernah absen.', 'For a Scribe who never stays away.'),
    Job('guardian', 'Guardian', 2, 3, Perk('subHp', 1), Garb(2, 2, 9), 'Bagi Sentinel yang tepat atau cepat.', 'For a Sentinel who is exact or quick.'),
    Job('monk', 'Monk', 2, 3, Perk('questXp', 15), Garb(0, 0, 10), 'Bagi Sentinel yang ingatannya dalam.', 'For a Sentinel whose memory runs deep.'),

    // ---- Baron: the own branch, or the hybrid when the two strongest sides are close
    Job(
      'blademaster',
      'Blademaster',
      3,
      0,
      Perk('xpCloze', 2),
      Garb(5, 1, 2),
      'Bagi Duelist yang tetap pada jalannya.',
      'For a Duelist who keeps to the path.',
    ),
    Job('paladin', 'Paladin', 3, 0, Perk('winXp', 25), Garb(2, 6, 7), 'Bagi Crusader yang tetap pada jalannya.', 'For a Crusader who keeps to the path.'),
    Job(
      'spellblade',
      'Spellblade',
      3,
      0,
      Perk('critXp', 3),
      Garb(5, 1, 4),
      'Bagi keturunan Blade yang dua sisi terkuatnya hampir sama.',
      'For one of the Blade line whose two strongest sides are nearly equal.',
    ),
    Job('marksman', 'Marksman', 3, 1, Perk('critWin', 1), Garb(1, 3, 8), 'Bagi Ranger yang tetap pada jalannya.', 'For a Ranger who keeps to the path.'),
    Job('nightblade', 'Nightblade', 3, 1, Perk('comboCap', 3), Garb(1, 4, 4), 'Bagi Rogue yang tetap pada jalannya.', 'For a Rogue who keeps to the path.'),
    Job(
      'trickster',
      'Trickster',
      3,
      1,
      Perk('xpColloc', 3),
      Garb(3, 4, 10),
      'Bagi keturunan Scout yang dua sisi terkuatnya hampir sama.',
      'For one of the Scout line whose two strongest sides are nearly equal.',
    ),
    Job('wizard', 'Wizard', 3, 2, Perk('solidXp', 3), Garb(3, 5, 4), 'Bagi Mage yang tetap pada jalannya.', 'For a Mage who keeps to the path.'),
    Job('bishop', 'Bishop', 3, 2, Perk('lapseXp', 4), Garb(5, 5, 6), 'Bagi Cleric yang tetap pada jalannya.', 'For a Cleric who keeps to the path.'),
    Job(
      'enchanter',
      'Enchanter',
      3,
      2,
      Perk('xpChoice', 2),
      Garb(3, 7, 8),
      'Bagi keturunan Scribe yang dua sisi terkuatnya hampir sama.',
      'For one of the Scribe line whose two strongest sides are nearly equal.',
    ),
    Job('warden', 'Warden', 3, 3, Perk('subTime', 3), Garb(2, 2, 1), 'Bagi Guardian yang tetap pada jalannya.', 'For a Guardian who keeps to the path.'),
    Job('mystic', 'Mystic', 3, 3, Perk('dayXp', 20), Garb(1, 5, 10), 'Bagi Monk yang tetap pada jalannya.', 'For a Monk who keeps to the path.'),
    Job(
      'runekeeper',
      'Runekeeper',
      3,
      3,
      Perk('questXp', 20),
      Garb(5, 7, 9),
      'Bagi keturunan Sentinel yang dua sisi terkuatnya hampir sama.',
      'For one of the Sentinel line whose two strongest sides are nearly equal.',
    ),

    // ---- Duke: the line, and whether hand (precision, swiftness) or mind (insight, endurance) leads
    Job(
      'champion',
      'Champion',
      4,
      0,
      Perk('xpCloze', 3),
      Garb(2, 1, 7),
      'Bagi keturunan Blade yang tangannya memimpin.',
      'For one of the Blade line whose hand leads.',
    ),
    Job(
      'inquisitor',
      'Inquisitor',
      4,
      0,
      Perk('formXp', 3),
      Garb(3, 6, 5),
      'Bagi keturunan Blade yang pikirannya memimpin.',
      'For one of the Blade line whose mind leads.',
    ),
    Job(
      'windrunner',
      'Windrunner',
      4,
      1,
      Perk('critXp', 4),
      Garb(1, 3, 6),
      'Bagi keturunan Scout yang tangannya memimpin.',
      'For one of the Scout line whose hand leads.',
    ),
    Job(
      'phantom',
      'Phantom',
      4,
      1,
      Perk('comboCap', 4),
      Garb(1, 4, 9),
      'Bagi keturunan Scout yang pikirannya memimpin.',
      'For one of the Scout line whose mind leads.',
    ),
    Job(
      'battlemage',
      'Battlemage',
      4,
      2,
      Perk('xpBuild', 4),
      Garb(2, 5, 2),
      'Bagi keturunan Scribe yang tangannya memimpin.',
      'For one of the Scribe line whose hand leads.',
    ),
    Job(
      'archmage',
      'Archmage',
      4,
      2,
      Perk('solidXp', 5),
      Garb(3, 5, 7),
      'Bagi keturunan Scribe yang pikirannya memimpin.',
      'For one of the Scribe line whose mind leads.',
    ),
    Job(
      'ironclad',
      'Ironclad',
      4,
      3,
      Perk('subHp', 2),
      Garb(2, 6, 9),
      'Bagi keturunan Sentinel yang tangannya memimpin.',
      'For one of the Sentinel line whose hand leads.',
    ),
    Job(
      'elder',
      'Elder',
      4,
      3,
      Perk('dayXp', 30),
      Garb(0, 5, 6),
      'Bagi keturunan Sentinel yang pikirannya memimpin.',
      'For one of the Sentinel line whose mind leads.',
    ),

    // ---- King: the strongest side of the whole journey
    Job(
      'sovereign',
      'Sovereign',
      5,
      0,
      Perk('xpCloze', 4),
      Garb(4, 1, 4),
      'Bagi yang sepanjang jalan paling tepat.',
      'For the one who was the most exact all the way.',
    ),
    Job(
      'conqueror',
      'Conqueror',
      5,
      1,
      Perk('critXp', 6),
      Garb(4, 2, 2),
      'Bagi yang sepanjang jalan paling cepat.',
      'For the one who was the quickest all the way.',
    ),
    Job(
      'sage',
      'Sage',
      5,
      2,
      Perk('solidXp', 8),
      Garb(4, 5, 3),
      'Bagi yang sepanjang jalan paling dalam ingatannya.',
      'For the one whose memory ran deepest all the way.',
    ),
    Job(
      'paragon',
      'Paragon',
      5,
      3,
      Perk('questXp', 50),
      Garb(4, 6, 7),
      'Bagi yang sepanjang jalan paling setia.',
      'For the one who was the most faithful all the way.',
    ),

    // ---- hidden: rare ways of learning
    Job(
      'nightwatch',
      'Nightwatch',
      1,
      0,
      Perk('nightXp', 2),
      Garb(1, 2, 5),
      'Ada yang belajar saat yang lain tidur.',
      'Some learn while the others sleep.',
      hidden: true,
    ),
    Job(
      'berserker',
      'Berserker',
      2,
      0,
      Perk('comboCap', 4),
      Garb(0, 6, 2),
      'Rantai yang panjang sekali, tanpa putus.',
      'A very long chain, never broken.',
      hidden: true,
    ),
    Job(
      'lexicon',
      'Lexicon Warden',
      3,
      0,
      Perk('formXp', 4),
      Garb(5, 7, 7),
      'Satu huruf, dijaga sampai kata terakhirnya.',
      'One letter, guarded down to its last word.',
      hidden: true,
    ),
    Job(
      'oracle',
      'Oracle',
      3,
      0,
      Perk('winXp', 50),
      Garb(1, 5, 6),
      'Seorang boss tumbang tanpa satu pukulan pun meleset.',
      'A boss fell without a single blow going astray.',
      hidden: true,
    ),
    Job(
      'chronomancer',
      'Chronomancer',
      4,
      0,
      Perk('critWin', 2),
      Garb(3, 5, 8),
      'Waktu seakan melambat bagi yang cukup cepat.',
      'Time seems to slow for those who are fast enough.',
      hidden: true,
    ),
    Job('polymath', 'Polymath', 5, 0, Perk('xpAll', 2), Garb(4, 7, 6), 'Empat sisi, sama kuat.', 'Four sides, equally strong.', hidden: true),
  ];

  static final _byId = {for (final j in all) j.id: j};
  static Job byId(String? id) => _byId[id] ?? all[0];

  static List<Job> get visible => [
    for (final j in all)
      if (!j.hidden) j,
  ];
  static List<Job> get secret => [
    for (final j in all)
      if (j.hidden) j,
  ];
  static List<Job> tier(int t) => [
    for (final j in all)
      if (j.tier == t && !j.hidden) j,
  ];

  static const _squire = ['blade', 'scout', 'scribe', 'sentinel'];
  // per line: [knight a, knight b], and which "other" side leads to a
  static const _knight = [
    ['duelist', 'crusader'],
    ['ranger', 'rogue'],
    ['mage', 'cleric'],
    ['guardian', 'monk'],
  ];
  static const _own = {
    'duelist': 'blademaster',
    'crusader': 'paladin',
    'ranger': 'marksman',
    'rogue': 'nightblade',
    'mage': 'wizard',
    'cleric': 'bishop',
    'guardian': 'warden',
    'monk': 'mystic',
  };
  static const _hybrid = ['spellblade', 'trickster', 'enchanter', 'runekeeper'];
  static const _duke = [
    ['champion', 'inquisitor'],
    ['windrunner', 'phantom'],
    ['battlemage', 'archmage'],
    ['ironclad', 'elder'],
  ];
  static const _king = ['sovereign', 'conqueror', 'sage', 'paragon'];

  static bool _first(int line, int other) => switch (line) {
    0 => other == 1,
    1 => other == 0,
    _ => other <= 1,
  };

  /// The job the tree gives at [tier] to someone who held [parent] (a job of the tree, never a hidden one), from
  /// the build [b] of the title just won and the build of the whole journey.
  static Job natural(int tier, Job parent, Build b, Build career) {
    final line = parent.line;
    switch (tier) {
      case 1:
        return byId(_squire[b.top]);
      case 2:
        return byId(_knight[line][_first(line, b.other(line)) ? 0 : 1]);
      case 3:
        // someone placed straight past Knight has no knight job to branch from: take the line's first
        final own = _own[parent.id] ?? _own[_knight[line][0]]!;
        return byId(b.balanced ? _hybrid[line] : own);
      case 4:
        return byId(_duke[line][b.top <= 1 ? 0 : 1]);
      case 5:
        return byId(_king[career.top]);
      default:
        return all[0];
    }
  }

  /// the branches open from [parent] at the next tier
  static List<Job> children(Job parent) {
    final line = parent.line;
    return switch (parent.tier) {
      0 => [for (final id in _squire) byId(id)],
      1 => [for (final id in _knight[line]) byId(id)],
      2 => [byId(_own[parent.id]), byId(_hybrid[line])],
      3 => [for (final id in _duke[line]) byId(id)],
      4 => [for (final id in _king) byId(id)],
      _ => const [],
    };
  }

  /// A hidden job earned at [tier], or null. [x]: n answers and nt night answers while the title was being won,
  /// bc the best combo, cz right gaps and czms their time, letter 1 when a whole letter is held, flawless 1 when
  /// the boss fell without a miss.
  static Job? hiddenFor(int tier, Build b, Build career, Map<String, num> x) {
    num v(String k) => x[k] ?? 0;
    switch (tier) {
      case 1:
        if (v('n') >= 80 && v('nt') / v('n') >= 0.5) return byId('nightwatch');
      case 2:
        if (v('bc') >= 100) return byId('berserker');
      case 3:
        if (v('letter') == 1) return byId('lexicon');
        if (v('flawless') == 1) return byId('oracle');
      case 4:
        if (v('cz') >= 150 && v('czms') / v('cz') < 4500) return byId('chronomancer');
      case 5:
        if (career.total >= 2000 && career.even) return byId('polymath');
    }
    return null;
  }
}
