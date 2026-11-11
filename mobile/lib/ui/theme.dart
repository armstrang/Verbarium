/// The look: paper and ink, one heraldic tincture per rank, two typefaces (IM Fell English for the voice of the
/// chronicle, Alegreya Sans for everything you read fast). All colours come from [Pal]; `contrast_test` measures
/// every pair that carries text.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/lang.dart';

class Pal {
  final bool dark;
  final Color bg, deep, field, line, ink, muted, onAccent, gold, good, bad;
  final List<Color> tinctures;
  const Pal({
    required this.dark,
    required this.bg,
    required this.deep,
    required this.field,
    required this.line,
    required this.ink,
    required this.muted,
    required this.onAccent,
    required this.gold,
    required this.good,
    required this.bad,
    required this.tinctures,
  });

  /// writing paper by day
  static const day = Pal(
    dark: false,
    bg: Color(0xFFF5F2EA),
    deep: Color(0xFFEAE6DA),
    field: Color(0xFFFCFBF7),
    line: Color(0xFFCFC9BA),
    ink: Color(0xFF1C1B19),
    muted: Color(0xFF5C574D),
    onAccent: Color(0xFFFCFBF7),
    gold: Color(0xFF9A7B2C),
    good: Color(0xFF2F5D3A),
    bad: Color(0xFF8E1B16),
    // tanah, vert, gules, azure, purpure, sable
    tinctures: [
      Color(0xFF6B4F3A),
      Color(0xFF2F5D3A),
      Color(0xFF8E1B16),
      Color(0xFF1F3F73),
      Color(0xFF5A2A6B),
      Color(0xFF1C1B19),
    ],
  );

  /// the same page by candlelight
  static const night = Pal(
    dark: true,
    bg: Color(0xFF1B1A17),
    deep: Color(0xFF24221E),
    field: Color(0xFF2A2823),
    line: Color(0xFF4A463D),
    ink: Color(0xFFEDE6D6),
    muted: Color(0xFFB5AD9C),
    onAccent: Color(0xFF1B1A17),
    gold: Color(0xFFD9B861),
    good: Color(0xFF8FBF96),
    bad: Color(0xFFE39A91),
    tinctures: [
      Color(0xFFC9A27E),
      Color(0xFF8FBF96),
      Color(0xFFE39A91),
      Color(0xFF9DB9EA),
      Color(0xFFCDA6DE),
      Color(0xFFD9B861),
    ],
  );

  Color tincture(int rank) => tinctures[rank.clamp(0, tinctures.length - 1)];
}

/// what a widget needs to draw itself: the palette, the accent of the rank held, whether motion is calmed
class Look extends InheritedWidget {
  final Pal pal;
  final int rank;
  final bool calm;
  final int stamp;
  const Look({
    super.key,
    required this.pal,
    required this.rank,
    required this.calm,
    this.stamp = 0,
    required super.child,
  });

  Color get accent => pal.tincture(rank);

  static Look of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Look>()!;

  @override
  bool updateShouldNotify(Look old) => old.pal != pal || old.rank != rank || old.calm != calm || old.stamp != stamp;
}

/// reads the phone's theme and the app's settings, and hands a [Look] down
class LookHost extends StatelessWidget {
  final Widget child;
  final int? rank;
  const LookHost({super.key, required this.child, this.rank});

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    final sys = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = app.theme == 'dark' || (app.theme == 'system' && sys);
    final calm = app.calm || MediaQuery.disableAnimationsOf(context);
    return Look(
      pal: dark ? Pal.night : Pal.day,
      rank: rank ?? app.engine.rank,
      calm: calm,
      stamp: app.stamp,
      child: child,
    );
  }
}

class T {
  static const fell = 'Fell';
  static const sans = 'Alegreya';

  static TextStyle display(double size, Color c, {bool italic = false, double height = 1.15}) => TextStyle(
    fontFamily: fell,
    fontSize: size,
    height: height,
    color: c,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  static TextStyle body(double size, Color c, {FontWeight w = FontWeight.w400, double height = 1.35}) =>
      TextStyle(fontFamily: sans, fontSize: size, height: height, color: c, fontWeight: w);

  static TextStyle label(Color c) => TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    height: 1.2,
    letterSpacing: 1.6,
    color: c,
    fontWeight: FontWeight.w500,
  );
}

/// shared timings: leaving is quicker than arriving
class Dur {
  static const tap = Duration(milliseconds: 110);
  static const out = Duration(milliseconds: 140);
  static const enter = Duration(milliseconds: 260);
  static const write = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 520);
}

/// the titles are English in every language
const rankNames = ['Peasant', 'Squire', 'Knight', 'Baron', 'Duke', 'King'];

/// how the app speaks to each title: plain to a farmer, with ceremony to a king
String rankGreeting(int rank) => [
  tr(
    'Ladang sudah digarap. Sekarang giliran kata.',
    'The field is tilled. Now it is the words\' turn.',
    'El campo está arado. Ahora les toca a las palabras.',
    'Le champ est labouré. Place aux mots.',
  ),
  tr(
    'Senjata latihanmu sudah diasah.',
    'Your practice arms are sharpened.',
    'Tus armas de práctica están afiladas.',
    'Tes armes d’entraînement sont affûtées.',
  ),
  tr(
    'Kudamu sudah dipelanai, Kesatria.',
    'Your horse is saddled, Sir Knight.',
    'Tu caballo está ensillado, Sir Knight.',
    'Ton cheval est sellé, Sir Knight.',
  ),
  tr(
    'Aula menantimu, Tuan Baron.',
    'The hall awaits you, my lord Baron.',
    'La sala te espera, mi señor Baron.',
    'La salle t’attend, mon seigneur Baron.',
  ),
  tr(
    'Istana sudah siap, Yang Mulia.',
    'The palace is ready, Your Grace.',
    'El palacio está listo, Vuestra Gracia.',
    'Le palais est prêt, Votre Grâce.',
  ),
  tr(
    'Takhta menunggu titahmu, Baginda.',
    'The throne awaits your word, Your Majesty.',
    'El trono espera tu palabra, Majestad.',
    'Le trône attend ta parole, Majesté.',
  ),
][rank.clamp(0, 5)];
