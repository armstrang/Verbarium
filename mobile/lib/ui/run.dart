/// One sitting at the desk, or one fight. Three kinds of question share the screen: the gap you type into (the main
/// one), the sentence you build from chips, and the meaning or partner word you choose. Trials are gaps only; the
/// fights against sub-bosses and bosses add an arena above the question, and each answer is a blow.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../data/deck.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import '../engine/jobs.dart';
import 'coronation.dart';
import 'pixel.dart';
import 'root.dart';
import 'theme.dart';
import 'widgets.dart';
import 'world.dart' show KingdomName;

enum RunKind { learn, placement, trial, sub, defence }

Route<void> runRoute(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: Dur.enter,
  reverseTransitionDuration: Dur.out,
  transitionsBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: AnimatedBuilder(
        animation: c,
        builder: (_, child) => Transform.translate(offset: Offset(0, 16 * (1 - c.value)), child: child),
        child: child,
      ),
    );
  },
);

class RunScreen extends StatelessWidget {
  /// for tests: what the card on screen expects (the word, the right option, or the sentence)
  @visibleForTesting
  static String probe = '';

  /// for tests: the id of the word on the card
  static String probeId = '';

  final RunKind kind;
  final int tier;
  final int extraFresh;
  const RunScreen({super.key, required this.kind, this.tier = 0, this.extraFresh = 0});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    // a coronation is fought by night, whatever the page is by day
    if (kind != RunKind.trial || look.pal.dark) return _Run(this);
    return Look(pal: Pal.night, rank: look.rank, calm: look.calm, stamp: look.stamp, child: _Run(this));
  }
}

class _Run extends StatefulWidget {
  final RunScreen s;
  const _Run(this.s);

  @override
  State<_Run> createState() => _RunState();
}

class _Item {
  final Word? w;
  final Colloc? c;
  final Quiz quiz;
  final bool fresh;
  final int tries;
  _Item(this.w, this.quiz, this.fresh, [this.tries = 0]) : c = null;
  _Item.colloc(this.c) : w = null, quiz = Quiz.choice, fresh = false, tries = 0;
}

/// ask: waiting · near: one slip or the wrong form, try again · shown: the word is shown, type it to go on
/// right: correct, a short pause · miss: wrong, the answer is shown for a moment
enum _Phase { ask, near, shown, right, miss }

