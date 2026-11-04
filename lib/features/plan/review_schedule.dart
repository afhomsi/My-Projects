/// Spaced repetition for the memorization plan.
///
/// Each hadith the user has started has a [ReviewCard]. After every
/// recitation the user grades themself, and the card moves up or down a
/// ladder of intervals: 1, 2, 4, 7, 15, 30, 60, then 120 days.
library;

const reviewIntervals = [1, 2, 4, 7, 15, 30, 60, 120];

/// From this stage on (15 days or more) a hadith counts as memorized.
const memorizedStage = 4;

/// How a recitation went, as judged by the user.
enum Grade {
  /// Could not recite it: start again from tomorrow.
  again,

  /// Recited with effort or a few slips: keep the same interval.
  hard,

  /// Recited well: move to the next, longer interval.
  good,
}

/// Days since 1970-01-01 for the local calendar date of [time].
int dayNumber(DateTime time) =>
    DateTime.utc(time.year, time.month, time.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

class ReviewCard {
  const ReviewCard({
    required this.number,
    required this.stage,
    required this.dueDay,
    required this.startedDay,
  });

  factory ReviewCard.fromJson(Map<String, dynamic> json) => ReviewCard(
    number: json['number'] as int,
    stage: json['stage'] as int,
    dueDay: json['due'] as int,
    startedDay: json['started'] as int,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'stage': stage,
    'due': dueDay,
    'started': startedDay,
  };

  /// The hadith number, 1 to 42.
  final int number;

  /// Position on [reviewIntervals]; 0 for a hadith just started.
  final int stage;

  /// The day (see [dayNumber]) the next review is due.
  final int dueDay;

  /// The day the user started memorizing this hadith.
  final int startedDay;

  bool get isMemorized => stage >= memorizedStage;

  bool isDue(int today) => dueDay <= today;

  /// The card after a recitation graded [grade] on [today]. A null [card]
  /// means the hadith is being recited for the first time.
  static ReviewCard grade(
    ReviewCard? card,
    int number,
    Grade grade,
    int today,
  ) {
    final stage = card?.stage ?? 0;
    final next = switch (grade) {
      Grade.again => 0,
      Grade.hard => stage,
      Grade.good => (stage + 1).clamp(0, reviewIntervals.length - 1),
    };
    return ReviewCard(
      number: number,
      stage: next,
      dueDay: today + reviewIntervals[next],
      startedDay: card?.startedDay ?? today,
    );
  }
}

/// The user's plan: how often to start a new hadith, and their cards.
class Plan {
  const Plan({this.paceDays = 2, this.cards = const {}});

  /// Start a new hadith every [paceDays] days.
  final int paceDays;
  final Map<int, ReviewCard> cards;

  static const paceChoices = [1, 2, 3, 7];

  Plan copyWith({int? paceDays, Map<int, ReviewCard>? cards}) =>
      Plan(paceDays: paceDays ?? this.paceDays, cards: cards ?? this.cards);

  int get memorizedCount => cards.values.where((c) => c.isMemorized).length;

  /// The lowest-numbered hadith not started yet, or null when all are.
  int? nextNew(int total) {
    for (var n = 1; n <= total; n++) {
      if (!cards.containsKey(n)) return n;
    }
    return null;
  }

  /// Days left before the next new hadith is due; 0 means today.
  int daysUntilNew(int today) {
    if (cards.isEmpty) return 0;
    final last = cards.values
        .map((c) => c.startedDay)
        .reduce((a, b) => a > b ? a : b);
    final wait = last + paceDays - today;
    return wait < 0 ? 0 : wait;
  }

  /// Cards due for review on [today], the most overdue first.
  List<ReviewCard> due(int today) =>
      cards.values.where((c) => c.isDue(today)).toList()..sort(
        (a, b) => a.dueDay != b.dueDay
            ? a.dueDay.compareTo(b.dueDay)
            : a.number.compareTo(b.number),
      );
}
