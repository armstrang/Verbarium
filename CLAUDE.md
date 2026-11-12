# Verbarium — project notes for Claude

English vocabulary for TOEFL/IELTS on Android, by **Armstrang** (Josh). Lingvist-like: a sentence with a gap, you
type the word. Progress is a ladder of seven feudal titles, one per CEFR level (Peasant A1, Squire A2, Knight B1, Baron B2, Count C1,
Duke C1+, King C2: English in every language) and, from Squire on, a job that the learner's build decides. Sister app of XueCi (`armstrang/XueCi`), but the look and
tone are deliberately different: paper and ink, heraldry, the voice of a chronicle. Josh writes in Indonesian:
**reply in Indonesian**. Not on Google Play yet.

**Standing rule (Josh):** change code, push or build only when he says "build sekarang" / "kerjakan sekarang",
and even then confirm first what will change and wait for his yes. Everything else is discussion.

## Layout

| Path | What |
|---|---|
| `mobile/assets/deck/` | the words, canonical. 6,912 words in all (5,894 core, about 500 per banner: 513 TOEFL, 505 IELTS); every file is checked by `check_deck.py`. Core `1-squire.txt` … `6-king.txt` (1 Squire A1–A2, 2 Knight B1, 3 Baron B2, 4 Count C1, 5 Duke C1+, 6 King C2, each word placed by its Oxford 3000/5000 CEFR level, else its BNC/COCA frequency; a rank may continue in `1-squire-b.txt`, …): `word|pos|meaning|sentence with ___[|=form]`. `collocations.txt`: `rank|phrase with [answer]|wrong,wrong,wrong|meaning|meaning in English`. Banner files `toefl.txt`, `ielts.txt`: rank in front. Two spellings: `american/british`; the banner decides which one is shown, both are accepted. A banner's own words come early among a rank's new words (one in two), and under TOEFL the build question comes more often. `en/<same file>`: `word|definition`, plain English, for learning through English. `es/`, `fr/`, `de/`, `pt/<same file>`: `word|meaning` in Spanish, French, German and Portuguese (collocations: `phrase with [answer]|meaning`), use ’ never ' |
| `mobile/assets/realm/` | the four kingdoms of other languages (Grauwacht Deutsch, Valdoro Español, Beaumarais Français, Alvamar Português; Aldmere is the English deck above): `1-peasant.txt` … `7-king.txt`, one line per word with every language in it, `pos|id|en|es|fr|de|pt|` then the sentence in each with the taught form in `[brackets]`; a field starting with `~` only glosses (not taught in that language). 1-peasant (A1) and 2-squire (A2) both lead to the Squire. Read by `Deck.loadRealm`; each kingdom keeps its own road in the store under `realms` (`Store.realm`), settings shared |
| `content/tools/` | `check_deck.py` (format, one gap, no word twice, a definition for every word — CI runs it), `dedupe_deck.py` (drops a word that a continuation file repeats), `place_defs.py` (definitions written anywhere as `word|definition` are filed under the deck file that holds the word), `make_music.py` (every sound: the music `m0`…`m6`, `battle`, and all effects — the kingdoms' arms `crest_en` … `crest_pt`, wrong, rise, levelup, fanfare, quill, seal, page, tap, hit, crit, hurt, victory, defeat and each line's `tap_*`, `hit_*`, `hitx_*` — rendered from the CC0 sample libraries VSCO 2 CE and VCSL, which are cloned outside the repo, see its header; numpy + scipy + ffmpeg → `res/raw/*.ogg`), `pair_spellings.py` (adds the British spelling where a known pattern gives one), `make_icons.py` (Pillow → `mipmap-*`), `make_crests.py` (the arms of the five kingdoms, drawn by code in `crests/`: beasts, relief, shield, crowns → `mobile/assets/crest/<code>/` shield, full, crown, scroll, moving parts `p_*.png` and `parts.json`; Pillow, numpy, scipy) |
| `mobile/lib/engine/engine.dart` | `Engine`: memory (stability in days, personal `ease`), plan, sitting of `Card`s, the three `Quiz` kinds and their weights, ranks, stages and sub-bosses, trials, placement, defence; `slip()` |
| `mobile/lib/engine/game.dart` | `Game`: experience and level, combo, figures, quests, feats, gear, enemies, advice, the build (`bp`) and the path of jobs. Never changes memory or rank |
| `mobile/lib/engine/lore.dart` | `LoreBook`: the lore of every title and job (quote, story, nature, background, drive) in both languages, from the document "Kitab Lore Verbarium"; shown only by `ui/lore.dart` (the introduction after a coronation, closed by its button, and the story page when the hero is tapped in Karakter) |
| `mobile/lib/engine/jobs.dart` | `Jobs`: the tree (45 on the map + 7 hidden; the Count's tier asks whether the build still leads with the line's own side), `natural()` decides a job from a `Build`, `hiddenFor()`, perks (`Perk`), looks (`Garb`) |
| `mobile/lib/app/lang.dart`, `l10n.dart` | `code` ('id', 'en', 'es', 'fr', 'de', 'pt') and `tr(id, en, es, fr, de, pt)`: every text is written in all six languages where it is used; data written only in English (gear, enemies, feats, job hints) gets the other four from `l10n.dart` through `tx(en)`. The learning language is universal (every kingdom); where it is the kingdom's own language, `via` (`set.via`, chosen once per kingdom on its banner, English by default) gives the language of meanings |
| `mobile/lib/data/` | `store.dart` (one JSON document, keys listed at the top — never rename), `deck.dart` (also `Kingdom`: the five kingdoms, their arms and the letters offered under the gap) |
| `mobile/lib/app/` | `app.dart` (`App`: settings, sound, `stamp`), `native.dart` (channel `verbarium/native`) |
| `mobile/lib/ui/` | `theme.dart` (`Pal`, `Look`, `T`, `Dur`), `widgets.dart` (paper, buttons, `Shield`, `Seal`), `root.dart` (app, opening ("Vocabulary Quest", English in every language), first run in four steps: language spoken, kingdom, banner or exam, where to start; tabs (`Shell.tab`), Today with the coin for Dukung Verbarium), `world.dart` (Negeri: the world map, the roll of titles with the Emperor (King in 3 kingdoms, an honour only), each kingdom's road, the ladder of titles; `KingdomName` on Today and over the desk, a long press for all five kingdoms), `crest.dart` (a kingdom's arms coming alive when it is entered, 2.5 s, a tap ends it), `banner.dart` (a kingdom's banner: exam to aim for, language of meanings), `run.dart` (learning, trials and fights: gap, build, choice, the arena), `pixel.dart` (sprites as letter grids, `HeroSprite`, `EnemySprite`), `hero.dart` (Karakter), `coronation.dart`, `realm.dart` (where the score ranges come from), `chronicle.dart`, `settings.dart` |
| `mobile/android/` | Kotlin `MainActivity.kt`: files folder, splash hand-over, MediaPlayer (ambience) + SoundPool (effects); `Donate.kt`: Google Play Billing for Dukung Verbarium (consumables `donasi_kecil`, `donasi_sedang`, `donasi_besar` that unlock nothing; the page shows only when Play has them, counted in `set.dn`) |
| `mobile/test/` | `deck_test`, `engine_test`, `contrast_test` (WCAG 4.5:1, both themes), `screens_test` (drives the app; pictures in `test/goldens/`, not committed: look at them) |
| `docs/riset-skor.md` | where each title's score range comes from |

Cloud sessions: Flutter comes from XueCi's `dev-flutter-sdk` release (public download; see XueCi's
`mobile/tool/cloud_sdk.sh`, the files can be fetched with curl from
`github.com/armstrang/XueCi/releases/download/dev-flutter-sdk/`). Then `. /opt/flutter-env.sh`, in `mobile/`:
`FLUTTER_ROOT=/opt/flutter dart pub get --offline`, `flutter analyze --no-pub`, `flutter test --no-pub --update-goldens`.
Only packages in that cache resolve offline, so **no third-party plugins**: native needs go through the method
channel. No Android SDK here: Kotlin is compiled by CI only. CI (`.github/workflows/flutter.yml`) pushes its
output to the branch `ci-out/main` and publishes `v0.5-alpha-N` when everything passes.

