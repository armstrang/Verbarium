# Verbarium — project notes for Claude

English vocabulary for TOEFL/IELTS on Android, by **Armstrang** (Josh). Lingvist-like: a sentence with a gap, you
type the word. Progress is a ladder of feudal titles. Sister app of XueCi (`armstrang/XueCi`), but the look and
tone are deliberately different: paper and ink, heraldry, the voice of a chronicle. Josh writes in Indonesian:
**reply in Indonesian**. Not on Google Play yet.

**Standing rule (Josh):** change code, push or build only when he says "build sekarang" / "kerjakan sekarang",
and even then confirm first what will change and wait for his yes. Everything else is discussion.

## Layout

| Path | What |
|---|---|
| `mobile/assets/deck/` | the words, canonical. Core `1-squire.txt` … `5-raja.txt`: `word|pos|meaning|sentence with ___`. Banner files `toefl.txt`, `ielts.txt`: rank in front. Two spellings: `american/british` |
| `content/tools/` | `check_deck.py` (format, one gap, no word twice — CI runs it), `make_audio.py` (numpy + scipy + ffmpeg → `res/raw/*.ogg`), `make_icons.py` (Pillow → `mipmap-*`) |
| `mobile/lib/engine/engine.dart` | `Engine`: memory (stability in days), plan, sitting, ranks, trials, placement, defence; `slip()` |
| `mobile/lib/data/` | `store.dart` (one JSON document, keys listed at the top — never rename), `deck.dart` |
| `mobile/lib/app/` | `app.dart` (`App`: settings, sound, `stamp`), `native.dart` (channel `verbarium/native`) |
| `mobile/lib/ui/` | `theme.dart` (`Pal`, `Look`, `T`, `Dur`), `widgets.dart` (paper, buttons, `Shield`, `Seal`), `root.dart` (app, opening, first run, tabs, Today), `run.dart` (learning and every trial), `coronation.dart`, `realm.dart`, `chronicle.dart`, `settings.dart` |
| `mobile/android/` | Kotlin `MainActivity.kt`: files folder, splash hand-over, MediaPlayer (ambience) + SoundPool (effects) |
| `mobile/test/` | `deck_test`, `engine_test`, `contrast_test` (WCAG 4.5:1, both themes), `screens_test` (drives the app; pictures in `test/goldens/`, not committed: look at them) |
| `docs/riset-skor.md` | where each title's score range comes from |

Cloud sessions: Flutter comes from XueCi's `dev-flutter-sdk` release (public download; see XueCi's
`mobile/tool/cloud_sdk.sh`, the files can be fetched with curl from
`github.com/armstrang/XueCi/releases/download/dev-flutter-sdk/`). Then `. /opt/flutter-env.sh`, in `mobile/`:
`FLUTTER_ROOT=/opt/flutter dart pub get --offline`, `flutter analyze --no-pub`, `flutter test --no-pub --update-goldens`.
Only packages in that cache resolve offline, so **no third-party plugins**: native needs go through the method
channel. No Android SDK here: Kotlin is compiled by CI only. CI (`.github/workflows/flutter.yml`) pushes its
output to the branch `ci-out/main` and publishes `v0.1-alpha-N` when everything passes.

## Rules

- **Store keys never change** once testers have the app (`v`, `set`, `mem`, `log`, `rank`, `ev`, `win`, `shaky`,
  `cool`, `placed`). A format change = a migration and a test.
- Package **`com.armstrang.verbarium`**. `versionCode` = 1000 + run for test builds. Signing key
  `keystore/verbarium.jks` is public: test builds only, never Play.
- **Deck**: everything self-written (no copied word lists or sentences). A sentence has exactly one `___` and the
  headword fits it in the form given. Run `check_deck.py` after edits.
- **Score ranges** only from the test owners' own CEFR alignments; update `docs/riset-skor.md`, `Engine.ranks`
  and `SourcesPage` together. A title is "kosakata setara …", never a promised score.
- **App text** sounds human, short, "kamu"; the chronicle voice ("Tercatat …", "Engkau dinobatkan …") only in
  ceremonies and the chronicle.
- No network permission. Sounds are synthesised, fonts are OFL (About → Lisensi huruf shows them).

## Look and motion

- Paper (`Pal.day`) and candlelight (`Pal.night`); the accent is the tincture of the title held
  (tanah, vert, gules, azure, purpure, sable). Colour is never the only sign: each shield has its own charge.
  `contrast_test` must stay green.
- The learning screen stays plain: one sentence, one field. Ornament lives in Negeri, Kronik and the coronation.
- Motion: transform/opacity, leaving faster than arriving (`Dur`), everything honours calm motion (`Look.calm`).
- Screens draw from `Look.of(context)`; `Look.stamp` changes on every `App.notifyListeners()`, which is what
  redraws them.
