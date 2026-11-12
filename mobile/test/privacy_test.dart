// Verbarium sends nothing anywhere. The INTERNET permission in the built app comes only from Google Play Billing
// (Donate.kt, for Dukung Verbarium); no code of ours may open a connection of its own.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _files(String dir, String ext) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith(ext));

void main() {
  test('no Dart code talks to the network', () {
    const banned = [
      'HttpClient',
      'package:http/',
      'WebSocket',
      'Socket.connect',
      'RawSocket',
      'HttpRequest',
      'Uri.http',
    ];
    for (final f in _files('lib', '.dart')) {
      final s = f.readAsStringSync();
      for (final b in banned) {
        expect(s.contains(b), isFalse, reason: '${f.path} uses $b');
      }
    }
  });

  test('no Kotlin code talks to the network, and only Donate.kt uses Google Play Billing', () {
    const banned = [
      'HttpURLConnection',
      'java.net.URL',
      'java.net.Socket',
      'okhttp',
      'URLConnection',
      'Firebase',
      'analytics',
    ];
    for (final f in _files('android/app/src/main/kotlin', '.kt')) {
      final s = f.readAsStringSync();
      for (final b in banned) {
        expect(s.contains(b), isFalse, reason: '${f.path} uses $b');
      }
      if (!f.path.endsWith('Donate.kt')) {
        expect(s.contains('billingclient'), isFalse, reason: '${f.path} touches Billing');
      }
    }
  });

  test('our own manifest asks for no network permission (Billing brings its own, only for donations)', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m.contains('android.permission.INTERNET'), isFalse);
    expect(m.contains('ACCESS_NETWORK_STATE'), isFalse);
  });

  test('no plugin with network or tracking code is added', () {
    final p = File('pubspec.yaml').readAsStringSync();
    for (final b in ['http:', 'dio:', 'firebase', 'analytics', 'sentry', 'crashlytics', 'google_mobile_ads']) {
      expect(p.contains(b), isFalse, reason: 'pubspec has $b');
    }
  });
}
