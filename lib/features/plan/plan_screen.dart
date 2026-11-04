import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../data/hadith_repository.dart';
import '../../l10n/app_localizations.dart';
import '../arabic_numbers.dart';
import '../memorize/memorize_screen.dart';
import 'plan_controller.dart';
import 'review_schedule.dart';

/// The memorization plan: today's new hadith, today's reviews, progress,
/// and how often to start a new hadith.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final book = ref.watch(bookProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.planTitle)),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(s.loadError)),
        data: (book) => _PlanBody(book: book),
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider);
    final today = dayNumber(ref.watch(clockProvider)());
    final total = book.ahadith.length;
    final nextNew = plan.nextNew(total);
    final wait = plan.daysUntilNew(today);
    final due = plan.due(today);
    Hadith hadith(int number) =>
        book.ahadith.firstWhere((h) => h.number == number);

    void open(int number) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemorizeScreen(hadith: hadith(number)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.planProgress(
                    arabicNumber(plan.cards.length),
                    arabicNumber(total),
                    arabicNumber(plan.memorizedCount),
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: plan.memorizedCount / total,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(s.memorizedMeaning, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(s.newHadithTitle, style: theme.textTheme.titleMedium),
        if (nextNew == null)
          ListTile(title: Text(s.allStarted))
        else if (wait == 0)
          ListTile(
            key: const ValueKey('plan-new'),
            leading: _NumberBadge(nextNew),
            title: Text(hadith(nextNew).title),
            subtitle: Text(s.startMemorizing),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(nextNew),
          )
        else
          ListTile(
            leading: _NumberBadge(nextNew),
            title: Text(hadith(nextNew).title),
            subtitle: Text(s.newHadithIn(wait, arabicNumber(wait))),
          ),
        const SizedBox(height: 8),
        Text(
          s.reviewTodayTitle(arabicNumber(due.length)),
          style: theme.textTheme.titleMedium,
        ),
        if (due.isEmpty)
          ListTile(title: Text(s.noReviewToday))
        else
          for (final card in due)
            ListTile(
              key: ValueKey('plan-due-${card.number}'),
              leading: _NumberBadge(card.number),
              title: Text(hadith(card.number).title),
              subtitle: card.dueDay < today
                  ? Text(
                      s.overdueBy(
                        today - card.dueDay,
                        arabicNumber(today - card.dueDay),
                      ),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(card.number),
            ),
        const Divider(height: 32),
        Text(s.paceTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final d in Plan.paceChoices)
              ButtonSegment(
                value: d,
                label: Text(
                  d == 7 ? s.paceWeek : s.paceDays(d, arabicNumber(d)),
                ),
              ),
          ],
          selected: {plan.paceDays},
          onSelectionChanged: (v) =>
              ref.read(planProvider.notifier).setPace(v.single),
        ),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(arabicNumber(number)),
    );
  }
}
