/// The app's state: the store, the deck for the chosen banner, the engine, settings, sound.
library;

import 'dart:io';

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

  final Store store;
  final int Function()? clock;
  late Deck deck;
  late Engine engine;
  late Game game;

  App._(this.store, this.clock);

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

  Future<void> _load() async {
    lang.code = langCode;
    deck = await Deck.load(banner.isEmpty ? 'toefl' : banner);
    engine = Engine(store, deck, clock: clock);
    game = Game(store, engine);
  }

  Map<String, dynamic> get _set => store.map('set');

  String get banner => _set['banner'] as String? ?? '';
  bool get british => banner == 'ielts';

  /// the language the learner learns through: 'id', 'en' (monolingual), 'es' or 'fr'
  String get langCode => switch (_set['lang']) {
    'en' => 'en',
    'es' => 'es',
    'fr' => 'fr',
    _ => 'id',
  };
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
    store.touch();
    if (key == 'music' || key == 'musicVol') syncMusic();
    if (key == 'lang') lang.code = langCode;
    notifyListeners();
  }

  Future<void> chooseBanner(String b) async {
    _set['banner'] = b;
    store.touch();
    await _load();
    notifyListeners();
  }

  void finishOnboarding() {
    _set['onb'] = 1;
    store.flush();
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

  Future<void> resetProgress() async {
    engine.reset();
    await _load();
    notifyListeners();
  }
}
