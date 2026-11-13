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
import 'package:verbarium/ui/crest.dart';
import 'package:verbarium/ui/lore.dart';
import 'package:verbarium/ui/pixel.dart';
import 'package:verbarium/ui/root.dart';
import 'package:verbarium/ui/run.dart';
import 'package:verbarium/ui/settings.dart';
import 'package:verbarium/ui/theme.dart';
import 'package:verbarium/ui/banner.dart';
import 'package:verbarium/ui/world.dart';

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
    'v': 2,
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
  if (rank < Engine.maxRank) {
    final next = app.deck.tier(rank + 1);
    final n = (next.length * share).round();
    for (var i = 0; i < n; i++) {
      mem[next[i].id] = [
        9.0,
        i < 12 ? now - 1000 * (i + 1) : now + 3 * Engine.day,
        3,
        i < 6 ? 1 : 0,
        now - 2 * Engine.day,
        1,
      ];
    }
  }
  final log = app.store.map('log');
  const pattern = [22, 31, 0, 18, 40, 27, 35, 12, 0, 29, 44, 38, 30, 16];
  for (var i = 0; i < 14; i++) {
    final c = history ? pattern[i] : 0;
    if (c > 0) {
      log[Engine.dayKey(now - (13 - i) * Engine.day)] = [
        c ~/ 3,
        c - c ~/ 3,
        (c * 0.85).round(),
        c - (c * 0.85).round(),
      ];
    }
  }
  if (rank > 0) {
    app.store.list('ev').addAll([
      {'t': now - 30 * Engine.day, 'k': 'place', 'r': 0, 'a': 3, 'b': 8},
      {'t': now - 12 * Engine.day, 'k': 'sub', 'r': rank - 1, 'a': 10, 'b': 12},
      {'t': now - 9 * Engine.day, 'k': 'fail', 'r': rank, 'a': 23, 'b': 30},
      {'t': now - 8 * Engine.day, 'k': 'crown', 'r': rank, 'a': 26, 'b': 28},
    ]);
  }
  return (await tester.runAsync(
    () => App.boot(backend: MemoryBackend(json.encode(app.store.data)), clock: () => now),
  ))!;
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
  final check = [
    for (final c in const ['Periksa', 'Check', 'Comprobar', 'Vérifier', 'Prüfen', 'Conferir']) find.text(c),
  ].firstWhere(has, orElse: () => find.text('Periksa'));
  if (has(find.byKey(const ValueKey('gap-field')))) {
    await tester.enterText(find.byKey(const ValueKey('gap-field')), right ? want : 'zzzzzzzz');
    await tester.tap(check);
    return 'cloze';
  }
  if (const [
    'Ketuk kata di bawah sesuai urutannya',
    'Tap the words below in the right order',
    'Toca las palabras de abajo en el orden correcto',
    'Touche les mots ci-dessous dans le bon ordre',
    'Tippe die Wörter unten in der richtigen Reihenfolge an',
    'Toque nas palavras abaixo na ordem certa',
  ].any((t) => has(find.text(t)))) {
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
    App.phoneLanguage = () => 'id';
    Native.off = true;
    splashOn = false;
    await fonts();
  });

  for (final (phone, want) in const [
    ('es', 'es'),
    ('fr', 'fr'),
    ('de', 'de'),
    ('pt', 'pt'),
    ('ja', 'en'),
    ('id', 'id'),
  ]) {
    testWidgets('a new learner starts in the phone language ($phone -> $want)', (tester) async {
      App.phoneLanguage = () => phone;
      final app = (await tester.runAsync(() => App.boot(backend: MemoryBackend())))!;
      expect(app.langCode, want);
      App.phoneLanguage = () => 'id';
    });
  }
  testWidgets('a learner who already chose keeps the language', (tester) async {
    App.phoneLanguage = () => 'fr';
    final app = (await tester.runAsync(
      () => App.boot(
        backend: MemoryBackend(
          json.encode({
            'set': {'lang': 'id', 'onb': 1},
          }),
        ),
      ),
    ))!;
    expect(app.langCode, 'id');
    App.phoneLanguage = () => 'id';
  });

  Future<void> until(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 12 && !has(f); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await beat(tester);
    }
    expect(f, findsWidgets);
  }

  testWidgets('first run: the language spoken, the kingdom, the banner, then where to start', (tester) async {
    phone(tester);
    await learner(tester, rank: 0, banner: '', onboarded: false, share: 0, history: false);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester);
    expect(find.text('Aplikasi bicara dalam bahasa apa?'), findsOneWidget);
    expect(find.text('Mengikuti bahasa ponselmu'), findsOneWidget);
    await shot(tester, '01-bahasa');
    await tester.tap(find.text('Lanjut'));
    await beat(tester);
    expect(find.text('Bahasa apa yang ingin kamu pelajari?'), findsOneWidget);
    await shot(tester, '01b-kerajaan');
    await tester.tap(find.text('Masuk ke Aldmere'));
    await until(tester, find.text('Pilih panjimu'));
    await shot(tester, '01c-panji');
    await tester.tap(find.text('IELTS'));
    await beat(tester);
    await tester.tap(find.text('Lanjut'));
    await until(tester, find.text('Dari mana kamu mulai?'));
    expect(find.textContaining('Aldmere · English · IELTS'), findsOneWidget);
    await shot(tester, '01d-mulai');
    await tester.tap(find.text('Mulai'));
    await beat(tester, 900);
    expect(find.text('Mulai belajar'), findsOneWidget);
    expect(find.textContaining('Peasant · '), findsOneWidget);
    await shot(tester, '03-hari-ini-petani');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('first run into another kingdom: its exam, then the placement test in its language', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, banner: '', onboarded: false, share: 0, history: false);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester);
    await tester.tap(find.text('Lanjut'));
    await beat(tester);
    await tester.tap(find.text('Grauwacht').last);
    await beat(tester);
    await tester.tap(find.text('Masuk ke Grauwacht'));
    await until(tester, find.textContaining('Goethe-Zertifikat'));
    expect(app.realm, 'de');
    await shot(tester, '01e-grauwacht');
    await tester.tap(find.text('Lanjut'));
    await until(tester, find.text('Dari mana kamu mulai?'));
    await tester.tap(find.text('Ikut ujian penempatan'));
    await beat(tester);
    await tester.tap(find.text('Mulai'));
    await beat(tester, 900);
    await shot(tester, '01g-penempatan');
    expect(find.textContaining('PENEMPATAN'), findsOneWidget);
    expect(find.text('ä'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('first run: Spanish learned through Spanish asks which language explains it', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 0, banner: '', onboarded: false, share: 0, history: false, lang: 'es');
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester);
    await tester.tap(find.text('Continuar'));
    await beat(tester);
    await tester.tap(find.text('Valdoro').last);
    await beat(tester);
    await tester.tap(find.text('Entrar en Valdoro'));
    await until(tester, find.text('¿En qué idioma ves los significados?'));
    await shot(tester, '01f-valdoro');
    await tester.tap(find.text('Deutsch'));
    await beat(tester);
    await tester.tap(find.text('Continuar'));
    await until(tester, find.text('¿Por dónde empiezas?'));
    expect(app.via, 'de');
    expect(app.viaChosen, isTrue);
    expect(find.text('Explicado en Deutsch'), findsOneWidget);
    await tester.tap(find.text('Empezar'));
    await beat(tester, 900);
    expect(find.text('LOS SIGNIFICADOS SE MUESTRAN EN'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('the four tabs ($theme)', (tester) async {
      phone(tester);
      await learner(tester, theme: theme);
      await tester.pumpWidget(const VerbariumApp());
      await beat(tester, 900);
      expect(find.textContaining('Squire · '), findsOneWidget);
      expect(find.textContaining('tingkat I ·'), findsOneWidget);
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
      final shown = has(find.byKey(const ValueKey('gap-field')))
          ? 'cloze'
          : (has(find.text('Ketuk kata di bawah sesuai urutannya')) ? 'build' : 'choice');
      if (seen.add(shown)) {
        await shot(tester, '24-${shown == 'cloze' ? 'celah-lagi' : (shown == 'build' ? 'susun' : 'pilih')}');
      }
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
    for (var i = 0; i < 6 && !has(find.textContaining('Ambil +')); i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await beat(tester);
    }
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
    expect(find.textContaining('tingkat II ·'), findsOneWidget);
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
    await tester.tap(find.text('Terima gelar'));
    await beat(tester, 900);
    // the new character is introduced; only its button closes the page
    expect(find.byType(JobIntro), findsOneWidget);
    await shot(tester, '37b-perkenalan');
    await tester.tap(find.text('Lihat kisahnya'));
    await beat(tester, 700);
    expect(find.byType(LorePage), findsOneWidget);
    await shot(tester, '37c-kisah');
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await beat(tester, 600);
    await tester.tap(find.textContaining('Mulai sebagai'));
    await beat(tester, 900);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await beat(tester);
    expect(find.textContaining('Knight · '), findsOneWidget);
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
    expect(find.textContaining('Duelist'), findsOneWidget, reason: 'Today names the job');
    await tester.tap(find.text('Karakter'));
    await beat(tester, 900);
    for (final j in ['Peasant', 'Blade', 'Duelist']) {
      expect(find.text(j), findsWidgets, reason: 'the path of jobs, one chip each');
    }
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
    expect(find.text('3 / 52'), findsOneWidget);
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
    expect(find.textContaining('Scribe'), findsOneWidget);
    expect(find.textContaining('Squire · '), findsOneWidget, reason: 'titles are the same in both languages');
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
    expect(
      app.deck.words.every((w) => w.def.isNotEmpty),
      isTrue,
      reason: 'every word the app loads has its definition',
    );
    expect(app.deck.words.length, greaterThan(5900));
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

  for (final (code, cont, tabs, prefix) in const [
    ('es', 'Seguir aprendiendo', ['Personaje', 'Crónica', 'Ajustes'], '75-es'),
    ('fr', 'Continuer d’apprendre', ['Personnage', 'Chronique', 'Réglages'], '76-fr'),
    ('de', 'Weiterlernen', ['Figur', 'Chronik', 'Einstellungen'], '77-de'),
    ('pt', 'Continuar aprendendo', ['Personagem', 'Crônica', 'Configurações'], '78-pt'),
  ]) {
    testWidgets('learning through $code: the app speaks it and a meaning is in it', (tester) async {
      phone(tester);
      final app = await learner(tester, lang: code, jobs: ['peasant', 'scribe']);
      expect(app.langCode, code);
      await tester.pumpWidget(const VerbariumApp());
      await beat(tester, 900);
      expect(find.text(cont), findsOneWidget);
      expect(find.textContaining('Scribe'), findsOneWidget, reason: 'jobs keep their English names');
      await shot(tester, '$prefix-today');
      await tester.tap(find.byIcon(Icons.tune));
      await beat(tester, 900);
      await shot(tester, '$prefix-settings');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await beat(tester, 900);
      await tester.tap(find.text(tabs[0]));
      await beat(tester, 900);
      await shot(tester, '$prefix-character');
      await tester.tap(find.text(tabs[1]));
      await beat(tester, 900);
      await shot(tester, '$prefix-chronicle');
      final w = app.deck.byId['tide']!;
      expect(w.gloss, const {'es': 'marea', 'fr': 'marée', 'de': 'Gezeiten', 'pt': 'maré'}[code]);
      final c = app.deck.collocs.first;
      expect(
        c.gloss,
        const {
          'es': 'tomar una decisión',
          'fr': 'prendre une décision',
          'de': 'eine Entscheidung treffen',
          'pt': 'tomar uma decisão',
        }[code],
      );
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('privacy, software licences, and the support page that only Google Play can open', (tester) async {
    phone(tester);
    await learner(tester);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.byIcon(Icons.tune));
    await beat(tester);
    await tester.scrollUntilVisible(find.text('Privasi'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Lisensi perangkat lunak'), findsOneWidget);
    expect(find.text('Dukung Verbarium'), findsNothing, reason: 'off Google Play the donation products are not found');
    await tester.ensureVisible(find.text('Privasi'));
    await beat(tester);
    await tester.tap(find.text('Privasi'));
    await beat(tester);
    expect(find.byType(PrivacyPage), findsOneWidget);
    await shot(tester, '53-privasi');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await beat(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const SupportPage(
              items: [
                (id: 'donasi_kecil', price: 'Rp15.000'),
                (id: 'donasi_sedang', price: 'Rp45.000'),
                (id: 'donasi_besar', price: 'Rp150.000'),
              ],
            ),
          ),
        );
    await beat(tester);
    expect(find.textContaining('Rp45.000'), findsOneWidget);
    await shot(tester, '54-dukung');
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
    // the other banner's own words of the tier go (under a tenth of it), the core stays
    expect(app.engine.stat(1).solid, greaterThan(solid * 0.9));
    await tester.runAsync(() => app.chooseBanner('ielts'));
    expect(app.engine.stat(1).solid, solid, reason: 'the words of the first banner were not forgotten');
  });

  testWidgets('Negeri: the living world map, the flight through the clouds, a kingdom\'s road', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: 2, stage: 1, jobs: ['peasant', 'blade', 'duelist']);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/79-hari-ini.png'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await beat(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/79b-hari-ini-bawah.png'));
    await tester.tap(find.text('Negeri'));
    await beat(tester, 900);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/80-dunia.png'));
    await tester.runAsync(() => app.chooseRealm('de'));
    await tester.tap(find.text('Grauwacht').last);
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/80b-zoom.png'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(KingdomScreen), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/81-jalan.png'));
    await tester.tap(find.text('Peta'));
    await beat(tester, 900);
    await tester.runAsync(() => app.chooseRealm('en'));
    await tester.tap(find.text('Aldmere').last);
    await beat(tester, 2500);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/82-jalan-aldmere.png'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await beat(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/83-tempat.png'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('another kingdom: Grauwacht has its own road, the sentence in Indonesian and the letters to type', (
    tester,
  ) async {
    phone(tester);
    final app = await learner(tester, rank: 2);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Negeri'));
    await beat(tester, 700);
    expect(find.text('Grauwacht'), findsWidgets);
    await tester.runAsync(() => app.chooseRealm('de'));
    await beat(tester, 700);
    expect(app.engine.rank, 0, reason: 'a new kingdom starts from the fields');
    expect(app.root.integer('rank'), 2, reason: 'Aldmere keeps its title');
    expect(find.textContaining('Grauwacht · Peasant'), findsNothing);
    expect(find.text('Grauwacht'), findsWidgets);
    await shot(tester, '70-negeri-grauwacht');
    await tester.tap(find.text('Hari ini'));
    await beat(tester, 700);
    await tester.tap(find.text('Mulai belajar'));
    await beat(tester, 900);
    await untilGap(tester);
    expect(find.text('ä'), findsOneWidget);
    expect(app.deck.byId[RunScreen.probeId]?.trans, isNotEmpty);
    await shot(tester, '71-celah-grauwacht');
    await tester.enterText(find.byKey(const ValueKey('gap-field')), RunScreen.probe.toUpperCase());
    await tester.tap(find.text('Periksa'));
    await beat(tester, 500);
    expect(app.engine.seenTotal, greaterThan(0));
    await tester.pump(const Duration(seconds: 3));
    await beat(tester);
  });

  testWidgets('a kingdom\'s banner names an exam; a kingdom learned in its own language asks how to explain it', (
    tester,
  ) async {
    phone(tester);
    final app = await learner(tester, rank: 1);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Negeri'));
    await beat(tester, 700);
    await tester.runAsync(() => app.chooseRealm('de'));
    await tester.tap(find.text('Grauwacht').last);
    await beat(tester, 2500);
    expect(find.byType(KingdomScreen), findsOneWidget);
    expect(find.text('UJIAN YANG BISA JADI TUJUAN'), findsNothing, reason: 'no question in Indonesian');
    await tester.tap(find.byType(BannerPill));
    await beat(tester, 600);
    expect(find.text('UJIAN YANG BISA JADI TUJUAN'), findsOneWidget);
    expect(find.textContaining('Goethe-Zertifikat'), findsOneWidget);
    await shot(tester, '84-panji-grauwacht');
    await tester.tap(find.text('Tutup'));
    await beat(tester, 600);
    await tester.tap(find.text('Peta'));
    await beat(tester, 900);
    // Spanish learned through Spanish: Valdoro asks once which language explains it
    app.put('lang', 'es');
    await tester.runAsync(() => app.chooseRealm('es'));
    await beat(tester, 600);
    await tester.tap(find.text('Valdoro').last);
    await beat(tester, 2500);
    expect(app.clash, isTrue);
    expect(find.text('LOS SIGNIFICADOS SE MUESTRAN EN'), findsOneWidget);
    expect(find.textContaining('DELE'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await shot(tester, '85-panji-valdoro');
    await tester.tap(find.text('Deutsch'));
    await beat(tester, 400);
    expect(app.via, 'de');
    final w = app.deck.words.first;
    expect(w.gloss, isNot(w.def), reason: 'the meaning is now German, not the English definition');
    await tester.tap(find.text('Cerrar'));
    await beat(tester, 600);
    expect(find.text('LOS SIGNIFICADOS SE MUESTRAN EN'), findsNothing, reason: 'asked only once');
    app.put('lang', 'id');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('every foe on its own ground, for looking at', (tester) async {
    phone(tester, w: 420, h: 760);
    await learner(tester);
    const foes = ['wolf', 'boar', 'bat', 'bandit', 'knight', 'skeleton', 'mage', 'count', 'gargoyle', 'dragon'];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Look(
          pal: Pal.day,
          rank: 1,
          calm: true,
          child: ColoredBox(
            color: Pal.day.bg,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in foes) FoeStage(sprite: e, boss: e == 'dragon' || e == 'count', width: 124),
                  const FoeStage(sprite: 'wolf', tone: 1, width: 124),
                  for (var t = 1; t < 4; t++) FoeStage(sprite: 'knight', tone: t, width: 124),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await shot(tester, '61-musuh');
  });

  testWidgets('every sprite, for looking at', (tester) async {
    phone(tester, w: 420, h: 760);
    await learner(tester);
    const enemies = ['wolf', 'boar', 'bat', 'bandit', 'knight', 'skeleton', 'mage', 'count', 'gargoyle', 'dragon'];
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
                      HeroSprite(
                        garb: j.garb,
                        tier: j.tier,
                        weapon: j.tier,
                        shield: j.tier > 0 ? j.tier : -1,
                        cloak: j.tier > 1 ? j.tier : -1,
                        size: 56,
                      ),
                    for (final j in Jobs.all.take(6)) HeroSprite(garb: j.garb, shadow: true, size: 56),
                    for (final j in Jobs.all.skip(1).take(8))
                      HeroSprite(garb: j.garb, tier: j.tier, weapon: 2, pose: HeroPose.attack, size: 56),
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
                    const EnemySprite(sprite: 'wolf', tone: 1, size: 88),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in enemies) FoeStage(sprite: e, boss: e == 'dragon' || e == 'count', width: 120),
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

  testWidgets('Today names the kingdom; a long press offers all five; the coin asks where to give', (tester) async {
    phone(tester);
    await learner(tester, rank: 2);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    expect(find.text('Aldmere · English'), findsOneWidget);
    await shot(tester, '86-hari-ini-negeri');
    await tester.longPress(find.text('Aldmere · English'));
    await beat(tester, 500);
    expect(find.text('Pindah negeri'), findsOneWidget);
    await shot(tester, '87-pindah-negeri');
    await tester.tapAt(const Offset(10, 10));
    await beat(tester, 500);
    await tester.tap(find.text('Aldmere · English'));
    await beat(tester, 700);
    expect(find.text('GULUNGAN GELAR'), findsOneWidget, reason: 'a tap opens Negeri');
    await tester.tap(find.text('Hari ini'));
    await beat(tester, 700);
    await tester.tap(find.bySemanticsLabel('Dukung Verbarium'));
    await beat(tester, 500);
    expect(find.textContaining('Play Store'), findsWidgets, reason: 'outside the Play Store the coin only explains');
    await shot(tester, '88-koin');
    await tester.tap(find.text('Mengerti'));
    await beat(tester, 400);
  });

  testWidgets('the arms of each kingdom come alive and settle', (tester) async {
    phone(tester);
    await learner(tester, rank: 2);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    for (final code in ['es', 'en', 'de', 'fr', 'pt']) {
      final ctx = tester.element(find.byType(Today));
      final shown = showCrest(ctx, code);
      // the pictures are read for real, outside the test's clock
      await tester.runAsync(() => CrestParts.load(code));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      }
      expect(find.byType(CrestSplash), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      if (code == 'es') await shot(tester, '89-lambang-api');
      await tester.pump(const Duration(milliseconds: 1700));
      await shot(tester, '89-lambang-$code');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CrestSplash), findsNothing, reason: 'the arms close by themselves');
      await shown;
    }
  });

  testWidgets('the roll of titles names an Emperor once three kingdoms are held as King', (tester) async {
    phone(tester);
    final app = await learner(tester, rank: Engine.maxRank);
    for (final c in ['de', 'es']) {
      app.root.realm(c).data['rank'] = Engine.maxRank;
      app.root.realm(c).map('mem')['x'] = [1];
    }
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Negeri'));
    await beat(tester, 900);
    expect(TitleRoll.kings(app), 3);
    expect(find.text('Emperor'), findsOneWidget);
    await shot(tester, '90-gulungan');
  });

  testWidgets('settings offer to save and restore a backup', (tester) async {
    phone(tester);
    await learner(tester, rank: 2);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.bySemanticsLabel('Pengaturan'));
    await beat(tester, 700);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await beat(tester);
    expect(find.text('Simpan cadangan'), findsOneWidget);
    expect(find.text('Pulihkan cadangan'), findsOneWidget);
    await shot(tester, '91-cadangan');
  });

  testWidgets('from Knight on, a word under review shows its first letter in the gap and only its kind below', (
    tester,
  ) async {
    phone(tester);
    await learner(tester, rank: 2);
    await tester.pumpWidget(const VerbariumApp());
    await beat(tester, 900);
    await tester.tap(find.text('Lanjut belajar'));
    await beat(tester, 900);
    // step past new words and other kinds until a reviewed gap with a first letter comes up
    for (var i = 0; i < 24 && !has(find.byKey(const ValueKey('gap-lead'))); i++) {
      await answer(tester);
      await beat(tester, 300);
      await tester.pump(const Duration(milliseconds: 2700));
      await beat(tester);
    }
    expect(find.byKey(const ValueKey('gap-lead')), findsOneWidget);
    final lead = (tester.widget(find.byKey(const ValueKey('gap-lead'))) as Text).data!;
    expect(RunScreen.probe.toLowerCase().startsWith(lead.toLowerCase()), isTrue);
    expect(find.textContaining('huruf'), findsNothing, reason: 'the length of the word is never told');
    await shot(tester, '92-petunjuk-huruf');
    await tester.tap(find.text('Petunjuk'));
    await beat(tester, 400);
    await shot(tester, '93-petunjuk-dibuka');
    // the rest of the word is enough: the first letter is already in the gap
    await tester.enterText(find.byKey(const ValueKey('gap-field')), RunScreen.probe.substring(1));
    await tester.tap(find.text('Periksa'));
    await beat(tester, 300);
    expect(find.text('+7 XP'), findsOneWidget, reason: 'right after the hint is worth 7');
  });
}
