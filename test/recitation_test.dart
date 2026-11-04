import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/recitation/arabic_normalizer.dart';
import 'package:arbaeen/recitation/recitation_matcher.dart';
import 'package:arbaeen/recitation/recitation_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_listener.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

final _marks = RegExp('[ً-ٰٟ]');

/// [matn] as a speech recognizer writes it: no harakat, no punctuation,
/// and the sign ﷺ said in full (or left out when [salawat] is false).
List<String> plain(String matn, {bool salawat = true}) => [
  for (final t in matn.split(RegExp(r'\s+')))
    if (t.contains('ﷺ'))
      ...(salawat ? salawatWords : const <String>[])
    else
      for (final w in [
        t.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), ''),
      ])
        if (w.isNotEmpty) w,
];

void main() {
  final book = _loadBook();
  Hadith hadith(int n) => book.ahadith[n - 1];

  test('the matn and plain spelling normalize to the same words', () {
    expect(normalizeWord('إِنَّمَا'), normalizeWord('انما'));
    expect(normalizeWord('الْإِيمَانِ'), normalizeWord('الايمان'));
    expect(normalizeWord('اللهِ'), normalizeWord('الله'));
    expect(normalizeWord('بِالنِّيَّاتِ'), normalizeWord('بالنيات'));
    expect(normalizeWord('امْرِئٍ'), normalizeWord('امرئ'));
  });

  test('the sign ﷺ is said as optional words', () {
    final words = wordsOfMatn('قَالَ رَسُولُ اللهِ ﷺ: «إِنَّمَا');
    expect(words.map((w) => w.text), [
      'قَالَ',
      'رَسُولُ',
      'اللهِ',
      ...salawatWords,
      '«إِنَّمَا',
    ]);
    expect(words.where((w) => w.optional), hasLength(4));
  });

  test('the matn is cut into parts at the end of sentences', () {
    final words = wordsOfMatn(hadith(2).matn);
    expect(words.first.part, 0);
    expect(words.last.part, greaterThan(5));
    expect(words.last.pause, isTrue);
  });

  test('every hadith recited right has no mistakes, with or without the '
      'salawat said', () {
    for (final h in book.ahadith) {
      final expected = wordsOfMatn(h.matn);
      for (final salawat in [true, false]) {
        final r = alignRecitation(expected, plain(h.matn, salawat: salawat));
        expect(r.isComplete, isTrue, reason: 'hadith ${h.number}');
        expect(r.mistakeCount, 0, reason: 'hadith ${h.number}');
      }
    }
  });

  group('the long hadith of Jibril (2)', () {
    final expected = wordsOfMatn(hadith(2).matn);
    final heard = plain(hadith(2).matn);

    test('finds a wrong word', () {
      final said = [...heard];
      final at = said.indexOf('الإسلام');
      said[at] = 'الإيمان';
      final r = alignRecitation(expected, said);
      expect(r.mistakeCount, 1);
      final wrong = r.words.singleWhere((w) => w.status == WordStatus.wrong);
      expect(wrong.heard, 'الإيمان');
    });

    test('finds a skipped word and an extra one', () {
      final said = [...heard];
      final at = said.indexOf('شديد');
      said.removeAt(at);
      said.insert(at + 10, 'جدا');
      final r = alignRecitation(expected, said);
      expect(r.mistakeCount, 2);
      expect(
        r.words.where((w) => w.status == WordStatus.skipped),
        hasLength(1),
      );
      expect(r.words.where((w) => w.extrasBefore.isNotEmpty), hasLength(1));
    });

    test('stopping half way is not a mistake', () {
      final r = alignRecitation(expected, heard.take(60).toList());
      expect(r.isComplete, isFalse);
      expect(r.mistakeCount, 0);
    });
  });

  group('a listening session', () {
    test('follows hadith 24 said fast in one long session, word by word', () {
      final h = hadith(24);
      final listener = FakeListener();
      final session = RecitationSession(
        listener: listener,
        expected: wordsOfMatn(h.matn),
      );
      final mistakes = <Mistake>[];
      session.onMistake = mistakes.add;
      final said = plain(h.matn);
      return session.start().then((_) {
        final watch = Stopwatch()..start();
        for (var k = 1; k <= said.length; k++) {
          listener.say(said.take(k).join(' '));
        }
        listener.say(said.join(' '), isFinal: true);
        watch.stop();
        expect(session.result.isComplete, isTrue);
        expect(mistakes, isEmpty);
        expect(session.isListening, isFalse);
        // One result per word must stay quick on a phone.
        expect(watch.elapsedMilliseconds, lessThan(3000));
      });
    });

    testWidgets('follows hadith 2 over many listening sessions, as Google '
        'restarts after each pause', (tester) async {
      final h = hadith(2);
      final listener = FakeListener();
      final session = RecitationSession(
        listener: listener,
        expected: wordsOfMatn(h.matn),
      );
      final mistakes = <Mistake>[];
      session.onMistake = mistakes.add;
      await session.start();
      final said = plain(h.matn);
      final at = said.indexOf('الساعة');
      said[at] = 'القيامة';
      for (var k = 0; k < said.length; k += 7) {
        final piece = said.skip(k).take(7).toList();
        for (var w = 1; w <= piece.length; w++) {
          listener.say(piece.take(w).join(' '));
        }
        listener.say(piece.join(' '), isFinal: true);
        // Let the restarted listening session begin.
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(session.result.isComplete, isTrue);
      expect(mistakes, hasLength(1));
      expect(mistakes.single.kind, MistakeKind.wrong);
      expect(mistakes.single.heard, 'القيامة');
      expect(listener.sessions, greaterThan(10));
      session.dispose();
    });

    testWidgets('tells a whole part left out once', (tester) async {
      final h = hadith(2);
      final expected = wordsOfMatn(h.matn);
      final listener = FakeListener();
      final session = RecitationSession(listener: listener, expected: expected);
      final mistakes = <Mistake>[];
      session.onMistake = mistakes.add;
      await session.start();
      // Leave out «قال: فأخبرني عن الإحسان.»
      final said = plain(h.matn);
      final to = said.indexOf('الإحسان');
      said.removeRange(to - 3, to + 1);
      listener.say(said.join(' '), isFinal: true);
      await tester.pump(const Duration(milliseconds: 350));
      final kinds = mistakes.map((m) => m.kind).toSet();
      expect(kinds, contains(MistakeKind.skippedPart));
      expect(mistakes.where((m) => m.kind == MistakeKind.skippedWord), isEmpty);
      session.dispose();
    });

    testWidgets('reports a refused microphone', (tester) async {
      final listener = FakeListener();
      final session = RecitationSession(
        listener: listener,
        expected: wordsOfMatn(hadith(1).matn),
      );
      await session.start();
      listener.fail('error_language_unavailable');
      expect(session.error, ListenError.needsNetwork);
      expect(session.isListening, isFalse);
      listener.fail('error_no_match');
      session.dispose();
    });
  });
}
