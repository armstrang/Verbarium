/// The progress store: one JSON document, kept in memory and written to the app's own files folder
/// (`files/store/state.json`) a moment after each change. It is written to a temporary file first and then
/// renamed, so a crash never leaves half a file.
///
/// Keys (never rename one: learners' progress depends on them):
///   v      schema version (2: seven titles; a version 1 file is moved up once when it is opened, see [Store.migrate])
///   set    settings {banner, lang, perDay, music, musicVol, sfx, theme, calm, onb}
///   mem    {word id: [stability days, due ms, reps, lapses, last ms, last answer clean 0/1]}
///   log    {yyyymmdd: [new words, reviews, right, wrong]}
///   rank   0 Peasant, 1 Squire, 2 Knight, 3 Baron, 4 Count, 5 Duke, 6 King
///   ev     chronicle entries [{t, k, r, a, b}]
///   win    the last review answers on ranks already held (1 right, 0 wrong)
///   shaky  ms since when the title wavers (0 = steady)
///   cool   ms until the next coronation trial is allowed
///   stage  0..2: stage I, II, III inside the rank · subcool: ms until the next sub-boss fight
///   ease, ret   the learner's own memory growth factor and the answers it is tuned from
///   er     {word id: last kind of slip}  ·  placed  1 after placement
///   game   everything of the game layer (engine/game.dart): xp, gear, quests, feats, figures
///   realms {de, es, fr, pt: one kingdom of another language each, with the same keys again (mem, log, rank, ev,
///          game, …) but without set: the settings are shared}. English (Aldmere) keeps the top-level keys.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract class Backend {
  String? load();
  void save(String text);
}

class MemoryBackend implements Backend {
  String? text;
  MemoryBackend([this.text]);
  @override
  String? load() => text;
  @override
  void save(String t) => text = t;
}

class FileBackend implements Backend {
  final Directory dir;
  FileBackend(this.dir);
  File get _file => File('${dir.path}/state.json');

  @override
  String? load() {
    try {
      if (_file.existsSync()) return _file.readAsStringSync();
      final bak = File('${dir.path}/state.json.bak');
      if (bak.existsSync()) return bak.readAsStringSync();
    } catch (_) {}
    return null;
  }

  @override
  void save(String text) {
    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final tmp = File('${dir.path}/state.json.tmp');
      tmp.writeAsStringSync(text, flush: true);
      if (_file.existsSync()) _file.copySync('${dir.path}/state.json.bak');
      tmp.renameSync(_file.path);
    } catch (_) {}
  }
}

class Store {
  static const schema = 2;
  final Backend backend;
  Map<String, dynamic> data = {};
  Timer? _timer;

  /// set for the store of one kingdom: its keys live inside the parent's `realms`, and it saves through the parent
  final Store? _parent;

  Store._child(Store parent, this.data) : backend = parent.backend, _parent = parent;

  /// the store of the kingdom of [code] ('de', 'es', 'fr', 'pt'), kept under `realms`
  Store realm(String code) {
    final all = map('realms');
    final m = all[code];
    final d = m is Map<String, dynamic> ? m : <String, dynamic>{'v': schema};
    all[code] = d;
    return Store._child(this, d);
  }

  Store(this.backend) : _parent = null {
    final text = backend.load();
    if (text != null) {
      try {
        final d = json.decode(text);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
    }
    if (text == null || data.isEmpty) data['v'] = schema;
    migrate(data);
  }

  /// Version 1 had six titles (Peasant … King, Squire = B1). Version 2 has seven, one per CEFR level, with the Count
  /// between Baron and Duke: every title held moves up one so that it keeps its CEFR level (a B1 Squire is now a
  /// B1 Knight). The chronicle follows; jobs keep their tier, and a job for the Count is put in for anyone who had
  /// gone past the Baron, on the side of their own line.
  static void migrate(Map<String, dynamic> data) {
    final v = (data['v'] as num?)?.toInt() ?? 1;
    if (v >= 2) return;
    int up(Object? r) {
      final n = (r as num?)?.toInt() ?? 0;
      return n >= 1 ? n + 1 : n;
    }

    if (data['rank'] is num) data['rank'] = up(data['rank']);
    final ev = data['ev'];
    if (ev is List) {
      for (final e in ev) {
        if (e is! Map || e['r'] is! num) continue;
        final r = (e['r'] as num).toInt();
        // a job event carries the job's tier, which only moves from the Duke up; the rest carry a title
        e['r'] = e['k'] == 'job' ? (r >= 4 ? r + 1 : r) : up(r);
      }
    }
    final g = data['game'];
    if (g is Map) {
      final jobs = g['jobs'];
      if (jobs is List && jobs.length > 4) jobs.insert(4, _countOf[jobs[3]] ?? 'justicar');
      final hid = g['hid'];
      if (hid is Map) {
        final moved = <String, dynamic>{
          for (final e in hid.entries)
            (int.tryParse('${e.key}') ?? 0) >= 4 ? '${int.parse('${e.key}') + 1}' : '${e.key}': e.value,
        };
        hid
          ..clear()
          ..addAll(moved);
      }
    }
    data['v'] = 2;
  }

  /// the Count's job that keeps to the line of a Baron's job
  static const _countOf = {
    'blademaster': 'justicar',
    'paladin': 'justicar',
    'spellblade': 'justicar',
    'marksman': 'pathfinder',
    'nightblade': 'pathfinder',
    'trickster': 'pathfinder',
    'wizard': 'loremaster',
    'bishop': 'loremaster',
    'enchanter': 'loremaster',
    'warden': 'bulwark',
    'mystic': 'bulwark',
    'runekeeper': 'bulwark',
  };

  Map<String, dynamic> map(String key) {
    // every kingdom shares the settings
    if (key == 'set' && _parent != null) return _parent.map('set');
    final v = data[key];
    if (v is Map<String, dynamic>) return v;
    final m = <String, dynamic>{};
    data[key] = m;
    return m;
  }

  List<dynamic> list(String key) {
    final v = data[key];
    if (v is List) return v;
    final l = <dynamic>[];
    data[key] = l;
    return l;
  }

  int integer(String key, [int fallback = 0]) {
    final v = data[key];
    return v is num ? v.toInt() : fallback;
  }

  void set(String key, Object? value) {
    data[key] = value;
    touch();
  }

  /// write soon (changes of one moment go out together)
  void touch() {
    if (_parent != null) return _parent.touch();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), flush);
  }

  void flush() {
    if (_parent != null) return _parent.flush();
    _timer?.cancel();
    _timer = null;
    backend.save(json.encode(data));
  }
}
