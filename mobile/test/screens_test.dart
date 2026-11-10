// Drives the app through every screen with the real fonts and writes pictures to test/goldens/ (not committed:
// look at them).   flutter test --update-goldens test/screens_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/app/app.dart';
import 'package:verbarium/app/native.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/engine/jobs.dart';
import 'package:verbarium/ui/coronation.dart';
import 'package:verbarium/ui/pixel.dart';
import 'package:verbarium/ui/root.dart';
import 'package:verbarium/ui/run.dart';
import 'package:verbarium/ui/settings.dart';
import 'package:verbarium/ui/theme.dart';

final now = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;

Future<void> fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
    }
    await l.load();
  }

  await load('Fell', ['assets/fonts/fell-400.ttf', 'assets/fonts/fell-400i.ttf']);
  await load('Alegreya', ['assets/fonts/sans-400.ttf', 'assets/fonts/sans-500.ttf', 'assets/fonts/sans-700.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (root != null && icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

/// a learner some weeks in: [rank] held at [stage], [share] of the next tier solid, some words due, a history
Future<App> learner(
  WidgetTester tester, {
  int rank = 1,
  int stage = 0,
  String banner = 'ielts',
  String theme = 'light',
  double share = 0.2,
  bool onboarded = true,
  bool history = true,
  int xp = 900,
  List<String> gear = const ['s1', 'c1', 'w1'],
  String lang = 'id',
  List<String>? jobs,
}) async {
  rootBundle.clear(); // a deck file first read inside a test's fake clock must not be handed to the next test
  final data = <String, dynamic>{
    'v': 1,
    'rank': rank,
    'stage': stage,
    'set': {'banner': banner, 'theme': theme, 'lang': lang, if (onboarded) 'onb': 1},
    if (history)
      'game': {
        'xp': xp,
        'gear': gear,
        'eq': {'weapon': 'w1', 'shield': 's1', 'cloak': 'c1'},
        'feats': ['first', 'boss1'],
        'title': 'Penakluk',
        'acc': [for (var i = 0; i < 40; i++) i % 8 == 0 ? 0 : 1],
        'ms': 5200,
        'n': 420,
        'bc': 14,
        'jobs': ?jobs,
        'seen': ?jobs,
        'bp': {'p': 245, 's': 260, 'i': 120, 'e': 90, 'n': 300},
      },
  };
  final app = (await tester.runAsync(() => App.boot(backend: MemoryBackend(json.encode(data)), clock: () => now)))!;
  final mem = app.store.map('mem');
  for (var t = 1; t <= rank; t++) {
    for (final w in app.deck.tier(t)) {
      mem[w.id] = [20.0, now + 9 * Engine.day, 4, 0, now - Engine.day, 1];
    }
  }
  if (rank < 5) {
    final next = app.deck.tier(rank + 1);
    final n = (next.length * share).round();
    for (var i = 0; i < n; i++) {
      mem[next[i].id] = [9.0, i < 12 ? now - 1000 * (i + 1) : now + 3 * Engine.day, 3, i < 6 ? 1 : 0, now - 2 * Engine.day, 1];
    }
  }
  final log = app.store.map('log');
  const pattern = [22, 31, 0, 18, 40, 27, 35, 12, 0, 29, 44, 38, 30, 16];
  for (var i = 0; i < 14; i++) {
    final c = history ? pattern[i] : 0;
    if (c > 0) log[Engine.dayKey(now - (13 - i) * Engine.day)] = [c ~/ 3, c - c ~/ 3, (c * 0.85).round(), c - (c * 0.85).round()];
  }
  if (rank > 0) {
    app.store.list('ev').addAll([
      {'t': now - 30 * Engine.day, 'k': 'place', 'r': 0, 'a': 3, 'b': 8},
      {'t': now - 12 * Engine.day, 'k': 'sub', 'r': rank - 1, 'a': 10, 'b': 12},
      {'t': now - 9 * Engine.day, 'k': 'fail', 'r': rank, 'a': 23, 'b': 30},
      {'t': now - 8 * Engine.day, 'k': 'crown', 'r': rank, 'a': 26, 'b': 28},
    ]);
  }
  return (await tester.runAsync(() => App.boot(backend: MemoryBackend(json.encode(app.store.data)), clock: () => now)))!;
}

Future<void> shot(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void phone(WidgetTester tester, {double w = 390, double h = 844}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// animations of sprites never settle, so tests step through time instead of waiting for stillness
Future<void> beat(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 320));
}

bool has(Finder f) => f.evaluate().isNotEmpty;

/// answers the card on screen, right or wrong, whatever kind it is; returns the kind
Future<String> answer(WidgetTester tester, {bool right = true}) async {
  final want = RunScreen.probe;
  final check = has(find.text('Periksa')) ? find.text('Periksa') : find.text('Check');
  if (has(find.byKey(const ValueKey('gap-field')))) {
    await tester.enterText(find.byKey(const ValueKey('gap-field')), right ? want : 'zzzzzzzz');
    await tester.tap(check);
    return 'cloze';
  }
  if (has(find.text('Ketuk kata di bawah sesuai urutannya')) || has(find.text('Tap the words below in the right order'))) {
    final words = want.split(' ');
    for (final w in right ? words : words.reversed) {
      await tester.tap(find.text(w).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.tap(check);
    return 'build';
  }
  final options = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Option');
  if (right) {
    await tester.tap(find.descendant(of: options, matching: find.text(want)).first);
  } else {
    final wrong = tester.widgetList(options).map((w) => (w as dynamic).text as String).firstWhere((t) => t != want);
    await tester.tap(find.descendant(of: options, matching: find.text(wrong)).first);
  }
  return 'choice';
}

/// the sitting's order depends on the deck: step past other kinds until a gap is on the page
Future<void> untilGap(WidgetTester tester) async {
  for (var i = 0; i < 20 && !has(find.byKey(const ValueKey('gap-field'))); i++) {
    await answer(tester);
    await beat(tester, 300);
    await tester.pump(const Duration(milliseconds: 2700));
    await beat(tester);
  }
}

void main() {
  setUpAll(() async {
    Native.off = true;
    splashOn = false;
    await fonts();
  });

  testWidgets('first run: banner, then where to start', (tester) async {
    phone(tester);
    await learner(tester, rank: 0, banner: '', onboarded: false, share: 0, history: false);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester);
    await shot(tester, '01-panji');
    await tester.tap(find.text('IELTS'));
    await beat(tester);
    await tester.tap(find.text('Lanjut'));
    for (var i = 0; i < 6 && !has(find.text('Dari mana kamu mulai?')); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await beat(tester);
    }
    expect(find.text('Dari mana kamu mulai?'), findsOneWidget);
    await tester.tap(find.text('Mulai sebagai Peasant'));
    await beat(tester, 900);
    expect(find.text('Mulai belajar'), findsOneWidget);
    expect(find.textContaining('Peasant I ·'), findsOneWidget);
    await shot(tester, '03-hari-ini-petani');
    await tester.pump(const Duration(seconds: 1));
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('the four tabs ($theme)', (tester) async {
      phone(tester);
      await learner(tester, theme: theme);
      await tester.pumpWidget(const VerbariumApp());
      await beat(tester, 900);
      expect(find.textContaining('Squire I ·'), findsOneWidget);
      await shot(tester, '10-hari-ini-$theme');
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await beat(tester);
      await shot(tester, '10b-hari-ini-bawah-$theme');
      await tester.tap(find.text('Negeri'));
      await beat(tester, 2000);
      await shot(tester, '11-negeri-$theme');
      await tester.tap(find.text('Karakter'));
      await beat(tester, 900);
      await shot(tester, '12-karakter-$theme');
      await tester.drag(find.byType(ListView), const Offset(0, -560));
      await beat(tester);
      await shot(tester, '12b-karakter-bawah-$theme');
      await tester.tap(find.text('Kronik'));
      await beat(tester, 900);
      await shot(tester, '13-kronik-$theme');
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('a sitting mixes the three kinds; typing happens in the gap itself', (tester) async {
    phone(tester);
    final app = await learner(tester);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Lanjut belajar'));
    await beat(tester);
    await untilGap(tester);
    expect(find.byKey(const ValueKey('gap-field')), findsOneWidget);
    expect(find.text('Ketik kata yang hilang'), findsNothing, reason: 'no separate box any more');
    await shot(tester, '20-celah');

    // one slip, then right
    final first = RunScreen.probe;
    await tester.enterText(find.byKey(const ValueKey('gap-field')), '${first.substring(0, first.length - 1)}x');
    await tester.tap(find.text('Periksa'));
    await beat(tester, 400);
    if (first.length >= 5) expect(find.text('Hampir. Periksa ejaannya.'), findsOneWidget);
    await shot(tester, '21-hampir');
    await answer(tester);
    await beat(tester, 500);
    await shot(tester, '22-benar');
    await tester.pump(const Duration(milliseconds: 700));
    await beat(tester);

    // "belum tahu": the word is shown as a ghost in the gap and has to be typed
    await untilGap(tester);
    final second = RunScreen.probe;
    await tester.tap(find.text('Belum tahu, tunjukkan'));
    await beat(tester);
    expect(find.textContaining('Ketik sekali supaya melekat'), findsOneWidget);
    await shot(tester, '23-ditunjukkan');
    await tester.enterText(find.byKey(const ValueKey('gap-field')), second);
    await tester.tap(find.text('Lanjut'));
    await beat(tester);

    final seen = <String>{};
    for (var i = 0; i < 140 && !has(find.text('Selesai')); i++) {
      final shown = has(find.byKey(const ValueKey('gap-field'))) ? 'cloze' : (has(find.text('Ketuk kata di bawah sesuai urutannya')) ? 'build' : 'choice');
      if (seen.add(shown)) await shot(tester, '24-${shown == 'cloze' ? 'celah-lagi' : (shown == 'build' ? 'susun' : 'pilih')}');
      final kind = await answer(tester, right: i % 9 != 4);
      await beat(tester, 300);
      if (kind == 'build' && seen.add('build-done')) await shot(tester, '25-susun-hasil');
      await tester.pump(const Duration(milliseconds: 2700));
      await beat(tester);
      // a missed gap asks for the word once more
      if (has(find.textContaining('Ketik sekali supaya melekat'))) {
        await tester.enterText(find.byKey(const ValueKey('gap-field')), RunScreen.probe);
        await tester.tap(find.text('Lanjut'));
        await beat(tester);
      }
    }
    expect(find.text('Selesai'), findsOneWidget);
    expect(seen, containsAll(['cloze', 'build', 'choice']));
    await shot(tester, '26-selesai');
    expect(app.game.xp, greaterThan(900));
    await tester.tap(find.text('Selesai'));
    await beat(tester, 900);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('new words are met by choosing, then return as gaps', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, share: 0, history: false);
    app.put('perDay', 5);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Mulai belajar'));
    await beat(tester);
    expect(find.textContaining('PILIH ARTINYA'), findsOneWidget);
    await shot(tester, '27-kata-baru');
    for (var i = 0; i < 40 && !has(find.text('Selesai')); i++) {
      await answer(tester);
      await beat(tester, 300);
      await tester.pump(const Duration(milliseconds: 1200));
      await beat(tester);
    }
    expect(find.text('Selesai'), findsOneWidget);
    expect(app.engine.seenTotal, 5);
    expect(app.game.daily.any((q) => q.id == 'new' && q.done), isTrue);
    await tester.tap(find.text('Selesai'));
    await beat(tester, 900);
    expect(find.textContaining('Ambil +'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a sub-boss falls after ten blows and drops gear', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 1, stage: 0, share: 0.3);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await beat(tester);
    expect(find.text('Lawan Bandit Jalanan'), findsOneWidget);
    await shot(tester, '30-lawan');
    await tester.tap(find.text('Lawan Bandit Jalanan'));
    await beat(tester, 500);
    expect(find.text('Belum tahu, tunjukkan'), findsNothing);
    await shot(tester, '31-arena');
    for (var i = 0; i < 12 && !has(find.text('Selesai')); i++) {
      await answer(tester, right: i != 2);
      await beat(tester, 250);
      if (i == 0) await shot(tester, '32-arena-pukul');
      if (i == 2) await shot(tester, '33-arena-kena');
      await tester.pump(const Duration(milliseconds: 1600));
      await beat(tester);
    }
    expect(find.text('Bandit Jalanan tumbang'), findsOneWidget);
    expect(app.engine.stage, 1);
    expect(app.game.owned, contains('s2'));
    await shot(tester, '34-menang');
    await tester.tap(find.text('Selesai'));
    await beat(tester, 900);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await beat(tester);
    expect(find.textContaining('Squire II ·'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('three misses lose a sub-boss fight', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 1, stage: 0, share: 0.3);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (c, child) => LookHost(child: child!),
        home: const RunScreen(kind: RunKind.sub, tier: 2),
      ),
    );
    await beat(tester);
    for (var i = 0; i < 3; i++) {
      await answer(tester, right: false);
      await beat(tester, 300);
      await tester.pump(const Duration(milliseconds: 1600));
      await beat(tester);
    }
    expect(find.text('Bandit Jalanan masih berdiri'), findsOneWidget);
    expect(app.engine.stage, 0);
    expect(app.engine.subOpen, isFalse);
    await shot(tester, '35-kalah');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the boss: twenty-six blows, then the coronation with its loot', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 1, stage: 2, share: 0.85);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await beat(tester);
    await tester.tap(find.text('Lawan Ksatria Hitam'));
    await beat(tester, 500);
    await shot(tester, '36-boss');
    for (var i = 0; i < 30 && !has(find.byType(Coronation)); i++) {
      await answer(tester);
      await beat(tester, 250);
      await tester.pump(const Duration(milliseconds: 1100));
      await beat(tester, 300);
    }
    expect(find.byType(Coronation), findsOneWidget);
    expect(app.engine.rank, 2);
    expect(app.engine.stage, 0);
    expect(app.game.equipped('weapon'), 'w2');
    await tester.pump(const Duration(milliseconds: 6000));
    await beat(tester, 400);
    await shot(tester, '37-penobatan');
    await tester.tap(find.text('Masuk ke negerimu'));
    await beat(tester, 900);
    expect(find.textContaining('Knight I ·'), findsOneWidget);
    await shot(tester, '38-hari-ini-knight');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('placement: eight words a rank, three misses end it', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, banner: 'toefl', share: 0, history: false);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (c, child) => LookHost(child: child!),
        home: const RunScreen(kind: RunKind.placement),
      ),
    );
    await beat(tester);
    expect(find.textContaining('UJIAN PENEMPATAN'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Belum tahu'));
      await beat(tester, 300);
      await tester.pump(const Duration(milliseconds: 1600));
      await beat(tester);
    }
    expect(find.text('Kamu mulai sebagai Peasant'), findsOneWidget);
    expect(app.engine.placed, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('settings, and a small phone with large text does not overflow', (tester) async {
    phone(tester, w: 360, h: 640);
    await learner(tester, rank: 3, banner: 'toefl');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
        child: const VerbariumApp(),
      ),
    );
    await beat(tester, 900);
    await shot(tester, '50-kecil-hari-ini');
    await tester.tap(find.text('Karakter'));
    await beat(tester, 900);
    await shot(tester, '50b-kecil-karakter');
    await tester.tap(find.text('Hari ini'));
    await beat(tester, 900);
    await tester.tap(find.byIcon(Icons.tune));
    await beat(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lilin'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Lilin'));
    await beat(tester);
    await shot(tester, '52-pengaturan-lilin');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the keyboard pushes the question up instead of covering it', (tester) async {
    phone(tester);
    await learner(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), viewInsets: EdgeInsets.only(bottom: 320)),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (c, child) => LookHost(child: child!),
          home: const RunScreen(kind: RunKind.sub, tier: 2),
        ),
      ),
    );
    await beat(tester, 500);
    final button = tester.getRect(find.text('Periksa'));
    expect(button.bottom, lessThan(844 - 320), reason: 'the button stays above the keyboard');
    await shot(tester, '53-papan-ketik');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Karakter shows the job, where the build leans, and the map of jobs', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 2, stage: 1, jobs: ['peasant', 'blade', 'duelist']);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    expect(find.text('Duelist'), findsOneWidget, reason: 'Today names the job');
    await tester.tap(find.text('Karakter'));
    await beat(tester, 900);
    expect(find.text('Peasant  ›  Blade  ›  Duelist'), findsOneWidget);
    await shot(tester, '40-job');
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await beat(tester);
    expect(find.text('Build-mu kini mengarah ke sini'), findsOneWidget);
    expect(find.text('? ? ?'), findsNWidgets(2), reason: 'the branches ahead have no name yet');
    expect(app.game.heading!.id, 'spellblade', reason: 'two strongest sides close together');
    await shot(tester, '41-arah-build');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await beat(tester);
    await tester.tap(find.text('Peta job'));
    await beat(tester, 900);
    expect(find.text('3 / 43'), findsOneWidget);
    await shot(tester, '42-peta-job');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await beat(tester);
    await shot(tester, '43-peta-job-bawah');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('learning through English: the app speaks English and a meaning is a definition', (tester) async {
    phone(tester);
    final app = await learner(tester, lang: 'en', jobs: ['peasant', 'scribe']);
    expect(app.english, isTrue);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Scribe'), findsOneWidget);
    expect(find.textContaining('Squire I ·'), findsOneWidget, reason: 'titles are the same in both languages');
    await shot(tester, '70-en-today');
    await tester.tap(find.text('Character'));
    await beat(tester, 900);
    await shot(tester, '71-en-character');
    await tester.tap(find.text('Chronicle'));
    await beat(tester, 900);
    await shot(tester, '72-en-chronicle');
    await tester.tap(find.text('Today'));
    await beat(tester, 900);
    await tester.tap(find.text('Continue learning'));
    await beat(tester);
    await shot(tester, '73-en-desk');
    final options = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Option');
    for (var i = 0; i < 30 && !has(options); i++) {
      await answer(tester);
      await beat(tester, 300);
      await tester.pump(const Duration(milliseconds: 2700));
      await beat(tester);
    }
    expect(options, findsNWidgets(4));
    await shot(tester, '74-en-choice');
    await tester.pump(const Duration(seconds: 1));

    // back to Indonesian in Settings, without losing anything
    final rank = app.engine.rank, seen = app.engine.seenTotal;
    app.put('lang', 'id');
    await beat(tester);
    expect(app.english, isFalse);
    expect(app.engine.rank, rank);
    expect(app.engine.seenTotal, seen);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('changing the banner keeps the title, the job and what is remembered', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 2, stage: 1, jobs: ['peasant', 'blade', 'duelist']);
    final solid = app.engine.stat(1).solid;
    await tester.runAsync(() => app.chooseBanner('toefl'));
    expect(app.banner, 'toefl');
    expect(app.engine.rank, 2);
    expect(app.engine.stage, 1);
    expect(app.game.job.id, 'duelist');
    expect(app.engine.stat(1).solid, greaterThan(solid * 0.95));
    await tester.runAsync(() => app.chooseBanner('ielts'));
    expect(app.engine.stat(1).solid, solid, reason: 'the words of the first banner were not forgotten');
  });

  testWidgets('every sprite, for looking at', (tester) async {
    phone(tester, w: 420, h: 760);
    await learner(tester);
    const enemies = ['wolf', 'boar', 'bandit', 'knight', 'skeleton', 'mage', 'gargoyle', 'dragon'];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Look(
          pal: Pal.day,
          rank: 1,
          calm: true,
          child: ColoredBox(
            color: Pal.day.bg,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pose in HeroPose.values) HeroSprite(garb: Jobs.byId('blade').garb, pose: pose, size: 72),
                    for (final j in Jobs.all)
                      HeroSprite(garb: j.garb, weapon: j.tier, shield: j.tier > 0 ? j.tier : -1, cloak: j.tier > 1 ? j.tier : -1, size: 56),
                    for (final j in Jobs.all.take(6)) HeroSprite(garb: j.garb, shadow: true, size: 56),
                    for (final j in Jobs.all.skip(1).take(8)) HeroSprite(garb: j.garb, weapon: 2, pose: HeroPose.attack, size: 56),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in enemies) EnemySprite(sprite: e, size: e == 'dragon' ? 150 : 88),
                    for (var t = 1; t < 4; t++) EnemySprite(sprite: 'knight', tone: t, size: 88),
                    const EnemySprite(sprite: 'mage', tone: 1, size: 88),
                    const EnemySprite(sprite: 'skeleton', tone: 1, size: 88),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await shot(tester, '60-sprite');
  });
}
