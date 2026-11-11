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

class RunScreen extends StatefulWidget {
  /// for tests: what the card on screen expects (the word, the right option, or the sentence)
  @visibleForTesting
  static String probe = '';

  final RunKind kind;
  final int tier;
  final int extraFresh;
  const RunScreen({super.key, required this.kind, this.tier = 0, this.extraFresh = 0});

  @override
  State<RunScreen> createState() => _RunState();
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

class _RunState extends State<RunScreen> with TickerProviderStateMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _write = AnimationController(vsync: this, duration: Dur.write);
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: Engine.trialSeconds),
  );
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
  RunKind get _kind => widget.kind;
  bool get _test => _kind != RunKind.learn;
  bool get _fight => _kind == RunKind.trial || _kind == RunKind.sub;
  bool get _timed => _fight || _kind == RunKind.defence;

  /// seconds per word; a job's perk can give a little more against a guard of the road, never in a coronation
  int get _seconds => Engine.trialSeconds + (_kind == RunKind.sub ? _g.perk('subTime') : 0);
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
        final cards = _e.sitting(extraFresh: widget.extraFresh);
        final collocs = App.I.deck.collocs.where((c) => c.tier <= _e.learning).toList()..shuffle(Random(_e.now()));
        var k = 0;
        for (var n = 0; n < cards.length; n++) {
          _q.add(_Item(cards[n].w, cards[n].quiz, cards[n].fresh));
          if ((n + 1) % _g.collocEvery == 0 && k < collocs.length) _q.add(_Item.colloc(collocs[k++]));
        }
      case RunKind.placement:
        _q.addAll([for (final w in _e.placementWords(1)) _Item(w, Quiz.cloze, false)]);
      case RunKind.trial:
        _q.addAll([for (final w in _e.trialWords(widget.tier, Engine.trialSize)) _Item(w, Quiz.cloze, false)]);
        _startFight(Engine.trialPass, Engine.trialSize - Engine.trialPass + 1);
      case RunKind.sub:
        _q.addAll([for (final w in _e.subWords()) _Item(w, Quiz.cloze, false)]);
        _startFight(Engine.subPass, Engine.subSize - Engine.subPass + 1 + _g.perk('subHp'));
        _clock.duration = Duration(seconds: _seconds);
      case RunKind.defence:
        _q.addAll([for (final w in _e.trialWords(widget.tier, Engine.defenceSize)) _Item(w, Quiz.cloze, false)]);
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
      _enemyHp = max(0, _enemyHp - 1);
      _blow(HeroPose.attack, crit ? tr('KRITIS!', 'CRITICAL!', '¡CRÍTICO!', 'CRITIQUE !') : '−1', true);
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
        _passed = _enemyHp <= 0 && _e.finishTrial(widget.tier, Engine.trialPass, Engine.trialSize);
        if (!_passed) _e.finishTrial(widget.tier, min(_right, Engine.trialPass - 1), Engine.trialSize);
        if (_passed) {
          _news.insertAll(0, _g.onVictory(_rankBefore, _stageBefore, true, _wrongN == 0));
          // the build of the title just won decides the job
          final (job, lines) = _g.onPromotion(widget.tier, _wrongN == 0);
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
        runRoute(Coronation(rank: widget.tier, right: _right, total: _done, news: List.of(_news), job: _newJob)),
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
          ? tr('Lari dari pertarungan?', 'Flee the fight?', '¿Huir del combate?', 'Fuir le combat ?')
          : tr('Tinggalkan ujian?', 'Leave the test?', '¿Salir de la prueba?', 'Quitter le test ?'),
      text: switch (_kind) {
        RunKind.trial => tr(
          'Lari setelah lima kata dihitung kalah, dan boss baru bisa dilawan lagi besok.',
          'Fleeing after five words counts as a defeat, and the boss can only be fought again tomorrow.',
          'Huir después de cinco palabras cuenta como derrota, y el jefe solo se podrá enfrentar de nuevo mañana.',
          'Fuir après cinq mots compte comme une défaite, et le boss ne pourra être affronté à nouveau que demain.',
        ),
        RunKind.sub => tr(
          'Lari setelah lima kata dihitung kalah, dan musuh ini baru bisa dilawan lagi empat jam kemudian.',
          'Fleeing after five words counts as a defeat, and this foe can only be fought again four hours later.',
          'Huir después de cinco palabras cuenta como derrota, y este enemigo solo se podrá enfrentar de nuevo dentro de cuatro horas.',
          'Fuir après cinq mots compte comme une défaite, et cet ennemi ne pourra être affronté à nouveau que dans quatre heures.',
        ),
        RunKind.placement => tr(
          'Gelarmu ditetapkan dari ranah yang sudah kamu lewati sejauh ini.',
          'Your title is set from the lands you have passed so far.',
          'Tu título se fija según las tierras que hayas superado hasta ahora.',
          'Ton titre est fixé d’après les terres franchies jusqu’ici.',
        ),
        _ => tr(
          'Gelarmu tetap goyah sampai ujian ini kamu selesaikan.',
          'Your title keeps wavering until you finish this test.',
          'Tu título seguirá tambaleándose hasta que termines esta prueba.',
          'Ton titre vacillera tant que tu n’auras pas fini ce test.',
        ),
      },
      yes: _fight ? tr('Lari', 'Flee', 'Huir', 'Fuir') : tr('Tinggalkan', 'Leave', 'Salir', 'Quitter'),
      no: _fight
          ? tr('Terus bertarung', 'Keep fighting', 'Seguir luchando', 'Continuer le combat')
          : tr('Lanjut ujian', 'Go on with the test', 'Seguir con la prueba', 'Poursuivre le test'),
    );
    if (!leave || !mounted) return;
    if (_kind == RunKind.trial && _done >= 5) {
      _e.finishTrial(widget.tier, min(_right, Engine.trialPass - 1), Engine.trialSize);
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
              label: tr('Tutup', 'Close', 'Cerrar', 'Fermer'),
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.close, color: pal.ink, size: 24)),
            ),
            Expanded(
              child: _fight ? Text(_enemy?.name ?? '', style: T.display(21, pal.ink)) : Bar(_done / total, height: 3),
            ),
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
                    ),
              style: T.body(15.5, pal.muted),
            ),
            const SizedBox(width: 8),
          ],
        ),
        if (_fight) _arena(context),
        if (_timed)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => Semantics(
                label: tr(
                  'Sisa waktu ${(_seconds * (1 - _clock.value)).ceil()} detik',
                  '${(_seconds * (1 - _clock.value)).ceil()} seconds left',
                  'Quedan ${(_seconds * (1 - _clock.value)).ceil()} segundos',
                  'Encore ${(_seconds * (1 - _clock.value)).ceil()} secondes',
                ),
                child: Bar(1 - _clock.value, height: 2, color: pal.ink, animate: false),
              ),
            ),
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
                      ? tr('Lanjut', 'Continue', 'Continuar', 'Continuer')
                      : tr('Periksa', 'Check', 'Comprobar', 'Vérifier'),
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
                            )
                          : tr('Belum tahu', 'I don\'t know', 'No lo sé', 'Je ne sais pas'),
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

  Widget _arena(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final g = _g;
    final en = _enemy!;
    final big = en.boss;
    return SizedBox(
      height: 152,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, right: 0, bottom: 14, child: Container(height: 1.5, color: pal.ink)),
          Positioned(left: 0, top: 0, child: _Hp(tr('Kamu', 'You', 'Tú', 'Toi'), _heroHp, _heroMax, pal.good)),
          Positioned(right: 0, top: 0, child: _Hp(en.name, _enemyHp, _enemyMax, pal.bad, right: true)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            left: _pose == HeroPose.attack ? 56 : (_pose == HeroPose.hurt ? 4 : 18),
            bottom: 15,
            child: HeroSprite(
              garb: g.job.garb,
              tier: g.job.tier,
              weapon: g.tone('weapon'),
              shield: g.tone('shield'),
              cloak: g.tone('cloak'),
              pose: _pose,
              size: 80,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 140),
            right: _pose == HeroPose.hurt ? 44 : 18,
            bottom: 15,
            child: EnemySprite(
              sprite: en.sprite,
              tone: en.tone,
              size: big ? 96 : 84,
              struck: _struck,
              beaten: _enemyHp <= 0,
            ),
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
                      _struck || _enemyHp <= 0 && _pose != HeroPose.hurt ? 0.55 : -0.6,
                      0.1 - t * 0.9,
                    ),
                    child: Opacity(
                      opacity: (1 - t * t).clamp(0.0, 1.0),
                      child: Text(
                        _float,
                        style: T.body(
                          _float.length > 3 ? 20 : 24,
                          _pose == HeroPose.hurt ? pal.bad : pal.ink,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            ? tr('Kata baru', 'New word', 'Palabra nueva', 'Nouveau mot')
            : (w.inflected
                  ? tr(
                      'Isi dengan bentuk yang tepat',
                      'Fill in the right form',
                      'Escribe la forma correcta',
                      'Écris la bonne forme',
                    )
                  : tr('Isi celahnya', 'Fill the gap', 'Completa el hueco', 'Remplis le trou')),
      RunKind.placement => tr(
        'Ujian penempatan · ${rankNames[_ptier]}',
        'Placement test · ${rankNames[_ptier]}',
        'Prueba de nivel · ${rankNames[_ptier]}',
        'Test de niveau · ${rankNames[_ptier]}',
      ),
      RunKind.trial || RunKind.sub => tr(
        'Serang dengan kata yang tepat',
        'Strike with the right word',
        'Golpea con la palabra correcta',
        'Frappe avec le bon mot',
      ),
      RunKind.defence => tr('Mempertahankan gelar', 'Defending the title', 'Defendiendo el título', 'Défense du titre'),
    };
    final String? note = switch (_phase) {
      _Phase.near =>
        _nearWhy == 'f'
            ? tr(
                'Katanya benar, bentuknya belum tepat. Lihat kata di sekitar celah.',
                'The word is right, the form is not. Look at the words around the gap.',
                'La palabra es correcta, la forma no. Mira las palabras alrededor del hueco.',
                'Le mot est juste, pas la forme. Regarde les mots autour du trou.',
              )
            : tr(
                'Hampir. Periksa ejaannya.',
                'Almost. Check the spelling.',
                'Casi. Revisa la ortografía.',
                'Presque. Vérifie l’orthographe.',
              ),
      _Phase.shown => tr(
        'Jawabannya $answer. Ketik sekali supaya melekat.',
        'The answer is $answer. Type it once so it sticks.',
        'La respuesta es $answer. Escríbela una vez para que se quede.',
        'La réponse est $answer. Tape-la une fois pour qu’elle reste.',
      ),
      _Phase.miss => tr(
        'Jawabannya $answer.',
        'The answer is $answer.',
        'La respuesta es $answer.',
        'La réponse est $answer.',
      ),
      _Phase.right =>
        _item.fresh
            ? tr(
                'Tercatat. Kata baru masuk kronikmu.',
                'Noted. A new word enters your chronicle.',
                'Anotado. Una palabra nueva entra en tu crónica.',
                'Noté. Un nouveau mot entre dans ta chronique.',
              )
            : (_reward?.crit ?? false
                  ? tr('Benar, dan cepat.', 'Right, and fast.', 'Correcto, y rápido.', 'Juste, et vite.')
                  : tr('Benar.', 'Right.', 'Correcto.', 'Juste.')),
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
        const SizedBox(height: 12),
        _noteLine(note),
      ],
    );
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
                )
              : (it.fresh
                    ? tr(
                        'Kata baru · pilih artinya',
                        'New word · choose its meaning',
                        'Palabra nueva · elige su significado',
                        'Nouveau mot · choisis son sens',
                      )
                    : tr('Pilih artinya', 'Choose the meaning', 'Elige el significado', 'Choisis le sens')),
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
            tr('Susunan yang benar:', 'The right order:', 'El orden correcto:', 'Le bon ordre :'),
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
            ),
          ),
      ],
    );
  }

  static String _posName(String p) => switch (p) {
    'n' => tr('kata benda', 'noun', 'sustantivo', 'nom'),
    'v' => tr('kata kerja', 'verb', 'verbo', 'verbe'),
    'adj' => tr('kata sifat', 'adjective', 'adjetivo', 'adjectif'),
    'adv' => tr('kata keterangan', 'adverb', 'adverbio', 'adverbe'),
    'prep' => tr('kata depan', 'preposition', 'preposición', 'préposition'),
    _ => tr('kata sambung', 'conjunction', 'conjunción', 'conjonction'),
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
        label = tr('Tercatat hari ini', 'Noted today', 'Anotado hoy', 'Noté aujourd’hui');
        title = _done == 0
            ? tr('Mejamu kosong', 'Your desk is empty', 'Tu mesa está vacía', 'Ton bureau est vide')
            : tr(
                '$_right benar dari $_done',
                '$_right right out of $_done',
                '$_right bien de $_done',
                '$_right justes sur $_done',
              );
        text = _done == 0
            ? tr(
                'Tidak ada kata yang menunggu. Kembali besok.',
                'No words are waiting. Come back tomorrow.',
                'No hay palabras esperando. Vuelve mañana.',
                'Aucun mot n’attend. Reviens demain.',
              )
            : [
                '+$_xp XP',
                if (_freshSeen > 0)
                  tr(
                    '$_freshSeen kata baru',
                    '$_freshSeen new words',
                    '$_freshSeen palabras nuevas',
                    '$_freshSeen nouveaux mots',
                  ),
                if (gained > 0)
                  tr(
                    '$gained kata kini kukuh',
                    '$gained words now solid',
                    '$gained palabras ya firmes',
                    '$gained mots désormais ancrés',
                  ),
                tr(
                  'combo terbaik ${_g.bestCombo}',
                  'best combo ${_g.bestCombo}',
                  'mejor combo ${_g.bestCombo}',
                  'meilleur combo ${_g.bestCombo}',
                ),
              ].join(' · ');
      case RunKind.placement:
        mark = Shield(rank, width: 96);
        label = tr('Ujian penempatan', 'Placement test', 'Prueba de nivel', 'Test de niveau');
        title = tr(
          'Kamu mulai sebagai ${rankNames[rank]}',
          'You start as a ${rankNames[rank]}',
          'Empiezas como ${rankNames[rank]}',
          'Tu commences en ${rankNames[rank]}',
        );
        text = rank == 0
            ? tr(
                'Semua kesatria pernah menjadi petani. Kata pertamamu menunggu.',
                'Every knight was once a peasant. Your first word is waiting.',
                'Todo caballero fue antes campesino. Tu primera palabra te espera.',
                'Tout chevalier fut d’abord paysan. Ton premier mot t’attend.',
              )
            : tr(
                'Jalanmu: ${_g.job.name}. Kosakatamu setara ${scoreLine(rank, App.I.banner)}. Kata dari ranah yang kamu lewati akan muncul untuk diulang, jadi gelar ini tetap harus dijaga.',
                'Your path: ${_g.job.name}. Your vocabulary is on a par with ${scoreLine(rank, App.I.banner)}. Words from the lands you skipped will come up for review, so this title still has to be kept.',
                'Tu camino: ${_g.job.name}. Tu vocabulario equivale a ${scoreLine(rank, App.I.banner)}. Las palabras de las tierras que saltaste volverán a repaso, así que este título aún hay que conservarlo.',
                'Ta voie : ${_g.job.name}. Ton vocabulaire équivaut à ${scoreLine(rank, App.I.banner)}. Les mots des terres sautées reviendront en révision : ce titre reste à garder.',
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
                pose: HeroPose.cheer,
                size: 104,
              )
            : EnemySprite(sprite: en.sprite, tone: en.tone, size: 104);
        label = _passed ? tr('Menang', 'Victory', 'Victoria', 'Victoire') : tr('Kalah', 'Defeat', 'Derrota', 'Défaite');
        title = _passed
            ? tr('${en.name} tumbang', 'The ${en.name} has fallen', '${en.name} ha caído', '${en.name} est tombé')
            : tr(
                '${en.name} masih berdiri',
                'The ${en.name} still stands',
                '${en.name} sigue en pie',
                '${en.name} tient toujours debout',
              );
        text = _passed
            ? tr(
                '$_right pukulan masuk, +$_xp XP. Kamu naik ke ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right blows landed, +$_xp XP. You rise to ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right golpes acertados, +$_xp XP. Subes a ${rankNames[rank]} ${stageName(e.stage)}.',
                '$_right coups portés, +$_xp XP. Tu montes à ${rankNames[rank]} ${stageName(e.stage)}.',
              )
            : tr(
                '$_right pukulan masuk, perlu $_enemyMax. Kata yang meleset sudah masuk antrean ulang. ${_kind == RunKind.sub ? 'Coba lagi empat jam lagi.' : 'Coba lagi besok.'}',
                '$_right blows landed, $_enemyMax needed. The words you missed are queued for review. ${_kind == RunKind.sub ? 'Try again in four hours.' : 'Try again tomorrow.'}',
                '$_right golpes acertados, se necesitaban $_enemyMax. Las palabras falladas vuelven a repaso. ${_kind == RunKind.sub ? 'Inténtalo de nuevo en cuatro horas.' : 'Inténtalo de nuevo mañana.'}',
                '$_right coups portés, il en fallait $_enemyMax. Les mots manqués repartent en révision. ${_kind == RunKind.sub ? 'Réessaie dans quatre heures.' : 'Réessaie demain.'}',
              );
      case RunKind.defence:
        mark = Shield(rank, width: 96, hollow: !_passed);
        label = tr('Mempertahankan gelar', 'Defending the title', 'Defendiendo el título', 'Défense du titre');
        title = _passed
            ? tr('Gelar dipertahankan', 'Title defended', 'Título defendido', 'Titre défendu')
            : tr('Belum cukup', 'Not enough yet', 'Aún no es suficiente', 'Pas encore assez');
        text = _passed
            ? tr(
                '$_right dari ${Engine.defenceSize} benar. ${rankNames[rank]} tetap gelarmu.',
                '$_right of ${Engine.defenceSize} right. ${rankNames[rank]} remains your title.',
                '$_right de ${Engine.defenceSize} bien. ${rankNames[rank]} sigue siendo tu título.',
                '$_right justes sur ${Engine.defenceSize}. ${rankNames[rank]} reste ton titre.',
              )
            : tr(
                '$_right dari ${Engine.defenceSize} benar, perlu ${Engine.defencePass}. Kamu masih punya ${e.shakyDaysLeft} hari.',
                '$_right of ${Engine.defenceSize} right, ${Engine.defencePass} needed. You still have ${e.shakyDaysLeft} days.',
                '$_right de ${Engine.defenceSize} bien, se necesitaban ${Engine.defencePass}. Aún te quedan ${e.shakyDaysLeft} días.',
                '$_right justes sur ${Engine.defenceSize}, il en fallait ${Engine.defencePass}. Il te reste ${e.shakyDaysLeft} jours.',
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
                ? tr('Masuk ke negerimu', 'Enter your realm', 'Entra en tu reino', 'Entre dans ton royaume')
                : tr('Selesai', 'Done', 'Hecho', 'Terminé'),
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
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                '${right ? tr('Musuh', 'Foe', 'Enemigo', 'Ennemi') : name}  $hp/$max',
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
