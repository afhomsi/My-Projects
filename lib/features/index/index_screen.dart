import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../data/hadith_repository.dart';
import '../../l10n/app_localizations.dart';
import '../arabic_numbers.dart';
import '../hadith/hadith_screen.dart';

/// The table of contents: the book's title, then the 42 ahadith in order.
class IndexScreen extends ConsumerWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final book = ref.watch(bookProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.appTitle)),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(s.loadError)),
        data: (book) => _IndexList(book: book),
      ),
    );
  }
}

class _IndexList extends StatelessWidget {
  const _IndexList({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: book.ahadith.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              children: [
                Text(
                  book.title,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  book.author,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${s.indexTitle} · '
                  '${s.ahadithCount(arabicNumber(book.ahadith.length))}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (book.isDraft) ...[
                  const SizedBox(height: 12),
                  DraftNotice(text: s.draftNotice),
                ],
              ],
            ),
          );
        }
        final hadith = book.ahadith[i - 1];
        return ListTile(
          key: ValueKey('hadith-${hadith.number}'),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(arabicNumber(hadith.number)),
          ),
          title: Text(hadith.title),
          subtitle: Text(hadith.narrator),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HadithScreen(book: book, initialIndex: i - 1),
            ),
          ),
        );
      },
    );
  }
}

/// A small banner saying the text has not been checked yet.
class DraftNotice extends StatelessWidget {
  const DraftNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
