import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'ui/root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // the fonts (OFL) and the music samples (CC0) beside Flutter's own notices in Settings → Software licences
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'IM Fell English',
      'Alegreya Sans',
    ], await rootBundle.loadString('assets/legal/licenses.txt'));
    yield const LicenseEntryWithLineBreaks(
      ['VSCO 2 CE', 'VCSL'],
      'The music and sound effects are rendered from instrument samples by Versilian Studios '
      '(VSCO 2 Community Edition and Versilian Community Sample Library), dedicated to the public domain under CC0 1.0 Universal.',
    );
  });
  await App.boot();
  runApp(const VerbariumApp());
}
