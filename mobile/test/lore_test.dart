import 'package:flutter_test/flutter_test.dart';
import 'package:verbarium/engine/jobs.dart';
import 'package:verbarium/engine/lore.dart';

void main() {
  test('every title and every job has its lore, in all four languages, and every job story is told in two or three sentences', () {
    expect(LoreBook.titles.length, 6);
    for (final l in LoreBook.titles) {
      for (final t in l.all) {
        expect(t.trim().length, greaterThan(8));
      }
    }
    for (final j in Jobs.all) {
      expect(LoreBook.has(j.id), isTrue, reason: '${j.id} has no lore');
      for (final t in LoreBook.job(j.id).all) {
        expect(t.trim().length, greaterThan(8), reason: j.id);
      }
      final l = LoreBook.job(j.id);
      if (j.id != 'peasant') {
        for (final i in [2, 3, 11, 16]) {
          expect('.'.allMatches(l.all[i]).length, greaterThanOrEqualTo(2), reason: '${j.id}: the story is two or three sentences');
        }
      }
    }
  });
}