## Rules

- **Store keys never change** once testers have the app (schema 2: seven titles, `Store.migrate` lifts a version 1 file) (`v`, `set`, `mem`, `log`, `rank`, `ev`, `win`, `shaky`,
  `cool`, `placed`, `stage`, `subcool`, `ease`, `ret`, `er`, `game`). A format change = a migration and a test.
- Package **`com.armstrang.verbarium`**. `versionCode` = 4000 + run for every build. Signing key
  `keystore/verbarium.jks` is public: test APKs only, never Play. The Play upload key is `keystore/upload.jks.enc`
  (AES-256, decrypted only in CI with the secret `VERBARIUM_UPLOAD_PASSWORD`; Josh keeps the original `.jks` and
  password); CI then builds `Verbarium.aab` with `VERBARIUM_PLAY=1`. Play App Signing holds the real app key.
- **Deck**: everything self-written (no copied word lists or sentences). A sentence has exactly one `___` and the
  headword fits it in the form given. Run `check_deck.py` after edits.
- **Score ranges** only from the test owners' own CEFR alignments; update `docs/riset-skor.md`, `Engine.ranks`
  and `SourcesPage` together. A title is "kosakata setara …", never a promised score.
- **Six languages**: Indonesian, English, Spanish, French, German and Portuguese (`set.lang`: id, en, es, fr, de, pt).
  A new text goes in as `tr('…', '…', '…', '…', '…', '…')` (French with ’, never '); names of titles and jobs stay English in every language. A
  definition never uses the word it explains. `docs/privasi.md` and Pengaturan → Privasi say the same thing.
- **Jobs** are decided by the build at a coronation (`Game.onPromotion`); there is no way to pick or change one,
  and a perk may never touch memory, rank or a coronation trial.
- **App text** sounds human, short, "kamu"; the chronicle voice ("Tercatat …", "Engkau dinobatkan …") only in
  ceremonies and the chronicle.
- **Backups** (Pengaturan → Cadangan): the whole store as one JSON file (`Store.backupText`, `{verbarium: 1, saved,
  store}`) written and read through Android's own file picker (`backupSave`, `backupOpen` on the channel), checked by
  `Store.fromBackup` (refuses anything else and newer schemas, lifts older ones) and put in place by `App.restore`
  after a yes. Android's Auto Backup is limited to `files/store/` (`res/xml/backup_rules.xml`,
  `data_extraction_rules.xml`). One streak is kept across all kingdoms (`Store.allLogs`).