class _RunState extends State<_Run> with TickerProviderStateMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _write = AnimationController(vsync: this, duration: Dur.write);
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: Engine.trialSeconds),
  );

  /// the air of the arena (embers, the boss's fire) and the flash of a blow
  late final AnimationController _air = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  bool _flashBad = false;

  /// one mark per word of a fight: true right, false missed
  final List<bool> _marks = [];
  final _watch = Stopwatch();

  final List<_Item> _q = [];
  int _i = 0;
  int _right = 0, _wrongN = 0, _done = 0, _freshSeen = 0, _xp = 0;
  _Phase _phase = _Phase.ask;
  bool _nearUsed = false;
  String _nearWhy = '';
  bool _finished = false;
  bool _passed = false;
  int _solidBefore = 0;
  Timer? _pause;
  Reward? _reward;
  Job? _newJob;
  final List<String> _news = [];

  // choosing and building
  List<String> _options = [];
  String? _picked;
  List<String> _pool = [], _placed = [], _target = [];

  // placement
  int _ptier = 1, _ptierRight = 0, _ptierCount = 0, _tiersPassed = 0;

  // fights
  Enemy? _enemy;
  int _heroHp = 0, _heroMax = 0, _enemyHp = 0, _enemyMax = 0;
  int _rankBefore = 0, _stageBefore = 0;
  HeroPose _pose = HeroPose.idle;
  bool _struck = false;
  String _float = '';
  int _floatN = 0;

  Engine get _e => App.I.engine;
  Game get _g => App.I.game;
  RunKind get _kind => widget.s.kind;
  bool get _test => _kind != RunKind.learn;
  bool get _fight => _kind == RunKind.trial || _kind == RunKind.sub;
  bool get _timed => _fight || _kind == RunKind.defence;

  /// seconds per word; a job's perk can give a little more against a guard of the road, never in a coronation;
  /// a boss below half its life rages and gives less
  int get _seconds =>
      Engine.trialSeconds + (_kind == RunKind.sub ? _g.perk('subTime') : 0) - (_rage ? Engine.rageCut : 0);

  /// the boss of a coronation, wounded past half, rages
  bool get _rage => _kind == RunKind.trial && _enemyMax > 0 && _enemyHp > 0 && _enemyHp * 2 <= _enemyMax;
  _Item get _item => _q[_i];

  @override
  void initState() {
    super.initState();
    _solidBefore = _e.solidTotal;
    _rankBefore = _e.rank;
    _stageBefore = _e.stage;
    _g.combo = 0;
    switch (_kind) {
      case RunKind.learn:
        final cards = _e.sitting(extraFresh: widget.s.extraFresh);
        final collocs = App.I.deck.collocs.where((c) => c.tier <= _e.learning).toList()..shuffle(Random(_e.now()));
        var k = 0;
        for (var n = 0; n < cards.length; n++) {
          _q.add(_Item(cards[n].w, cards[n].quiz, cards[n].fresh));
          if ((n + 1) % _g.collocEvery == 0 && k < collocs.length) _q.add(_Item.colloc(collocs[k++]));
        }
      case RunKind.placement:
        _q.addAll([for (final w in _e.placementWords(1)) _Item(w, Quiz.cloze, false)]);
      case RunKind.trial:
        _q.addAll([for (final w in _e.trialWords(widget.s.tier, Engine.trialSize)) _Item(w, Quiz.cloze, false)]);
        _startFight(Engine.trialPass, Engine.trialSize - Engine.trialPass + 1);
      case RunKind.sub:
        _q.addAll([for (final w in _e.subWords()) _Item(w, Quiz.cloze, false)]);
        _startFight(Engine.subPass, Engine.subSize - Engine.subPass + 1 + _g.perk('subHp'));
        _clock.duration = Duration(seconds: _seconds);
      case RunKind.defence:
        _q.addAll([for (final w in _e.trialWords(widget.s.tier, Engine.defenceSize)) _Item(w, Quiz.cloze, false)]);
    }
    if (_q.isEmpty) _finished = true;
    _clock.addStatusListener((s) {
      if (s == AnimationStatus.completed && _phase != _Phase.right && _phase != _Phase.miss) _wrong('m');
    });
    if (!_finished) _open();
  }

  void _startFight(int enemyHp, int heroHp) {
    _enemy = _g.enemy;
    _enemyHp = _enemyMax = enemyHp;
    _heroHp = _heroMax = heroHp;
    App.I.setBattle(true);
    _air.repeat();
  }

  /// prepares the card at [_i]: options or chips, the clock, the stopwatch
  void _open() {
    final it = _item;
    _picked = null;
    final r = Random(_e.now() + _i);
    if (it.c != null) {
      _options = [it.c!.correct, ...it.c!.wrong]..shuffle(r);
    } else if (it.quiz == Quiz.choice) {
      _options = [
        it.w!.gloss,
        ..._e.distractors(it.w!, 3, seed: _e.now() + _i, close: App.I.english).map((x) => x.gloss),
      ]..shuffle(r);
    } else if (it.quiz == Quiz.build) {
      _target = it.w!.tokens(App.I.british);
      final extra = <String>[];
      if (it.w!.inflected) extra.add(it.w!.forms[0]);
      for (final d in _e.distractors(it.w!, 4, seed: _e.now() + _i)) {
        final a = d.answer(App.I.british);
        if (extra.length < 2 && !_target.any((t) => _plain(t) == a)) extra.add(a);
      }
      _pool = [..._target, ...extra]..shuffle(r);
      _placed = [];
    }
    RunScreen.probeId = it.w?.id ?? '';
    RunScreen.probe = it.c != null
        ? it.c!.correct
        : (it.quiz == Quiz.choice
              ? it.w!.gloss
              : (it.quiz == Quiz.build ? _target.join(' ') : it.w!.answer(App.I.british)));
    _watch
      ..reset()
      ..start();
    if (_timed) _clock.forward(from: 0);
  }

  static String _plain(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z\-]'), '');

  @override
  void dispose() {
    _pause?.cancel();
    if (_fight) App.I.setBattle(false);
    _input.dispose();
    _focus.dispose();
    _shake.dispose();
    _write.dispose();
    _clock.dispose();
    _air.dispose();
    _flash.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ answering

  void _check() {
    if (_phase == _Phase.right || _phase == _Phase.miss) return;
    final it = _item;
    if (it.quiz == Quiz.build) {
      if (_placed.length < _target.length) return;
      final ok =
          _placed.length == _target.length &&
          [for (var i = 0; i < _target.length; i++) _plain(_placed[i]) == _plain(_target[i])].every((x) => x);
      ok ? _rightAnswer() : _wrong('o');
      return;
    }
    final typed = _input.text.trim();
    if (typed.isEmpty) return;
    final w = it.w!;
    if (_phase == _Phase.shown) {
      if (w.accepts(typed)) {
        _advance();
      } else {
        _shake.forward(from: 0);
      }
      return;
    }
    if (w.accepts(typed)) {
      _rightAnswer();
    } else if (!_nearUsed && w.wrongForm(typed)) {
      _near('f');
    } else if (!_nearUsed && w.wanted.map((f) => slip(typed, f)).reduce(min) == 1) {
      _near('s');
    } else {
      _wrong('m');
    }
  }

  void _near(String why) {
    setState(() {
      _phase = _Phase.near;
      _nearUsed = true;
      _nearWhy = why;
    });
    _shake.forward(from: 0);
    App.I.sfx('wrong', 0.4);
  }

  void _pick(String option) {
    if (_picked != null) return;
    final it = _item;
    setState(() => _picked = option);
    final ok = option == (it.c != null ? it.c!.correct : it.w!.gloss);
    ok ? _rightAnswer() : _wrong('m');
  }

  void _grade(Grade g, String err) {
    final it = _item;
    final ms = _watch.elapsedMilliseconds;
    if (it.c != null) {
      _reward = _g.onColloc(g != Grade.wrong);
    } else {
      final w = it.w!;
      final lapses = (_e.mem(w)?.lapses ?? 0) > 0;
      final stab = _e.mem(w)?.s ?? 0.0;
      _e.answer(w, g, count: _kind != RunKind.placement, quiz: it.quiz);
      _reward = _g.onAnswer(w, it.quiz, g, ms, err: err, fresh: it.fresh, hadLapses: lapses, stab: stab);
    }
    _xp += _reward!.xp;
    if (_reward!.news.isNotEmpty) {
      _news.addAll(_reward!.news);
      if (_reward!.levelUp) App.I.sfx('levelup');
    }
  }

  void _rightAnswer() {
    _grade(_nearUsed ? Grade.helped : Grade.clean, _nearUsed ? _nearWhy : '');
    _clock.stop();
    _right++;
    if (_kind == RunKind.placement) _ptierRight++;
    if (_item.fresh) _freshSeen++;
    final crit = _reward?.crit ?? false;
    if (_fight) {
      final calmBefore = !_rage;
      _enemyHp = max(0, _enemyHp - 1);
      _marks.add(true);
      _flashBad = false;
      _flash.forward(from: 0);
      _blow(
        HeroPose.attack,
        crit ? tr('KRITIS!', 'CRITICAL!', '¡CRÍTICO!', 'CRITIQUE !', 'KRITISCH!', 'CRÍTICO!') : '−1',
        true,
      );
      if (calmBefore && _rage) {
        _clock.duration = Duration(seconds: _seconds);
        App.I.sfx('crit');
      }
      App.I.sfx(crit ? 'crit' : 'hit');
    } else {
      App.I.sfx('quill');
    }
    App.I.haptic();
    setState(() => _phase = _Phase.right);
    _write.forward(from: 0);
    final quick = _item.quiz == Quiz.choice;
    _pause = Timer(Duration(milliseconds: quick ? 650 : (Look.of(context).calm ? 650 : 1000)), _advance);
  }

  void _wrong(String err) {
    _grade(Grade.wrong, err);
    _clock.stop();
    _wrongN++;
    App.I.haptic(strong: true);
    _shake.forward(from: 0);
    if (_item.fresh) _freshSeen++;
    if (_fight) {
      _heroHp = max(0, _heroHp - 1);
      _marks.add(false);
      _flashBad = true;
      _flash.forward(from: 0);
      _blow(HeroPose.hurt, '−1', false);
      App.I.sfx('hurt');
    } else {
      App.I.sfx('wrong');
    }
    final it = _item;
    if (_test || it.quiz != Quiz.cloze) {
      // a missed build or choice in learning comes back later as a gap
      if (!_test && it.w != null && it.tries < 2) {
        _q.insert(min(_i + 4, _q.length), _Item(it.w, Quiz.cloze, false, it.tries + 1));
      }
      setState(() => _phase = _Phase.miss);
      _pause = Timer(Duration(milliseconds: it.quiz == Quiz.build ? 2600 : 1500), _advance);
    } else {
      if (it.tries < 2) _q.insert(min(_i + 4, _q.length), _Item(it.w, Quiz.cloze, false, it.tries + 1));
      _input.clear();
      setState(() => _phase = _Phase.shown);
    }
  }

  void _blow(HeroPose pose, String text, bool onEnemy) {
    _pose = pose;
    _struck = onEnemy;
    _float = text;
    _floatN++;
    Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _pose = HeroPose.idle;
        _struck = false;
      });
    });
  }

  void _advance() {
    _pause?.cancel();
    if (!mounted) return;
    _done++;
    if (_fight && (_enemyHp <= 0 || _heroHp <= 0)) {
      _finish();
      return;
    }
    if (_kind == RunKind.placement) {
      _ptierCount++;
      final missed = _ptierCount - _ptierRight;
      if (missed > Engine.placementPerTier - Engine.placementPass) {
        _finish();
        return;
      }
      if (_ptierCount == Engine.placementPerTier) {
        _tiersPassed = _ptier;
        if (_ptier >= Engine.placementTop) {
          _finish();
          return;
        }
        _ptier++;
        _ptierCount = 0;
        _ptierRight = 0;
        _q.addAll([for (final w in _e.placementWords(_ptier)) _Item(w, Quiz.cloze, false)]);
      }
    }
    if (_i + 1 >= _q.length) {
      _finish();
      return;
    }
    if (!_fight) App.I.sfx('page', 0.45);
    setState(() {
      _i++;
      _phase = _Phase.ask;
      _nearUsed = false;
      _input.clear();
      _open();
    });
    _write.value = 0;
    if (_item.quiz == Quiz.cloze) {
      _focus.requestFocus();
    } else {
      _focus.unfocus();
    }
  }

  void _finish() {
    _clock.stop();
    final total = max(_done, 1);
    switch (_kind) {
      case RunKind.learn:
        App.I.sfx('seal', 0.8);
      case RunKind.placement:
        _e.finishPlacement(_tiersPassed, _right, total);
        _passed = _tiersPassed > 0;
        App.I.sfx(_passed ? 'rise' : 'seal', 0.9);
      case RunKind.trial:
        _passed = _enemyHp <= 0 && _e.finishTrial(widget.s.tier, Engine.trialPass, Engine.trialSize);
        if (!_passed) _e.finishTrial(widget.s.tier, min(_right, Engine.trialPass - 1), Engine.trialSize);
        if (_passed) {
          _news.insertAll(0, _g.onVictory(_rankBefore, _stageBefore, true, _wrongN == 0));
          // the build of the title just won decides the job
          final (job, lines) = _g.onPromotion(widget.s.tier, _wrongN == 0);
          _newJob = job;
          _news.insertAll(0, lines);
        }
      case RunKind.sub:
        _passed = _e.finishSub(_enemyHp <= 0 ? Engine.subPass : min(_right, Engine.subPass - 1), Engine.subSize);
        if (_passed) _news.insertAll(0, _g.onVictory(_rankBefore, _stageBefore, false, _wrongN == 0));
        App.I.sfx(_passed ? 'victory' : 'defeat');
      case RunKind.defence:
        _passed = _e.finishDefence(_right, Engine.defenceSize);
        App.I.sfx(_passed ? 'rise' : 'seal', 0.9);
    }
    if (_fight) App.I.setBattle(false);
    App.I.store.flush();
    App.I.changed();
    if (_kind == RunKind.trial && _passed) {
      Navigator.of(context).pushReplacement(
        runRoute(Coronation(rank: widget.s.tier, right: _right, total: _done, news: List.of(_news), job: _newJob)),
      );
      return;
    }
    if (_kind == RunKind.trial) App.I.sfx('defeat');
    _focus.unfocus();
    setState(() => _finished = true);
  }

  Future<void> _close() async {
    if (_finished || !_test) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirm(
      context,
      title: _fight
          ? tr(
              'Lari dari pertarungan?',
              'Flee the fight?',
              '¿Huir del combate?',
              'Fuir le combat ?',
              'Aus dem Kampf fliehen?',
              'Fugir da luta?',
            )
          : tr(
              'Tinggalkan ujian?',
              'Leave the test?',
              '¿Salir de la prueba?',
              'Quitter le test ?',
              'Den Test verlassen?',
              'Sair do teste?',
            ),
      text: switch (_kind) {
        RunKind.trial => tr(
          'Lari setelah lima kata dihitung kalah, dan boss baru bisa dilawan lagi besok.',
          'Fleeing after five words counts as a defeat, and the boss can only be fought again tomorrow.',
          'Huir después de cinco palabras cuenta como derrota, y el jefe solo se podrá enfrentar de nuevo mañana.',
          'Fuir après cinq mots compte comme une défaite, et le boss ne pourra être affronté à nouveau que demain.',
          'Flucht nach fünf Wörtern zählt als Niederlage, und gegen den Boss kannst du erst morgen wieder kämpfen.',
          'Fugir depois de cinco palavras conta como derrota, e só dá para lutar contra o boss de novo amanhã.',
        ),
        RunKind.sub => tr(
          'Lari setelah lima kata dihitung kalah, dan musuh ini baru bisa dilawan lagi empat jam kemudian.',
          'Fleeing after five words counts as a defeat, and this foe can only be fought again four hours later.',
          'Huir después de cinco palabras cuenta como derrota, y este enemigo solo se podrá enfrentar de nuevo dentro de cuatro horas.',
          'Fuir après cinq mots compte comme une défaite, et cet ennemi ne pourra être affronté à nouveau que dans quatre heures.',
          'Flucht nach fünf Wörtern zählt als Niederlage, und gegen diesen Gegner kannst du erst in vier Stunden wieder kämpfen.',
          'Fugir depois de cinco palavras conta como derrota, e só dá para lutar contra este inimigo de novo daqui a quatro horas.',
        ),
        RunKind.placement => tr(
          'Gelarmu ditetapkan dari ranah yang sudah kamu lewati sejauh ini.',
          'Your title is set from the lands you have passed so far.',
          'Tu título se fija según las tierras que hayas superado hasta ahora.',
          'Ton titre est fixé d’après les terres franchies jusqu’ici.',
          'Dein Titel richtet sich nach den Ländern, die du bisher geschafft hast.',
          'Seu título é definido pelas terras que você superou até agora.',
        ),
        _ => tr(
          'Gelarmu tetap goyah sampai ujian ini kamu selesaikan.',
          'Your title keeps wavering until you finish this test.',
          'Tu título seguirá tambaleándose hasta que termines esta prueba.',
          'Ton titre vacillera tant que tu n’auras pas fini ce test.',
          'Dein Titel wankt weiter, bis du diesen Test beendest.',
          'Seu título continua vacilando até você terminar este teste.',
        ),
      },
      yes: _fight
          ? tr('Lari', 'Flee', 'Huir', 'Fuir', 'Fliehen', 'Fugir')
          : tr('Tinggalkan', 'Leave', 'Salir', 'Quitter', 'Verlassen', 'Sair'),
      no: _fight
          ? tr(
              'Terus bertarung',
              'Keep fighting',
              'Seguir luchando',
              'Continuer le combat',
              'Weiterkämpfen',
              'Continuar lutando',
            )
          : tr(
              'Lanjut ujian',
              'Go on with the test',
              'Seguir con la prueba',
              'Poursuivre le test',
              'Mit dem Test weitermachen',
              'Seguir com o teste',
            ),
    );
    if (!leave || !mounted) return;
    if (_kind == RunKind.trial && _done >= 5) {
      _e.finishTrial(widget.s.tier, min(_right, Engine.trialPass - 1), Engine.trialSize);
    }
    if (_kind == RunKind.sub && _done >= 5) _e.finishSub(min(_right, Engine.subPass - 1), Engine.subSize);
    if (_kind == RunKind.placement) _e.finishPlacement(_tiersPassed, _right, max(_done, 1));
    App.I.store.flush();
    App.I.changed();
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ building

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished || !_test,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Leaf(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: _finished ? _ending(context) : _desk(context),
      ),
    );
  }

  Widget _desk(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final it = _item;
    final total = _kind == RunKind.placement ? Engine.placementPerTier * Engine.placementTop : _q.length;
    final busy = _phase == _Phase.right || _phase == _Phase.miss;
    final combo = _g.combo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Press(
              onTap: _close,
              label: tr('Tutup', 'Close', 'Cerrar', 'Fermer', 'Schließen', 'Fechar'),
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.close, color: pal.ink, size: 24)),
            ),
            Expanded(child: _fight ? _Tally(_marks, _q.length, _i) : Bar(_done / total, height: 3)),
            const SizedBox(width: 12),
            if (combo >= 3)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text('Combo ×$combo', style: T.body(15.5, pal.ink, w: FontWeight.w700)),
              ),
            Text(
              _fight
                  ? '+$_xp XP'
                  : tr(
                      '${_done + 1} dari $total',
                      '${_done + 1} of $total',
                      '${_done + 1} de $total',
                      '${_done + 1} sur $total',
                      '${_done + 1} von $total',
                      '${_done + 1} de $total',
                    ),
              style: T.body(15.5, pal.muted),
            ),
            const SizedBox(width: 8),
          ],
        ),
        // which kingdom, which language: said quietly over the desk
        if (!_fight) const Padding(padding: EdgeInsets.only(left: 12), child: KingdomName(active: false)),
        if (_fight) _arena(context),
        if (_timed && !_fight)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(alignment: Alignment.centerRight, child: _ring(context)),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(8, _fight ? 12 : 22, 8, 8),
            child: AnimatedSwitcher(
              duration: look.calm ? Duration.zero : Dur.enter,
              reverseDuration: Duration.zero,
              layoutBuilder: (current, _) => current ?? const SizedBox(),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_i),
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    final dx = look.calm ? 0.0 : sin(t * pi * 5) * 7 * (1 - t);
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: switch (it.quiz) {
                    Quiz.cloze => _cloze(context),
                    Quiz.build => _build(context),
                    Quiz.choice => _choice(context),
                  },
                ),
              ),
            ),
          ),
        ),
        if (it.quiz != Quiz.choice)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkButton(
                  _phase == _Phase.shown
                      ? tr('Lanjut', 'Continue', 'Continuar', 'Continuer', 'Weiter', 'Continuar')
                      : tr('Periksa', 'Check', 'Comprobar', 'Vérifier', 'Prüfen', 'Conferir'),
                  onTap: busy || (it.quiz == Quiz.build && _placed.length < _target.length) ? null : _check,
                  sound: false,
                ),
                if (it.quiz == Quiz.cloze && (_kind == RunKind.learn || _kind == RunKind.placement))
                  Opacity(
                    opacity: _phase == _Phase.ask || _phase == _Phase.near ? 1 : 0,
                    child: GhostButton(
                      _kind == RunKind.learn
                          ? tr(
                              'Belum tahu, tunjukkan',
                              'I don\'t know, show me',
                              'No lo sé, muéstramelo',
                              'Je ne sais pas, montre-moi',
                              'Weiß ich nicht, zeig es mir',
                              'Não sei, me mostre',
                            )
                          : tr(
                              'Belum tahu',
                              'I don\'t know',
                              'No lo sé',
                              'Je ne sais pas',
                              'Weiß ich nicht',
                              'Não sei',
                            ),
                      onTap: _phase == _Phase.ask || _phase == _Phase.near ? () => _wrong('m') : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // -- the arena of a fight

  /// the time left for this word, as a ring that empties; red in its last seconds
  Widget _ring(BuildContext context) {
    final pal = Look.of(context).pal;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final left = (_seconds * (1 - _clock.value)).ceil();
        return Semantics(
          label: tr(
            'Sisa waktu $left detik',
            '$left seconds left',
            'Quedan $left segundos',
            'Encore $left secondes',
            'Noch $left Sekunden',
            'Faltam $left segundos',
          ),
          child: ExcludeSemantics(
            child: SizedBox(
              width: 42,
              height: 42,
              child: CustomPaint(
                painter: _RingPainter(1 - _clock.value, left <= 3 ? pal.bad : pal.ink, pal.line, pal.field),
                child: Center(
                  child: Text('$left', style: T.body(16, left <= 3 ? pal.bad : pal.ink, w: FontWeight.w700)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _arena(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final g = _g;
    final en = _enemy!;
    final big = en.boss;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final height = big ? (typing ? 236.0 : 300.0) : (typing ? 176.0 : 214.0);
    final rage = Text(
      _rage
          ? tr(
              'MURKA · −${Engine.rageCut} detik',
              'ENRAGED · −${Engine.rageCut} s',
              'FURIA · −${Engine.rageCut} s',
              'FUREUR · −${Engine.rageCut} s',
              'RASEND · −${Engine.rageCut} s',
              'FURIOSO · −${Engine.rageCut} s',
            )
          : tr(
              'Di bawah separuh: murka · −${Engine.rageCut} detik',
              'Below half: enraged · −${Engine.rageCut} s',
              'Por debajo de la mitad: furia · −${Engine.rageCut} s',
              'Sous la moitié : fureur · −${Engine.rageCut} s',
              'Unter der Hälfte: rasend · −${Engine.rageCut} s',
              'Abaixo da metade: furioso · −${Engine.rageCut} s',
            ),
      textAlign: TextAlign.center,
      style: _rage ? T.label(pal.bad) : T.body(12.5, pal.muted),
    );
    final hero = _Pips('${tr('Kamu', 'You', 'Tú', 'Toi', 'Du', 'Você')} · ${g.job.name}', _heroHp, _heroMax, pal.good);
    final stage = LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final foe = big ? min(h - 6, 176.0) : min(h - 10, 104.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              left: _pose == HeroPose.attack ? 64 : (_pose == HeroPose.hurt ? 4 : 18),
              bottom: 6,
              child: HeroSprite(
                garb: g.job.garb,
                tier: g.job.tier,
                weapon: g.tone('weapon'),
                shield: g.tone('shield'),
                cloak: g.tone('cloak'),
                livery: App.I.livery,
                pose: _pose,
                size: min(h - 10, 86.0),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 140),
              right: _pose == HeroPose.hurt ? 40 : (big ? 0 : 14),
              bottom: 4,
              child: EnemySprite(sprite: en.sprite, tone: en.tone, size: foe, struck: _struck, beaten: _enemyHp <= 0),
            ),
            if (_float.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_floatN),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, t, _) => Align(
                      alignment: Alignment(
                        _struck || _enemyHp <= 0 && _pose != HeroPose.hurt ? 0.5 : -0.6,
                        0.1 - t * 0.9,
                      ),
                      child: Opacity(
                        opacity: (1 - t * t).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: look.calm ? 1 : 1 + 0.35 * (1 - t) * (1 - t),
                          child: Text(
                            _float,
                            style: _float.length > 3
                                ? T.display(26, _pose == HeroPose.hurt ? pal.bad : pal.gold)
                                : T.body(28, _pose == HeroPose.hurt ? pal.bad : pal.gold, w: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 2, child: Center(child: _ring(context))),
          ],
        );
      },
    );
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = look.calm || !_flashBad ? 0.0 : sin(t * pi * 6) * 6 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: AnimatedContainer(
        duration: look.calm ? Duration.zero : Dur.enter,
        curve: Curves.easeOutCubic,
        height: height,
        margin: const EdgeInsets.only(top: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _Sky(look.calm ? null : _air, pal, big, _rage))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (big) ...[
                      _BossCard(
                        label: tr(
                          'Boss · penobatan ${rankNames[widget.s.tier]}',
                          'Boss · ${rankNames[widget.s.tier]} coronation',
                          'Jefe · coronación de ${rankNames[widget.s.tier]}',
                          'Boss · couronnement de ${rankNames[widget.s.tier]}',
                          'Boss · Krönung zum ${rankNames[widget.s.tier]}',
                          'Boss · coroação de ${rankNames[widget.s.tier]}',
                        ),
                        name: en.name,
                        compact: typing,
                      ),
                      const SizedBox(height: 6),
                      _BossBar(_enemyHp, _enemyMax, en.name),
                      const SizedBox(height: 3),
                      rage,
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerLeft, child: hero),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [hero, const Spacer(), _Hp(en.name, _enemyHp, _enemyMax, pal.bad, right: true)],
                      ),
                    Expanded(child: stage),
                  ],
                ),
              ),
              // the flash of a blow: gold when you strike, red when you are struck
              if (!look.calm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _flash,
                      builder: (context, _) {
                        final t = _flash.value;
                        if (t == 0 || t == 1) return const SizedBox();
                        return ColoredBox(
                          color: (_flashBad ? const Color(0xFFB8402E) : const Color(0xFFD9B861)).withValues(
                            alpha: 0.32 * (1 - t) * (1 - t),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -- the gap

  Widget _cloze(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final w = _item.w!;
    final answer = w.answer(App.I.british);
    final parts = w.parts;
    final heading = switch (_kind) {
      RunKind.learn =>
        _item.fresh
            ? tr('Kata baru', 'New word', 'Palabra nueva', 'Nouveau mot', 'Neues Wort', 'Palavra nova')
            : (w.inflected
                  ? tr(
                      'Isi dengan bentuk yang tepat',
                      'Fill in the right form',
                      'Escribe la forma correcta',
                      'Écris la bonne forme',
                      'Setze die richtige Form ein',
                      'Escreva a forma certa',
                    )
                  : tr(
                      'Isi celahnya',
                      'Fill the gap',
                      'Completa el hueco',
                      'Remplis le trou',
                      'Fülle die Lücke',
                      'Preencha a lacuna',
                    )),
      RunKind.placement => tr(
        'Ujian penempatan · ${rankNames[_ptier]}',
        'Placement test · ${rankNames[_ptier]}',
        'Prueba de nivel · ${rankNames[_ptier]}',
        'Test de niveau · ${rankNames[_ptier]}',
        'Einstufungstest · ${rankNames[_ptier]}',
        'Teste de nivelamento · ${rankNames[_ptier]}',
      ),
      RunKind.trial || RunKind.sub => tr(
        'Serang dengan kata yang tepat',
        'Strike with the right word',
        'Golpea con la palabra correcta',
        'Frappe avec le bon mot',
        'Schlag mit dem richtigen Wort zu',
        'Golpeie com a palavra certa',
      ),
      RunKind.defence => tr(
        'Mempertahankan gelar',
        'Defending the title',
        'Defendiendo el título',
        'Défense du titre',
        'Titel wird verteidigt',
        'Defendendo o título',
      ),
    };
    final String? note = switch (_phase) {
      _Phase.near =>
        _nearWhy == 'f'
            ? tr(
                'Katanya benar, bentuknya belum tepat. Lihat kata di sekitar celah.',
                'The word is right, the form is not. Look at the words around the gap.',
                'La palabra es correcta, la forma no. Mira las palabras alrededor del hueco.',
                'Le mot est juste, pas la forme. Regarde les mots autour du trou.',
                'Das Wort stimmt, die Form nicht. Sieh dir die Wörter um die Lücke an.',
                'A palavra está certa, a forma não. Olhe as palavras em volta da lacuna.',
              )
            : tr(
                'Hampir. Periksa ejaannya.',
                'Almost. Check the spelling.',
                'Casi. Revisa la ortografía.',
                'Presque. Vérifie l’orthographe.',
                'Fast. Prüfe die Schreibung.',
                'Quase. Confira a grafia.',
              ),
      _Phase.shown => tr(
        'Jawabannya $answer. Ketik sekali supaya melekat.',
        'The answer is $answer. Type it once so it sticks.',
        'La respuesta es $answer. Escríbela una vez para que se quede.',
        'La réponse est $answer. Tape-la une fois pour qu’elle reste.',
        'Die Antwort ist $answer. Tipp sie einmal, damit sie hängen bleibt.',
        'A resposta é $answer. Digite uma vez para fixar.',
      ),
      _Phase.miss => tr(
        'Jawabannya $answer.',
        'The answer is $answer.',
        'La respuesta es $answer.',
        'La réponse est $answer.',
        'Die Antwort ist $answer.',
        'A resposta é $answer.',
      ),
      _Phase.right =>
        _item.fresh
            ? tr(
                'Tercatat. Kata baru masuk kronikmu.',
                'Noted. A new word enters your chronicle.',
                'Anotado. Una palabra nueva entra en tu crónica.',
                'Noté. Un nouveau mot entre dans ta chronique.',
                'Verzeichnet. Ein neues Wort kommt in deine Chronik.',
                'Registrado. Uma palavra nova entra na sua crônica.',
              )
            : (_reward?.crit ?? false
                  ? tr(
                      'Benar, dan cepat.',
                      'Right, and fast.',
                      'Correcto, y rápido.',
                      'Juste, et vite.',
                      'Richtig, und schnell.',
                      'Certo, e rápido.',
                    )
                  : tr('Benar.', 'Right.', 'Correcto.', 'Juste.', 'Richtig.', 'Certo.')),
      _Phase.ask => null,
    };
    final typing = _phase == _Phase.ask || _phase == _Phase.near || _phase == _Phase.shown;
    final style = T.display(29, pal.ink, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(heading),
        const SizedBox(height: 14),
        Semantics(
          label: typing
              ? tr(
                  '${parts[0]} celah ${parts[1]}',
                  '${parts[0]} gap ${parts[1]}',
                  '${parts[0]} hueco ${parts[1]}',
                  '${parts[0]} trou ${parts[1]}',
                  '${parts[0]} Lücke ${parts[1]}',
                  '${parts[0]} lacuna ${parts[1]}',
                )
              : '${parts[0]}$answer${parts[1]}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: parts[0]),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: typing
                        ? _GapField(
                            controller: _input,
                            focus: _focus,
                            ghost: _phase == _Phase.shown ? answer : null,
                            onDone: _check,
                            minChars: max(5, answer.length),
                          )
                        : _GapWord(answer: answer, write: _write, told: _phase == _Phase.miss),
                  ),
                  TextSpan(text: parts[1]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: w.gloss,
                style: T.body(19, pal.ink, w: FontWeight.w500),
              ),
              TextSpan(
                text: '   ${_posName(w.pos)}${w.inflected ? ' · ${w.forms[0]}' : ''}',
                style: T.body(15, pal.muted),
              ),
            ],
          ),
        ),
        // a kingdom of another language: the whole sentence in the learner's own, and the letters to type with
        if (w.trans.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(w.trans, style: T.body(16.5, pal.muted, height: 1.4)),
        ],
        if (typing && App.I.kingdom.letters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final c in App.I.kingdom.letters) _LetterKey(c, onTap: () => _typeLetter(c))],
          ),
        ],
        const SizedBox(height: 12),
        _noteLine(note),
      ],
    );
  }

  void _typeLetter(String c) {
    final v = _input.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, c);
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + c.length),
    );
    _focus.requestFocus();
  }

  Widget _heading(String text) {
    final look = Look.of(context);
    return Row(
      children: [
        Expanded(child: Label(text)),
        if ((_reward?.xp ?? 0) > 0 && _phase == _Phase.right && !_fight)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('+${_reward!.xp} XP', style: T.body(15, look.pal.good, w: FontWeight.w700)),
          ),
        AnimatedScale(
          scale: _phase == _Phase.right ? 1 : 1.7,
          duration: look.calm ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _phase == _Phase.right ? 1 : 0,
            duration: const Duration(milliseconds: 90),
            child: const Seal(size: 30),
          ),
        ),
      ],
    );
  }

  Widget _noteLine(String? note) {
    final pal = Look.of(context).pal;
    final c = _phase == _Phase.right ? pal.good : (_phase == _Phase.near ? pal.muted : pal.bad);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: AnimatedSwitcher(
        duration: Dur.out,
        child: note == null
            ? const SizedBox(key: ValueKey('none'))
            : Row(
                key: ValueKey(note),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _phase == _Phase.right
                          ? Icons.check
                          : (_phase == _Phase.near ? Icons.edit_outlined : Icons.arrow_forward),
                      size: 18,
                      color: c,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(note, style: T.body(16, c, w: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // -- choosing a meaning or a partner word

  Widget _choice(BuildContext context) {
    final pal = Look.of(context).pal;
    final it = _item;
    final c = it.c;
    final correct = c != null ? c.correct : it.w!.gloss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          c != null
              ? tr(
                  'Pilih pasangan katanya',
                  'Choose the partner word',
                  'Elige la palabra compañera',
                  'Choisis le mot compagnon',
                  'Wähle das Partnerwort',
                  'Escolha a palavra parceira',
                )
              : (it.fresh
                    ? tr(
                        'Kata baru · pilih artinya',
                        'New word · choose its meaning',
                        'Palabra nueva · elige su significado',
                        'Nouveau mot · choisis son sens',
                        'Neues Wort · wähle seine Bedeutung',
                        'Palavra nova · escolha o sentido',
                      )
                    : tr(
                        'Pilih artinya',
                        'Choose the meaning',
                        'Elige el significado',
                        'Choisis le sens',
                        'Wähle die Bedeutung',
                        'Escolha o sentido',
                      )),
        ),
        const SizedBox(height: 14),
        if (c != null) ...[
          Text.rich(
            TextSpan(
              style: T.display(31, pal.ink, height: 1.4),
              children: [
                TextSpan(text: c.before),
                TextSpan(
                  text: _picked == null ? '_____' : correct,
                  style: TextStyle(color: _picked == null ? pal.ink : pal.good),
                ),
                TextSpan(text: c.after),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(c.gloss, style: T.body(18, pal.muted)),
        ] else ...[
          Text(it.w!.answer(App.I.british), style: T.display(42, pal.ink)),
          const SizedBox(height: 2),
          Text(_posName(it.w!.pos), style: T.body(15, pal.muted)),
        ],
        const SizedBox(height: 18),
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Option(
              text: o,
              state: _picked == null ? 0 : (o == correct ? 1 : (o == _picked ? 2 : 3)),
              onTap: _picked == null ? () => _pick(o) : null,
            ),
          ),
        if (_picked != null && c == null && it.fresh)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr(
                'Kata ini akan kembali sebentar lagi sebagai celah.',
                'This word will come back in a moment as a gap.',
                'Esta palabra volverá enseguida como hueco.',
                'Ce mot reviendra dans un instant sous forme de trou.',
                'Dieses Wort kommt gleich als Lücke zurück.',
                'Esta palavra volta daqui a pouco como lacuna.',
              ),
              style: T.body(15, pal.muted),
            ),
          ),
      ],
    );
  }

  // -- building the sentence

  Widget _build(BuildContext context) {
    final pal = Look.of(context).pal;
    final w = _item.w!;
    final done = _phase == _Phase.right || _phase == _Phase.miss;
    final left = List<String>.of(_pool);
    for (final p in _placed) {
      left.remove(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          tr(
            'Susun kalimat dengan kata ini',
            'Build the sentence with this word',
            'Construye la frase con esta palabra',
            'Construis la phrase avec ce mot',
            'Bau den Satz mit diesem Wort',
            'Monte a frase com esta palavra',
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: w.gloss,
                style: T.body(19, pal.ink, w: FontWeight.w500),
              ),
              TextSpan(
                text: '   ${w.forms[0]}',
                style: T.body(16, pal.muted, w: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: pal.field,
            border: Border.all(color: pal.ink, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _placed.length; i++)
                _Chip(
                  text: _placed[i],
                  state: !done ? 0 : (i < _target.length && _plain(_placed[i]) == _plain(_target[i]) ? 1 : 2),
                  onTap: done ? null : () => setState(() => _placed.removeAt(i)),
                ),
              if (_placed.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr(
                      'Ketuk kata di bawah sesuai urutannya',
                      'Tap the words below in the right order',
                      'Toca las palabras de abajo en el orden correcto',
                      'Touche les mots ci-dessous dans le bon ordre',
                      'Tippe die Wörter unten in der richtigen Reihenfolge an',
                      'Toque nas palavras abaixo na ordem certa',
                    ),
                    style: T.body(16, pal.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!done)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in left) _Chip(text: t, state: 0, onTap: () => setState(() => _placed.add(t)))],
          )
        else if (_phase == _Phase.miss) ...[
          Text(
            tr(
              'Susunan yang benar:',
              'The right order:',
              'El orden correcto:',
              'Le bon ordre :',
              'Die richtige Reihenfolge:',
              'A ordem certa:',
            ),
            style: T.body(15, pal.muted),
          ),
          const SizedBox(height: 4),
          Text(_target.join(' '), style: T.display(23, pal.ink, height: 1.4)),
        ] else
          _noteLine(
            tr(
              'Benar. Dua kata lainnya hanya pengecoh.',
              'Right. The other two words were only decoys.',
              'Correcto. Las otras dos palabras solo eran señuelos.',
              'Juste. Les deux autres mots n’étaient que des leurres.',
              'Richtig. Die anderen zwei Wörter waren nur Köder.',
              'Certo. As outras duas palavras eram só iscas.',
            ),
          ),
      ],
    );
  }

  static String _posName(String p) => switch (p) {
    'n' => tr('kata benda', 'noun', 'sustantivo', 'nom', 'Nomen', 'substantivo'),
    'v' => tr('kata kerja', 'verb', 'verbo', 'verbe', 'Verb', 'verbo'),
    'adj' => tr('kata sifat', 'adjective', 'adjetivo', 'adjectif', 'Adjektiv', 'adjetivo'),
    'adv' => tr('kata keterangan', 'adverb', 'adverbio', 'adverbe', 'Adverb', 'advérbio'),
    'prep' => tr('kata depan', 'preposition', 'preposición', 'préposition', 'Präposition', 'preposição'),
    _ => tr('kata sambung', 'conjunction', 'conjunción', 'conjonction', 'Konjunktion', 'conjunção'),
  };

  // ------------------------------------------------------------------ endings

  Widget _ending(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final e = _e;
    final rank = e.rank;
    late final Widget mark;
    late final String label, title, text;
    switch (_kind) {
      case RunKind.learn:
        final gained = max(0, e.solidTotal - _solidBefore);
        mark = const Seal(size: 76);
        label = tr(
          'Tercatat hari ini',
          'Noted today',
          'Anotado hoy',
          'Noté aujourd’hui',
          'Heute verzeichnet',
          'Registrado hoje',
        );
        title = _done == 0
            ? tr(
                'Mejamu kosong',
                'Your desk is empty',
                'Tu mesa está vacía',
                'Ton bureau est vide',
                'Dein Pult ist leer',
                'Sua mesa está vazia',
              )
            : tr(
                '$_right benar dari $_done',
                '$_right right out of $_done',
                '$_right bien de $_done',
                '$_right justes sur $_done',
                '$_right richtig von $_done',
                '$_right certas de $_done',
              );
        text = _done == 0
            ? tr(
                'Tidak ada kata yang menunggu. Kembali besok.',
                'No words are waiting. Come back tomorrow.',
                'No hay palabras esperando. Vuelve mañana.',
                'Aucun mot n’attend. Reviens demain.',
                'Keine Wörter warten. Komm morgen wieder.',
                'Nenhuma palavra esperando. Volte amanhã.',
              )
            : [
                '+$_xp XP',
                if (_freshSeen > 0)
                  tr(
                    '$_freshSeen kata baru',
                    '$_freshSeen new words',
                    '$_freshSeen palabras nuevas',
                    '$_freshSeen nouveaux mots',
                    '$_freshSeen neue Wörter',
                    '$_freshSeen palavras novas',
                  ),
                if (gained > 0)
                  tr(
                    '$gained kata kini kukuh',
                    '$gained words now solid',
                    '$gained palabras ya firmes',
                    '$gained mots désormais ancrés',
                    '$gained Wörter jetzt gefestigt',
                    '$gained palavras agora firmes',
                  ),
                tr(
                  'combo terbaik ${_g.bestCombo}',
                  'best combo ${_g.bestCombo}',
                  'mejor combo ${_g.bestCombo}',
                  'meilleur combo ${_g.bestCombo}',
                  'beste Kombo ${_g.bestCombo}',
                  'melhor combo ${_g.bestCombo}',
                ),
              ].join(' · ');
      case RunKind.placement:
        mark = Shield(rank, width: 96);
        label = tr(
          'Ujian penempatan',
          'Placement test',
          'Prueba de nivel',
          'Test de niveau',
          'Einstufungstest',
          'Teste de nivelamento',
        );
        title = tr(
          'Kamu mulai sebagai ${rankNames[rank]}',
          'You start as a ${rankNames[rank]}',
          'Empiezas como ${rankNames[rank]}',
          'Tu commences en ${rankNames[rank]}',
          'Du beginnst als ${rankNames[rank]}',
          'Você começa como ${rankNames[rank]}',
        );
        text = rank == 0
            ? tr(
                'Semua kesatria pernah menjadi petani. Kata pertamamu menunggu.',
                'Every knight was once a peasant. Your first word is waiting.',
                'Todo caballero fue antes campesino. Tu primera palabra te espera.',
                'Tout chevalier fut d’abord paysan. Ton premier mot t’attend.',
                'Jeder Ritter war einmal ein Bauer. Dein erstes Wort wartet.',
                'Todo cavaleiro já foi camponês. Sua primeira palavra espera.',
              )
            : tr(
                'Jalanmu: ${_g.job.name}. Kosakatamu setara ${scoreLine(rank, App.I.banner)}. Kata dari ranah yang kamu lewati akan muncul untuk diulang, jadi gelar ini tetap harus dijaga.',
                'Your path: ${_g.job.name}. Your vocabulary is on a par with ${scoreLine(rank, App.I.banner)}. Words from the lands you skipped will come up for review, so this title still has to be kept.',
                'Tu camino: ${_g.job.name}. Tu vocabulario equivale a ${scoreLine(rank, App.I.banner)}. Las palabras de las tierras que saltaste volverán a repaso, así que este título aún hay que conservarlo.',
                'Ta voie : ${_g.job.name}. Ton vocabulaire équivaut à ${scoreLine(rank, App.I.banner)}. Les mots des terres sautées reviendront en révision : ce titre reste à garder.',
                'Dein Weg: ${_g.job.name}. Dein Wortschatz liegt auf dem Niveau von ${scoreLine(rank, App.I.banner)}. Wörter aus den übersprungenen Ländern kommen zur Wiederholung, also muss dieser Titel noch gehalten werden.',
                'Seu caminho: ${_g.job.name}. Seu vocabulário está no nível de ${scoreLine(rank, App.I.banner)}. Palavras das terras que você pulou vão aparecer para revisão, então este título ainda precisa ser mantido.',
              );
      case RunKind.trial || RunKind.sub:
        final en = _enemy!;
        mark = _passed
            ? HeroSprite(
                garb: _g.job.garb,
                tier: _g.job.tier,
                weapon: _g.tone('weapon'),
                shield: _g.tone('shield'),
                cloak: _g.tone('cloak'),
                livery: App.I.livery,
                pose: HeroPose.cheer,
                size: 104,
              )
            : EnemySprite(sprite: en.sprite, tone: en.tone, size: 104);
        label = _passed
            ? tr('Menang', 'Victory', 'Victoria', 'Victoire', 'Sieg', 'Vitória')
            : tr('Kalah', 'Defeat', 'Derrota', 'Défaite', 'Niederlage', 'Derrota');
        title = _passed
            ? tr(
                '${en.name} tumbang',
                'The ${en.name} has fallen',
                '${en.name} ha caído',
                '${en.name} est tombé',
                '${en.name} ist gefallen',
                '${en.name} caiu',
              )
            : tr(
                '${en.name} masih berdiri',
                'The ${en.name} still stands',
                '${en.name} sigue en pie',
                '${en.name} tient toujours debout',
                '${en.name} steht noch',
                '${en.name} ainda está de pé',
              );
        text = _passed
            ? tr(
                '$_right pukulan masuk, +$_xp XP. Kamu naik ke ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right blows landed, +$_xp XP. You rise to ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right golpes acertados, +$_xp XP. Subes a ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right coups portés, +$_xp XP. Tu montes à ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right Hiebe trafen, +$_xp XP. Du steigst auf zu ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right golpes acertaram, +$_xp XP. Você sobe para ${rankNames[rank]} ${stageName(e.stage)}.',
              )
            : tr(
                '$_right pukulan masuk, perlu $_enemyMax. Kata yang meleset sudah masuk antrean ulang. ${_kind == RunKind.sub ? 'Coba lagi empat jam lagi.' : 'Coba lagi besok.'}',
                '$_right blows landed, $_enemyMax needed. The words you missed are queued for review. ${_kind == RunKind.sub ? 'Try again in four hours.' : 'Try again tomorrow.'}',
                '$_right golpes acertados, se necesitaban $_enemyMax. Las palabras falladas vuelven a repaso. ${_kind == RunKind.sub ? 'Inténtalo de nuevo en cuatro horas.' : 'Inténtalo de nuevo mañana.'}',
                '$_right coups portés, il en fallait $_enemyMax. Les mots manqués repartent en révision. ${_kind == RunKind.sub ? 'Réessaie dans quatre heures.' : 'Réessaie demain.'}',
                '$_right Hiebe trafen, $_enemyMax waren nötig. Die verfehlten Wörter stehen zur Wiederholung an. ${_kind == RunKind.sub ? 'Versuch es in vier Stunden wieder.' : 'Versuch es morgen wieder.'}',
                '$_right golpes acertaram, eram precisos $_enemyMax. As palavras que você errou estão na fila de revisão. ${_kind == RunKind.sub ? 'Tente de novo em quatro horas.' : 'Tente de novo amanhã.'}',
              );
      case RunKind.defence:
        mark = Shield(rank, width: 96, hollow: !_passed);
        label = tr(
          'Mempertahankan gelar',
          'Defending the title',
          'Defendiendo el título',
          'Défense du titre',
          'Titel wird verteidigt',
          'Defendendo o título',
        );
        title = _passed
            ? tr(
                'Gelar dipertahankan',
                'Title defended',
                'Título defendido',
                'Titre défendu',
                'Titel verteidigt',
                'Título defendido',
              )
            : tr(
                'Belum cukup',
                'Not enough yet',
                'Aún no es suficiente',
                'Pas encore assez',
                'Noch nicht genug',
                'Ainda não basta',
              );
        text = _passed
            ? tr(
                '$_right dari ${Engine.defenceSize} benar. ${rankNames[rank]} tetap gelarmu.',
                '$_right of ${Engine.defenceSize} right. ${rankNames[rank]} remains your title.',
                '$_right de ${Engine.defenceSize} bien. ${rankNames[rank]} sigue siendo tu título.',
                '$_right justes sur ${Engine.defenceSize}. ${rankNames[rank]} reste ton titre.',
                '$_right von ${Engine.defenceSize} richtig. ${rankNames[rank]} bleibt dein Titel.',
                '$_right de ${Engine.defenceSize} certas. ${rankNames[rank]} continua sendo seu título.',
              )
            : tr(
                '$_right dari ${Engine.defenceSize} benar, perlu ${Engine.defencePass}. Kamu masih punya ${e.shakyDaysLeft} hari.',
                '$_right of ${Engine.defenceSize} right, ${Engine.defencePass} needed. You still have ${e.shakyDaysLeft} days.',
                '$_right de ${Engine.defenceSize} bien, se necesitaban ${Engine.defencePass}. Aún te quedan ${e.shakyDaysLeft} días.',
                '$_right justes sur ${Engine.defenceSize}, il en fallait ${Engine.defencePass}. Il te reste ${e.shakyDaysLeft} jours.',
                '$_right von ${Engine.defenceSize} richtig, ${Engine.defencePass} nötig. Du hast noch ${e.shakyDaysLeft} Tage.',
                '$_right de ${Engine.defenceSize} certas, eram precisas ${Engine.defencePass}. Você ainda tem ${e.shakyDaysLeft} dias.',
              );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Rise(child: Center(child: mark)),
          const SizedBox(height: 26),
          Rise(
            delay: const Duration(milliseconds: 80),
            child: Center(child: Label(label)),
          ),
          const SizedBox(height: 10),
          Rise(
            delay: const Duration(milliseconds: 140),
            child: Text(title, textAlign: TextAlign.center, style: T.display(36, pal.ink)),
          ),
          const SizedBox(height: 12),
          Rise(
            delay: const Duration(milliseconds: 200),
            child: Text(text, textAlign: TextAlign.center, style: T.body(17, pal.muted, height: 1.45)),
          ),
          if (_news.isNotEmpty) ...[
            const SizedBox(height: 16),
            Rise(
              delay: const Duration(milliseconds: 280),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.field,
                  border: Border.all(color: pal.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final n in _news.toSet().take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(n, style: T.body(16.5, pal.ink, w: FontWeight.w500)),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(flex: 3),
          InkButton(
            _kind == RunKind.placement
                ? tr(
                    'Masuk ke negerimu',
                    'Enter your realm',
                    'Entra en tu reino',
                    'Entre dans ton royaume',
                    'Betritt dein Reich',
                    'Entre no seu reino',
                  )
                : tr('Selesai', 'Done', 'Hecho', 'Terminé', 'Fertig', 'Pronto'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String stageName(int stage) => const ['I', 'II', 'III'][stage.clamp(0, 2)];

/// The gap itself is the field: you tap it and type in the sentence. It is as wide as the word needs and grows
/// with what is typed.
class _GapField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String? ghost;
  final VoidCallback onDone;
  final int minChars;
  const _GapField({
    required this.controller,
    required this.focus,
    required this.ghost,
    required this.onDone,
    required this.minChars,
  });

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final style = T.display(29, pal.ink, height: 1.2);
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: pal.ink,
        selectionColor: pal.ink.withValues(alpha: 0.18),
        selectionHandleColor: pal.ink,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pal.ink, width: 2)),
        ),
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 14.0 * minChars.clamp(5, 12)),
            child: TextField(
              key: const ValueKey('gap-field'),
              controller: controller,
              focusNode: focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onEditingComplete: onDone,
              cursorColor: pal.ink,
              cursorWidth: 2,
              style: style,
              decoration: InputDecoration.collapsed(
                hintText: ghost,
                hintStyle: style.copyWith(color: pal.muted.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gap once it is answered: the word written in from the left, or told plainly.
class _GapWord extends StatelessWidget {
  final String answer;
  final Animation<double> write;
  final bool told;
  const _GapWord({required this.answer, required this.write, required this.told});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final style = T.display(29, told ? pal.bad : (pal.dark ? pal.ink : look.accent), height: 1.2);
    Widget word = Text(answer, key: const ValueKey('gap-word'), style: style);
    if (!told && !look.calm) {
      word = Stack(
        children: [
          Opacity(opacity: 0, child: Text(answer, style: style)),
          AnimatedBuilder(
            animation: write,
            builder: (context, child) => ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: Curves.easeOut.transform(write.value).clamp(0.0, 1.0),
                child: child,
              ),
            ),
            child: word,
          ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.ink, width: 2)),
      ),
      child: word,
    );
  }
}

class _Option extends StatelessWidget {
  final String text;
  final int state; // 0 open, 1 the right one, 2 picked and wrong, 3 not picked
  final VoidCallback? onTap;
  const _Option({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final edge = state == 1 ? pal.good : (state == 2 ? pal.bad : (state == 3 ? pal.line : pal.ink));
    return Press(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Dur.out,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: state == 1 ? pal.field : Colors.transparent,
          border: Border.all(color: edge, width: state == 1 || state == 2 ? 2.2 : 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: T.body(17.5, state == 3 ? pal.muted : pal.ink, w: FontWeight.w500)),
            ),
            if (state == 1) Icon(Icons.check, color: pal.good, size: 22),
            if (state == 2) Icon(Icons.close, color: pal.bad, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final int state; // 0 plain, 1 in the right place, 2 in the wrong place
  final VoidCallback? onTap;
  const _Chip({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: pal.bg,
          border: Border.all(
            color: state == 2 ? pal.bad : (state == 1 ? pal.good : pal.ink),
            width: state == 0 ? 1.5 : 2.2,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: T
              .display(21, pal.ink, height: 1.2)
              .copyWith(decoration: state == 2 ? TextDecoration.lineThrough : null),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// a life bar with its number, so it never rests on colour alone
class _Hp extends StatelessWidget {
  final String name;
  final int hp, max;
  final Color color;
  final bool right;
  const _Hp(this.name, this.hp, this.max, this.color, {this.right = false});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Semantics(
      label: tr(
        '$name, nyawa $hp dari $max',
        '$name, life $hp of $max',
        '$name, vida $hp de $max',
        '$name, vie $hp sur $max',
        '$name, Leben $hp von $max',
        '$name, vida $hp de $max',
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                '${right ? tr('Musuh', 'Foe', 'Enemigo', 'Ennemi', 'Gegner', 'Inimigo') : name}  $hp/$max',
                style: T.body(14, pal.ink, w: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Container(
                height: 9,
                decoration: BoxDecoration(border: Border.all(color: pal.ink, width: 1.2)),
                child: Bar(max == 0 ? 0 : hp / max, height: 9, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// a letter the keyboard may hide (ä, ñ, ç …), pressed into the gap
class _LetterKey extends StatelessWidget {
  final String letter;
  final VoidCallback onTap;
  const _LetterKey(this.letter, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Press(
      onTap: onTap,
      label: letter,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pal.deep,
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(letter, style: T.body(19, pal.ink)),
      ),
    );
  }
}

/// the time left, as a ring
class _RingPainter extends CustomPainter {
  final double left;
  final Color color, track, fill;
  _RingPainter(this.left, this.color, this.track, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2.5;
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * left.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.left != left || old.color != color || old.fill != fill;
}

/// the land behind a fight: a road under a pale sky, or for a boss a dark ridge, its fire and the embers rising
class _Sky extends CustomPainter {
  final Animation<double>? air;
  final Pal pal;
  final bool boss, rage;
  _Sky(this.air, this.pal, this.boss, this.rage) : super(repaint: air);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = air?.value ?? 0.35;
    if (!boss) {
      final sky = Color.lerp(pal.deep, const Color(0xFF9DB0B8), pal.dark ? 0.12 : 0.32)!;
      final ground = Color.lerp(pal.deep, const Color(0xFFB9AE94), pal.dark ? 0.16 : 0.55)!;
      canvas.drawRect(Offset.zero & size, Paint()..color = sky);
      final trees = Paint()..color = pal.line.withValues(alpha: pal.dark ? 0.9 : 0.75);
      for (final x in [0.04, 0.12, 0.84, 0.93]) {
        final cx = x * w, base = h * 0.74;
        canvas.drawPath(
          Path()
            ..moveTo(cx - 13, base)
            ..lineTo(cx, base - 34 - (x * 37 % 1) * 12)
            ..lineTo(cx + 13, base)
            ..close(),
          trees,
        );
      }
      canvas.drawRect(Rect.fromLTWH(0, h * 0.74, w, h * 0.26), Paint()..color = ground);
      final dash = Paint()
        ..color = pal.muted.withValues(alpha: 0.35)
        ..strokeWidth = 2;
      for (var x = 6.0; x < w; x += 14) {
        canvas.drawLine(Offset(x, h * 0.86), Offset(x + 6, h * 0.86), dash);
      }
      return;
    }
    // the boss's hall: night, a ridge of broken stone, and its own fire behind it
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF100D0C), Color(0xFF1E1915)],
        ).createShader(Offset.zero & size),
    );
    final pulse = 0.78 + 0.22 * sin(t * 2 * pi);
    final fire = Offset(w * 0.72, h * 0.72);
    canvas.drawCircle(
      fire,
      w * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF8E1B16).withValues(alpha: (rage ? 0.9 : 0.62) * pulse),
            const Color(0xFF8E1B16).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: fire, radius: w * 0.62)),
    );
    final ridge = Path()..moveTo(0, h * 0.82);
    const peaks = [0.62, 0.74, 0.52, 0.7, 0.46, 0.66, 0.5, 0.72, 0.58, 0.8];
    for (var i = 0; i < peaks.length; i++) {
      ridge.lineTo(w * (i + 0.5) / peaks.length, h * peaks[i]);
      ridge.lineTo(w * (i + 1) / peaks.length, h * (peaks[i] + 0.12).clamp(0.0, 0.84));
    }
    ridge
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ridge, Paint()..color = const Color(0xFF2A2420));
    canvas.drawPath(
      ridge,
      Paint()
        ..color = const Color(0xFF3F3B34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.9, w, h * 0.1), Paint()..color = const Color(0xFF211C18));
    // embers, each on its own clock
    final n = rage ? 26 : 14;
    final ember = Paint();
    for (var i = 0; i < n; i++) {
      final seed = (i * 0.6180339) % 1;
      final p = (t + seed * 1.7) % 1;
      final x = w * ((seed * 7.3) % 1) + sin((p + seed) * 2 * pi) * 8;
      final y = h * 0.98 - p * h * 0.85;
      final a = p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85;
      ember.color = const Color(0xFFE07A3A).withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 1.3 + seed * 1.1, ember);
    }
  }

  @override
  bool shouldRepaint(_Sky old) => old.rage != rage || old.pal != pal || old.boss != boss || old.air != air;
}

/// the boss's name, struck in like a title card
class _BossCard extends StatelessWidget {
  final String label, name;
  final bool compact;
  const _BossCard({required this.label, required this.name, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: look.calm ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.3 - 0.3 * t, child: child),
      ),
      child: Column(
        children: [
          if (!compact) Text(label.toUpperCase(), textAlign: TextAlign.center, style: T.label(pal.gold)),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.display(compact ? 22 : 32, pal.ink, height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// the boss's life across the arena, with the mark where its rage begins
class _BossBar extends StatelessWidget {
  final int hp, max;
  final String name;
  const _BossBar(this.hp, this.max, this.name);

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final frac = max == 0 ? 0.0 : hp / max;
    return Semantics(
      label: tr(
        '$name, nyawa $hp dari $max',
        '$name, life $hp of $max',
        '$name, vida $hp de $max',
        '$name, vie $hp sur $max',
        '$name, Leben $hp von $max',
        '$name, vida $hp de $max',
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: 2,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pal.field,
                          border: Border.all(color: pal.muted),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 3,
                      bottom: 3,
                      right: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedFractionallySizedBox(
                          duration: look.calm ? Duration.zero : Dur.slow,
                          curve: Curves.easeOutCubic,
                          widthFactor: frac,
                          heightFactor: 1,
                          child: const DecoratedBox(decoration: BoxDecoration(color: Color(0xFFB8402E))),
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0),
                      child: Container(width: 2, height: 16, color: pal.gold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$hp/$max', style: T.body(13.5, pal.ink, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// your life as boxes, one for each blow you can still take
class _Pips extends StatelessWidget {
  final String name;
  final int hp, max;
  final Color color;
  const _Pips(this.name, this.hp, this.max, this.color);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Semantics(
      label: tr(
        '$name, nyawa $hp dari $max',
        '$name, life $hp of $max',
        '$name, vida $hp de $max',
        '$name, vie $hp sur $max',
        '$name, Leben $hp von $max',
        '$name, vida $hp de $max',
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$name  $hp/$max', style: T.body(13.5, pal.ink, w: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < max; i++)
                  AnimatedContainer(
                    duration: Dur.enter,
                    width: 16,
                    height: 9,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: i < hp ? color : pal.field,
                      border: Border.all(color: i < hp ? color : pal.muted),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// every word of a fight as a box: filled when right, struck through when missed, ringed when it is the one now
class _Tally extends StatelessWidget {
  final List<bool> marks;
  final int total, now;
  const _Tally(this.marks, this.total, this.now);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final right = marks.where((m) => m).length;
    return Semantics(
      label: tr(
        'Kata ${now + 1} dari $total · $right benar, ${marks.length - right} salah',
        'Word ${now + 1} of $total · $right right, ${marks.length - right} missed',
        'Palabra ${now + 1} de $total · $right bien, ${marks.length - right} mal',
        'Mot ${now + 1} sur $total · $right justes, ${marks.length - right} manqués',
        'Wort ${now + 1} von $total · $right richtig, ${marks.length - right} verfehlt',
        'Palavra ${now + 1} de $total · $right certas, ${marks.length - right} erradas',
      ),
      child: ExcludeSemantics(
        child: SizedBox(height: 14, child: CustomPaint(painter: _TallyPainter(marks, total, now, pal))),
      ),
    );
  }
}

class _TallyPainter extends CustomPainter {
  final List<bool> marks;
  final int total, now;
  final Pal pal;
  _TallyPainter(this.marks, this.total, this.now, this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final gap = total > 15 ? 2.0 : 3.0;
    final bw = (size.width - gap * (total - 1)) / total;
    for (var i = 0; i < total; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (bw + gap), 1, bw, size.height - 2),
        const Radius.circular(1.5),
      );
      if (i < marks.length) {
        canvas.drawRRect(r, Paint()..color = marks[i] ? pal.good : pal.bad);
        if (!marks[i]) {
          canvas.drawLine(
            r.outerRect.bottomLeft + const Offset(1, -1),
            r.outerRect.topRight + const Offset(-1, 1),
            Paint()
              ..color = pal.field
              ..strokeWidth = 1.4,
          );
        }
      } else {
        canvas.drawRRect(
          r,
          Paint()
            ..color = i == now ? pal.ink : pal.line
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == now ? 1.8 : 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) => true;
}
