// Draws every screen with the real fonts and writes the pictures to test/goldens/ (not committed: look at them).
//   flutter test --update-goldens test/screens_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/app/app.dart';
import 'package:verbarium/app/native.dart';
import 'package:verbarium/data/store.dart';
import 'package:verbarium/engine/engine.dart';
import 'package:verbarium/ui/coronation.dart';
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

/// a learner some weeks in: [rank] held, part of the next tier solid, some words due, a chronicle
Future<App> learner(
  WidgetTester tester, {
  int rank = 1,
  String banner = 'ielts',
  String theme = 'light',
  double share = 0.5,
  bool onboarded = true,
  bool history = true,
}) async {
  rootBundle.clear(); // a deck file first read inside a test's fake clock must not be handed to the next test
  final data = <String, dynamic>{
    'v': 1,
    'rank': rank,
    'set': {'banner': banner, 'theme': theme, if (onboarded) 'onb': 1},
  };
  final app = (await tester.runAsync(() => App.boot(backend: MemoryBackend(json.encode(data)), clock: () => now)))!;
  final e = app.engine;
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
      mem[next[i].id] = [9.0, i < 12 ? now - 1000 * (i + 1) : now + 3 * Engine.day, 3, 0, now - 2 * Engine.day, 1];
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
      {'t': now - 9 * Engine.day, 'k': 'fail', 'r': rank, 'a': 23, 'b': 30},
      {'t': now - 8 * Engine.day, 'k': 'crown', 'r': rank, 'a': 28, 'b': 30},
    ]);
  }
  final fresh = (await tester.runAsync(() => App.boot(backend: MemoryBackend(json.encode(app.store.data)), clock: () => now)))!;
  expect(fresh.engine.rank, e.rank);
  return fresh;
}

Future<void> shot(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void phone(WidgetTester tester, {double w = 390, double h = 844}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
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
    await tester.pumpAndSettle();
    await shot(tester, '01-panji');
    await tester.tap(find.text('IELTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('Dari mana kamu mulai?'), findsOneWidget);
    await shot(tester, '02-mulai');
    await tester.tap(find.text('Mulai sebagai Petani'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai belajar'), findsOneWidget);
    await shot(tester, '03-hari-ini-petani');
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('the three tabs ($theme)', (tester) async {
      phone(tester);
      await learner(tester, theme: theme);
      await tester.pumpWidget(const VerbariumApp());
      await tester.pumpAndSettle();
      expect(find.text('Squire'), findsWidgets);
      await shot(tester, '10-hari-ini-$theme');
      await tester.tap(find.text('Negeri'));
      await tester.pumpAndSettle();
      await shot(tester, '11-negeri-$theme');
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      await shot(tester, '12-negeri-tangga-$theme');
      await tester.tap(find.text('Kronik'));
      await tester.pumpAndSettle();
      await shot(tester, '13-kronik-$theme');
    });

    testWidgets('a sitting: asked, nearly, right, told ($theme)', (tester) async {
      phone(tester);
      final app = await learner(tester, theme: theme);
      await tester.pumpWidget(const VerbariumApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut belajar'));
      await tester.pumpAndSettle();
      final first = app.engine.sitting().first;
      final answer = first.answer(true);
      await shot(tester, '20-tanya-$theme');

      await tester.enterText(find.byType(TextField), '${answer.substring(0, answer.length - 1)}x');
      await tester.tap(find.text('Periksa'));
      await tester.pump(const Duration(milliseconds: 500));
      if (answer.length >= 5) expect(find.text('Hampir. Periksa ejaannya.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), answer);
      await tester.tap(find.text('Periksa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await shot(tester, '21-benar-$theme');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Belum tahu, tunjukkan'));
      await tester.pumpAndSettle();
      expect(find.text('Ini katanya. Ketik sekali supaya melekat.'), findsOneWidget);
      await shot(tester, '22-ditunjukkan-$theme');
    });
  }

  testWidgets('a whole sitting ends with what was recorded', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, share: 0, history: false);
    app.put('perDay', 5);
    await tester.pumpWidget(const VerbariumApp());
    await tester.pumpAndSettle();
    final words = app.engine.sitting();
    expect(words.length, 5);
    await tester.tap(find.text('Mulai belajar'));
    await tester.pumpAndSettle();
    for (final w in words) {
      await tester.enterText(find.byType(TextField), w.answer(true));
      await tester.tap(find.text('Periksa'));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
    }
    expect(find.text('5 benar dari 5'), findsOneWidget);
    await shot(tester, '23-selesai');
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(app.engine.seenTotal, 5);
    expect(find.text('Tercatat. Tugas hari ini selesai.'), findsOneWidget);
  });

  testWidgets('the coronation trial: timed, no help, and a pass leads to the coronation', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 1, share: 0.85);
    await tester.pumpWidget(const VerbariumApp());
    await tester.pumpAndSettle();
    expect(find.text('Ujian penobatan Knight terbuka'), findsOneWidget);
    await shot(tester, '30-ujian-terbuka');
    await tester.scrollUntilVisible(find.text('Ikuti ujian'), 200);
    await tester.tap(find.text('Ikuti ujian'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Belum tahu, tunjukkan'), findsNothing);
    await shot(tester, '31-ujian');
    final byId = app.deck.byId;
    for (var i = 0; i < Engine.trialSize; i++) {
      // read the word from the gap's hidden text
      final gap = tester.widget<Text>(find.byKey(const ValueKey('gap-word'))).data!;
      expect(byId.values.any((w) => w.forms.contains(gap)), isTrue);
      await tester.enterText(find.byType(TextField), gap);
      await tester.tap(find.text('Periksa'));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 2600));
    await shot(tester, '32-penobatan-tengah');
    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Coronation), findsOneWidget);
    expect(app.engine.rank, 2);
    await shot(tester, '33-penobatan');
    await tester.tap(find.text('Masuk ke negerimu'));
    await tester.pumpAndSettle();
    expect(find.text('Knight'), findsWidgets);
    await shot(tester, '34-hari-ini-knight');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('placement: eight words a rank, three misses end it', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, banner: 'toefl', onboarded: true, share: 0, history: false);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (c, child) => LookHost(child: child!),
        home: const RunScreen(kind: RunKind.placement),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('UJIAN PENEMPATAN'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Belum tahu'));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    }
    expect(find.text('Kamu mulai sebagai Petani'), findsOneWidget);
    expect(app.engine.placed, isTrue);
    await shot(tester, '40-penempatan-hasil');
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
    await tester.pumpAndSettle();
    await shot(tester, '50-kecil-hari-ini');
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await shot(tester, '51-pengaturan');
    await tester.scrollUntilVisible(find.text('Lilin'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Lilin'));
    await tester.pumpAndSettle();
    await shot(tester, '52-pengaturan-lilin');
    await tester.pump(const Duration(seconds: 1)); // the store writes a moment after a change
  });
}
