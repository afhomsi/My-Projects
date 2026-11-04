import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/features/memorize/word_hiding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('punctuation stays outside the hidden part', () {
    final words = splitMatn('قَالَ: «إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ، ﷺ');
    expect(words.map((w) => w.core), [
      'قَالَ',
      'إِنَّمَا',
      'الْأَعْمَالُ',
      'بِالنِّيَّاتِ',
      '',
    ]);
    expect(words[0].suffix, ':');
    expect(words[1].prefix, '«');
    expect(words[3].suffix, '،');
    expect(words[4].isHideable, isFalse);
    expect(words[4].prefix, 'ﷺ');
  });

  test('the first letter hint keeps its harakat', () {
    final w = splitMatn('إِنَّمَا').single;
    expect(w.firstLetter, 'إِ');
    expect(w.rest, 'نَّمَا');
    expect(splitMatn('بِالنِّيَّاتِ').single.firstLetter, 'بِ');
    expect(splitMatn('الْأَعْمَالُ').single.firstLetter, 'الْأَ');
    expect(splitMatn('امْرِئٍ').single.firstLetter, 'ا');
  });

  test('splitting loses no text of any of the 42 ahadith', () {
    final book = Book.fromJson(
      jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final h in book.ahadith) {
      final words = splitMatn(h.matn);
      final joined = words.map((w) => w.prefix + w.core + w.suffix).join(' ');
      expect(joined, h.matn.trim().split(RegExp(r'\s+')).join(' '));
      expect(words.where((w) => w.isHideable), isNotEmpty);
    }
  });

  test('levels hide the right share of words, the same for one seed', () {
    final words = splitMatn('أ ب ت ث ج ح خ د ذ ر ز س');
    expect(pickHidden(words, HideLevel.none, 1), isEmpty);
    expect(pickHidden(words, HideLevel.third, 1), hasLength(4));
    expect(pickHidden(words, HideLevel.twoThirds, 1), hasLength(8));
    expect(pickHidden(words, HideLevel.all, 1), hasLength(12));
    expect(
      pickHidden(words, HideLevel.third, 7),
      pickHidden(words, HideLevel.third, 7),
    );
  });

  test('words that cannot be hidden are never picked', () {
    final words = splitMatn('قَالَ ﷺ « يَقُولُ');
    expect(pickHidden(words, HideLevel.all, 3), {0, 3});
  });
}
