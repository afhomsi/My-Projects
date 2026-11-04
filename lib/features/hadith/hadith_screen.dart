import 'package:flutter/material.dart';

import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../arabic_numbers.dart';

/// One page per hadith. Swipe, or use the buttons, to move between ahadith.
class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key, required this.book, this.initialIndex = 0});

  final Book book;
  final int initialIndex;

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ahadith = widget.book.ahadith;
    final current = ahadith[_index];
    return Scaffold(
      appBar: AppBar(title: Text(s.hadithNumber(arabicNumber(current.number)))),
      body: PageView.builder(
        controller: _controller,
        itemCount: ahadith.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => HadithPage(hadith: ahadith[i]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: Text(s.previous),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _index < ahadith.length - 1
                    ? () => _goTo(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: Text(s.next),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The content of one hadith: title, matn, narrator, takhreej, then sharh.
class HadithPage extends StatelessWidget {
  const HadithPage({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          hadith.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.narratorLabel(hadith.narrator),
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SelectableText(
          hadith.matn,
          style: matnStyle(context),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 20),
        _Section(
          title: s.sourceLabel,
          child: Text(hadith.source, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 12),
        _Section(
          title: s.sharhTitle,
          child: hadith.shuruh.isEmpty
              ? Text(
                  s.sharhComingSoon,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sharh in hadith.shuruh) ...[
                      Text(sharh.author, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(sharh.text, style: theme.textTheme.bodyLarge),
                      Text(sharh.source, style: theme.textTheme.bodySmall),
                      if (!sharh.isReviewed)
                        Text(
                          s.sharhDraftNotice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        if (!hadith.isChecked) ...[
          const SizedBox(height: 16),
          Text(
            s.draftNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
