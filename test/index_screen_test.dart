import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<void> _pumpApp(WidgetTester tester) async {
  final book = _loadBook();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookProvider.overrideWith((ref) async => book),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ArbaeenApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('index lists the ahadith, right to left', (tester) async {
    await _pumpApp(tester);

    expect(find.text('الأربعون النووية'), findsWidgets);
    expect(find.text('إنما الأعمال بالنيات'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.text('إنما الأعمال بالنيات')),
    );
    expect(direction, TextDirection.rtl);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('hadith-42')),
      300,
    );
    expect(find.text('يا ابن آدم إنك ما دعوتني ورجوتني'), findsOneWidget);
  });

  testWidgets('tapping an entry opens the hadith, next moves on', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('إنما الأعمال بالنيات'));
    await tester.pumpAndSettle();
    expect(find.text('الحديث ١'), findsOneWidget);
    expect(find.textContaining('إِنَّمَا الْأَعْمَالُ'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('الحديث ٢'), findsOneWidget);

    await tester.tap(find.text('السابق'));
    await tester.pumpAndSettle();
    expect(find.text('الحديث ١'), findsOneWidget);
  });

  testWidgets('the hadith page shows the short sharh as a draft', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('إنما الأعمال بالنيات'));
    await tester.pumpAndSettle();
    final sharh = find.textContaining('أصل في أن قبول العمل');
    await tester.scrollUntilVisible(
      sharh,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(sharh, findsOneWidget);
    expect(find.text('الشرح المختصر'), findsOneWidget);
    expect(find.text('شرح مختصر من إعداد التطبيق'), findsOneWidget);
    expect(find.textContaining('لم يراجع هذا الشرح'), findsOneWidget);
  });
}
