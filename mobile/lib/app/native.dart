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

  /// ok | pending | cancel | error
  static Future<String> donBuy(String id) async => await _call<String>('donBuy', id) ?? 'error';
}
