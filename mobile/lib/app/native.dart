/// The Android side (MainActivity.kt) on the method channel "verbarium/native": the files folder, the splash
/// hand-over and sound. Every call is safe without Android (tests): it does nothing and returns null.
library;

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
  static Future<void> music(bool on, double volume, String track) => _call<void>('music', {'on': on, 'volume': volume, 'track': track});
  static Future<void> openUrl(String url) => _call<void>('openUrl', url);
}
