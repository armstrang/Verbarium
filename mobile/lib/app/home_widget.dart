/// The practice widget on the phone's home screen (Android, `PracticeWidget.kt`): a sentence with a gap and four
/// words to choose from, no typing. The app and the widget share two files in the app's own files folder:
///
///   widget/deck.json     written here: today's questions for the kingdom being played (12, repeated all day)
///   widget/answers.jsonl written by the widget, one line per answer: {"k":code,"id":word,"ok":bool,"t":ms}
///
/// When the app opens (and before it changes kingdom) the answers are read back and then cleared: each counts for
/// memory as a choice does (light, see quizWeight), a right one is worth 1–5 XP (Game.bonus), and ten answers on
/// a day keep the streak (`set.wd`, read by Engine.streak). Nothing leaves the phone.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/deck.dart';
import '../data/store.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import 'app.dart';
import 'lang.dart';
import 'native.dart';

class HomeWidget {
  /// questions a day; when they are done the same ones come round again
  static const perDay = 12;

  /// answers in the widget that keep a day's streak
  static const forStreak = 10;

  /// experience for a right answer in the widget, by the word's tier (1 Squire … 6 King)
  static int xpFor(Word w) => const [2, 2, 2, 3, 3, 4, 5][w.tier.clamp(0, 6)];

  /// today's questions: the words of this kingdom already met, the most due first, each with three other words of
  /// the same kind to choose from. Below B1 the meaning shows from the start; above, only after answering.
  static Map<String, dynamic> deckFor(Engine e, Deck d, Kingdom k, String day, {bool british = false}) {
    final met = [
      for (final w in d.words)
        if (e.mem(w) != null && w.sentence.contains('___')) w,
    ]..sort((a, b) => e.mem(a)!.due.compareTo(e.mem(b)!.due));
    final items = <Map<String, dynamic>>[];
    final seed = day.codeUnits.fold<int>(k.code.hashCode, (a, c) => a * 31 + c) & 0x7fffffff;
    for (final w in met) {
      if (items.length >= perDay) break;
      final answer = w.answer(british);
      final others = <String>{};
      final same = d.words.where((o) => o.pos == w.pos && o.id != w.id).toList();
      final pool = same.length >= 6 ? same : d.words.where((o) => o.id != w.id).toList();
      final r = Random(seed ^ w.id.hashCode);
      for (var tries = 0; others.length < 3 && tries < 60; tries++) {
        final o = pool[r.nextInt(pool.length)].answer(british);
        if (o.toLowerCase() != answer.toLowerCase() && !w.accepts(o)) others.add(o);
      }
      if (others.length < 3) continue;
      final options = [answer, ...others]..shuffle(r);
      final parts = w.parts;
      items.add({
        'id': w.id,
        'a': parts[0].trimRight(),
        'b': parts[1].trimLeft(),
        'ans': answer,
        'opt': options,
        'mean': w.gloss,
        'pos': posName(w.pos),
        'show': Engine.hintLevel(w, false, false) == 0,
      });
    }
    return {
      'v': 1,
      'day': day,
      'k': k.code,
      'name': k.name,
      'items': items,
      'say': {
        'today': tr('hari ini', 'today', 'hoy', 'aujourd’hui', 'heute', 'hoje'),
        'right': tr('Benar', 'Right', 'Correcto', 'Juste', 'Richtig', 'Certo'),
        'wrong': tr(
          'Jawabannya',
          'The answer is',
          'La respuesta es',
          'La réponse est',
          'Die Antwort ist',
          'A resposta é',
        ),
        'done': tr(
          'Streak hari ini aman. Soal hari ini diulang.',
          'Today’s streak is safe. Today’s questions come round again.',
          'La racha de hoy está a salvo. Las preguntas de hoy se repiten.',
          'La série du jour est sauve. Les questions du jour reviennent.',
          'Die Serie für heute ist sicher. Die Fragen von heute kommen noch einmal.',
          'A sequência de hoje está garantida. As perguntas de hoje se repetem.',
        ),
        'empty': tr(
          'Buka Verbarium dan pelajari beberapa kata dulu.',
          'Open Verbarium and learn a few words first.',
          'Abre Verbarium y aprende algunas palabras primero.',
          'Ouvre Verbarium et apprends d’abord quelques mots.',
          'Öffne Verbarium und lerne zuerst ein paar Wörter.',
          'Abra o Verbarium e aprenda algumas palavras primeiro.',
        ),
      },
    };
  }

  /// the answers the widget wrote, oldest first; lines that cannot be read are skipped
  static List<Map<String, dynamic>> parseAnswers(String text) => [
    for (final line in const LineSplitter().convert(text))
      if (line.trim().isNotEmpty)
        ...(() {
          try {
            final m = json.decode(line);
            if (m is Map<String, dynamic> &&
                m['id'] is String &&
                m['ok'] is bool &&
                m['t'] is num &&
                m['k'] is String) {
              return [m];
            }
          } catch (_) {}
          return const <Map<String, dynamic>>[];
        })(),
  ];

  /// counts the answers of the kingdom being played: memory as a choice, 1–5 XP when right, the day's widget
  /// answers for the streak. Answers of another kingdom only count for the streak (their words are not loaded).
  /// Returns the experience gained.
  static int apply(App app, List<Map<String, dynamic>> answers) =>
      applyTo(root: app.root, realm: app.realm, deck: app.deck, engine: app.engine, game: app.game, answers: answers);

  static int applyTo({
    required Store root,
    required String realm,
    required Deck deck,
    required Engine engine,
    required Game game,
    required List<Map<String, dynamic>> answers,
  }) {
    var xp = 0;
    final days = root.map('set').putIfAbsent('wd', () => <String, dynamic>{}) as Map;
    final byId = {for (final w in deck.words) w.id: w};
    for (final a in answers) {
      final day = Engine.dayKey((a['t'] as num).toInt());
      days[day] = ((days[day] as num?) ?? 0) + 1;
      if (a['k'] != realm) continue;
      final w = byId[a['id']];
      if (w == null || engine.mem(w) == null) continue;
      final ok = a['ok'] as bool;
      engine.answer(w, ok ? Grade.clean : Grade.wrong, count: false, quiz: Quiz.choice);
      if (ok) xp += game.bonus(xpFor(w)).xp;
    }
    // keep two weeks of widget days
    final keep = Engine.dayKey(engine.now() - 14 * Engine.day);
    days.removeWhere((k, _) => (k as String).compareTo(keep) < 0);
    root.touch();
    return xp;
  }

  /// reads and clears what the widget answered, then writes today's questions for the kingdom being played and asks
  /// the widget to redraw. Does nothing where there is no files folder (tests).
  static Future<void> sync(App app) async {
    final dir = await Native.filesDir();
    if (dir == null) return;
    final folder = Directory('$dir/widget');
    await folder.create(recursive: true);
    final log = File('${folder.path}/answers.jsonl');
    if (await log.exists()) {
      final taken = File('${folder.path}/answers.taken');
      await log.rename(taken.path);
      final read = parseAnswers(await taken.readAsString());
      await taken.delete();
      if (read.isNotEmpty) {
        apply(app, read);
        app.store.flush();
      }
    }
    final day = Engine.dayKey(app.engine.now());
    final deck = deckFor(app.engine, app.deck, app.kingdom, day, british: app.british);
    final tmp = File('${folder.path}/deck.tmp');
    await tmp.writeAsString(json.encode(deck), flush: true);
    await tmp.rename('${folder.path}/deck.json');
    await Native.widgetRefresh();
  }
}
