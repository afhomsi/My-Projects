import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/memorize/word_hiding.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:arbaeen/features/quiz/quiz.dart';
import 'package:arbaeen/features/quiz/quiz_screen.dart';
import 'package:arbaeen/l10n/app_localizations.dart';
import 'package:arbaeen/recitation/recitation_matcher.dart';
import 'package:arbaeen/recitation/speech_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_listener.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

final _marks = RegExp('[ً-ٰٟ]');

/// The words of [q] as a recognizer writes them, without the cue.
String _answer(QuizQuestion q) => [
  for (final w in q.expected)
    if (w.kind == WordKind.salawat)
      w.text
    else if (w.kind == WordKind.matn)
      w.text.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), ''),
].join(' ');

void main() {
  final book = _loadBook();

  test('every question asks for at least the minimum words, or the whole '
      'hadith, after its cue', () {
    final random = Random(1);
    for (final h in book.ahadith) {
      final all = wordsOfMatn(h.matn).where((w) => !w.optional).length;
      for (var k = 0; k < 20; k++) {
        final q = questionOn(h, random);
        final asked = q.expected.where((w) => w.kind == WordKind.matn).length;
        expect(
          asked,
          greaterThanOrEqualTo(min(quizMinWords, all)),
          reason: 'hadith ${h.number}',
        );
        expect(q.to, greaterThan(q.from));
        if (!q.fromStart) expect(q.cueFrom, lessThan(q.from));
      }
    }
  });

  test('a test asks about different ahadith from the pool', () {
    final pool = book.ahadith.take(5).toList();
    final quiz = buildQuiz(pool, Random(3));
    expect(quiz, hasLength(quizLength));
    expect(quiz.map((q) => q.hadith.number).toSet(), hasLength(quizLength));
    expect(buildQuiz(pool.take(2).toList(), Random(3)), hasLength(2));
  });

  Future<FakeListener> pumpQuiz(
    WidgetTester tester,
    List<QuizQuestion> questions,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final listener = FakeListener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          speechListenerProvider.overrideWithValue(listener),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: QuizScreen(questions: questions),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return listener;
  }

  testWidgets('three questions: right, with a mistake, and given up', (
    tester,
  ) async {
    final random = Random(7);
    final questions = [
      for (final n in [1, 2, 24]) questionOn(book.ahadith[n - 1], random),
    ];
    final listener = await pumpQuiz(tester, questions);
    expect(find.text('السؤال ١ من ٣'), findsOneWidget);

    // 1: right, with the cue said again first.
    await tester.tap(find.byKey(const ValueKey('quiz-start')));
    await tester.pump();
    final q1 = questions[0];
    final cue = [
      for (final w in q1.expected)
        if (w.kind == WordKind.cue)
          w.text.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), ''),
    ].where((w) => w.isNotEmpty).join(' ');
    listener.say('$cue ${_answer(q1)}'.trim(), isFinal: true);
    await tester.pumpAndSettle();
    expect(find.text('الأخطاء'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await tester.pumpAndSettle();
    expect(find.text('السؤال ٢ من ٣'), findsOneWidget);

    // 2: one wrong word.
    await tester.tap(find.byKey(const ValueKey('quiz-start')));
    await tester.pump();
    final words = _answer(questions[1]).split(' ');
    words[3] = 'كلمة';
    listener.say(words.join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(find.text('الأخطاء'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await tester.pumpAndSettle();

    // 3: shows the answer instead.
    await tester.tap(find.byKey(const ValueKey('quiz-reveal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-next')));
    await tester.pumpAndSettle();

    expect(find.text('أجبت عن ١ من ٣ دون خطأ'), findsOneWidget);
    expect(find.text('دون خطأ'), findsOneWidget);
    expect(find.text('خطأ واحد'), findsOneWidget);
    expect(find.text('أظهرت الجواب'), findsOneWidget);
  });

  testWidgets('the cue shows the sentence before and hides the answer', (
    tester,
  ) async {
    final random = Random(2);
    QuizQuestion q;
    do {
      q = questionOn(book.ahadith[1], random);
    } while (q.fromStart);
    await pumpQuiz(tester, [q]);
    expect(find.text('أكمل بعد قوله:'), findsOneWidget);
    final tokens = splitMatn(book.ahadith[1].matn);
    final last = tokens[q.from - 1];
    expect(
      find.textContaining('${last.prefix}${last.core}${last.suffix}'),
      findsWidgets,
    );
  });

  testWidgets('the plan opens the test once a hadith is started', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider.overrideWith((ref) async => book),
          sharedPreferencesProvider.overrideWithValue(prefs),
          speechListenerProvider.overrideWithValue(FakeListener()),
        ],
        child: const ArbaeenApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-plan')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('plan-quiz'));
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(
      find.text('ابدأ حفظ حديث في الخطة ليُفتح الاختبار.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('plan-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أتقنته'));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // Only hadith 1 is started, so the test has one question on it.
    expect(find.text('السؤال ١ من ١'), findsOneWidget);
    expect(find.textContaining('الحديث ١: '), findsOneWidget);
  });
}
