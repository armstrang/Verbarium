import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/ui/theme.dart';

double _lin(double c) => c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
double lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double ratio(Color a, Color b) {
  final x = lum(a), y = lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  for (final entry in {'kertas': Pal.day, 'lilin': Pal.night}.entries) {
    final p = entry.value;
    test('${entry.key}: every pair that carries text reaches 4.5:1', () {
      final pairs = <String, List<Color>>{
        'ink on paper': [p.ink, p.bg],
        'ink on deep': [p.ink, p.deep],
        'ink on field': [p.ink, p.field],
        'muted on paper': [p.muted, p.bg],
        'muted on deep': [p.muted, p.deep],
        'muted on field': [p.muted, p.field],
        'good on paper': [p.good, p.bg],
        'bad on paper': [p.bad, p.bg],
        'bad on field': [p.bad, p.field],
        'paper on ink (chosen option)': [p.bg, p.ink],
        for (var r = 0; r < p.tinctures.length; r++) 'button text on tincture $r': [p.onAccent, p.tincture(r)],
        for (var r = 0; r < p.tinctures.length; r++) 'tincture $r as text on paper': [p.tincture(r), p.bg],
      };
      final low = [
        for (final e in pairs.entries)
          if (ratio(e.value[0], e.value[1]) < 4.5) '${e.key}: ${ratio(e.value[0], e.value[1]).toStringAsFixed(2)}',
      ];
      expect(low, isEmpty);
    });

    test('${entry.key}: lines and tinctures stand out from the paper (3:1 for shapes)', () {
      final low = [
        for (var r = 0; r < p.tinctures.length; r++)
          if (ratio(p.tincture(r), p.bg) < 3) 'tincture $r',
      ];
      expect(low, isEmpty);
    });
  }
}
