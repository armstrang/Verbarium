/// The progress store: one JSON document, kept in memory and written to the app's own files folder
/// (`files/store/state.json`) a moment after each change. It is written to a temporary file first and then
/// renamed, so a crash never leaves half a file.
///
/// Keys (never rename one: learners' progress depends on them):
///   v      schema version (1)
///   set    settings {banner, perDay, music, musicVol, sfx, theme, calm, onb}
///   mem    {word id: [stability days, due ms, reps, lapses, last ms, last answer clean 0/1]}
///   log    {yyyymmdd: [new words, reviews, right, wrong]}
///   rank   0 Petani … 5 Raja
///   ev     chronicle entries [{t, k, r, a, b}]
///   win    the last review answers on ranks already held (1 right, 0 wrong)
///   shaky  ms since when the title wavers (0 = steady)
///   cool   ms until the next coronation trial is allowed
///   stage  0..2: stage I, II, III inside the rank · subcool: ms until the next sub-boss fight
///   ease, ret   the learner's own memory growth factor and the answers it is tuned from
///   er     {word id: last kind of slip}  ·  placed  1 after placement
///   game   everything of the game layer (engine/game.dart): xp, gear, quests, feats, figures
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
  static const schema = 1;
  final Backend backend;
  Map<String, dynamic> data = {};
  Timer? _timer;

  Store(this.backend) {
    final text = backend.load();
    if (text != null) {
      try {
        final d = json.decode(text);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
    }
    data['v'] ??= schema;
  }

  Map<String, dynamic> map(String key) {
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
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    backend.save(json.encode(data));
  }
}
