/// The Android side (MainActivity.kt) on the method channel "verbarium/native": the files folder, the splash
/// hand-over and sound. Every call is safe without Android (tests): it does nothing and returns null.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Native {
  static const _ch = MethodChannel('verbarium/native');

  /// in tests: replaces the platform
  static bool off = false;

  static Future<T?> _call<T>(String m, [Object? a]) async {
    if (off || kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<T>(m, a);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> filesDir() => _call<String>('filesDir');
  static Future<void> ready() => _call<void>('ready');
  static Future<void> sfx(String name, double volume) => _call<void>('sfx', {'name': name, 'volume': volume});
  static Future<void> music(bool on, double volume, String track) =>
      _call<void>('music', {'on': on, 'volume': volume, 'track': track});
  static Future<void> openUrl(String url) => _call<void>('openUrl', url);

  /// Dukung Verbarium (Donate.kt, Google Play Billing): the products found on Play with their prices, and how many
  /// earlier purchases were finished just now; null when Play is not there or the products are not set up (the test
  /// APK from GitHub), and then the support page does not appear at all
  static Future<({List<({String id, String price})> items, int done})?> donProducts(List<String> ids) async {
    final s = await _call<String>('donProducts', json.encode(ids));
    if (s == null) return null;
    try {
      final m = json.decode(s) as Map;
      if (m['ok'] != true) return null;
      return (
        items: [for (final e in m['items'] as List) (id: '${(e as Map)['id']}', price: '${e['price']}')],
        done: (m['done'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// installed from the Play Store (read on the phone, no network): only then is Dukung Verbarium offered
  static Future<bool> fromPlay() async => await _call<bool>('fromPlay') ?? false;

  /// closes the connection to Google Play when the support page is left
  static Future<void> donEnd() => _call<void>('donEnd');

  /// ok | pending | cancel | error
  static Future<String> donBuy(String id) async => await _call<String>('donBuy', id) ?? 'error';

  /// Cadangan: the system's own file picker writes [text] to a file the learner chooses (Download, Drive, a card).
  /// ok | cancel | error
  static Future<String> backupSave(String name, String text) async =>
      await _call<String>('backupSave', {'name': name, 'text': text}) ?? 'error';

  /// the text of a backup file the learner picks; null when nothing was picked or it could not be read
  static Future<String?> backupOpen() => _call<String>('backupOpen');

  /// asks the practice widget on the home screen to read widget/deck.json again
  static Future<void> widgetRefresh() => _call<void>('widgetRefresh');
}
