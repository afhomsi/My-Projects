import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/data/hadith.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final book = Book.fromJson(
    jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('has 42 ahadith numbered 1 to 42 in order', () {
    expect(book.ahadith, hasLength(42));
    expect(book.ahadith.map((h) => h.number), List.generate(42, (i) => i + 1));
  });

  test('every hadith has a title, narrator, matn and source', () {
    for (final h in book.ahadith) {
      expect(h.title.trim(), isNotEmpty, reason: 'title of ${h.number}');
      expect(h.narrator.trim(), isNotEmpty, reason: 'narrator of ${h.number}');
      expect(h.matn.trim(), isNotEmpty, reason: 'matn of ${h.number}');
      expect(h.source.trim(), isNotEmpty, reason: 'source of ${h.number}');
    }
  });

  test('matn carries tashkeel and no Latin letters', () {
    final harakat = RegExp('[ً-ْ]');
    final latin = RegExp('[A-Za-z]');
    for (final h in book.ahadith) {
      expect(harakat.hasMatch(h.matn), isTrue, reason: 'tashkeel ${h.number}');
      expect(latin.hasMatch(h.matn), isFalse, reason: 'latin in ${h.number}');
      expect(latin.hasMatch(h.source), isFalse, reason: 'latin ${h.number}');
    }
  });

  test('no sharh is bundled without an author and source', () {
    for (final h in book.ahadith) {
      for (final sharh in h.shuruh) {
        expect(sharh.author.trim(), isNotEmpty);
        expect(sharh.source.trim(), isNotEmpty);
      }
    }
  });

  test('the built asset matches the parts in tool/matn', () {
    final parts =
        Directory('tool/matn')
            .listSync()
            .whereType<File>()
            .expand(
              (f) => (jsonDecode(f.readAsStringSync()) as List<dynamic>)
                  .cast<Map<String, dynamic>>(),
            )
            .toList()
          ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    expect(parts.map((p) => p['matn']), book.ahadith.map((h) => h.matn));
  });
}
