import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/data/store.dart';

void main() {
  test('a new store starts on schema 2 and is left alone', () {
    final s = Store(MemoryBackend());
    expect(s.data['v'], 2);
    expect(s.integer('rank'), 0);
  });

  test('a version 1 Duke becomes a version 2 Duke, with a Count job put in on the side of the line', () {
    final old = {
      'v': 1,
      'rank': 4,
      'stage': 1,
      'ev': [
        {'t': 1, 'k': 'crown', 'r': 1, 'a': 28, 'b': 30},
        {'t': 2, 'k': 'job', 'r': 1, 'j': 'scribe'},
        {'t': 3, 'k': 'crown', 'r': 4, 'a': 27, 'b': 30},
        {'t': 4, 'k': 'job', 'r': 4, 'j': 'archmage'},
        {'t': 5, 'k': 'sub', 'r': 0, 'a': 10, 'b': 12},
      ],
      'game': {
        'jobs': ['peasant', 'scribe', 'mage', 'wizard', 'archmage'],
        'hid': {'1': 'nightwatch', '4': 'chronomancer'},
      },
    };
    final s = Store(MemoryBackend(json.encode(old)));
    expect(s.data['v'], 2);
    expect(s.integer('rank'), 5);
    expect(s.integer('stage'), 1);
    final ev = s.list('ev');
    expect([for (final e in ev) e['r']], [2, 1, 5, 5, 0]);
    final g = s.map('game');
    expect(g['jobs'], ['peasant', 'scribe', 'mage', 'wizard', 'loremaster', 'archmage']);
    expect(g['hid'], {'1': 'nightwatch', '5': 'chronomancer'});
  });

  test('a version 1 Squire becomes a Knight and keeps the Squire job; a Peasant stays a Peasant', () {
    final sq = Store(
      MemoryBackend(
        json.encode({
          'v': 1,
          'rank': 1,
          'game': {
            'jobs': ['peasant', 'blade'],
          },
        }),
      ),
    );
    expect(sq.integer('rank'), 2);
    expect(sq.map('game')['jobs'], ['peasant', 'blade']);
    final p = Store(MemoryBackend(json.encode({'v': 1, 'rank': 0})));
    expect(p.integer('rank'), 0);
  });

  test('migration runs once', () {
    final s = Store(MemoryBackend(json.encode({'v': 1, 'rank': 2})));
    s.flush();
    final again = Store(MemoryBackend((s.backend as MemoryBackend).text));
    expect(again.integer('rank'), 3);
  });

  test('a kingdom keeps its own road under realms, shares the settings, and saves through the whole store', () {
    final b = MemoryBackend();
    final s = Store(b);
    s.map('set')['lang'] = 'en';
    s.set('rank', 3);
    final de = s.realm('de');
    expect(de.integer('rank'), 0);
    expect(de.map('set')['lang'], 'en');
    de.set('rank', 1);
    de.map('mem')['der Abakus (-se)'] = [3.0, 0, 1, 0, 0, 1];
    de.flush();
    final again = Store(MemoryBackend(b.text));
    expect(again.integer('rank'), 3);
    expect(again.realm('de').integer('rank'), 1);
    expect(again.realm('de').map('mem'), contains('der Abakus (-se)'));
  });
}
