/// The app's state: the store, the deck for the chosen banner, the engine, settings, sound.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/deck.dart';
import '../data/store.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import 'lang.dart' as lang;
import 'native.dart';

class App extends ChangeNotifier {
  static late App I;

  /// the whole save; [store] is the part of the kingdom being played (the same object in Aldmere)
  final Store root;
  Store store;
  final int Function()? clock;
  late Deck deck;
  late Engine engine;
  late Game game;

  App._(this.root, this.clock) : store = root;

  /// counts every change; [Look] carries it, so whatever draws from the app's state is redrawn
  int stamp = 0;

  @override
  void notifyListeners() {
    stamp++;
    super.notifyListeners();
  }

  static Future<App> boot({Backend? backend, int Function()? clock}) async {
    var b = backend;
    if (b == null) {
      final dir = await Native.filesDir();
      b = dir == null ? MemoryBackend() : FileBackend(Directory('$dir/store'));
    }
    final app = App._(Store(b), clock);
    await app._load();
    app.engine.checkDemotion();
    I = app;
    return app;
  }

  /// the phone's language; a new learner starts in it when Verbarium speaks it, otherwise in English
  static String Function() phoneLanguage = () => ui.PlatformDispatcher.instance.locale.languageCode;

  Future<void> _load() async {
    if (!onboarded && _set['lang'] == null) {
      final p = phoneLanguage();
      _set['lang'] = const ['id', 'en', 'es', 'fr', 'de', 'pt'].contains(p) ? p : 'en';
    }
    lang.code = langCode;
    lang.via = via;
    final k = realm;
    if (k == 'en') {
      store = root;
      deck = await Deck.load(banner.isEmpty ? 'toefl' : banner);
    } else {
      store = root.realm(k);
      deck = await Deck.loadRealm(k);
    }
    engine = Engine(store, deck, clock: clock);
    game = Game(store, engine);
  }

  Map<String, dynamic> get _set => root.map('set');

  String get banner => _set['banner'] as String? ?? '';
  bool get british => realm == 'en' && banner == 'ielts';

  /// the kingdom being played: 'en' Aldmere, or 'de', 'es', 'fr', 'pt'
  String get realm => Kingdom.all.any((k) => k.code == _set['realm']) ? _set['realm'] as String : 'en';
  Kingdom get kingdom => Kingdom.of(realm);

  /// the kingdom's place in Kingdom.all: the livery the hero wears there
  int get livery => Kingdom.all.indexWhere((k) => k.code == realm);

  /// where another kingdom stands without loading it: the title held and the words met
  ({int rank, int seen}) standing(String code) {
    final m = code == 'en' ? root.data : (root.map('realms')[code] as Map<String, dynamic>? ?? const {});
    final mem = m['mem'];
    return (rank: ((m['rank'] as num?)?.toInt() ?? 0).clamp(0, Engine.maxRank), seen: mem is Map ? mem.length : 0);
  }

  /// go to another kingdom: its own deck, title, character and chronicle
  Future<void> chooseRealm(String code) async {
    if (code == realm) return;
    _set['realm'] = code;
    root.flush();
    await _load();
    engine.checkDemotion();
    syncMusic();
    notifyListeners();
  }

  /// the language the learner learns through, the same in every kingdom: 'id', 'en' (monolingual in Aldmere), 'es',
  /// 'fr', 'de' or 'pt'
  String get langCode => switch (_set['lang']) {
    'en' => 'en',
    'es' => 'es',
    'fr' => 'fr',
    'de' => 'de',
    'pt' => 'pt',
    _ => 'id',
  };

  /// a kingdom whose own language is the learning language cannot explain itself: its meanings are shown in another
  /// language, chosen once per kingdom (`set.via`), English until then
  bool get clash => realm != 'en' && realm == langCode;
  bool get viaChosen => (_set['via'] as Map?)?[realm] != null;
  String get via => clash ? ((_set['via'] as Map?)?[realm] as String? ?? 'en') : '';
  void chooseVia(String c) {
    final m = Map<String, dynamic>.from(_set['via'] as Map? ?? const {});
    m[realm] = c;
    put('via', m);
  }

  bool get english => langCode == 'en';
  bool get onboarded => _set['onb'] == 1;
  int get perDay => engine.perDay;
  bool get musicOn => _set['music'] != 0;
  double get musicVol => (_set['musicVol'] as num?)?.toDouble() ?? 0.45;
  bool get sfxOn => _set['sfx'] != 0;
  String get theme => _set['theme'] as String? ?? 'system';

  /// fewer and gentler animations (Settings); the phone's own setting is honoured as well
  bool get calm => _set['calm'] == 1;

  /// Dukung Verbarium: consumable products on Google Play that unlock nothing
  static const donIds = ['donasi_kecil', 'donasi_sedang', 'donasi_besar'];

  /// how many times this phone has supported Verbarium (only counted here, never sent anywhere)
  int get donations => (_set['dn'] as num?)?.toInt() ?? 0;
  void donAdd(int n) {
    if (n > 0) put('dn', donations + n);
  }

  void put(String key, Object value) {
    _set[key] = value;
    root.touch();
    if (key == 'music' || key == 'musicVol') syncMusic();
    if (key == 'lang' || key == 'via') {
      lang.code = langCode;
      lang.via = via;
    }
    notifyListeners();
  }

  Future<void> chooseBanner(String b) async {
    _set['banner'] = b;
    root.touch();
    await _load();
    notifyListeners();
  }

  void finishOnboarding() {
    _set['onb'] = 1;
    root.flush();
    notifyListeners();
  }

  /// after answers, trials, anything that moves progress
  void changed() {
    syncMusic();
    notifyListeners();
  }

  void sfx(String name, [double volume = 1]) {
    if (!sfxOn) return;
    // a tap and a blow sound like the character who makes them: the Peasant on wood, then each line its own
    // family (Blade steel, Scout string and wind, Scribe ink and bells, Sentinel wood and stone), richer from tier 3
    final job = game.job;
    final line = job.tier == 0 ? 'p' : '${job.line}';
    switch (name) {
      case 'tap':
        Native.sfx('tap_$line', volume);
      case 'hit':
        Native.sfx(job.tier >= 3 ? 'hitx_$line' : 'hit_$line', volume);
      case 'crit':
        Native.sfx('crit', volume * 0.7);
        Native.sfx(line == 'p' ? 'hit_p' : 'hitx_$line', volume);
      default:
        Native.sfx(name, volume);
    }
  }

  void haptic({bool strong = false}) {
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// in a fight the battle tune plays; otherwise the tune of the title held
  bool battle = false;

  void syncMusic() => Native.music(musicOn, musicVol, battle ? 'battle' : 'm${engine.rank}');

  void setBattle(bool on) {
    if (battle == on) return;
    battle = on;
    syncMusic();
  }

  /// a backup read back in place of everything on this phone: every kingdom, the settings and the chronicle
  Future<void> restore(Map<String, dynamic> data) async {
    root.replace(data);
    await _load();
    engine.checkDemotion();
    syncMusic();
    notifyListeners();
  }

  Future<void> resetProgress() async {
    engine.reset();
    await _load();
    notifyListeners();
  }
}
