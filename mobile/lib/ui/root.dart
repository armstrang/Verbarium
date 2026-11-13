/// The app's frame: MaterialApp, the opening, the first-run choices, the three tabs and Today.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../app/native.dart';
import '../engine/engine.dart';
import '../data/deck.dart';
import '../engine/game.dart';
import 'banner.dart' show examOf;
import 'chronicle.dart';
import 'crest.dart' show KingdomArms;
import 'hero.dart';
import 'world.dart';
import 'pixel.dart';
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
  // a kingdom of another language, or the Peasant: CEFR alone
  if (banner.isEmpty || r.ielts == '–') return 'CEFR ${r.cefr}';
  return banner == 'ielts' ? 'IELTS ${below(r.ielts)}' : 'TOEFL iBT ${below(r.toefl)}';
}

/// "<4.0" as words
String below(String s) => s.startsWith('<')
    ? tr(
        'di bawah ${s.substring(1)}',
        'below ${s.substring(1)}',
        'por debajo de ${s.substring(1)}',
        'en dessous de ${s.substring(1)}',
        'unter ${s.substring(1)}',
        'abaixo de ${s.substring(1)}',
      )
    : s;

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
      App.I.syncWidget();
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
    // the home-screen widget: what it answered comes in, the latest questions go out
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) App.I.syncWidget();
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

  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

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
                Opacity(
                  opacity: calm ? 1 : _span(0.5, 0.72),
                  // the tagline stays English in every language, like the names of titles
                  child: const Label('Vocabulary Quest'),
                ),
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

/// The first run, in four steps: the language the app speaks, the kingdom (the language learned), then the banner
/// (Aldmere), an exam to aim for (another kingdom) or the language of meanings (a kingdom whose language is the one
/// the app speaks), and where to start.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

