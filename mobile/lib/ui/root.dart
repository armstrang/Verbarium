/// The app's frame: MaterialApp, the opening, the first-run choices, the three tabs and Today.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/native.dart';
import '../engine/engine.dart';
import '../engine/game.dart';
import 'chronicle.dart';
import 'hero.dart';
import 'pixel.dart';
import 'realm.dart';
import 'run.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

/// set to false in tests: no opening animation
bool splashOn = true;

String bannerName(String b) => b == 'ielts' ? 'IELTS' : 'TOEFL';

/// what a rank's vocabulary is on a par with, in the words of the chosen test
String scoreLine(int rank, String banner) {
  final r = Engine.ranks[rank];
  return banner == 'ielts' ? 'IELTS ${r.ielts}' : 'TOEFL iBT ${r.toefl}';
}

class VerbariumApp extends StatelessWidget {
  const VerbariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) => MaterialApp(
        title: 'Verbarium',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: T.sans, useMaterial3: true, splashFactory: NoSplash.splashFactory),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // text follows the phone's size, within limits the layouts were drawn for
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35)),
            child: LookHost(
              child: Builder(
                builder: (context) {
                  final pal = Look.of(context).pal;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Colors.transparent,
                      statusBarIconBrightness: pal.dark ? Brightness.light : Brightness.dark,
                      systemNavigationBarIconBrightness: pal.dark ? Brightness.light : Brightness.dark,
                    ),
                    child: ColoredBox(color: pal.bg, child: child!),
                  );
                },
              ),
            ),
          );
        },
        home: const Root(),
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool _opening = splashOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Native.ready();
      if (!_opening) App.I.syncMusic();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) App.I.store.flush();
    if (state == AppLifecycleState.resumed && App.I.engine.checkDemotion()) App.I.changed();
  }

  @override
  Widget build(BuildContext context) {
    final calm = Look.of(context).calm;
    final Widget page = _opening
        ? Splash(
            key: const ValueKey('splash'),
            onDone: () {
              App.I.syncMusic();
              setState(() => _opening = false);
            },
          )
        : (App.I.onboarded ? const Shell(key: ValueKey('shell')) : const Onboarding(key: ValueKey('onb')));
    return AnimatedSwitcher(duration: calm ? Dur.out : Dur.slow, reverseDuration: Dur.out, child: page);
  }
}

// ---------------------------------------------------------------------------- the opening

