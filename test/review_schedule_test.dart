import 'package:arbaeen/features/plan/review_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = 20000;

  test('a first good recitation is reviewed after two days', () {
    final c = ReviewCard.grade(null, 5, Grade.good, today);
    expect(c.stage, 1);
    expect(c.dueDay, today + 2);
    expect(c.startedDay, today);
  });

  test('good climbs the ladder, hard stays, again starts over', () {
    var c = ReviewCard.grade(null, 1, Grade.good, today);
    final days = <int>[];
    for (var i = 0; i < 9; i++) {
      c = ReviewCard.grade(c, 1, Grade.good, c.dueDay);
      days.add(c.dueDay - reviewIntervals[c.stage]);
    }
    expect(c.stage, reviewIntervals.length - 1);
    expect(c.isMemorized, isTrue);
    expect(c.startedDay, today);

    final hard = ReviewCard.grade(c, 1, Grade.hard, today);
    expect(hard.stage, c.stage);
    final again = ReviewCard.grade(c, 1, Grade.again, today);
    expect(again.stage, 0);
    expect(again.dueDay, today + 1);
    expect(again.isMemorized, isFalse);
  });

  test('cards survive a round trip through JSON', () {
    final c = ReviewCard.grade(null, 7, Grade.hard, today);
    final back = ReviewCard.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
  });

  test('a new hadith comes once every pace days, in order', () {
    var plan = const Plan(paceDays: 2);
    expect(plan.nextNew(42), 1);
    expect(plan.daysUntilNew(today), 0);

    plan = plan.copyWith(
      cards: {1: ReviewCard.grade(null, 1, Grade.good, today)},
    );
    expect(plan.nextNew(42), 2);
    expect(plan.daysUntilNew(today), 2);
    expect(plan.daysUntilNew(today + 1), 1);
    expect(plan.daysUntilNew(today + 5), 0);
  });

  test('due lists the most overdue first', () {
    final plan = Plan(
      cards: {
        for (final (n, due) in [(1, today - 3), (2, today), (3, today + 1)])
          n: ReviewCard(number: n, stage: 1, dueDay: due, startedDay: 0),
      },
    );
    expect(plan.due(today).map((c) => c.number), [1, 2]);
  });

  test('all started means no next new hadith', () {
    final plan = Plan(
      cards: {
        for (var n = 1; n <= 3; n++)
          n: ReviewCard(number: n, stage: 0, dueDay: 0, startedDay: 0),
      },
    );
    expect(plan.nextNew(3), isNull);
  });

  test('dayNumber counts calendar days', () {
    expect(
      dayNumber(DateTime(2026, 11, 5, 0, 1)) -
          dayNumber(DateTime(2026, 11, 4, 23, 59)),
      1,
    );
  });
}
