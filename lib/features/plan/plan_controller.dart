import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_schedule.dart';

/// Set in `main()` once [SharedPreferences] is loaded; overridden in tests.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not set'),
);

/// The current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final planProvider = NotifierProvider<PlanController, Plan>(PlanController.new);

const _paceKey = 'plan.pace';
const _cardsKey = 'plan.cards';

/// Holds the memorization plan and saves every change on the device.
class PlanController extends Notifier<Plan> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  int get today => dayNumber(ref.read(clockProvider)());

  @override
  Plan build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_cardsKey);
    final cards = <int, ReviewCard>{};
    if (raw != null) {
      for (final c in jsonDecode(raw) as List<dynamic>) {
        final card = ReviewCard.fromJson(c as Map<String, dynamic>);
        cards[card.number] = card;
      }
    }
    return Plan(paceDays: prefs.getInt(_paceKey) ?? 2, cards: cards);
  }

  void setPace(int days) {
    state = state.copyWith(paceDays: days);
    _prefs.setInt(_paceKey, days);
  }

  /// Records a recitation of hadith [number] and schedules its next review.
  ReviewCard grade(int number, Grade grade) {
    final card = ReviewCard.grade(state.cards[number], number, grade, today);
    state = state.copyWith(cards: {...state.cards, number: card});
    _prefs.setString(
      _cardsKey,
      jsonEncode([for (final c in state.cards.values) c.toJson()]),
    );
    return card;
  }
}
