import 'package:flutter/material.dart';

import '../services/card_store.dart';
import '../services/common_words.dart';
import '../services/dictionary_service.dart';
import '../services/flashcards.dart';
import '../widgets/gender_badge.dart';
import 'review_screen.dart';

/// Flashcard hub: today's study session, adding common words, and the deck.
class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => WordsScreenState();
}

class WordsScreenState extends State<WordsScreen> {
  final _store = CardStore();
  final _dict = DictionaryService();
  late final _common = CommonWords(_dict, _store);
  bool _enriched = false;

  List<Flashcard>? _cards;
  DeckStats? _stats;
  int _newPerDay = CardStore.defaultNewPerDay;
  int _commonPos = 0;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    reload().then((_) => _enrichOldCards());
  }

  /// Cards saved by older versions lack article/forms: look them up once.
  Future<void> _enrichOldCards() async {
    if (_enriched) return;
    _enriched = true;
    try {
      if (await _store.enrichIncomplete(_dict) > 0) await reload();
    } catch (_) {
      // Offline or rate-limited: try again next time the app starts.
    }
  }

  Future<void> reload() async {
    final cards = await _store.all();
    final stats = await _store.stats();
    final perDay = await _store.newPerDay();
    final pos = await _common.position();
    if (!mounted) return;
    setState(() {
      _cards = cards..sort((a, b) => b.added.compareTo(a.added));
      _stats = stats;
      _newPerDay = perDay;
      _commonPos = pos;
    });
  }

  Future<void> _study() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReviewScreen()));
    reload();
  }

  Future<void> _addCommon() async {
    if (_commonPos == 0 &&
        !(_cards ?? []).any((c) => c.source.startsWith('Häufige'))) {
      final start = await _chooseStart();
      if (start == null) return;
      await _common.setPosition(start);
    }
    setState(() => _adding = true);
    try {
      final added = await _common.addNext(10);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added.isEmpty
                  ? 'No new words found.'
                  : 'Added ${added.length}: ${added.map((c) => c.word).join(', ')}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add words: $e')));
      }
    }
    if (mounted) setState(() => _adding = false);
    reload();
  }

  Future<int?> _chooseStart() => showDialog<int>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Where should the common words start?'),
      children: [
        for (final (rank, label, hint) in [
          (0, 'Von Anfang an', 'ich, und, sein … (A1)'),
          (300, 'Ab Wort 300', 'already know the basics (A2)'),
          (1000, 'Ab Wort 1000', 'intermediate (B1)'),
          (2500, 'Ab Wort 2500', 'upper intermediate (B2)'),
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, rank),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: Text(hint),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final stats = _stats;
    if (cards == null || stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final toStudy = stats.due + stats.newAvailable;

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Today's session
          Card(
            color: theme.colorScheme.primaryContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heute lernen',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stat(value: stats.due, label: 'fällig'),
                      _Stat(value: stats.newAvailable, label: 'neu'),
                      _Stat(
                        value: stats.review + stats.learning,
                        label: 'gelernt',
                      ),
                      _Stat(value: stats.known, label: 'gekannt'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.school_outlined),
                      label: Text(
                        toStudy == 0
                            ? 'Alles erledigt für heute'
                            : 'Lernen ($toStudy Karten)',
                      ),
                      onPressed: toStudy == 0 ? null : _study,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Adding words
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Häufige Wörter', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    _commonPos == 0
                        ? 'Add the most frequent German words, with article, plural and meaning.'
                        : 'Next: word #${_commonPos + 1} of the frequency list.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        icon: _adding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('10 Wörter'),
                        onPressed: _adding ? null : _addCommon,
                      ),
                      const Spacer(),
                      Text('Neu pro Tag ', style: theme.textTheme.bodySmall),
                      DropdownButton<int>(
                        value: _newPerDay,
                        underline: const SizedBox(),
                        items: [5, 10, 15, 20, 30]
                            .map(
                              (n) =>
                                  DropdownMenuItem(value: n, child: Text('$n')),
                            )
                            .toList(),
                        onChanged: (n) async {
                          if (n == null) return;
                          await _store.setNewPerDay(n);
                          reload();
                        },
                      ),
                    ],
                  ),
                  Text(
                    'Tip: words you save while reading become cards too.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Alle Karten (${cards.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No cards yet. Add common words above, or tap a word '
                'while reading and press the bookmark.',
              ),
            ),
          for (final c in cards)
            Dismissible(
              key: ValueKey(c.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: theme.colorScheme.errorContainer,
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) async {
                await _store.remove(c.id);
                reload();
              },
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    for (final g in c.genders) ...[
                      GenderBadge(g, style: theme.textTheme.labelMedium),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(c.word, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                subtitle: Text(
                  c.english.isNotEmpty ? c.english : (c.meaning ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _status(c),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _status(Flashcard c) {
    switch (c.state) {
      case CardState.fresh:
        return 'neu';
      case CardState.known:
        return 'gekannt';
      case CardState.learning:
        return 'lernen';
      case CardState.review:
        final d = c.due.difference(DateTime.now());
        return d.isNegative ? 'fällig' : 'in ${Scheduler.describe(d)}';
    }
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