- **Internet only for donations.** Our manifest asks for no network permission; Google Play Billing adds INTERNET,
  used only while the Dukung Verbarium page is open (shown only when installed from the Play Store). No other
  network code, ads, analytics or trackers: `privacy_test` guards it. Sounds are rendered from CC0 samples (VSCO 2 CE, VCSL by Versilian
  Studios); fonts are OFL (About → Lisensi huruf shows them).

## Look and motion

- Paper (`Pal.day`) and candlelight (`Pal.night`); the accent is the tincture of the title held
  (tanah, vert, gules, azure, murrey, purpure, sable). Colour is never the only sign: each shield has its own charge.
  `contrast_test` must stay green.
- The learning screen stays plain: one sentence with the gap you type into. Ornament and pixel art live in Negeri, Karakter, the fights and the coronation.
- Pixel art is built from shapes in `pixel.dart` (no image files): figures 40×43 (body 32 wide, room for a swing),
  beasts 32×32, each material shaded from the upper left and outlined in its own dark tone. Look at
  `test/goldens/60-sprite.png` after changing it. The hero wears the livery of the kingdom being played
  (`liveries`, `App.livery`: tabard, sash, cape, plume and trim), the job keeps the coat.
- The one exception to "no image files": the kingdoms' arms (`assets/crest/`), drawn by code too, in
  `content/tools/make_crests.py` (Josh's decision, 13 Nov 2026: cast metal would not survive a redraw in Flutter).
  They are written at half size and shown with `FilterQuality.none`, so they read as large pixels. Change the
  drawing there and run it again; never edit the PNGs by hand.
- Music follows the lore: the title decides the music, the character decides the effects. One theme belongs to the
  Chronicler (`THEME` in `make_music.py`) and is played differently for each title: the Peasant's recorder never
  comes home, the Knight's horn is answered by minor cellos over a pedal, the Baron's harpsichords chase each other,
  the Duke's theme hangs at half speed, the King's comes home for the first time and returns to the village. Each
  piece is followed by its place alone (wind, town, hall, night). Taps and blows sound like the character's line
  (`App.sfx`). Every melody stays Verbarium's own: a mood may be an inspiration, a melody may not be copied.
- Motion: transform/opacity, leaving faster than arriving (`Dur`), everything honours calm motion (`Look.calm`).
- Screens draw from `Look.of(context)`; `Look.stamp` changes on every `App.notifyListeners()`, which is what
  redraws them.
