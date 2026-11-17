/// Hikayat: one short tale of Aldmere for each title, read once the title is held (assets/hikayat/en.txt). Words of
/// the deck that the learner has met are underlined; a tap shows the meaning and says the word.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/lang.dart';
import '../data/deck.dart';
import 'theme.dart';
import 'widgets.dart';

class Tale {
  final int rank;
  final String title;
  final List<String> paragraphs;
  const Tale(this.rank, this.title, this.paragraphs);

  /// "== rank|Title" opens a tale, the lines after it are paragraphs; '#' lines are notes
  static List<Tale> parse(String text) {
    final out = <Tale>[];
    int? rank;
    String title = '';
    var paras = <String>[];
    void close() {
      if (rank != null) out.add(Tale(rank, title, paras));
    }

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('==')) {
        close();
        final parts = line.substring(2).trim().split('|');
        rank = int.tryParse(parts[0].trim()) ?? 0;
        title = parts.length > 1 ? parts[1].trim() : '';
        paras = <String>[];
      } else {
        paras.add(line);
      }
    }
    close();
    return out;
  }
}

/// the deck's words by every form they take, for finding them in a tale
Map<String, Word> wordForms(Deck deck) => {
  for (final w in deck.words)
    for (final f in [...w.forms, ...w.wanted]) f.toLowerCase(): w,
};

class HikayatPage extends StatefulWidget {
  const HikayatPage({super.key});

  @override
  State<HikayatPage> createState() => _HikayatPageState();
}

class _HikayatPageState extends State<HikayatPage> {
  List<Tale> _tales = const [];
  int? _open;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/hikayat/en.txt').then((t) {
      if (mounted) setState(() => _tales = Tale.parse(t));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final rank = App.I.engine.rank;
    final tale = _open == null ? null : _tales[_open!];
    return Leaf(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Press(
                onTap: () => tale == null ? Navigator.of(context).pop() : setState(() => _open = null),
                label: tr('Kembali', 'Back', 'Volver', 'Retour', 'Zurück', 'Voltar'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(child: Text(tale?.title ?? 'Hikayat Aldmere', style: T.display(25, pal.ink))),
            ],
          ),
          Expanded(
            child: tale == null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    children: [
                      Text(
                        tr(
                          'Satu kisah untuk tiap gelar, dalam bahasa Inggris setingkat gelarnya. Kisah terbuka saat gelarnya kamu pegang. Kata yang sudah kamu temui bergaris bawah: ketuk untuk melihat artinya.',
                          'One tale for each title, in English at that title\'s level. A tale opens once you hold its title. Words you have met are underlined: tap one to see its meaning.',
                          'Un relato por cada título, en inglés del nivel de ese título. Se abre cuando tienes el título. Las palabras que ya viste están subrayadas: toca una para ver su significado.',
                          'Un récit pour chaque titre, en anglais du niveau de ce titre. Il s’ouvre quand tu détiens le titre. Les mots déjà rencontrés sont soulignés : touche-en un pour voir son sens.',
                          'Eine Erzählung für jeden Titel, auf Englisch im Niveau dieses Titels. Sie öffnet sich, sobald du den Titel trägst. Wörter, die du schon kennst, sind unterstrichen: tipp eines an, um seine Bedeutung zu sehen.',
                          'Uma história para cada título, em inglês do nível desse título. Ela abre quando você tem o título. As palavras que você já viu estão sublinhadas: toque numa para ver o sentido.',
                        ),
                        style: T.body(15, pal.muted, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < _tales.length; i++)
                        Press(
                          onTap: _tales[i].rank <= rank ? () => setState(() => _open = i) : null,
                          label: _tales[i].title,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Shield(_tales[i].rank, width: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tales[i].rank <= rank ? _tales[i].title : '? ? ?',
                                        style: T.display(20, _tales[i].rank <= rank ? pal.ink : pal.muted),
                                      ),
                                      Text(rankNames[_tales[i].rank], style: T.body(13.5, pal.muted)),
                                    ],
                                  ),
                                ),
                                if (_tales[i].rank > rank) Icon(Icons.lock_outline, color: pal.muted, size: 20),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : _TaleText(tale),
          ),
        ],
      ),
    );
  }
}

class _TaleText extends StatefulWidget {
  final Tale tale;
  const _TaleText(this.tale);

  @override
  State<_TaleText> createState() => _TaleTextState();
}

class _TaleTextState extends State<_TaleText> {
  late final Map<String, Word> _forms = wordForms(App.I.deck);
  final List<TapGestureRecognizer> _taps = [];
  Word? _shown;

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(String p, Pal pal) {
    final out = <InlineSpan>[];
    final e = App.I.engine;
    final re = RegExp(r"[A-Za-z]+(?:[’'][a-z]+)?");
    var at = 0;
    for (final m in re.allMatches(p)) {
      if (m.start > at) out.add(TextSpan(text: p.substring(at, m.start)));
      final token = m.group(0)!;
      final w = _forms[token.toLowerCase()];
      if (w != null && e.seen(w)) {
        final tap = TapGestureRecognizer()
          ..onTap = () {
            setState(() => _shown = w);
            App.I.say(token, force: true);
          };
        _taps.add(tap);
        out.add(
          TextSpan(
            text: token,
            recognizer: tap,
            style: TextStyle(decoration: TextDecoration.underline, decorationColor: pal.muted),
          ),
        );
      } else {
        out.add(TextSpan(text: token));
      }
      at = m.end;
    }
    if (at < p.length) out.add(TextSpan(text: p.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    final shown = _shown;
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
            children: [
              for (final p in widget.tale.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text.rich(TextSpan(children: _spans(p, pal)), style: T.display(19.5, pal.ink, height: 1.45)),
                ),
            ],
          ),
        ),
        if (shown != null)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${shown.answer(App.I.british)}  ',
                    style: T.body(16.5, pal.ink, w: FontWeight.w700),
                  ),
                  TextSpan(text: shown.gloss, style: T.body(16, pal.ink)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
