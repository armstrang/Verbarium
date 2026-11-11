/// The language the learner learns through: Indonesian (the first one), English, Spanish or French. In English a
/// word is explained by a plain English definition (the monolingual way); in Spanish and French by its meaning in
/// that language. Names of titles and jobs are English in every language.
library;

import 'l10n.dart';

/// set by the app from the store (`set.lang`): 'id', 'en', 'es' or 'fr'; plain so that the engine and the deck can
/// read it without Flutter
String code = 'id';

bool get english => code == 'en';
set english(bool v) => code = v ? 'en' : 'id';

/// index of the language among the ones that are not written inline as `id`/`en`: 0 Spanish, 1 French, -1 neither
int get foreign => switch (code) { 'es' => 0, 'fr' => 1, _ => -1 };

/// one sentence in every language; the app shows the one that is on. Spanish and French may be left out where the
/// English is a piece of data (a gear or feat name): then they come from [l10n], keyed by the English
String tr(String id, String en, [String? es, String? fr]) => switch (code) {
      'id' => id,
      'es' => es ?? tx(en),
      'fr' => fr ?? tx(en),
      _ => en,
    };

/// a piece of English data in the language that is on (Indonesian has its own text where the data is written)
String tx(String en) {
  final i = foreign;
  if (i < 0) return en;
  return l10n[en]?[i] ?? en;
}
