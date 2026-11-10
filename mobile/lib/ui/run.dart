/// One sitting at the desk: a sentence with a gap, you type the word. The same screen runs daily learning, the
/// placement trial, the coronation trial and the defence of a title; only the rules around the question differ.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/deck.dart';
import '../engine/engine.dart';
import 'coronation.dart';
import 'root.dart';
import 'theme.dart';
import 'widgets.dart';

enum RunKind { learn, placement, trial, defence }

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
  final RunKind kind;
  final int tier;
  final int extraFresh;
  const RunScreen({super.key, required this.kind, this.tier = 0, this.extraFresh = 0});

  @override
  State<RunScreen> createState() => _RunState();
}

class _Item {
  final Word w;
  final bool fresh;
  final int tries;
  _Item(this.w, this.fresh, [this.tries = 0]);
}

/// ask: waiting for the word · near: one slip, try again · shown: the word is shown, type it to go on (learning)
/// right: correct, a short pause · miss: wrong in a trial, the word flashes by
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

  final List<_Item> _q = [];
  int _i = 0;
  int _right = 0, _done = 0, _freshSeen = 0;
  _Phase _phase = _Phase.ask;
  bool _nearUsed = false;
  bool _finished = false;
  bool _passed = false;
  int _solidBefore = 0;
  Timer? _pause;

  // placement
  int _ptier = 1, _ptierRight = 0, _ptierCount = 0, _tiersPassed = 0;

  Engine get _e => App.I.engine;
  RunKind get _kind => widget.kind;
  bool get _test => _kind != RunKind.learn;
  bool get _timed => _kind == RunKind.trial || _kind == RunKind.defence;
  _Item get _item => _q[_i];

  @override
  void initState() {
    super.initState();
    _solidBefore = _e.solidTotal;
    switch (_kind) {
      case RunKind.learn:
        _q.addAll([for (final w in _e.sitting(extraFresh: widget.extraFresh)) _Item(w, !_e.seen(w))]);
      case RunKind.placement:
        _q.addAll([for (final w in _e.placementWords(1)) _Item(w, false)]);
      case RunKind.trial:
        _q.addAll([for (final w in _e.trialWords(widget.tier, Engine.trialSize)) _Item(w, false)]);
      case RunKind.defence:
        _q.addAll([for (final w in _e.trialWords(widget.tier, Engine.defenceSize)) _Item(w, false)]);
    }
    if (_q.isEmpty) _finished = true;
    _clock.addStatusListener((s) {
      if (s == AnimationStatus.completed && _phase != _Phase.right && _phase != _Phase.miss) _wrong();
    });
    if (_timed && !_finished) _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _pause?.cancel();
    _input.dispose();
    _focus.dispose();
    _shake.dispose();
    _write.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ answering

  void _record(Grade g) => _e.answer(_item.w, g, count: _kind != RunKind.placement);

  void _check() {
    if (_phase == _Phase.right || _phase == _Phase.miss) return;
    final typed = _input.text.trim();
    if (typed.isEmpty) return;
    final w = _item.w;
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
    } else if (!_nearUsed && w.forms.map((f) => slip(typed, f)).reduce(min) == 1) {
      setState(() {
        _phase = _Phase.near;
        _nearUsed = true;
      });
      _shake.forward(from: 0);
      App.I.sfx('wrong', 0.4);
    } else {
      _wrong();
    }
  }

  void _rightAnswer() {
    _record(_nearUsed ? Grade.helped : Grade.clean);
    _clock.stop();
    _right++;
    if (_kind == RunKind.placement) _ptierRight++;
    if (_item.fresh) _freshSeen++;
    setState(() => _phase = _Phase.right);
    App.I.sfx('quill');
    App.I.haptic();
    _write.forward(from: 0);
    _pause = Timer(Duration(milliseconds: Look.of(context).calm ? 650 : 1000), _advance);
  }

  void _wrong() {
    _record(Grade.wrong);
    _clock.stop();
    App.I.sfx('wrong');
    App.I.haptic(strong: true);
    _shake.forward(from: 0);
    if (_item.fresh) _freshSeen++;
    if (_test) {
      setState(() => _phase = _Phase.miss);
      _pause = Timer(const Duration(milliseconds: 1300), _advance);
    } else {
      // it comes back four cards later, twice at most
      if (_item.tries < 2) _q.insert(min(_i + 4, _q.length), _Item(_item.w, false, _item.tries + 1));
      _input.clear();
      setState(() => _phase = _Phase.shown);
    }
  }

  void _advance() {
    _pause?.cancel();
    if (!mounted) return;
    _done++;
    if (_kind == RunKind.placement) {
      _ptierCount++;
      final missed = _ptierCount - _ptierRight;
      final lost = missed > Engine.placementPerTier - Engine.placementPass;
      if (lost) {
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
        _q.addAll([for (final w in _e.placementWords(_ptier)) _Item(w, false)]);
      }
    }
    if (_i + 1 >= _q.length) {
      _finish();
      return;
    }
    App.I.sfx('page', 0.45);
    setState(() {
      _i++;
      _phase = _Phase.ask;
      _nearUsed = false;
      _input.clear();
    });
    _write.value = 0;
    if (_timed) _clock.forward(from: 0);
    _focus.requestFocus();
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
        _passed = _e.finishTrial(widget.tier, _right, Engine.trialSize);
      case RunKind.defence:
        _passed = _e.finishDefence(_right, Engine.defenceSize);
        App.I.sfx(_passed ? 'rise' : 'seal', 0.9);
    }
    App.I.store.flush();
    App.I.changed();
    if (_kind == RunKind.trial && _passed) {
      Navigator.of(context).pushReplacement(runRoute(Coronation(rank: widget.tier, right: _right, total: Engine.trialSize)));
      return;
    }
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
      title: 'Tinggalkan ujian?',
      text: switch (_kind) {
        RunKind.trial => 'Ujian yang ditinggalkan setelah lima kata dihitung gagal, dan baru bisa diulang besok.',
        RunKind.placement => 'Gelarmu ditetapkan dari ranah yang sudah kamu lewati sejauh ini.',
        _ => 'Gelarmu tetap goyah sampai ujian ini kamu selesaikan.',
      },
      yes: 'Tinggalkan',
      no: 'Lanjut ujian',
    );
    if (!leave || !mounted) return;
    if (_kind == RunKind.trial && _done >= 5) _e.finishTrial(widget.tier, _right, Engine.trialSize);
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
      child: Leaf(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: _finished ? _ending(context) : _desk(context)),
    );
  }

  Widget _desk(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final total = _kind == RunKind.placement ? Engine.placementPerTier * Engine.placementTop : _q.length;
    final busy = _phase == _Phase.right || _phase == _Phase.miss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Press(
              onTap: _close,
              label: 'Tutup',
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.close, color: pal.ink, size: 24)),
            ),
            Expanded(child: Bar(_done / total, height: 3)),
            const SizedBox(width: 12),
            Text('${_done + 1} dari $total', style: T.body(15.5, pal.muted)),
            const SizedBox(width: 8),
          ],
        ),
        if (_timed)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => Semantics(
                label: 'Sisa waktu ${(Engine.trialSeconds * (1 - _clock.value)).ceil()} detik',
                child: Bar(1 - _clock.value, height: 2, color: pal.ink, animate: false),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
            child: AnimatedSwitcher(
              duration: look.calm ? Duration.zero : Dur.enter,
              reverseDuration: Duration.zero,
              layoutBuilder: (current, _) => current ?? const SizedBox(),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_i), child: _question(context)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Label('Ketik kata yang hilang'),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = look.calm ? 0.0 : sin(t * pi * 5) * 7 * (1 - t);
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(cursorColor: pal.ink, selectionColor: pal.ink.withValues(alpha: 0.18), selectionHandleColor: pal.ink),
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    autofocus: true,
                    readOnly: busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _check,
                    cursorColor: pal.ink,
                    style: T.display(25, pal.ink, height: 1.2),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: pal.field,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide(color: pal.ink, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide(color: pal.ink, width: 2.2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkButton(_phase == _Phase.shown ? 'Lanjut' : 'Periksa', onTap: busy ? null : _check, sound: false),
              if (_kind == RunKind.learn || _kind == RunKind.placement)
                Opacity(
                  opacity: _phase == _Phase.ask || _phase == _Phase.near ? 1 : 0,
                  child: GhostButton(
                    _kind == RunKind.learn ? 'Belum tahu, tunjukkan' : 'Belum tahu',
                    onTap: _phase == _Phase.ask || _phase == _Phase.near ? _wrong : null,
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _question(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final w = _item.w;
    final answer = w.answer(App.I.british);
    final parts = w.parts;
    final heading = switch (_kind) {
      RunKind.learn => _item.fresh ? 'Kata baru' : 'Ulang',
      RunKind.placement => 'Ujian penempatan · ${rankNames[_ptier]}',
      RunKind.trial => 'Ujian penobatan ${rankNames[widget.tier]}',
      RunKind.defence => 'Mempertahankan gelar',
    };
    final revealed = _phase == _Phase.shown || _phase == _Phase.miss;
    final String? note = switch (_phase) {
      _Phase.near => 'Hampir. Periksa ejaannya.',
      _Phase.shown => 'Ini katanya. Ketik sekali supaya melekat.',
      _Phase.miss => 'Jawabannya $answer.',
      _Phase.right => _item.fresh ? 'Tercatat. Kata baru masuk kronikmu.' : 'Benar.',
      _Phase.ask => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Label(heading)),
            AnimatedScale(
              scale: _phase == _Phase.right ? 1 : 1.7,
              duration: look.calm ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(opacity: _phase == _Phase.right ? 1 : 0, duration: const Duration(milliseconds: 90), child: const Seal(size: 30)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label: revealed || _phase == _Phase.right ? '${parts[0]}$answer${parts[1]}' : '${parts[0]} kata yang hilang ${parts[1]}',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: T.display(29, pal.ink, height: 1.5),
                children: [
                  TextSpan(text: parts[0]),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _Gap(answer: answer, write: _write, state: _phase == _Phase.right ? 1 : (revealed ? 2 : 0)),
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
                text: w.meaning,
                style: T.body(19, pal.ink, w: FontWeight.w500),
              ),
              TextSpan(text: '   ${_posName(w.pos)}', style: T.body(15, pal.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 26,
          child: AnimatedSwitcher(
            duration: Dur.out,
            child: note == null
                ? const SizedBox(key: ValueKey('none'))
                : Row(
                    key: ValueKey(note),
                    children: [
                      Icon(
                        _phase == _Phase.right ? Icons.check : (_phase == _Phase.near ? Icons.edit_outlined : Icons.arrow_forward),
                        size: 18,
                        color: _phase == _Phase.right ? pal.good : (_phase == _Phase.near ? pal.muted : pal.bad),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            note,
                            style: T.body(16, _phase == _Phase.right ? pal.good : (_phase == _Phase.near ? pal.muted : pal.bad), w: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  static String _posName(String p) => switch (p) {
    'n' => 'kata benda',
    'v' => 'kata kerja',
    'adj' => 'kata sifat',
    'adv' => 'kata keterangan',
    'prep' => 'kata depan',
    _ => 'kata sambung',
  };

  // ------------------------------------------------------------------ endings

  Widget _ending(BuildContext context) {
    final pal = Look.of(context).pal;
    final e = _e;
    final rank = e.rank;
    late final Widget mark;
    late final String label, title, text;
    switch (_kind) {
      case RunKind.learn:
        final gained = max(0, e.solidTotal - _solidBefore);
        mark = const Seal(size: 76);
        label = 'Tercatat hari ini';
        title = _done == 0 ? 'Mejamu kosong' : '$_right benar dari $_done';
        text = _done == 0
            ? 'Tidak ada kata yang menunggu. Kembali besok.'
            : [
                if (_freshSeen > 0) '$_freshSeen kata baru',
                if (gained > 0) '$gained kata kini kukuh',
                'kata yang meleset akan kembali lebih cepat',
              ].join(' · ');
      case RunKind.placement:
        mark = Shield(rank, width: 96);
        label = 'Ujian penempatan';
        title = 'Kamu mulai sebagai ${rankNames[rank]}';
        text = rank == 0
            ? 'Semua kesatria pernah menjadi petani. Kata pertamamu menunggu.'
            : 'Kosakatamu setara ${scoreLine(rank, App.I.banner)}. Kata dari ranah yang kamu lewati akan muncul untuk diulang, jadi gelar ini tetap harus dijaga.';
      case RunKind.trial:
        mark = Shield(widget.tier, width: 96, hollow: true);
        label = 'Ujian penobatan ${rankNames[widget.tier]}';
        title = 'Belum hari ini';
        text =
            '$_right dari ${Engine.trialSize} benar, lulus pada ${Engine.trialPass}. Kata yang meleset sudah masuk antrean ulang. Ujian bisa dicoba lagi besok.';
      case RunKind.defence:
        mark = Shield(rank, width: 96, hollow: !_passed);
        label = 'Mempertahankan gelar';
        title = _passed ? 'Gelar dipertahankan' : 'Belum cukup';
        text = _passed
            ? '$_right dari ${Engine.defenceSize} benar. ${rankNames[rank]} tetap gelarmu.'
            : '$_right dari ${Engine.defenceSize} benar, perlu ${Engine.defencePass}. Kamu masih punya ${e.shakyDaysLeft} hari.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Rise(child: Center(child: mark)),
          const SizedBox(height: 28),
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
          const Spacer(flex: 3),
          InkButton(_kind == RunKind.placement ? 'Masuk ke negerimu' : 'Selesai', onTap: () => Navigator.of(context).pop()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The gap in the sentence. The word is always laid out (so the line never jumps); it is invisible while you are
/// asked, written in from the left when you are right, and shown plainly when it has to be told.
class _Gap extends StatelessWidget {
  final String answer;
  final Animation<double> write;
  final int state; // 0 hidden, 1 written in, 2 told
  const _Gap({required this.answer, required this.write, required this.state});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final style = T.display(29, state == 2 ? pal.bad : (pal.dark ? pal.ink : look.accent), height: 1.2);
    Widget word = Text(answer, key: const ValueKey('gap-word'), style: style);
    if (state == 0) {
      word = Opacity(opacity: 0, child: word);
    } else if (state == 1 && !look.calm) {
      word = AnimatedBuilder(
        animation: write,
        builder: (context, child) => ClipRect(
          child: Align(alignment: Alignment.centerLeft, widthFactor: Curves.easeOut.transform(write.value).clamp(0.0, 1.0), child: child),
        ),
        child: word,
      );
      // the gap keeps its width while the word is being written
      word = Stack(
        children: [
          Opacity(opacity: 0, child: Text(answer, style: style)),
          word,
        ],
      );
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.ink, width: 2)),
      ),
      child: word,
    );
  }
}
