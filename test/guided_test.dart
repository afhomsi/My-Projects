import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/guided/guided_screen.dart';
import 'package:arbaeen/features/guided/guided_steps.dart';
import 'package:arbaeen/features/memorize/word_hiding.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:arbaeen/recitation/recitation_matcher.dart';
import 'package:arbaeen/recitation/speech_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_listener.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

final _marks = RegExp('[ً-ٰٟ]');

/// [words] as a recognizer writes them: no harakat, no punctuation.
List<String> _plain(List<ExpectedWord> words) => [
  for (final w in words)
    if (w.kind == WordKind.salawat)
      w.text
    else
      w.text.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), ''),
];

void main() {
  final book = _loadBook();

  test('units cover the words in order, none of a couple of words', () {
    for (final h in book.ahadith) {
      for (final scope in ReciteScope.values) {
        if (scope == ReciteScope.prophetWords && !hasProphetWords(h.matn)) {
          continue;
        }
        final words = wordsOfMatn(h.matn, scope: scope);
        final units = unitsOf(words);
        expect(units.first.$1, 0);
        expect(units.last.$2, words.length);
        for (var u = 1; u < units.length; u++) {
          expect(units[u].$1, units[u - 1].$2);
        }
        if (units.length > 1) {
          for (final (from, to) in units) {
            final size = words
                .sublist(from, to)
                .where((w) => !w.optional)
                .length;
            expect(
              size,
              greaterThanOrEqualTo(minUnitWords),
              reason: 'hadith ${h.number}',
            );
          }
        }
      }
    }
  });

  test('a long first sentence is learnt in pieces cut at commas', () {
    final words = wordsOfMatn(book.ahadith[0].matn);
    final units = unitsOf(words);
    expect(units.length, greaterThan(2));
    for (final (_, to) in units.take(units.length - 1)) {
      expect(words[to - 1].pause, isTrue);
    }
  });

  test('each unit is read, hidden bit by bit, linked, then the whole', () {
    final words = wordsOfMatn(book.ahadith[1].matn);
    final units = unitsOf(words);
    expect(units.length, greaterThan(2));
    final steps = guidedSteps(words);
    expect(steps.take(4).map((s) => s.level), HideLevel.values);
    expect(steps.take(4).every((s) => s.unit == 0), isTrue);
    expect(steps[4].unit, 1);
    expect(steps[8].kind, GuidedStepKind.link);
    expect(steps[8].from, units[0].$1);
    expect(steps[8].to, units[1].$2);
    expect(steps.last.kind, GuidedStepKind.whole);
    expect(steps.last.wordsOf(words).length, words.length);
    expect(steps.length, units.length * 5 - 1 + 1);
  });

  test('two failures in a row show more of the text', () {
    final p = GuidedProgress(guidedSteps(wordsOfMatn(book.ahadith[0].matn)));
    expect(p.fail(), isFalse);
    p.pass();
    expect(p.current.level, HideLevel.third);
    expect(p.fail(), isFalse);
    expect(p.fail(), isTrue);
    expect(p.current.level, HideLevel.none);
    // Reading with the text shown never goes back.
    expect(p.fail(), isFalse);
    expect(p.fail(), isFalse);
    expect(p.at, 0);
  });

  // Rule 5 of CLAUDE.md: long ahadith, not only short ones.
  for (final n in [2, 24, 1, 42]) {
    test('every step of hadith $n passes when recited right', () {
      final words = wordsOfMatn(book.ahadith[n - 1].matn);
      final steps = guidedSteps(words);
      for (final step in steps) {
        final expected = step.wordsOf(words);
        final result = alignRecitation(expected, _plain(expected));
        expect(result.isComplete, isTrue, reason: '$step');
        expect(result.mistakeCount, 0, reason: '$step');
      }
    });
  }

  testWidgets('memorize hadith 1 by voice, step by step', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final listener = FakeListener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider.overrideWith((ref) async => book),
          sharedPreferencesProvider.overrideWithValue(prefs),
          speechListenerProvider.overrideWithValue(listener),
        ],
        child: const ArbaeenApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنما الأعمال بالنيات').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-guided')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recite-choose-full')));
    await tester.pumpAndSettle();

    expect(find.text('الحفظ بالصوت: الحديث ١'), findsOneWidget);
    expect(find.text('اقرأ الجملة بصوتك وأنت تنظر إليها.'), findsOneWidget);
    final words = wordsOfMatn(book.ahadith[0].matn);
    final steps = guidedSteps(words);

    // The first step: said right, it passes.
    await tester.tap(find.byKey(const ValueKey('guided-start')));
    await tester.pump();
    listener.say(_plain(steps[0].wordsOf(words)).join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(find.text('أحسنت! سمّعتها دون خطأ.'), findsOneWidget);
    expect(prefs.getInt(guidedKey(1, ReciteScope.full)), 1);

    // The next step hides a third; said with a wrong word, it fails.
    await tester.tap(find.byKey(const ValueKey('guided-go')));
    await tester.pump();
    expect(find.text('أخفينا ثلث الكلمات: سمّع الجملة.'), findsOneWidget);
    expect(listener.listening, isTrue);
    final wrong = _plain(steps[1].wordsOf(words));
    wrong[2] = 'الأفعال';
    listener.say(wrong.join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(find.text('فيها أخطاء، فأعد المحاولة.'), findsOneWidget);
    expect(find.text('الأخطاء'), findsOneWidget);

    // A second failure goes back to reading with the text shown.
    await tester.tap(find.byKey(const ValueKey('guided-go')));
    await tester.pump();
    listener.say(wrong.join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(
      find.text('أظهرنا لك كلمات أكثر، لتتقنها ثم نخفيها من جديد.'),
      findsOneWidget,
    );
    expect(prefs.getInt(guidedKey(1, ReciteScope.full)), 0);

    // Going through every step to the end.
    for (var at = 0; at < steps.length; at++) {
      await tester.tap(find.byKey(const ValueKey('guided-go')));
      await tester.pump();
      listener.say(_plain(steps[at].wordsOf(words)).join(' '), isFinal: true);
      await tester.pumpAndSettle();
      expect(find.text('أحسنت! سمّعتها دون خطأ.'), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('guided-go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guided-done')), findsOneWidget);
    expect(prefs.getInt(guidedKey(1, ReciteScope.full)), steps.length);

    // Coming back later resumes where it was left: here, at the end.
    await tester.tap(find.byKey(const ValueKey('guided-start-over')));
    await tester.pumpAndSettle();
    expect(prefs.getInt(guidedKey(1, ReciteScope.full)), 0);
    expect(find.text('اقرأ الجملة بصوتك وأنت تنظر إليها.'), findsOneWidget);
  });
}
