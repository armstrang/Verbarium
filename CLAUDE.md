# Verbarium — project notes for Claude

English vocabulary for TOEFL/IELTS on Android, by **Armstrang** (Josh). Lingvist-like: a sentence with a gap, you
type the word. Progress is a ladder of feudal titles (Peasant, Squire, Knight, Baron, Duke, King: English in every
language) and, from Squire on, a job that the learner's build decides. Sister app of XueCi (`armstrang/XueCi`), but the look and
tone are deliberately different: paper and ink, heraldry, the voice of a chronicle. Josh writes in Indonesian:
**reply in Indonesian**. Not on Google Play yet.

**Standing rule (Josh):** change code, push or build only when he says "build sekarang" / "kerjakan sekarang",
and even then confirm first what will change and wait for his yes. Everything else is discussion.

## Layout

| Path | What |
|---|---|
| `mobile/assets/deck/` | the words, canonical. 6,133 words in all (5,894 core, about 120 per banner); every file is checked by `check_deck.py`. Core `1-squire.txt` … `5-raja.txt` (a rank may continue in `1-squire-b.txt`, …): `word|pos|meaning|sentence with ___[|=form]`. `collocations.txt`: `rank|phrase with [answer]|wrong,wrong,wrong|meaning|meaning in English`. Banner files `toefl.txt`, `ielts.txt`: rank in front. Two spellings: `american/british`. `en/<same file>`: `word|definition`, plain English, for learning through English |
| `content/tools/` | `check_deck.py` (format, one gap, no word twice, a definition for every word — CI runs it), `dedupe_deck.py` (drops a word that a continuation file repeats), `place_defs.py` (definitions written anywhere as `word|definition` are filed under the deck file that holds the word), `make_audio.py` (numpy + scipy + ffmpeg → `res/raw/*.ogg`), `make_icons.py` (Pillow → `mipmap-*`) |
| `mobile/lib/engine/engine.dart` | `Engine`: memory (stability in days, personal `ease`), plan, sitting of `Card`s, the three `Quiz` kinds and their weights, ranks, stages and sub-bosses, trials, placement, defence; `slip()` |
| `mobile/lib/engine/game.dart` | `Game`: experience and level, combo, figures, quests, feats, gear, enemies, advice, the build (`bp`) and the path of jobs. Never changes memory or rank |
| `mobile/lib/engine/jobs.dart` | `Jobs`: the tree (37 on the map + 6 hidden), `natural()` decides a job from a `Build`, `hiddenFor()`, perks (`Perk`), looks (`Garb`) |
| `mobile/lib/app/lang.dart` | `english` and `tr(id, en)`: every text is written in both languages where it is used |
| `mobile/lib/data/` | `store.dart` (one JSON document, keys listed at the top — never rename), `deck.dart` |
| `mobile/lib/app/` | `app.dart` (`App`: settings, sound, `stamp`), `native.dart` (channel `verbarium/native`) |
| `mobile/lib/ui/` | `theme.dart` (`Pal`, `Look`, `T`, `Dur`), `widgets.dart` (paper, buttons, `Shield`, `Seal`), `root.dart` (app, opening, first run, tabs, Today), `run.dart` (learning, trials and fights: gap, build, choice, the arena), `pixel.dart` (sprites as letter grids, `HeroSprite`, `EnemySprite`), `hero.dart` (Karakter), `coronation.dart`, `realm.dart`, `chronicle.dart`, `settings.dart` |
| `mobile/android/` | Kotlin `MainActivity.kt`: files folder, splash hand-over, MediaPlayer (ambience) + SoundPool (effects) |
| `mobile/test/` | `deck_test`, `engine_test`, `contrast_test` (WCAG 4.5:1, both themes), `screens_test` (drives the app; pictures in `test/goldens/`, not committed: look at them) |
| `docs/riset-skor.md` | where each title's score range comes from |

Cloud sessions: Flutter comes from XueCi's `dev-flutter-sdk` release (public download; see XueCi's
`mobile/tool/cloud_sdk.sh`, the files can be fetched with curl from
`github.com/armstrang/XueCi/releases/download/dev-flutter-sdk/`). Then `. /opt/flutter-env.sh`, in `mobile/`:
`FLUTTER_ROOT=/opt/flutter dart pub get --offline`, `flutter analyze --no-pub`, `flutter test --no-pub --update-goldens`.
Only packages in that cache resolve offline, so **no third-party plugins**: native needs go through the method
channel. No Android SDK here: Kotlin is compiled by CI only. CI (`.github/workflows/flutter.yml`) pushes its
output to the branch `ci-out/main` and publishes `v0.3-alpha-N` when everything passes.

## Rules

- **Store keys never change** once testers have the app (`v`, `set`, `mem`, `log`, `rank`, `ev`, `win`, `shaky`,
  `cool`, `placed`, `stage`, `subcool`, `ease`, `ret`, `er`, `game`). A format change = a migration and a test.
- Package **`com.armstrang.verbarium`**. `versionCode` = 3000 + run for test builds. Signing key
  `keystore/verbarium.jks` is public: test builds only, never Play.
- **Deck**: everything self-written (no copied word lists or sentences). A sentence has exactly one `___` and the
  headword fits it in the form given. Run `check_deck.py` after edits.
- **Score ranges** only from the test owners' own CEFR alignments; update `docs/riset-skor.md`, `Engine.ranks`
  and `SourcesPage` together. A title is "kosakata setara …", never a promised score.
- **Two languages**: Indonesian and English (`set.lang`). A new text goes in as `tr('…', '…')`; names of titles and
  jobs stay English. A definition never uses the word it explains.
- **Jobs** are decided by the build at a coronation (`Game.onPromotion`); there is no way to pick or change one,
  and a perk may never touch memory, rank or a coronation trial.
- **App text** sounds human, short, "kamu"; the chronicle voice ("Tercatat …", "Engkau dinobatkan …") only in
  ceremonies and the chronicle.
- No network permission. Sounds are synthesised, fonts are OFL (About → Lisensi huruf shows them).

## Look and motion

- Paper (`Pal.day`) and candlelight (`Pal.night`); the accent is the tincture of the title held
  (tanah, vert, gules, azure, purpure, sable). Colour is never the only sign: each shield has its own charge.
  `contrast_test` must stay green.
- The learning screen stays plain: one sentence with the gap you type into. Ornament and pixel art live in Negeri, Karakter, the fights and the coronation.
- Pixel art is letters in `pixel.dart` (no image files); look at `test/goldens/60-sprite.png` after changing it.
- Music: one theme (`THEME` in `make_audio.py`), arranged per title as `m0`…`m5.ogg` plus `battle.ogg`. It must stay Verbarium's own tune: a mood may be an inspiration, a melody may not be copied.
- Motion: transform/opacity, leaving faster than arriving (`Dur`), everything honours calm motion (`Look.calm`).
- Screens draw from `Look.of(context)`; `Look.stamp` changes on every `App.notifyListeners()`, which is what
  redraws them.