/// About 1.9 s: a line is ruled, the name is written letter by letter, the seal comes down.
class Splash extends StatefulWidget {
  final VoidCallback onDone;
  const Splash({super.key, required this.onDone});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  bool _sealed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_sealed && _c.value > 0.72) {
        _sealed = true;
        App.I.sfx('seal', 0.9);
        App.I.haptic(strong: true);
      }
    });
    _c.forward().whenComplete(() => Future.delayed(const Duration(milliseconds: 350), _finish));
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) => curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    const name = 'Verbarium';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Leaf(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final calm = look.calm;
            final seal = calm ? 1.0 : _span(0.7, 0.86, Curves.easeOutBack);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < name.length; i++)
                      Builder(
                        builder: (context) {
                          final t = calm ? 1.0 : _span(0.08 + i * 0.05, 0.3 + i * 0.05);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - t)),
                              child: Text(name[i], style: T.display(52, pal.ink)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 0.42 * (calm ? 1.0 : _span(0.0, 0.3)),
                  child: Container(height: 2, color: pal.ink),
                ),
                const SizedBox(height: 14),
                Opacity(opacity: calm ? 1 : _span(0.5, 0.72), child: Label('Kosakata TOEFL & IELTS')),
                const SizedBox(height: 44),
                Opacity(
                  opacity: calm ? 1 : _span(0.68, 0.76, Curves.linear),
                  child: Transform.rotate(
                    angle: -0.12 * (1 - seal),
                    child: Transform.scale(scale: 1.9 - 0.9 * seal, child: const Seal(size: 66)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- first run

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int _step = 0;
  String _banner = '';

  Future<void> _next() async {
    await App.I.chooseBanner(_banner);
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _placement() async {
    await Navigator.of(context).push(runRoute(const RunScreen(kind: RunKind.placement)));
    App.I.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final Widget body = _step == 0
        ? Column(
            key: const ValueKey(0),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Label('Selamat datang'),
              const SizedBox(height: 8),
              Text('Pilih panjimu', style: T.display(38, pal.ink)),
              const SizedBox(height: 10),
              Text('Kata dan ejaan mengikuti ujian yang kamu tuju. Bisa diganti kapan saja.', style: T.body(17.5, pal.muted)),
              const SizedBox(height: 28),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _BannerCard(
                        'toefl',
                        'TOEFL',
                        'Kata kampus dan kuliah. Ejaan Amerika.',
                        _banner == 'toefl',
                        () => setState(() => _banner = 'toefl'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _BannerCard(
                        'ielts',
                        'IELTS',
                        'Kata topik esai dan grafik. Ejaan Inggris.',
                        _banner == 'ielts',
                        () => setState(() => _banner = 'ielts'),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkButton('Lanjut', onTap: _banner.isEmpty ? null : _next),
            ],
          )
        : Column(
            key: const ValueKey(1),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Label('Panji ${bannerName(_banner)}'),
              const SizedBox(height: 8),
              Text('Dari mana kamu mulai?', style: T.display(38, pal.ink)),
              const SizedBox(height: 10),
              Text(
                'Semua orang mulai sebagai Petani. Kalau kosakatamu sudah jauh, ujian penempatan bisa mengangkatmu langsung, paling tinggi sampai Baron.',
                style: T.body(17.5, pal.muted),
              ),
              const SizedBox(height: 28),
              Rise(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var r = 0; r <= 5; r++)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Shield(r, width: 26.0 + r * 3),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              InkButton('Ikut ujian penempatan', onTap: _placement),
              const SizedBox(height: 6),
              Center(child: Text('Sampai 24 kata, sekitar lima menit', style: T.body(15, pal.muted))),
              const SizedBox(height: 6),
              GhostButton('Mulai sebagai Petani', onTap: App.I.finishOnboarding),
            ],
          );
    return Leaf(
      child: AnimatedSwitcher(duration: Dur.enter, reverseDuration: Dur.out, child: body),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String id, title, note;
  final bool chosen;
  final VoidCallback onTap;
  const _BannerCard(this.id, this.title, this.note, this.chosen, this.onTap);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final tint = pal.tincture(id == 'toefl' ? 3 : 2);
    return Press(
      onTap: onTap,
      label: 'Panji $title',
      child: Semantics(
        selected: chosen,
        child: AnimatedContainer(
          duration: Dur.out,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          decoration: BoxDecoration(
            color: chosen ? pal.field : Colors.transparent,
            border: Border.all(color: chosen ? pal.ink : pal.line, width: chosen ? 2 : 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(size: const Size(44, 72), painter: _PennantPainter(tint)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(title, style: T.display(28, pal.ink))),
                  if (chosen) Icon(Icons.check, size: 22, color: pal.ink),
                ],
              ),
              const SizedBox(height: 4),
              Text(note, style: T.body(15.5, pal.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PennantPainter extends CustomPainter {
  final Color color;
  _PennantPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.78)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PennantPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------- the tabs

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    const names = ['Hari ini', 'Negeri', 'Karakter', 'Kronik'];
    const icons = [Icons.edit_outlined, Icons.map_outlined, Icons.shield_outlined, Icons.menu_book_outlined];
    final pages = [const Today(), const RealmTab(), const HeroTab(), const ChronicleTab()];
    return Material(
      type: MaterialType.transparency,
      child: Paper(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: look.calm ? Duration.zero : Dur.enter,
                reverseDuration: look.calm ? Duration.zero : Dur.out,
                child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pal.deep,
                border: Border(top: BorderSide(color: pal.ink, width: 1.5)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      for (var i = 0; i < names.length; i++)
                        Expanded(
                          child: Press(
                            onTap: () {
                              if (_tab != i) {
                                App.I.sfx('page', 0.5);
                                setState(() => _tab = i);
                              }
                            },
                            sound: false,
                            label: names[i],
                            child: Semantics(
                              selected: _tab == i,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 0,
                                    child: AnimatedContainer(
                                      duration: Dur.enter,
                                      curve: Curves.easeOutCubic,
                                      height: 3,
                                      width: _tab == i ? 44 : 0,
                                      color: look.accent,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icons[i], size: 22, color: _tab == i ? pal.ink : pal.muted),
                                      const SizedBox(height: 3),
                                      ExcludeSemantics(
                                        child: Text(
                                          names[i],
                                          style: T.body(14, _tab == i ? pal.ink : pal.muted, w: _tab == i ? FontWeight.w700 : FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab's content: safe area on top, centred column, scrolls when the screen is short.
class TabBody extends StatelessWidget {
  final List<Widget> children;
  const TabBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 24), children: children),
        ),
      ),
    );
  }
}

Future<void> runFrom(BuildContext context, RunScreen screen) async {
  await Navigator.of(context).push(runRoute(screen));
  App.I.changed();
}

/// the fight that stands next, as a card with the enemy on it; shown on Today and under the map
class FightCard extends StatelessWidget {
  const FightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final e = App.I.engine, g = App.I.game;
    final rank = e.rank;
    if (e.shaky) {
      return Notice(
        title: 'Gelarmu goyah',
        text: 'Kata dari ranah yang sudah kamu kuasai banyak yang lepas. Pertahankan gelar ${rankNames[rank]} dalam ${e.shakyDaysLeft} hari, atau gelar turun.',
        action: 'Pertahankan gelar',
        strong: true,
        onTap: () => runFrom(context, RunScreen(kind: RunKind.defence, tier: rank)),
      );
    }
    final en = g.enemy;
    if (en == null) return const Notice(title: 'Takhta di tanganmu', text: 'Tidak ada lawan di atas Raja. Jaga kata-katamu tetap kukuh.');
    final next = rank + 1;
    final st = e.stat(next);
    final need = (st.total * g.fightNeeds).ceil();
    final open = g.fightOpen;
    final cooling = g.enemyIsBoss ? e.cooling : e.subCooldown > e.now();
    return Rise(
      delay: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.field,
          border: Border.all(color: pal.ink, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                EnemySprite(sprite: en.sprite, tone: en.tone, size: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(en.boss ? 'Boss · menuju ${rankNames[next]}' : 'Penjaga jalan · tingkat ${stageName(e.stage)}'),
                      const SizedBox(height: 2),
                      Text(en.name, style: T.display(25, pal.ink)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (open) ...[
              Text(
                en.boss
                    ? '${Engine.trialSize} kata, ${Engine.trialSeconds} detik tiap kata, tanpa petunjuk. Tumbang pada ${Engine.trialPass} pukulan; kamu kalah pada pukulan kelima yang meleset.'
                    : '${Engine.subSize} kata, ${Engine.trialSeconds} detik tiap kata. Tumbang pada ${Engine.subPass} pukulan; kamu kalah pada pukulan ketiga yang meleset.',
                style: T.body(15.5, pal.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              InkButton(
                'Lawan ${en.name}',
                outline: true,
                onTap: () => runFrom(context, RunScreen(kind: en.boss ? RunKind.trial : RunKind.sub, tier: next)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(cooling ? 'Memulihkan diri' : 'Belum bisa dilawan', style: T.body(16, pal.ink, w: FontWeight.w500)),
                  ),
                  Text('${st.solid} dari $need kata kukuh', style: T.body(15, pal.muted)),
                ],
              ),
              const SizedBox(height: 8),
              Bar(need == 0 ? 0 : st.solid / need, height: 6),
              const SizedBox(height: 8),
              Text(
                cooling
                    ? (en.boss ? 'Boss bisa dilawan lagi besok.' : 'Musuh ini bisa dilawan lagi dalam beberapa jam.')
                    : 'Kata menjadi kukuh setelah kamu mengingatnya lebih dari seminggu lewat celah kalimat.',
                style: T.body(15, pal.muted, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Today

class Today extends StatelessWidget {
  const Today({super.key});

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final app = App.I;
    final e = app.engine, g = app.game;
    final rank = e.rank;
    final plan = e.plan();
    final moreFresh = e.freshWords(10).length;
    final advice = g.advice();
    final quests = g.daily;

    return TabBody(
      children: [
        Row(
          children: [
            Expanded(child: Text('Verbarium', style: T.display(30, pal.ink))),
            Press(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
              label: 'Pengaturan',
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.tune, color: pal.ink, size: 24)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Rise(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              HeroSprite(rank: rank, weapon: g.tone('weapon'), shield: g.tone('shield'), cloak: g.tone('cloak'), size: 66),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Shield(rank, width: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${rankNames[rank]}${rank < Engine.maxRank ? ' ${stageName(e.stage)}' : ''}', style: T.display(28, pal.ink))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Level ${g.level}${g.title.isEmpty ? '' : ' · ${g.title}'} · setara ${scoreLine(rank, app.banner)}', style: T.body(15, pal.muted)),
                    const SizedBox(height: 6),
                    Semantics(label: '${g.toNext} XP lagi ke level ${g.level + 1}', child: Bar(g.levelShare, height: 5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(rankGreeting[rank], style: T.display(19, pal.muted, italic: true)),
        const SizedBox(height: 14),
        const Rule(),
        const SizedBox(height: 16),
        const Label('Saran hari ini'),
        const SizedBox(height: 8),
        for (final a in advice)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Transform.rotate(angle: 0.785, child: Container(width: 6, height: 6, color: look.accent)),
                ),
                Expanded(child: Text(a, style: T.body(16.5, pal.ink, height: 1.4))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Rise(
          delay: const Duration(milliseconds: 60),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Count(plan.reviews, 'ulang'),
              const SizedBox(width: 32),
              _Count(plan.fresh, 'kata baru'),
              Expanded(
                child: e.streak > 0
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 12),
                        child: Text('${e.streak} hari beruntun', textAlign: TextAlign.right, style: T.body(15.5, pal.muted)),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!plan.empty)
          InkButton(plan.doneToday > 0 ? 'Lanjut belajar' : 'Mulai belajar', onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn)))
        else ...[
          Text(
            plan.doneToday > 0 ? 'Tercatat. Tugas hari ini selesai.' : 'Belum ada yang perlu diulang hari ini.',
            style: T.display(22, pal.ink, italic: true),
          ),
          const SizedBox(height: 12),
          if (moreFresh > 0)
            InkButton('Tambah $moreFresh kata baru', outline: true, onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn, extraFresh: 10))),
        ],
        const SizedBox(height: 22),
        const FightCard(),
        const SizedBox(height: 22),
        const Label('Quest hari ini'),
        const SizedBox(height: 4),
        for (final q in quests) QuestRow(q),
      ],
    );
  }
}

class QuestRow extends StatelessWidget {
  final Quest q;
  const QuestRow(this.q, {super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.text, style: T.body(16.5, q.claimed ? pal.muted : pal.ink).copyWith(decoration: q.claimed ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Bar(q.goal == 0 ? 0 : q.prog / q.goal, height: 4)),
                    const SizedBox(width: 10),
                    Text('${min(q.prog, q.goal)}/${q.goal}', style: T.body(14, pal.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (q.done && !q.claimed)
            Press(
              onTap: () {
                final news = App.I.game.claim(q);
                App.I.sfx(news.isEmpty ? 'rise' : 'levelup', 0.8);
                App.I.changed();
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Look.of(context).accent, borderRadius: BorderRadius.circular(3)),
                child: Text('Ambil +${q.xp}', style: T.body(15.5, pal.onAccent, w: FontWeight.w700)),
              ),
            )
          else
            SizedBox(
              width: 74,
              child: Text(q.claimed ? 'Diambil' : '+${q.xp} XP', textAlign: TextAlign.right, style: T.body(14.5, pal.muted)),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final int n;
  final String what;
  const _Count(this.n, this.what);

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Semantics(
      label: '$n $what',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: T.display(48, pal.ink, height: 1)),
            Text(what, style: T.body(15.5, pal.muted)),
          ],
        ),
      ),
    );
  }
}

class Notice extends StatelessWidget {
  final String title, text;
  final String? action;
  final VoidCallback? onTap;
  final bool strong;
  const Notice({super.key, required this.title, required this.text, this.action, this.onTap, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    return Rise(
      delay: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.field,
          border: Border.all(color: strong ? pal.bad : pal.ink, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (strong) ...[Icon(Icons.warning_amber_rounded, color: pal.bad, size: 22), const SizedBox(width: 8)],
                Expanded(child: Text(title, style: T.display(23, pal.ink))),
              ],
            ),
            const SizedBox(height: 6),
            Text(text, style: T.body(16, pal.muted)),
            if (action != null) ...[const SizedBox(height: 14), InkButton(action!, outline: true, onTap: onTap)],
          ],
        ),
      ),
    );
  }
}
