/// The app's frame: MaterialApp, the opening, the first-run choices, the three tabs and Today.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/lang.dart';
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
  return banner == 'ielts' ? 'IELTS ${below(r.ielts)}' : 'TOEFL iBT ${below(r.toefl)}';
}

/// "<4.0" as words
String below(String s) => s.startsWith('<') ? tr('di bawah ${s.substring(1)}', 'below ${s.substring(1)}') : s;

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
                Opacity(opacity: calm ? 1 : _span(0.5, 0.72), child: Label(tr('Kosakata TOEFL & IELTS', 'TOEFL & IELTS vocabulary'))),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final l in const [('id', 'Indonesia'), ('en', 'English')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Press(
                        onTap: () => App.I.put('lang', l.$1),
                        label: l.$2,
                        child: Semantics(
                          selected: App.I.english == (l.$1 == 'en'),
                          child: ExcludeSemantics(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: App.I.english == (l.$1 == 'en') ? pal.ink : Colors.transparent,
                                border: Border.all(color: pal.ink, width: 1.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(l.$2, style: T.body(15.5, App.I.english == (l.$1 == 'en') ? pal.bg : pal.ink, w: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Label(tr('Selamat datang', 'Welcome')),
              const SizedBox(height: 8),
              Text(tr('Pilih panjimu', 'Choose your banner'), style: T.display(38, pal.ink)),
              const SizedBox(height: 10),
              Text(
                tr(
                  'Kata dan ejaan mengikuti ujian yang kamu tuju. Bisa diganti kapan saja.',
                  'Words and spelling follow the test you are heading for. You can change it at any time.',
                ),
                style: T.body(17.5, pal.muted),
              ),
              const SizedBox(height: 28),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _BannerCard(
                        'toefl',
                        'TOEFL',
                        tr('Kata kampus dan kuliah. Ejaan Amerika.', 'Words of campus and lectures. American spelling.'),
                        _banner == 'toefl',
                        () => setState(() => _banner = 'toefl'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _BannerCard(
                        'ielts',
                        'IELTS',
                        tr('Kata topik esai dan grafik. Ejaan Inggris.', 'Words of essay topics and charts. British spelling.'),
                        _banner == 'ielts',
                        () => setState(() => _banner = 'ielts'),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkButton(tr('Lanjut', 'Continue'), onTap: _banner.isEmpty ? null : _next),
            ],
          )
        : Column(
            key: const ValueKey(1),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Label(tr('Panji ${bannerName(_banner)}', 'Banner ${bannerName(_banner)}')),
              const SizedBox(height: 8),
              Text(tr('Dari mana kamu mulai?', 'Where do you start?'), style: T.display(38, pal.ink)),
              const SizedBox(height: 10),
              Text(
                tr(
                  'Semua orang mulai sebagai Peasant. Kalau kosakatamu sudah jauh, ujian penempatan bisa mengangkatmu langsung, paling tinggi sampai Baron.',
                  'Everyone starts as a Peasant. If your vocabulary is already far along, the placement test can raise you at once, as high as Baron.',
                ),
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
              InkButton(tr('Ikut ujian penempatan', 'Take the placement test'), onTap: _placement),
              const SizedBox(height: 6),
              Center(child: Text(tr('Sampai 24 kata, sekitar lima menit', 'Up to 24 words, about five minutes'), style: T.body(15, pal.muted))),
              const SizedBox(height: 6),
              GhostButton(tr('Mulai sebagai Peasant', 'Start as a Peasant'), onTap: App.I.finishOnboarding),
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
      label: tr('Panji $title', 'Banner $title'),
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
    final names = [tr('Hari ini', 'Today'), tr('Negeri', 'Realm'), tr('Karakter', 'Character'), tr('Kronik', 'Chronicle')];
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
        title: tr('Gelarmu goyah', 'Your title wavers'),
        text: tr(
          'Kata dari ranah yang sudah kamu kuasai banyak yang lepas. Pertahankan gelar ${rankNames[rank]} dalam ${e.shakyDaysLeft} hari, atau gelar turun.',
          'Many words from the lands you already hold have slipped. Defend the title of ${rankNames[rank]} within ${e.shakyDaysLeft} days, or it is lost.',
        ),
        action: tr('Pertahankan gelar', 'Defend the title'),
        strong: true,
        onTap: () => runFrom(context, RunScreen(kind: RunKind.defence, tier: rank)),
      );
    }
    final en = g.enemy;
    if (en == null) {
      return Notice(
        title: tr('Takhta di tanganmu', 'The throne is yours'),
        text: tr('Tidak ada lawan di atas King. Jaga kata-katamu tetap kukuh.', 'There is no foe above a King. Keep your words solid.'),
      );
    }
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
                      Label(
                        en.boss
                            ? tr('Boss · menuju ${rankNames[next]}', 'Boss · on the way to ${rankNames[next]}')
                            : tr('Penjaga jalan · tingkat ${stageName(e.stage)}', 'Guard of the road · stage ${stageName(e.stage)}'),
                      ),
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
                    ? tr(
                        '${Engine.trialSize} kata, ${Engine.trialSeconds} detik tiap kata, tanpa petunjuk. Tumbang pada ${Engine.trialPass} pukulan; kamu kalah pada pukulan kelima yang meleset.',
                        '${Engine.trialSize} words, ${Engine.trialSeconds} seconds each, no hints. It falls at ${Engine.trialPass} blows; you lose at the fifth blow that misses.',
                      )
                    : tr(
                        '${Engine.subSize} kata, ${Engine.trialSeconds + g.perk('subTime')} detik tiap kata. Tumbang pada ${Engine.subPass} pukulan; kamu punya ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} nyawa.',
                        '${Engine.subSize} words, ${Engine.trialSeconds + g.perk('subTime')} seconds each. It falls at ${Engine.subPass} blows; you have ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} lives.',
                      ),
                style: T.body(15.5, pal.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              InkButton(
                tr('Lawan ${en.name}', 'Fight the ${en.name}'),
                outline: true,
                onTap: () => runFrom(context, RunScreen(kind: en.boss ? RunKind.trial : RunKind.sub, tier: next)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cooling ? tr('Memulihkan diri', 'Recovering') : tr('Belum bisa dilawan', 'Cannot be fought yet'),
                      style: T.body(16, pal.ink, w: FontWeight.w500),
                    ),
                  ),
                  Text(tr('${st.solid} dari $need kata kukuh', '${st.solid} of $need solid words'), style: T.body(15, pal.muted)),
                ],
              ),
              const SizedBox(height: 8),
              Bar(need == 0 ? 0 : st.solid / need, height: 6),
              const SizedBox(height: 8),
              Text(
                cooling
                    ? (en.boss
                          ? tr('Boss bisa dilawan lagi besok.', 'The boss can be fought again tomorrow.')
                          : tr('Musuh ini bisa dilawan lagi dalam beberapa jam.', 'This foe can be fought again in a few hours.'))
                    : tr(
                        'Kata menjadi kukuh setelah kamu mengingatnya lebih dari seminggu lewat celah kalimat.',
                        'A word becomes solid once you have remembered it for more than a week through the gap in a sentence.',
                      ),
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
              label: tr('Pengaturan', 'Settings'),
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.tune, color: pal.ink, size: 24)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Rise(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              HeroSprite(garb: g.job.garb, tier: g.job.tier, weapon: g.tone('weapon'), shield: g.tone('shield'), cloak: g.tone('cloak'), size: 66),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Shield(rank, width: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(g.job.name, style: T.display(28, pal.ink)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rankNames[rank]}${rank < Engine.maxRank ? ' ${stageName(e.stage)}' : ''} · Level ${g.level}${g.title.isEmpty ? '' : ' · ${g.title}'}',
                      style: T.body(15, pal.ink, w: FontWeight.w500),
                    ),
                    Text(
                      tr('Kosakata setara ${scoreLine(rank, app.banner)}', 'Vocabulary on a par with ${scoreLine(rank, app.banner)}'),
                      style: T.body(15, pal.muted),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: tr('${g.toNext} XP lagi ke level ${g.level + 1}', '${g.toNext} XP to level ${g.level + 1}'),
                      child: Bar(g.levelShare, height: 5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(rankGreeting(rank), style: T.display(19, pal.muted, italic: true)),
        const SizedBox(height: 14),
        const Rule(),
        const SizedBox(height: 16),
        Label(tr('Saran hari ini', 'Advice for today')),
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
              _Count(plan.reviews, tr('ulang', 'to review')),
              const SizedBox(width: 32),
              _Count(plan.fresh, tr('kata baru', 'new words')),
              Expanded(
                child: e.streak > 0
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 12),
                        child: Text(tr('${e.streak} hari beruntun', '${e.streak} days in a row'), textAlign: TextAlign.right, style: T.body(15.5, pal.muted)),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!plan.empty)
          InkButton(
            plan.doneToday > 0 ? tr('Lanjut belajar', 'Continue learning') : tr('Mulai belajar', 'Start learning'),
            onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn)),
          )
        else ...[
          Text(
            plan.doneToday > 0
                ? tr('Tercatat. Tugas hari ini selesai.', 'Noted. Today\'s tasks are done.')
                : tr('Belum ada yang perlu diulang hari ini.', 'Nothing needs review today.'),
            style: T.display(22, pal.ink, italic: true),
          ),
          const SizedBox(height: 12),
          if (moreFresh > 0)
            InkButton(
              tr('Tambah $moreFresh kata baru', 'Add $moreFresh new words'),
              outline: true,
              onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn, extraFresh: 10)),
            ),
        ],
        const SizedBox(height: 22),
        const FightCard(),
        const SizedBox(height: 22),
        Label(tr('Quest hari ini', 'Today\'s quests')),
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
                child: Text(tr('Ambil +${App.I.game.questXp(q)}', 'Take +${App.I.game.questXp(q)}'), style: T.body(15.5, pal.onAccent, w: FontWeight.w700)),
              ),
            )
          else
            SizedBox(
              width: 74,
              child: Text(q.claimed ? tr('Diambil', 'Taken') : '+${App.I.game.questXp(q)} XP', textAlign: TextAlign.right, style: T.body(14.5, pal.muted)),
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
