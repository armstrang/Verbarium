// Cadangan: the whole save goes out as one file and comes back unchanged; anything else is refused.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/ui/settings.dart' show backupSummary;

void main() {
  Map<String, dynamic> save() => {
    'v': 2,
    'set': {'lang': 'id', 'realm': 'de', 'onb': 1},
    'rank': 2,
    'mem': {'apple': {}, 'river': {}},
    'realms': {
      'de': {
        'v': 2,
        'rank': 1,
        'mem': {'haus': {}},
      },
    },
  };

  test('a backup carries the whole save and reads back the same', () {
    final s = Store(MemoryBackend(json.encode(save())));
    final text = s.backupText(DateTime(2026, 11, 13));
    final back = Store.fromBackup(text)!;
    expect(back, save());
    expect(json.decode(text)['verbarium'], 1);
  });

  test('restoring replaces everything and is written at once', () {
    final b = MemoryBackend();
    final s = Store(b);
    s.replace(Store.fromBackup(json.encode(save()))!);
    expect(s.integer('rank'), 2);
    expect(s.realm('de').integer('rank'), 1);
    expect(json.decode(b.text!)['set']['realm'], 'de');
  });

  test('a bare state.json is accepted, and an old one is lifted to schema 2', () {
    final old = {
      'v': 1,
      'rank': 2,
      'set': {'lang': 'en'},
    };
    final back = Store.fromBackup(json.encode(old))!;
    expect(back['v'], 2);
    expect(back['rank'], 3);
  });

  test('what is not a backup, or comes from a newer Verbarium, is refused', () {
    expect(Store.fromBackup('not json'), isNull);
    expect(Store.fromBackup('[1, 2]'), isNull);
    expect(Store.fromBackup(json.encode({'hello': 'world'})), isNull);
    expect(Store.fromBackup(json.encode({'v': 2})), isNull);
    expect(Store.fromBackup(json.encode({'v': Store.schema + 1, 'set': {}})), isNull);
  });

  test('the summary names each kingdom with its title and words', () {
    final sum = backupSummary(save());
    expect(sum, contains('Aldmere: Knight · 2'));
    expect(sum, contains('Grauwacht: Squire · 1'));
    expect(sum, isNot(contains('Valdoro')));
  });
}
