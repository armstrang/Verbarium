# Changelog

## v0.3 (alpha, not released)

Jobs, a second learning language, and a deck of more than 6,000 words.

- **Jobs.** From Squire on, the character has a job, and nobody picks it: every answer adds to one of four sides
  of the build (Precision, Swiftness, Insight, Endurance), and at each coronation the build decides the branch.
  37 jobs are on the map (4 for a Squire, 8 for a Knight, 12 for a Baron, 8 for a Duke, 4 for a King) and 6 more
  are hidden. A job cannot be chosen or changed.
- Each job has a perk, and the perks of the whole path add up. Perks touch experience and the fights against the
  guards of the road; a coronation trial is the same for everyone.
- Karakter shows the job, the path and its perks, where the build leans, and the branches ahead as shadows with a
  hint. The map of jobs shows what has been held in colour and the rest as shadows. Each job has its own look:
  headgear, what is carried, the colour of the tunic.
- **Learning language** (Settings, and on the first screen): Indonesian or English. In English the whole app
  speaks English and a word is explained by a plain English definition; when choosing a meaning, words that look
  alike (adapt, adopt) come first among the wrong ones.
- Titles are English in both languages: Peasant, Squire, Knight, Baron, Duke, King.
- The banner (TOEFL, IELTS) can be changed in Settings without losing the title, the job or what is remembered.
- The deck grows past 6,000 words, each with an English definition.

## v0.2 (alpha, not released)

Verbarium becomes a game around the same learning.

- You type straight into the gap of the sentence; the separate box is gone, and the keyboard no longer covers
  the page.
- Three kinds of question, chosen for each word: the gap (worth most, the only one that makes a word *kukuh*,
  now also asking for the right form of a word), building the sentence from chips with two decoys, and choosing
  the meaning or the partner word (collocation).
- The schedule tunes itself to you; slips are sorted into spelling, form, meaning, order and collocation, and
  the weakest side shapes the advice of the day and the questions you get.
- Level and experience, combo and fast answers, four figures of the character, three daily quests made from
  your own data, two weekly ones, feats and honorary titles.
- Each title has three stages. A sub-boss guards each stage and a boss guards the title: fights in an arena,
  one blow per right answer, with loot (weapons, shields, cloaks) worn by the pixel hero.
- A pixel-art hero and enemies, drawn in code: walking on the map, fighting, cheering.
- One original theme arranged for each title, a battle tune, and jingles; all synthesised.
- The page dresses with the title: a ruled margin from Knight, doubled for a Duke, gold for a King.

## v0.1 (alpha, not released)

First test builds of Verbarium.

- Learn by typing the missing word in a sentence, with the Indonesian meaning as the cue. One slip in spelling
  gets a second try; a missed word comes back four cards later.
- Spaced repetition on the device. A word is *kukuh* once it has been remembered for more than a week.
- Six titles (Petani, Squire, Knight, Baron, Duke, Raja), each with its own shield and colour. Only trials
  change a title: placement at the start, a timed coronation trial without help, and a defence when a title wavers.
- Score ranges per title for IELTS and TOEFL iBT (new 1–6 scale and the old one), from the test owners' CEFR
  alignments (`docs/riset-skor.md`).
- 1,018 core words in five ranks plus 43 TOEFL and 44 IELTS words; every sentence and meaning written for Verbarium.
- Paper look by day, candlelight by night; calm-motion setting.
- Court ambience and effects, all synthesised (`content/tools/make_audio.py`).
- Fully offline; no network permission.
