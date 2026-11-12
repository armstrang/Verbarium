/// The language the learner learns through: Indonesian (the first one), English, Spanish, French, German or
/// Portuguese. It is universal: the app speaks it in every kingdom. In English a word of Aldmere is explained by a
/// plain English definition (the monolingual way); in the others by its meaning in that language. Names of titles
/// and jobs are English in every language.
library;

import 'l10n.dart';

/// set by the app from the store (`set.lang`): 'id', 'en', 'es', 'fr', 'de' or 'pt'; plain so that the engine and
/// the deck can read it without Flutter
String code = 'id';

/// the language meanings and translations are shown in, when it may not be [code]: in a kingdom whose language is
/// the learning language itself (Spanish learned in Spanish), the learner picks another one once (English unless
/// chosen). Empty: the same as [code]
String via = '';

/// the language a word's meaning and its sentence's translation are shown in
String get meaning => via.isNotEmpty ? via : code;

/// index of a language among the four kept beside Indonesian and English: 0 Spanish, 1 French, 2 German,
/// 3 Portuguese, -1 neither
int fourOf(String c) => switch (c) {
  'es' => 0,
  'fr' => 1,
  'de' => 2,
  'pt' => 3,
  _ => -1,
};

bool get english => code == 'en';
set english(bool v) => code = v ? 'en' : 'id';

/// index of the language among the ones that are not written inline as `id`/`en`: 0 Spanish, 1 French, -1 neither
int get foreign => fourOf(code);

/// one sentence in every language; the app shows the one that is on. Spanish and French may be left out where the
/// English is a piece of data (a gear or feat name): then they come from [l10n], keyed by the English
String tr(String id, String en, [String? es, String? fr, String? de, String? pt]) => switch (code) {
  'id' => id,
  'es' => es ?? tx(en),
  'fr' => fr ?? tx(en),
  'de' => de ?? tx(en),
  'pt' => pt ?? tx(en),
  _ => en,
};

/// a piece of English data in the language that is on (Indonesian has its own text where the data is written)
String tx(String en) {
  final i = foreign;
  if (i < 0) return en;
  final t = l10n[en];
  return t != null && i < t.length ? t[i] : en;
}
