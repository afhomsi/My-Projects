import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arbaeen/app.dart';
import 'package:arbaeen/audio/device_speech_voice.dart';
import 'package:arbaeen/audio/hadith_voice.dart';
import 'package:arbaeen/audio/listen_controller.dart';
import 'package:arbaeen/data/hadith.dart';
import 'package:arbaeen/data/hadith_repository.dart';
import 'package:arbaeen/features/plan/plan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _loadBook() => Book.fromJson(
  jsonDecode(File('assets/hadith/arbaeen.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// A voice that "plays" until the test calls [finish].
class FakeVoice implements HadithVoice {
  final played = <int>[];
  int stops = 0;
  bool unavailable = false;
  Completer<void>? _current;

  bool get isPlaying => _current != null;

  @override
  VoiceKind get kind => VoiceKind.deviceSpeech;

  @override
  Future<void> play(Hadith hadith) {
    if (unavailable) return Future.error(const VoiceUnavailable());
    played.add(hadith.number);
    return (_current = Completer<void>()).future;
  }

  void finish() {
    final c = _current!;
    _current = null;
    c.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _current;
    _current = null;
    c?.complete();
  }
}

Future<(FakeVoice, SharedPreferences)> _openHadith(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final voice = FakeVoice();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookProvider.overrideWith((ref) async => _loadBook()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        hadithVoiceProvider.overrideWithValue(voice),
      ],
      child: const ArbaeenApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('إنما الأعمال بالنيات').first);
  await tester.pumpAndSettle();
  return (voice, prefs);
}

/// Ends the current repetition and waits through the gap before the next.
Future<void> _finishRound(WidgetTester tester, FakeVoice voice) async {
  voice.finish();
  await tester.pump();
  await tester.pump(repeatGap);
}

String _round(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('listen-round'))).data!;

void main() {
  testWidgets('plays the hadith three times by default, then stops', (
    tester,
  ) async {
    final (voice, _) = await _openHadith(tester);
    expect(find.text('التكرار: ٣ مرات'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();
    expect(voice.played, [1]);
    expect(_round(tester), 'المرة ١ من ٣');
    expect(find.byKey(const ValueKey('listen-notice')), findsOneWidget);

    await _finishRound(tester, voice);
    expect(voice.played, [1, 1]);
    expect(_round(tester), 'المرة ٢ من ٣');

    await _finishRound(tester, voice);
    expect(voice.played, [1, 1, 1]);
    expect(_round(tester), 'المرة ٣ من ٣');

    voice.finish();
    await tester.pumpAndSettle();
    expect(voice.played, [1, 1, 1]);
    expect(find.byKey(const ValueKey('listen-round')), findsNothing);
    expect(find.text('استمع'), findsOneWidget);
  });

  testWidgets('the chosen count is saved and used', (tester) async {
    final (voice, prefs) = await _openHadith(tester);

    await tester.tap(find.byKey(const ValueKey('listen-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مرة واحدة').last);
    await tester.pumpAndSettle();
    expect(prefs.getInt('listen.repeat'), 1);
    expect(find.text('التكرار: مرة واحدة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();
    voice.finish();
    await tester.pumpAndSettle();
    expect(voice.played, [1]);
    expect(find.text('استمع'), findsOneWidget);
  });

  testWidgets('a saved count is restored; 20 and 50 read correctly', (
    tester,
  ) async {
    await _openHadith(tester, saved: {'listen.repeat': 20});
    expect(find.text('التكرار: ٢٠ مرة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listen-repeat')));
    await tester.pumpAndSettle();
    expect(find.text('١٠ مرات'), findsOneWidget);
    expect(find.text('٥٠ مرة'), findsOneWidget);
  });

  testWidgets('endless keeps going until stopped', (tester) async {
    final (voice, _) = await _openHadith(tester, saved: {'listen.repeat': 0});
    expect(find.text('التكرار: بلا توقف'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await _finishRound(tester, voice);
    }
    expect(voice.played.length, 61);
    expect(_round(tester), 'المرة ٦١');

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump(repeatGap * 2);
    expect(voice.isPlaying, isFalse);
    expect(voice.played.length, 61);
    expect(find.text('استمع'), findsOneWidget);
  });

  testWidgets('moving to the next hadith stops the sound', (tester) async {
    final (voice, _) = await _openHadith(tester);

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();
    expect(voice.isPlaying, isTrue);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(voice.isPlaying, isFalse);
    expect(voice.played, [1]);
    expect(find.text('استمع'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();
    expect(voice.played, [1, 2]);
  });

  testWidgets('leaving the hadith page stops the sound', (tester) async {
    final (voice, _) = await _openHadith(tester);
    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(voice.isPlaying, isFalse);
    await tester.pump(repeatGap * 2);
    expect(voice.played, [1]);
  });

  testWidgets('says so when the device has no Arabic voice', (tester) async {
    final (voice, _) = await _openHadith(tester);
    voice.unavailable = true;

    await tester.tap(find.byKey(const ValueKey('listen-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'لا يوجد صوت عربي على هذا الجهاز. ثبّته من إعدادات تحويل النص إلى كلام.',
      ),
      findsOneWidget,
    );
    expect(find.text('استمع'), findsOneWidget);
  });

  group('DeviceSpeechVoice', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];
    var arabic = true;

    setUp(() {
      calls.clear();
      arabic = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'isLanguageAvailable' ? arabic : 1;
          });
    });

    final hadith = _loadBook().ahadith.first;

    test('speaks the full matn in Arabic', () async {
      await DeviceSpeechVoice().play(hadith);
      expect(calls.map((c) => c.method), [
        'awaitSpeakCompletion',
        'isLanguageAvailable',
        'setLanguage',
        'speak',
      ]);
      expect(calls[2].arguments, 'ar');
      expect(calls[3].arguments, hadith.matn);
    });

    test('throws VoiceUnavailable without an Arabic voice', () async {
      arabic = false;
      await expectLater(
        DeviceSpeechVoice().play(hadith),
        throwsA(isA<VoiceUnavailable>()),
      );
      expect(calls.map((c) => c.method), isNot(contains('speak')));
    });
  });
}
