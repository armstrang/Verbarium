/// The language the learner learns through. Indonesian is the first one; in English everything is said in
/// English and a word is explained by a plain English definition (the monolingual way). Names of titles and jobs
/// are English in every language.
library;

/// set by the app from the store (`set.lang`); plain so that the engine and the deck can read it without Flutter
bool english = false;

/// one sentence in both languages; the app shows the one that is on
String tr(String id, String en) => english ? en : id;
