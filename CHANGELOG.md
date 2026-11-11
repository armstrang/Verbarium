# Changelog

## v0.4 (alpha, not released)

### v0.4-alpha-2: the lore

- **Lore.** Verbarium has a world now: everything lasts as long as its name is remembered, the Fog of Forgetting
  fades the rest, and the Great Chronicle records every word held. Every title and every job has its quote, story,
  nature, background and drive, in both languages.
- **A new character is introduced** after each coronation, on its own page that only its button closes.
- **Tap the hero** in Karakter to read their story and the realm of the title held.
- **Music from the lore**, played on recorded instruments (CC0 samples): one theme belongs to the Chronicler and is
  played differently for each title, from the Peasant's lone recorder that never comes home to the King's, which
  comes home for the first time. Each piece is followed by the sound of its place (wind, town, hall, night).
- **Characters sound like themselves:** taps and blows follow the line (Peasant wood, Blade steel, Scout string and
  wind, Scribe ink and bells, Sentinel wood and stone), richer from tier 3.

### v0.4-alpha-1

A new look for every figure, a piece of music for every title, and banners that matter.

- **Figures.** The hero, all 43 jobs and the enemies are drawn anew: taller and more heroic (40×43), with eyes
  and brows, three tones of light on every material and an outline in each part's own dark colour. From tier 2 a
  fighter wears plate; capes blow behind. The hero walks, winds up and strikes with a swing, flinches when hit and
  cheers. Enemies (wolf, boar, bandit, knight, skeleton, mage, gargoyle, dragon) are drawn in the same style.
  The arena is a little larger.
- **Music.** Each title has its own original piece, fuller as the titles rise: Hutan Pagi (Peasant, harp and
  flute), Perjalanan (Squire, 6/8 with a frame drum), Benteng (Knight, a slow march with horn and timpani),
  Kenangan Lampau (Baron, piano), Malam Bintang (Duke, celesta and crickets), Takhta (King, strings, horn and a soft
  choir). A new battle piece, and new sounds for a wrong answer, a trial passed, a level and a coronation.
- **Banners.** TOEFL and IELTS now have about 500 words of their own each (TOEFL: lectures in the sciences, history
  and the arts, and campus life; IELTS: describing graphs and trends, and the topics of essays and of everyday
  British life), every one with a sentence and an English definition. A banner's words come early among a rank's
  new words. Under TOEFL the build question, close to its build-a-sentence task, comes more often.
- More words carry both spellings (organize/organise), shown by the banner and both accepted.
- The TOEFL score ranges were checked again against ETS's table for the 1–6 scale.

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
