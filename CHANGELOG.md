# Changelog

## v0.5 (alpha, not released)

### v0.5-alpha-4: the arms of the kingdoms, backups, one streak

- **The arms of the five kingdoms.** Going to another kingdom shows its arms coming alive for 2.5 seconds: the
  dragon of Valdoro breathes fire, the lion of Aldmere roars, the griffin of Grauwacht beats its wings and cries,
  the phoenix of Beaumarais flares, the eastern dragon of Alvamar sways after its pearl. Then the kingdom's own
  crown comes down and its motto unrolls. Every beast, crown and sound is Verbarium's own. A tap ends it; with calm
  motion the arms only fade in.
- **Where you are:** the kingdom and its language are named on Today and over the learning screen. Tap the name for
  Negeri, press it long to choose any of the five kingdoms at once.
- **One streak** for the whole realm: a day of learning in any kingdom keeps it going.
- **The roll of titles** in Negeri shows the title held in each kingdom; King in three of them makes you Emperor,
  an honour that changes nothing else.
- **Each kingdom's livery:** your character wears the colours of the kingdom you play (azure and gold, slate and
  silver, crimson and gold, purple and pale gold, sea green and bronze).
- **Backups.** Pengaturan → Cadangan saves everything (every kingdom, the chronicle, the settings) to a file you
  choose, and restores it on a new phone after showing what it holds. Android's own backup now keeps only the
  progress file. Verbarium still sends nothing anywhere; the privacy page says how.
- **A coin beside the settings** opens Dukung Verbarium in the Play Store version; elsewhere it explains where
  donations can be made.
- The opening now reads **Vocabulary Quest**.

### v0.5-alpha-3: a first run for five kingdoms

- **The first run asks what it should:** the language the app speaks (the phone's language is marked), then the
  language you want to learn, as one of the five kingdoms, then the banner (Aldmere), an exam to aim for (the
  other kingdoms) or, when you learn a language through itself, the language of meanings. Last: start as a
  Peasant or take the placement test, now in every kingdom.
- Steps can be gone back through; nothing changes for learners who already started.

### v0.5-alpha-1: five kingdoms, seven titles, six languages

- **Seven titles, one for each CEFR level:** Peasant A1, Squire A2, Knight B1, Baron B2, Count C1, Duke C1+ and
  King C2. The Count is new, between Baron and Duke, with its own jobs, boss and music. Saves from 0.4 are lifted
  to the new ladder: titles, jobs and the chronicle are kept.
- **Five kingdoms.** Beside Aldmere (English) there are Grauwacht (German), Valdoro (Spanish), Beaumarais (French)
  and Alvamar (Portuguese), each with its own road from Peasant to King, its own character and chronicle.
- **The world map.** Negeri is now a living map: tap a kingdom, fly down through the clouds to its road of seven
  places, each place a title. The ladder of titles has its own page.
- **A kingdom's banner** can be tapped from the start and names an exam to aim for: Goethe-Zertifikat, DELE or
  SIELE, DELF or DALF, CAPLE or Celpe-Bras. A suggestion only, never a score.
- **German and Portuguese** as learning languages, beside Indonesian, English, Spanish and French: every screen,
  the lore, and the meaning of all 6,912 words and 84 collocations. The learning language is the same in every
  kingdom; a kingdom learned in its own language (Spanish in Valdoro) asks once which language explains it.
- **Fights by night.** A coronation boss is fought in the dark among embers: its name struck in, its rage marked on
  its life bar, a box for each of the words and a ring for the time. Every blow flashes and shakes.
- **Candlelight coronation:** rays turning, the crown coming down onto the shield, the job sealed on its card, the
  title's own words, then Terima gelar.
- **New layouts** for Hari ini, Karakter, Kronik and Pengaturan; scarier, bigger bosses and foes.
- Calm motion is still honoured everywhere, and the learning screen stays plain.

## v0.4 (alpha, not released)

### v0.4-alpha-4: ready for Google Play

- **Internet only for donations.** Dukung Verbarium appears only when the app was installed from the Play Store
  (read on the phone, no network). Google Play is contacted only while that page is open, and the connection is
  closed when it is left. A new test fails the build if any other code tries to use the network.
- **Privacy** (in the app and `docs/privasi.md`) explains the internet permission in all four languages.
- **The phone's language first.** A new learner starts in Indonesian, English, Spanish or French as the phone
  is set; any other language starts in English. It can still be changed.
- **AAB for Google Play**, signed with a private upload key, built by CI next to the test APK.

### v0.4-alpha-3: four languages

- **Spanish and French.** Learn through Español or Français as well as Indonesian and English: every screen, the
  lore, and the meaning of all 6,912 words and 84 collocations. Titles and jobs keep their English names.
- **Longer lore.** Every job's story is now told in two or three sentences, in all four languages.
- **New sounds.** The last synthesised effects (right answer, page, seal, tap, blow, critical, hurt, victory,
  defeat) are now played on the same CC0 instruments as the music; `make_audio.py` is gone.
- **Ready for the Play Store:** Settings → Software licences (Flutter's notices, the fonts, the CC0 samples) and
  Settings → Privacy (`docs/privasi.md`): nothing leaves the phone.
- **Dukung Verbarium** (dormant): voluntary support through Google Play Billing that unlocks nothing. The page
  appears only when the products exist on Google Play, so never in the test APK.
- Deck: a comma in one sentence; automatic checks for a/an, doubled words, missing verb forms and spacing pass.

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