const _langNames = [
  ('id', 'Bahasa Indonesia'),
  ('en', 'English'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('de', 'Deutsch'),
  ('pt', 'Português'),
];

/// words each kingdom teaches, for the card that offers it
const _kingdomWords = {'en': 6912, 'de': 8236, 'es': 8008, 'fr': 8055, 'pt': 8069};

String _langName(String c) => _langNames.firstWhere((l) => l.$1 == c, orElse: () => _langNames[1]).$2;

class _OnboardingState extends State<Onboarding> {
  int _step = 0;
  String _k = App.I.realm;
  String _banner = '';
  String _via = 'en';
  bool _test = false;
  bool _busy = false;

  Future<void> _go(Future<void> Function() work, int next) async {
    if (_busy) return;
    setState(() => _busy = true);
    await work();
    if (mounted) {
      setState(() {
        _busy = false;
        _step = next;
      });
    }
  }

  Future<void> _start() async {
    if (_test) {
      await Navigator.of(context).push(runRoute(const RunScreen(kind: RunKind.placement)));
    }
    App.I.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final app = App.I;
    final Kingdom k = Kingdom.of(_k);
    final (Widget content, String button, VoidCallback? onTap) = switch (_step) {
      0 => (
        _language(context),
        tr('Lanjut', 'Continue', 'Continuar', 'Continuer', 'Weiter', 'Continuar'),
        () => setState(() => _step = 1),
      ),
      1 => (
        _kingdom(context),
        tr(
          'Masuk ke ${k.name}',
          'Enter ${k.name}',
          'Entrar en ${k.name}',
          'Entrer à ${k.name}',
          '${k.name} betreten',
          'Entrar em ${k.name}',
        ),
        () => _go(() async {
          await app.chooseRealm(_k);
          if (app.clash) _via = app.viaChosen ? app.via : 'en';
        }, 2),
      ),
      2 => (
        _k == 'en' ? _bannerStep(context) : _examStep(context),
        tr('Lanjut', 'Continue', 'Continuar', 'Continuer', 'Weiter', 'Continuar'),
        _k == 'en' && _banner.isEmpty
            ? null
            : () => _go(() async {
                if (_k == 'en') await app.chooseBanner(_banner);
                if (app.clash) app.chooseVia(_via);
              }, 3),
      ),
      _ => (_startStep(context), tr('Mulai', 'Start', 'Empezar', 'Commencer', 'Starten', 'Começar'), _start),
    };
    return Leaf(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (_step > 0)
                  Press(
                    onTap: () => setState(() => _step--),
                    label: tr('Kembali', 'Back', 'Atrás', 'Retour', 'Zurück', 'Voltar'),
                    child: SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back, color: pal.ink)),
                  )
                else
                  const Seal(size: 34),
                const SizedBox(width: 10),
                Text('VERBARIUM', style: T.label(pal.muted).copyWith(letterSpacing: 3)),
                const Spacer(),
                Semantics(
                  label: tr(
                    'Langkah ${_step + 1} dari 4',
                    'Step ${_step + 1} of 4',
                    'Paso ${_step + 1} de 4',
                    'Étape ${_step + 1} sur 4',
                    'Schritt ${_step + 1} von 4',
                    'Passo ${_step + 1} de 4',
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          AnimatedContainer(
                            duration: Dur.enter,
                            margin: const EdgeInsets.only(left: 6),
                            width: i == _step ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _step ? pal.ink : pal.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: Dur.enter,
              reverseDuration: Dur.out,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: SingleChildScrollView(key: ValueKey('$_step$_k'), child: content),
            ),
          ),
          const SizedBox(height: 12),
          InkButton(button, onTap: _busy ? null : onTap),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String title, String sub) {
    final pal = Look.of(context).pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: T.display(32, pal.ink, height: 1.15)),
        const SizedBox(height: 8),
        Text(sub, style: T.body(16.5, pal.muted, height: 1.45)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required bool on,
    required VoidCallback onTap,
    required Widget child,
    String? label,
  }) {
    final pal = Look.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Press(
        onTap: onTap,
        label: label,
        child: Semantics(
          selected: on,
          child: AnimatedContainer(
            duration: Dur.out,
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(horizontal: on ? 13 : 14, vertical: on ? 9 : 10),
            decoration: BoxDecoration(
              color: pal.field,
              border: Border.all(color: on ? pal.ink : pal.line, width: on ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                if (on) Icon(Icons.check_circle, size: 24, color: pal.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- 1: the language the app speaks

  Widget _language(BuildContext context) {
    final pal = Look.of(context).pal;
    final phone = App.phoneLanguage();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          tr(
            'Aplikasi bicara dalam bahasa apa?',
            'Which language should the app speak?',
            '¿En qué idioma te habla la app?',
            'Dans quelle langue l’app te parle-t-elle ?',
            'In welcher Sprache soll die App sprechen?',
            'Em que idioma o app fala com você?',
          ),
          tr(
            'Menu, arti kata, dan terjemahan kalimat memakai bahasa ini, di semua kerajaan. Bisa diganti kapan saja di Pengaturan.',
            'Menus, meanings and sentence translations use this language in every kingdom. You can change it any time in Settings.',
            'Los menús, los significados y las traducciones usan este idioma en todos los reinos. Puedes cambiarlo cuando quieras en Ajustes.',
            'Les menus, les sens et les traductions utilisent cette langue dans tous les royaumes. Tu peux la changer à tout moment dans Réglages.',
            'Menüs, Bedeutungen und Übersetzungen erscheinen in jedem Königreich in dieser Sprache. Du kannst sie jederzeit in den Einstellungen ändern.',
            'Menus, sentidos e traduções usam este idioma em todos os reinos. Dá para mudar a qualquer momento nas Configurações.',
          ),
        ),
        for (final (code, name) in _langNames)
          _row(
            context,
            on: App.I.langCode == code,
            onTap: () => App.I.put('lang', code),
            label: name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: T.body(18, pal.ink, w: FontWeight.w700)),
                if (code == phone)
                  Text(
                    tr(
                      'Mengikuti bahasa ponselmu',
                      'Matches your phone',
                      'El idioma de tu teléfono',
                      'La langue de ton téléphone',
                      'Die Sprache deines Handys',
                      'O idioma do seu celular',
                    ),
                    style: T.body(14, pal.muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // -- 2: the kingdom, the language learned

  Widget _kingdom(BuildContext context) {
    final pal = Look.of(context).pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          tr(
            'Bahasa apa yang ingin kamu pelajari?',
            'Which language do you want to learn?',
            '¿Qué idioma quieres aprender?',
            'Quelle langue veux-tu apprendre ?',
            'Welche Sprache möchtest du lernen?',
            'Que idioma você quer aprender?',
          ),
          tr(
            'Setiap bahasa adalah satu kerajaan dengan jalan, gelar, dan karakternya sendiri. Kerajaan lain bisa dibuka nanti lewat peta Negeri.',
            'Each language is a kingdom with its own road, titles and character. The others can be opened later from the map.',
            'Cada idioma es un reino con su propio camino, sus títulos y su personaje. Los demás se pueden abrir luego desde el mapa.',
            'Chaque langue est un royaume avec sa route, ses titres et son personnage. Les autres s’ouvrent plus tard depuis la carte.',
            'Jede Sprache ist ein Königreich mit eigenem Weg, eigenen Titeln und eigener Figur. Die anderen kannst du später über die Karte öffnen.',
            'Cada idioma é um reino com sua própria estrada, títulos e personagem. Os outros podem ser abertos depois pelo mapa.',
          ),
        ),
        for (final k in Kingdom.all)
          _row(
            context,
            on: _k == k.code,
            onTap: () => setState(() => _k = k.code),
            label: '${k.name}, ${k.language}',
            child: Row(
              children: [
                KingdomArms(k.code, height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(k.name, style: T.display(21, pal.ink)),
                          const SizedBox(width: 8),
                          Text(k.language, style: T.body(14.5, pal.muted)),
                        ],
                      ),
                      Text(
                        '${tr('${_kingdomWords[k.code]} kata', '${_kingdomWords[k.code]} words', '${_kingdomWords[k.code]} palabras', '${_kingdomWords[k.code]} mots', '${_kingdomWords[k.code]} Wörter', '${_kingdomWords[k.code]} palavras')} · '
                        '${k.code == 'en' ? 'TOEFL · IELTS' : k.letters.take(4).join(' ')}',
                        style: T.body(14, pal.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -- 3: Aldmere's banner

  Widget _bannerStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          tr(
            'Pilih panjimu',
            'Choose your banner',
            'Elige tu estandarte',
            'Choisis ta bannière',
            'Wähle dein Banner',
            'Escolha seu estandarte',
          ),
          tr(
            'Kata dan ejaan mengikuti ujian yang kamu tuju. Kedua ejaan tetap diterima, dan panji bisa diganti kapan saja.',
            'Words and spelling follow the test you are heading for. Both spellings are accepted, and you can change it at any time.',
            'Las palabras y la ortografía siguen el examen al que te diriges. Se aceptan ambas ortografías y puedes cambiarlo cuando quieras.',
            'Les mots et l’orthographe suivent le test que tu vises. Les deux orthographes sont acceptées, et tu peux le changer quand tu veux.',
            'Wörter und Schreibung folgen der Prüfung, die du anstrebst. Beide Schreibungen gelten, und du kannst es jederzeit ändern.',
            'As palavras e a grafia seguem a prova que você vai fazer. As duas grafias são aceitas, e dá para mudar a qualquer momento.',
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BannerCard(
                  'toefl',
                  'TOEFL',
                  tr(
                    'Kata kampus dan kuliah. Ejaan Amerika.',
                    'Words of campus and lectures. American spelling.',
                    'Palabras del campus y de las clases. Ortografía estadounidense.',
                    'Mots du campus et des cours. Orthographe américaine.',
                    'Wörter aus Campus und Vorlesung. Amerikanische Schreibung.',
                    'Palavras de campus e aulas. Grafia americana.',
                  ),
                  _banner == 'toefl',
                  () => setState(() => _banner = 'toefl'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BannerCard(
                  'ielts',
                  'IELTS',
                  tr(
                    'Kata topik esai dan grafik. Ejaan Inggris.',
                    'Words of essay topics and charts. British spelling.',
                    'Palabras de redacciones y gráficos. Ortografía británica.',
                    'Mots des rédactions et des graphiques. Orthographe britannique.',
                    'Wörter aus Aufsatzthemen und Diagrammen. Britische Schreibung.',
                    'Palavras de temas de redação e gráficos. Grafia britânica.',
                  ),
                  _banner == 'ielts',
                  () => setState(() => _banner = 'ielts'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -- 3: another kingdom: an exam to aim for, and the language of meanings where it must be chosen

  Widget _examStep(BuildContext context) {
    final pal = Look.of(context).pal;
    final k = Kingdom.of(_k);
    final clash = App.I.clash;
    final exam = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.field,
        border: Border.all(color: pal.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              'UJIAN YANG BISA JADI TUJUAN',
              'AN EXAM TO AIM FOR',
              'UN EXAMEN COMO META',
              'UN EXAMEN POUR CIBLE',
              'EINE PRÜFUNG ALS ZIEL',
              'UMA PROVA COMO META',
            ),
            style: T.label(pal.muted),
          ),
          const SizedBox(height: 6),
          Text(examOf(k.code), style: T.body(16.5, pal.ink, height: 1.45)),
          const SizedBox(height: 6),
          Text(
            tr(
              'Ini hanya saran. Gelar di sini mengukur kosakata, bukan nilai ujian.',
              'This is only a suggestion. A title here measures vocabulary, not an exam score.',
              'Es solo una sugerencia. Aquí un título mide vocabulario, no la nota de un examen.',
              'Ce n’est qu’une suggestion. Ici, un titre mesure le vocabulaire, pas une note d’examen.',
              'Das ist nur ein Vorschlag. Ein Titel misst hier den Wortschatz, kein Prüfungsergebnis.',
              'É só uma sugestão. Aqui um título mede vocabulário, não a nota de uma prova.',
            ),
            style: T.body(14.5, pal.muted, height: 1.4),
          ),
        ],
      ),
    );
    if (clash) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            context,
            tr(
              'Arti ditampilkan dalam bahasa apa?',
              'Which language for the meanings?',
              '¿En qué idioma ves los significados?',
              'Dans quelle langue vois-tu les sens ?',
              'In welcher Sprache stehen die Bedeutungen?',
              'Em que idioma aparecem os sentidos?',
            ),
            tr(
              'Kamu belajar ${k.language} lewat ${k.language}, jadi arti kata dan terjemahan kalimat ditampilkan dalam bahasa lain. Bisa diganti lewat panji ${k.name}.',
              'You learn ${k.language} through ${k.language}, so meanings and translations are shown in another language. You can change it on the banner of ${k.name}.',
              'Aprendes ${k.language.toLowerCase()} a través del ${k.language.toLowerCase()}, así que los significados y las traducciones se muestran en otro idioma. Puedes cambiarlo en el estandarte de ${k.name}.',
              'Tu apprends le ${k.language.toLowerCase()} en ${k.language.toLowerCase()} : les sens et les traductions s’affichent donc dans une autre langue. Tu peux la changer sur la bannière de ${k.name}.',
              'Du lernst ${k.language} über ${k.language}, darum erscheinen Bedeutungen und Übersetzungen in einer anderen Sprache. Du kannst sie am Banner von ${k.name} ändern.',
              'Você aprende ${k.language.toLowerCase()} por meio do ${k.language.toLowerCase()}, então os sentidos e as traduções aparecem em outro idioma. Dá para mudar no estandarte de ${k.name}.',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, name) in _langNames)
                if (code != k.code)
                  Press(
                    onTap: () => setState(() => _via = code),
                    label: name,
                    child: Semantics(
                      selected: _via == code,
                      child: ExcludeSemantics(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _via == code ? pal.ink : Colors.transparent,
                            border: Border.all(color: pal.ink, width: 1.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(name, style: T.body(15, _via == code ? pal.bg : pal.ink, w: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 18),
          exam,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(child: KingdomArms(k.code, height: 120)),
        const SizedBox(height: 10),
        Center(child: Text(k.name, style: T.display(34, pal.ink))),
        Center(child: Text(k.language, style: T.body(16, pal.muted))),
        const SizedBox(height: 20),
        exam,
        const SizedBox(height: 18),
        Text(
          tr(
            'Yang kamu dapat',
            'What you get',
            'Lo que obtienes',
            'Ce que tu as',
            'Was du bekommst',
            'O que você recebe',
          ),
          style: T.body(16, pal.ink, w: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'Kalimat dengan celah, terjemahan kalimatnya, dan tombol huruf ${k.letters.take(4).join(' ')} di bawah celah.',
            'Sentences with a gap, their translation, and keys for ${k.letters.take(4).join(' ')} under the gap.',
            'Frases con un hueco, su traducción y teclas para ${k.letters.take(4).join(' ')} bajo el hueco.',
            'Des phrases à trou, leur traduction et des touches pour ${k.letters.take(4).join(' ')} sous le trou.',
            'Sätze mit einer Lücke, ihre Übersetzung und Tasten für ${k.letters.take(4).join(' ')} unter der Lücke.',
            'Frases com uma lacuna, a tradução delas e teclas para ${k.letters.take(4).join(' ')} embaixo da lacuna.',
          ),
          style: T.body(16, pal.muted, height: 1.45),
        ),
      ],
    );
  }

  // -- 4: where to start

  Widget _startStep(BuildContext context) {
    final pal = Look.of(context).pal;
    final app = App.I;
    final k = Kingdom.of(_k);
    final explained = app.clash ? app.via : app.langCode;
    Widget option(bool test, Widget icon, String title, String note) => _row(
      context,
      on: _test == test,
      onTap: () => setState(() => _test = test),
      label: title,
      child: Row(
        children: [
          SizedBox(width: 30, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body(17, pal.ink, w: FontWeight.w700)),
                Text(note, style: T.body(14, pal.muted)),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          tr(
            'Dari mana kamu mulai?',
            'Where do you start?',
            '¿Por dónde empiezas?',
            'Par où commences-tu ?',
            'Wo fängst du an?',
            'Por onde você começa?',
          ),
          tr(
            'Semua orang mulai sebagai Peasant. Kalau kosakatamu sudah jauh, ujian penempatan bisa mengangkatmu langsung, paling tinggi sampai Baron.',
            'Everyone starts as a Peasant. If your vocabulary is already far along, the placement test can raise you at once, as high as Baron.',
            'Todos empiezan como Peasant. Si tu vocabulario ya va avanzado, la prueba de nivel puede subirte enseguida, hasta Baron.',
            'Tout le monde commence en Peasant. Si ton vocabulaire est déjà avancé, le test de niveau peut te faire monter tout de suite, jusqu’à Baron.',
            'Alle beginnen als Peasant. Ist dein Wortschatz schon weit, kann dich der Einstufungstest sofort aufsteigen lassen, bis zum Baron.',
            'Todos começam como Peasant. Se seu vocabulário já vai longe, o teste de nivelamento pode subir você na hora, até Baron.',
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.field,
            border: Border.all(color: pal.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('JALANMU', 'YOUR ROAD', 'TU CAMINO', 'TA ROUTE', 'DEIN WEG', 'SEU CAMINHO'),
                style: T.label(pal.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  KingdomArms(k.code, height: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${k.name} · ${k.language}${k.code == 'en' && app.banner.isNotEmpty ? ' · ${bannerName(app.banner)}' : ''}',
                          style: T.body(16, pal.ink, w: FontWeight.w700),
                        ),
                        Text(
                          tr(
                            'Dijelaskan dalam ${_langName(explained)}',
                            'Explained in ${_langName(explained)}',
                            'Explicado en ${_langName(explained)}',
                            'Expliqué en ${_langName(explained)}',
                            'Erklärt auf ${_langName(explained)}',
                            'Explicado em ${_langName(explained)}',
                          ),
                          style: T.body(14, pal.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        option(
          false,
          const Shield(0, width: 24),
          tr(
            'Mulai sebagai Peasant',
            'Start as a Peasant',
            'Empezar como Peasant',
            'Commencer en Peasant',
            'Als Peasant beginnen',
            'Começar como Peasant',
          ),
          tr(
            'Dari kata dasar · CEFR A1',
            'From the basics · CEFR A1',
            'Desde lo básico · MCER A1',
            'Depuis les bases · CECRL A1',
            'Von den Grundlagen · GER A1',
            'Do básico · QECR A1',
          ),
        ),
        option(
          true,
          Icon(Icons.star_border, color: pal.ink, size: 28),
          tr(
            'Ikut ujian penempatan',
            'Take the placement test',
            'Hacer la prueba de nivel',
            'Passer le test de niveau',
            'Einstufungstest machen',
            'Fazer o teste de nivelamento',
          ),
          tr(
            'Sampai 24 kata, sekitar lima menit',
            'Up to 24 words, about five minutes',
            'Hasta 24 palabras, unos cinco minutos',
            'Jusqu’à 24 mots, environ cinq minutes',
            'Bis zu 24 Wörter, etwa fünf Minuten',
            'Até 24 palavras, uns cinco minutos',
          ),
        ),
      ],
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
      label: tr(
        'Panji $title',
        'Banner $title',
        'Estandarte $title',
        'Bannière $title',
        'Banner $title',
        'Estandarte $title',
      ),
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

  /// the tab shown; anything may move it (the kingdom's name on Today opens Negeri)
  static final tab = ValueNotifier<int>(0);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int get _tab => Shell.tab.value;

  void _moved() => setState(() {});

  @override
  void initState() {
    super.initState();
    Shell.tab.value = 0; // a new shell (a new start) opens on Today
    Shell.tab.addListener(_moved);
  }

  @override
  void dispose() {
    Shell.tab.removeListener(_moved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    final names = [
      tr('Hari ini', 'Today', 'Hoy', 'Aujourd’hui', 'Heute', 'Hoje'),
      tr('Negeri', 'Realm', 'Reino', 'Royaume', 'Reich', 'Reino'),
      tr('Karakter', 'Character', 'Personaje', 'Personnage', 'Figur', 'Personagem'),
      tr('Kronik', 'Chronicle', 'Crónica', 'Chronique', 'Chronik', 'Crônica'),
    ];
    const icons = [Icons.edit_outlined, Icons.map_outlined, Icons.shield_outlined, Icons.menu_book_outlined];
    final pages = [const Today(), const RealmWorld(), const HeroTab(), const ChronicleTab()];
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
                                Shell.tab.value = i;
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
                                          style: T.body(
                                            14,
                                            _tab == i ? pal.ink : pal.muted,
                                            w: _tab == i ? FontWeight.w700 : FontWeight.w500,
                                          ),
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
        title: tr(
          'Gelarmu goyah',
          'Your title wavers',
          'Tu título se tambalea',
          'Ton titre vacille',
          'Dein Titel wankt',
          'Seu título vacila',
        ),
        text: tr(
          'Kata dari ranah yang sudah kamu kuasai banyak yang lepas. Pertahankan gelar ${rankNames[rank]} dalam ${e.shakyDaysLeft} hari, atau gelar turun.',
          'Many words from the lands you already hold have slipped. Defend the title of ${rankNames[rank]} within ${e.shakyDaysLeft} days, or it is lost.',
          'Muchas palabras de las tierras que ya dominas se han escapado. Defiende el título de ${rankNames[rank]} en ${e.shakyDaysLeft} días o lo perderás.',
          'Beaucoup de mots des terres que tu tiens t’ont échappé. Défends le titre de ${rankNames[rank]} dans les ${e.shakyDaysLeft} jours, sinon il est perdu.',
          'Viele Wörter aus deinen Ländern sind dir entglitten. Verteidige den Titel ${rankNames[rank]} innerhalb von ${e.shakyDaysLeft} Tagen, sonst ist er verloren.',
          'Muitas palavras das terras que você já tem escaparam. Defenda o título de ${rankNames[rank]} em até ${e.shakyDaysLeft} dias, ou ele será perdido.',
        ),
        action: tr(
          'Pertahankan gelar',
          'Defend the title',
          'Defender el título',
          'Défendre le titre',
          'Titel verteidigen',
          'Defender o título',
        ),
        strong: true,
        onTap: () => runFrom(context, RunScreen(kind: RunKind.defence, tier: rank)),
      );
    }
    final en = g.enemy;
    if (en == null) {
      return Notice(
        title: tr(
          'Takhta di tanganmu',
          'The throne is yours',
          'El trono es tuyo',
          'Le trône est à toi',
          'Der Thron gehört dir',
          'O trono é seu',
        ),
        text: tr(
          'Tidak ada lawan di atas King. Jaga kata-katamu tetap kukuh.',
          'There is no foe above a King. Keep your words solid.',
          'No hay enemigo por encima de un King. Mantén firmes tus palabras.',
          'Aucun ennemi au-dessus d’un King. Garde tes mots bien ancrés.',
          'Über einem King gibt es keinen Gegner. Halte deine Wörter fest.',
          'Não há inimigo acima de um King. Mantenha suas palavras firmes.',
        ),
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
                FoeStage(sprite: en.sprite, tone: en.tone, boss: en.boss, width: en.boss ? 118 : 100),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(
                        en.boss
                            ? tr(
                                'Boss · menuju ${rankNames[next]}',
                                'Boss · on the way to ${rankNames[next]}',
                                'Jefe · camino a ${rankNames[next]}',
                                'Boss · en route vers ${rankNames[next]}',
                                'Boss · auf dem Weg zum ${rankNames[next]}',
                                'Boss · a caminho de ${rankNames[next]}',
                              )
                            : tr(
                                'Penjaga jalan · tingkat ${stageName(e.stage)}',
                                'Guard of the road · stage ${stageName(e.stage)}',
                                'Guardián del camino · etapa ${stageName(e.stage)}',
                                'Gardien de la route · étape ${stageName(e.stage)}',
                                'Wächter der Straße · Stufe ${stageName(e.stage)}',
                                'Guardião da estrada · etapa ${stageName(e.stage)}',
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(en.name, style: T.display(25, pal.ink)),
                      if (en.threat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(en.threat, style: T.display(15.5, pal.bad, italic: true)),
                      ],
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
                        '${Engine.trialSize} kata, ${Engine.trialSeconds} detik tiap kata, tanpa petunjuk. Tumbang pada ${Engine.trialPass} pukulan; kamu kalah pada pukulan kelima yang meleset. Setelah separuh nyawanya hilang ia murka: ${Engine.rageCut} detik lebih sedikit tiap kata.',
                        '${Engine.trialSize} words, ${Engine.trialSeconds} seconds each, no hints. It falls at ${Engine.trialPass} blows; you lose at the fifth blow that misses. Once half its life is gone it rages: ${Engine.rageCut} seconds fewer per word.',
                        '${Engine.trialSize} palabras, ${Engine.trialSeconds} segundos cada una, sin pistas. Cae con ${Engine.trialPass} golpes; pierdes al quinto golpe fallado. Cuando pierde la mitad de su vida se enfurece: ${Engine.rageCut} segundos menos por palabra.',
                        '${Engine.trialSize} mots, ${Engine.trialSeconds} secondes chacun, sans indice. Il tombe après ${Engine.trialPass} coups ; tu perds au cinquième coup manqué. Une fois la moitié de sa vie perdue, il entre en fureur : ${Engine.rageCut} secondes de moins par mot.',
                        '${Engine.trialSize} Wörter, je ${Engine.trialSeconds} Sekunden, keine Hilfen. Er fällt nach ${Engine.trialPass} Hieben; du verlierst beim fünften Fehlschlag. Ist die Hälfte seines Lebens weg, rast er: ${Engine.rageCut} Sekunden weniger pro Wort.',
                        '${Engine.trialSize} palavras, ${Engine.trialSeconds} segundos cada, sem dicas. Ele cai com ${Engine.trialPass} golpes; você perde no quinto golpe errado. Quando perde metade da vida, fica furioso: ${Engine.rageCut} segundos a menos por palavra.',
                      )
                    : tr(
                        '${Engine.subSize} kata, ${Engine.trialSeconds + g.perk('subTime')} detik tiap kata. Tumbang pada ${Engine.subPass} pukulan; kamu punya ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} nyawa.',
                        '${Engine.subSize} words, ${Engine.trialSeconds + g.perk('subTime')} seconds each. It falls at ${Engine.subPass} blows; you have ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} lives.',
                        '${Engine.subSize} palabras, ${Engine.trialSeconds + g.perk('subTime')} segundos cada una. Cae con ${Engine.subPass} golpes; tienes ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} vidas.',
                        '${Engine.subSize} mots, ${Engine.trialSeconds + g.perk('subTime')} secondes chacun. Il tombe après ${Engine.subPass} coups ; tu as ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} vies.',
                        '${Engine.subSize} Wörter, je ${Engine.trialSeconds + g.perk('subTime')} Sekunden. Er fällt nach ${Engine.subPass} Hieben; du hast ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} Leben.',
                        '${Engine.subSize} palavras, ${Engine.trialSeconds + g.perk('subTime')} segundos cada. Ele cai com ${Engine.subPass} golpes; você tem ${Engine.subSize - Engine.subPass + 1 + g.perk('subHp')} vidas.',
                      ),
                style: T.body(15.5, pal.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              InkButton(
                tr(
                  'Lawan ${en.name}',
                  'Fight the ${en.name}',
                  'Enfrentar a ${en.name}',
                  'Affronter ${en.name}',
                  'Gegen ${en.name} kämpfen',
                  'Lutar contra ${en.name}',
                ),
                outline: true,
                onTap: () => runFrom(context, RunScreen(kind: en.boss ? RunKind.trial : RunKind.sub, tier: next)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cooling
                          ? tr(
                              'Memulihkan diri',
                              'Recovering',
                              'Recuperándose',
                              'En récupération',
                              'Erholt sich',
                              'Recuperando-se',
                            )
                          : tr(
                              'Belum bisa dilawan',
                              'Cannot be fought yet',
                              'Aún no se puede enfrentar',
                              'Pas encore affrontable',
                              'Noch nicht bekämpfbar',
                              'Ainda não dá para lutar',
                            ),
                      style: T.body(16, pal.ink, w: FontWeight.w500),
                    ),
                  ),
                  Text(
                    tr(
                      '${st.solid} dari $need kata kukuh',
                      '${st.solid} of $need solid words',
                      '${st.solid} de $need palabras firmes',
                      '${st.solid} mots ancrés sur $need',
                      '${st.solid} von $need gefestigten Wörtern',
                      '${st.solid} de $need palavras firmes',
                    ),
                    style: T.body(15, pal.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Bar(need == 0 ? 0 : st.solid / need, height: 6),
              const SizedBox(height: 8),
              Text(
                cooling
                    ? (en.boss
                          ? tr(
                              'Boss bisa dilawan lagi besok.',
                              'The boss can be fought again tomorrow.',
                              'Podrás volver a enfrentarte al jefe mañana.',
                              'Tu pourras affronter le boss à nouveau demain.',
                              'Gegen den Boss kannst du morgen wieder kämpfen.',
                              'Dá para lutar contra o boss de novo amanhã.',
                            )
                          : tr(
                              'Musuh ini bisa dilawan lagi dalam beberapa jam.',
                              'This foe can be fought again in a few hours.',
                              'Podrás volver a enfrentarte a este enemigo en unas horas.',
                              'Tu pourras affronter cet ennemi à nouveau dans quelques heures.',
                              'Gegen diesen Gegner kannst du in ein paar Stunden wieder kämpfen.',
                              'Dá para lutar contra este inimigo de novo em algumas horas.',
                            ))
                    : tr(
                        'Kata menjadi kukuh setelah kamu mengingatnya lebih dari seminggu lewat celah kalimat.',
                        'A word becomes solid once you have remembered it for more than a week through the gap in a sentence.',
                        'Una palabra se vuelve firme cuando la recuerdas más de una semana a través del hueco de una frase.',
                        'Un mot devient ancré quand tu t’en souviens plus d’une semaine grâce au trou d’une phrase.',
                        'Ein Wort ist gefestigt, wenn du es länger als eine Woche über die Lücke im Satz behalten hast.',
                        'Uma palavra fica firme quando você a lembra por mais de uma semana pela lacuna de uma frase.',
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

    final next = min(rank + 1, Engine.maxRank);
    final road = e.stat(next);
    return TabBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Hari ini', 'Today', 'Hoy', 'Aujourd’hui', 'Heute', 'Hoje'),
                style: T.display(30, pal.ink),
              ),
            ),
            if (e.streak > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  tr(
                    'Rentetan ${e.streak} hari',
                    '${e.streak}-day streak',
                    'Racha de ${e.streak} días',
                    'Série de ${e.streak} jours',
                    '${e.streak} Tage in Folge',
                    '${e.streak} dias seguidos',
                  ),
                  style: T.body(15, pal.gold, w: FontWeight.w700),
                ),
              ),
            const DonateButton(),
            Press(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
              label: tr('Pengaturan', 'Settings', 'Ajustes', 'Réglages', 'Einstellungen', 'Configurações'),
              child: SizedBox(width: 48, height: 48, child: Icon(Icons.tune, color: pal.ink, size: 24)),
            ),
          ],
        ),
        const Align(alignment: Alignment.centerLeft, child: KingdomName()),
        const SizedBox(height: 6),
        Rise(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: pal.field,
              border: Border.all(color: pal.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                HeroSprite(
                  garb: g.job.garb,
                  tier: g.job.tier,
                  weapon: g.tone('weapon'),
                  shield: g.tone('shield'),
                  cloak: g.tone('cloak'),
                  livery: App.I.livery,
                  size: 64,
                ),
                const SizedBox(width: 12),
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
                              child: Text('${rankNames[rank]} · ${g.job.name}', style: T.display(24, pal.ink)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${App.I.realm == 'en' ? '' : '${App.I.kingdom.name} · '}${rank < Engine.maxRank ? '${tr('tingkat', 'stage', 'etapa', 'étape', 'Stufe', 'etapa')} ${stageName(e.stage)} · ' : ''}Level ${g.level}${g.title.isEmpty ? '' : ' · ${g.title}'}',
                        style: T.body(14.5, pal.ink, w: FontWeight.w500),
                      ),
                      Text(
                        tr(
                          'Kosakata setara ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                          'Vocabulary on a par with ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                          'Vocabulario equivalente a ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                          'Vocabulaire équivalent à ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                          'Wortschatz auf dem Niveau von ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                          'Vocabulário no nível de ${scoreLine(rank, app.realm == 'en' ? app.banner : '')}',
                        ),
                        style: T.body(14, pal.muted),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        label: tr(
                          '${g.toNext} XP lagi ke level ${g.level + 1}',
                          '${g.toNext} XP to level ${g.level + 1}',
                          '${g.toNext} XP para el nivel ${g.level + 1}',
                          '${g.toNext} XP avant le niveau ${g.level + 1}',
                          '${g.toNext} XP bis Stufe ${g.level + 1}',
                          '${g.toNext} XP até o nível ${g.level + 1}',
                        ),
                        child: Bar(g.levelShare, height: 6),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(
                          '${g.toNext} XP lagi ke level ${g.level + 1}',
                          '${g.toNext} XP to level ${g.level + 1}',
                          '${g.toNext} XP para el nivel ${g.level + 1}',
                          '${g.toNext} XP avant le niveau ${g.level + 1}',
                          '${g.toNext} XP bis Stufe ${g.level + 1}',
                          '${g.toNext} XP até o nível ${g.level + 1}',
                        ),
                        style: T.body(12.5, pal.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(rankGreeting(rank), style: T.display(18.5, pal.muted, italic: true)),
        const SizedBox(height: 14),
        Rise(
          delay: const Duration(milliseconds: 60),
          child: Row(
            children: [
              _Tile(
                plan.reviews,
                tr('ulang', 'to review', 'por repasar', 'à réviser', 'zu wiederholen', 'para revisar'),
              ),
              const SizedBox(width: 8),
              _Tile(
                plan.fresh,
                tr('kata baru', 'new words', 'palabras nuevas', 'nouveaux mots', 'neue Wörter', 'palavras novas'),
              ),
              const SizedBox(width: 8),
              _Tile(e.solidTotal, tr('kukuh', 'solid', 'firmes', 'ancrés', 'gefestigt', 'firmes')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!plan.empty)
          InkButton(
            plan.doneToday > 0
                ? tr(
                    'Lanjut belajar',
                    'Continue learning',
                    'Seguir aprendiendo',
                    'Continuer d’apprendre',
                    'Weiterlernen',
                    'Continuar aprendendo',
                  )
                : tr(
                    'Mulai belajar',
                    'Start learning',
                    'Empezar a aprender',
                    'Commencer à apprendre',
                    'Lernen beginnen',
                    'Começar a aprender',
                  ),
            onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn)),
          )
        else ...[
          Text(
            plan.doneToday > 0
                ? tr(
                    'Tercatat. Tugas hari ini selesai.',
                    'Noted. Today\'s tasks are done.',
                    'Anotado. Las tareas de hoy están hechas.',
                    'Noté. Les tâches du jour sont faites.',
                    'Verzeichnet. Die Aufgaben für heute sind erledigt.',
                    'Registrado. As tarefas de hoje estão feitas.',
                  )
                : tr(
                    'Belum ada yang perlu diulang hari ini.',
                    'Nothing needs review today.',
                    'Hoy no hay nada que repasar.',
                    'Rien à réviser aujourd’hui.',
                    'Heute ist nichts zu wiederholen.',
                    'Nada precisa de revisão hoje.',
                  ),
            style: T.display(22, pal.ink, italic: true),
          ),
          const SizedBox(height: 12),
          if (moreFresh > 0)
            InkButton(
              tr(
                'Tambah $moreFresh kata baru',
                'Add $moreFresh new words',
                'Añadir $moreFresh palabras nuevas',
                'Ajouter $moreFresh nouveaux mots',
                '$moreFresh neue Wörter hinzufügen',
                'Adicionar $moreFresh palavras novas',
              ),
              outline: true,
              onTap: () => runFrom(context, const RunScreen(kind: RunKind.learn, extraFresh: 10)),
            ),
        ],
        if (rank < Engine.maxRank) ...[
          const SizedBox(height: 14),
          Rise(
            delay: const Duration(milliseconds: 120),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: pal.field,
                border: Border.all(color: pal.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Shield(next, width: 18, hollow: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(
                            'Jalan ke ${rankNames[next]} · ${(road.share * 100).round()}% kata kukuh',
                            'The road to ${rankNames[next]} · ${(road.share * 100).round()}% of words solid',
                            'Camino a ${rankNames[next]} · ${(road.share * 100).round()}% de palabras firmes',
                            'Route vers ${rankNames[next]} · ${(road.share * 100).round()} % de mots ancrés',
                            'Der Weg zum ${rankNames[next]} · ${(road.share * 100).round()} % der Wörter gefestigt',
                            'O caminho até ${rankNames[next]} · ${(road.share * 100).round()}% das palavras firmes',
                          ),
                          style: T.body(14.5, pal.ink, w: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RoadBar(road.share),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Ujian penobatan terbuka di ${(Engine.openShare * 100).round()}%.',
                      'The coronation trial opens at ${(Engine.openShare * 100).round()}%.',
                      'La prueba de coronación se abre al ${(Engine.openShare * 100).round()} %.',
                      'L’épreuve du couronnement s’ouvre à ${(Engine.openShare * 100).round()} %.',
                      'Die Krönungsprüfung öffnet sich bei ${(Engine.openShare * 100).round()} %.',
                      'A prova de coroação abre em ${(Engine.openShare * 100).round()}%.',
                    ),
                    style: T.body(13, pal.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const FightCard(),
        const SizedBox(height: 20),
        Label(
          tr(
            'Quest hari ini',
            'Today\'s quests',
            'Misiones de hoy',
            'Quêtes du jour',
            'Aufgaben für heute',
            'Missões de hoje',
          ),
        ),
        const SizedBox(height: 4),
        for (final (i, q) in quests.indexed)
          Rise(
            delay: Duration(milliseconds: 160 + 50 * i),
            child: QuestRow(q),
          ),
        if (advice.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(color: pal.deep, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: pal.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          'Saran hari ini',
                          'Advice for today',
                          'Consejo de hoy',
                          'Conseil du jour',
                          'Rat für heute',
                          'Conselho de hoje',
                        ),
                        style: T.body(14.5, pal.ink, w: FontWeight.w700),
                      ),
                      for (final a in advice)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(a, style: T.body(15, pal.ink, height: 1.4)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// the bar toward the next title, with the mark where the coronation trial opens
class _RoadBar extends StatelessWidget {
  final double share;
  const _RoadBar(this.share);

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          Bar(share, height: 8),
          Positioned(
            left: box.maxWidth * Engine.openShare - 1,
            top: -3,
            child: Container(width: 2, height: 14, color: look.pal.gold),
          ),
        ],
      ),
    );
  }
}

/// a number in a box that counts up when it first shows
class _Tile extends StatelessWidget {
  final int n;
  final String what;
  const _Tile(this.n, this.what);

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final pal = look.pal;
    return Expanded(
      child: Semantics(
        label: '$n $what',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: pal.field,
              border: Border.all(color: pal.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(what, style: T.body(13, pal.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: n.toDouble()),
                  duration: look.calm ? Duration.zero : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(_grouped(v.round()), style: T.display(30, pal.ink, height: 1.1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _grouped(int v) {
    final s = '$v';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
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
                Text(
                  q.text,
                  style: T
                      .body(16.5, q.claimed ? pal.muted : pal.ink)
                      .copyWith(decoration: q.claimed ? TextDecoration.lineThrough : null),
                ),
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
                child: Text(
                  tr(
                    'Ambil +${App.I.game.questXp(q)}',
                    'Take +${App.I.game.questXp(q)}',
                    'Cobrar +${App.I.game.questXp(q)}',
                    'Prendre +${App.I.game.questXp(q)}',
                    '+${App.I.game.questXp(q)} nehmen',
                    'Pegar +${App.I.game.questXp(q)}',
                  ),
                  style: T.body(15.5, pal.onAccent, w: FontWeight.w700),
                ),
              ),
            )
          else
            SizedBox(
              width: 74,
              child: Text(
                q.claimed
                    ? tr('Diambil', 'Taken', 'Cobrado', 'Pris', 'Genommen', 'Pego')
                    : '+${App.I.game.questXp(q)} XP',
                textAlign: TextAlign.right,
                style: T.body(14.5, pal.muted),
              ),
            ),
        ],
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
