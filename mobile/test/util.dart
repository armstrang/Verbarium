import 'dart:io';

import 'package:verbarium/data/deck.dart';

/// every core word, read straight from the deck files (a rank may be spread over several: 1-squire.txt, 1-squire-b.txt)
List<Word> coreWords() {
  final files = Directory('assets/deck').listSync().whereType<File>().where((f) => RegExp(r'/[1-5]-[^/]*\.txt$').hasMatch(f.path)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) ...Deck.parse(f.readAsStringSync(), tier: int.parse(f.uri.pathSegments.last[0]))];
}
