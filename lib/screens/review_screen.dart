import 'package:flutter/material.dart';

import '../services/card_store.dart';
import '../services/flashcards.dart';
import '../widgets/gender_badge.dart';

/// A study session: due cards first, then today's new cards.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _store = CardStore();
  List<Flashcard>? _queue;
  bool _revealed = false;
  int _done = 0;

  /// Cards answered "again"/"hard" come back if due within this window.
  static const _learnAhead = Duration(minutes: 20);

  @override
  void initState() {
    super.initState();
    _store.sessionQueue().then((q) {
      if (mounted) setState(() => _queue = q);
    });
  }

  Future<void> _answer(Grade grade) async {
    final queue = _queue!;
    final card = queue.removeAt(0);
    final now = DateTime.now();
    if (card.state == CardState.fresh) await _store.countNewIntroduced();
    final record = Scheduler.answer(card, grade, now);
    await _store.update(card);
    await _store.logReview(record);
    if (card.due.isBefore(now.add(_learnAhead))) {
      // Still learning: show it again later in this session.
      queue.add(card);
    }
    setState(() {
      _revealed = false;
      _done++;
    });
  }

  Future<void> _markKnown() async {
    final card = _queue!.removeAt(0);
    if (card.state == CardState.fresh) await _store.countNewIntroduced();
    card.known = true;
    await _store.update(card);
    setState(() {
      _revealed = false;
      _done++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          queue == null || queue.isEmpty ? 'Lernen' : '${queue.length} übrig',
        ),
      ),
      body: queue == null
          ? const Center(child: CircularProgressIndicator())
          : queue.isEmpty
          ? _Finished(done: _done)
          : _CardView(
              card: queue.first,
              revealed: _revealed,
              onReveal: () => setState(() => _revealed = true),
              onAnswer: _answer,
              onKnown: _markKnown,
            ),
    );
  }
}

class _CardView extends StatelessWidget {
  final Flashcard card;
  final bool revealed;
  final VoidCallback onReveal;
  final ValueChanged<Grade> onAnswer;
  final VoidCallback onKnown;

  const _CardView({
    required this.card,
    required this.revealed,
    required this.onReveal,
    required this.onAnswer,
    required this.onKnown,
  });

  String get _prompt {
    if (card.genders.isNotEmpty || card.wordType == 'Substantiv') {
      return 'Artikel · Plural · Bedeutung?';
    }
    if (card.wordType == 'Verb') return 'Bedeutung · Präteritum · Perfekt?';
    return 'Bedeutung?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              children: [
                Text(
                  card.wordType,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // Front: the bare word (no article — that's part of the answer).
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    if (revealed)
                      for (final g in card.genders)
                        GenderBadge(g, style: theme.textTheme.headlineSmall),
                    Text(
                      card.word,
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (!revealed) ...[
                  const SizedBox(height: 16),
                  Text(
                    _prompt,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (revealed) ...[
                  if (card.forms != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.forms!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (card.english.isNotEmpty)
                    Text(
                      card.english,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (card.meaning != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.meaning!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (card.example != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        card.example!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    card.source,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: !revealed
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: onReveal,
                          child: const Text('Antwort zeigen'),
                        ),
                      ),
                      TextButton(
                        onPressed: onKnown,
                        child: const Text('Kenne ich schon'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      for (final (grade, label, color) in [
                        (Grade.again, 'Nochmal', theme.colorScheme.error),
                        (Grade.hard, 'Schwer', Colors.orange.shade700),
                        (Grade.good, 'Gut', Colors.green.shade700),
                        (Grade.easy, 'Leicht', Colors.blue.shade700),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => onAnswer(grade),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(label),
                                  Text(
                                    Scheduler.describe(
                                      Scheduler.preview(
                                        card,
                                        grade,
                                        now,
                                      ).difference(now),
                                    ),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  final int done;
  const _Finished({required this.done});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Fertig für heute!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '$done Antworten. Come back tomorrow for your next reviews.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zurück'),
            ),
          ],
        ),
      ),
    );
  }
}
