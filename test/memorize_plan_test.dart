import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/memorize/memorize_screen.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

var _now = DateTime(2026, 11, 4, 10);

Future<SharedPreferences> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final book = _loadBook();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookProvider.overrideWith((ref) async => book),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const ArbaeenApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> _openPlan(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-plan')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _now = DateTime(2026, 11, 4, 10));

  testWidgets('first day: start hadith 1, grade it, it leaves today', (
    tester,
  ) async {
    final prefs = await _pumpApp(tester);
    await _openPlan(tester);

    expect(find.text('خطة الحفظ'), findsOneWidget);
    expect(find.text('بدأت ٠ من ٤٢ · أتقنت ٠'), findsOneWidget);
    expect(find.text('لا مراجعة اليوم.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-new')));
    await tester.pumpAndSettle();
    expect(find.text('تسميع الحديث ١'), findsOneWidget);

    await tester.tap(find.text('أتقنته'));
    await tester.pumpAndSettle();
    expect(find.text('المراجعة القادمة بعد يومين'), findsOneWidget);
    expect(find.text('بدأت ١ من ٤٢ · أتقنت ٠'), findsOneWidget);
    expect(find.text('يبدأ بعد يومين'), findsOneWidget);
    expect(prefs.getString('plan.cards'), contains('"number":1'));
  });

  testWidgets('saved cards come back as due reviews and a new hadith', (
    tester,
  ) async {
    final today = DateTime.utc(2026, 11, 4).millisecondsSinceEpoch ~/ 86400000;
    await _pumpApp(
      tester,
      saved: {
        'plan.pace': 1,
        'plan.cards': jsonEncode([
          {'number': 1, 'stage': 2, 'due': today - 3, 'started': today - 9},
          {'number': 2, 'stage': 1, 'due': today, 'started': today - 2},
        ]),
      },
    );
    await _openPlan(tester);

    expect(find.text('مراجعة اليوم (٢)'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-due-1')), findsOneWidget);
    expect(find.text('متأخر ٣ أيام'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-due-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-new')), findsOneWidget);
    expect(find.text('بدأت ٢ من ٤٢ · أتقنت ٠'), findsOneWidget);
  });

  testWidgets('changing the pace is saved', (tester) async {
    final prefs = await _pumpApp(tester);
    await _openPlan(tester);
    await tester.scrollUntilVisible(find.text('أسبوع'), 200);
    await tester.tap(find.text('أسبوع'));
    await tester.pumpAndSettle();
    expect(prefs.getInt('plan.pace'), 7);
  });

  testWidgets('memorize screen: hide all, reveal next, then the level', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('إنما الأعمال بالنيات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-memorize')));
    await tester.pumpAndSettle();
    expect(find.text('تسميع الحديث ١'), findsOneWidget);

    HiddenMatn matn() => tester.widget<HiddenMatn>(find.byType(HiddenMatn));
    final words = matn().words.where((w) => w.isHideable).length;
    expect(matn().hidden, hasLength((words / 3).round()));

    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();
    expect(matn().hidden, hasLength(words));
    expect(matn().revealed, isEmpty);

    await tester.tap(find.text('أظهر الكلمة التالية'));
    await tester.pump();
    expect(matn().revealed, {0});
    await tester.tap(find.text('أظهر الكلمة التالية'));
    await tester.pump();
    expect(matn().revealed, {0, 1});

    await tester.tap(find.text('لا شيء'));
    await tester.pumpAndSettle();
    expect(matn().hidden, isEmpty);
  });

  testWidgets('long hadith 24 hides and grades without errors', (tester) async {
    final prefs = await _pumpApp(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('hadith-24')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('hadith-24')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-memorize')));
    await tester.pumpAndSettle();
    expect(find.text('تسميع الحديث ٢٤'), findsOneWidget);
    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لم أحفظه'));
    await tester.pumpAndSettle();
    expect(find.text('المراجعة القادمة غدًا'), findsOneWidget);
    expect(prefs.getString('plan.cards'), contains('"number":24'));
  });
}
