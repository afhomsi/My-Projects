import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:arbaeen/features/plan/review_schedule.dart';
import 'package:arbaeen/features/recitation/recite_screen.dart';
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

final _marks = RegExp('[ً-ٰٟ]');

/// The matn of hadith [n] as a recognizer writes it.
List<String> _plain(int n) => [
  for (final t in _loadBook().ahadith[n - 1].matn.split(RegExp(r'\s+')))
    if (t.contains('ﷺ'))
      ...salawatWords
    else if (t.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), '')
        case final w when w.isNotEmpty)
      w,
];

Future<(FakeListener, SharedPreferences)> _openRecite(
  WidgetTester tester, {
  String scope = 'full',
}) async {
  // Tall enough to show the matn and the list of mistakes together.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final listener = FakeListener();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookProvider.overrideWith((ref) async => _loadBook()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        speechListenerProvider.overrideWithValue(listener),
      ],
      child: const ArbaeenApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('إنما الأعمال بالنيات').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-recite')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('recite-choose-$scope')));
  await tester.pumpAndSettle();
  return (listener, prefs);
}

String _matn(WidgetTester tester) => tester
    .widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('recited-matn')),
        matching: find.byType(RichText),
      ),
    )
    .text
    .toPlainText();

void main() {
  test('the suggested grade follows the number of mistakes', () {
    expect(suggestedGrade(0), Grade.good);
    expect(suggestedGrade(2), Grade.hard);
    expect(suggestedGrade(5), Grade.again);
  });

  testWidgets('recite hadith 1 by voice with one wrong word, then grade', (
    tester,
  ) async {
    final (listener, prefs) = await _openRecite(tester);
    expect(find.text('التسميع بالصوت: الحديث ١'), findsOneWidget);
    expect(
      find.text('يُتعرَّف على صوتك في هاتفك، ولا يُرسل إلى أي مكان.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('recite-start')));
    await tester.pump();
    expect(listener.listening, isTrue);
    expect(find.byKey(const ValueKey('recite-stop')), findsOneWidget);

    final said = _plain(1);
    final at = said.indexOf('الأعمال');
    said[at] = 'الأفعال';
    listener.say(said.take(20).join(' '));
    await tester.pump();
    expect(find.textContaining('سمعت: '), findsOneWidget);

    listener.say(said.join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(listener.listening, isFalse);
    expect(find.text('الأخطاء'), findsOneWidget);
    expect(
      find.textContaining('سمعت «الأفعال» والصواب «الْأَعْمَالُ»'),
      findsOneWidget,
    );
    expect(find.text('سمّعت الحديث كاملًا، وفيه خطأ واحد.'), findsOneWidget);
    expect(_matn(tester), contains('الْأَعْمَالُ'));

    // One mistake suggests "بصعوبة"; any grade may be chosen.
    final hard = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('recite-grade-hard')),
    );
    expect(hard, isA<FilledButton>());
    await tester.tap(find.byKey(const ValueKey('recite-grade-hard')));
    await tester.pumpAndSettle();
    expect(prefs.getString('plan.cards'), contains('"number":1'));
    expect(find.byKey(const ValueKey('recited-matn')), findsNothing);
  });

  testWidgets('words to come stay hidden until said, or shown faded', (
    tester,
  ) async {
    final (listener, _) = await _openRecite(tester);
    await tester.tap(find.byKey(const ValueKey('recite-start')));
    await tester.pump();
    listener.say('عن أمير المؤمنين', isFinal: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('قرأت ٣ من ${_arabicCount()}'), findsOneWidget);
    // A hint shows the next word.
    await tester.tap(find.byKey(const ValueKey('recite-hint')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recite-show-text')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recite-restart')));
    await tester.pumpAndSettle();
    expect(find.text('قرأت ٠ من ${_arabicCount()}'), findsOneWidget);
  });

  testWidgets('without Arabic on the device, offers recognition online', (
    tester,
  ) async {
    final (listener, prefs) = await _openRecite(tester);
    await tester.tap(find.byKey(const ValueKey('recite-start')));
    await tester.pump();
    listener.fail('error_language_unavailable');
    await tester.pump();
    expect(find.byKey(const ValueKey('recite-error')), findsOneWidget);
    expect(find.textContaining('دون إنترنت'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recite-allow-online')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('recite.allowOnline'), isTrue);
    expect(listener.listening, isTrue);
    expect(find.byKey(const ValueKey('recite-error')), findsNothing);
    expect(find.textContaining('عبر الإنترنت'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recite-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recite-device-only')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('recite.allowOnline'), isFalse);
  });

  testWidgets('only the Prophet\'s words: the chain is shown, not asked', (
    tester,
  ) async {
    final (listener, _) = await _openRecite(tester, scope: 'prophet');
    expect(find.text('كلام رسول الله ﷺ فقط'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recite-start')));
    await tester.pump();
    final quoted = _loadBook().ahadith[0].matn.split('«')[1].split('»')[0];
    final said = [
      for (final t in quoted.split(RegExp(r'\s+')))
        if (t.replaceAll(_marks, '').replaceAll(RegExp('[^ء-ي]'), '')
            case final w when w.isNotEmpty)
          w,
    ];
    listener.say(said.join(' '), isFinal: true);
    await tester.pumpAndSettle();
    expect(find.text('أحسنت! سمّعت الحديث كاملًا دون خطأ.'), findsOneWidget);
  });
}

String _arabicCount() {
  final n = wordsOfMatn(_loadBook().ahadith[0].matn)
      .where((w) => !w.optional)
      .length;
  return n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
}
