import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../services/card_store.dart';
import '../services/dictionary_service.dart';
import '../services/flashcards.dart';
import '../services/grammar_service.dart';
import '../services/settings_store.dart';
import 'gender_badge.dart';

final _dictionary = DictionaryService();
final _grammar = GrammarService();
final _store = SettingsStore();
final _cards = CardStore();

Future<void> showWordSheet(
  BuildContext context, {
  required String word,
  required String sentence,
  required String source,
  bool sentenceStart = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) => WordSheet(
        word: word,
        sentence: sentence,
        source: source,
        sentenceStart: sentenceStart,
        controller: controller,
      ),
    ),
  );
}

class WordSheet extends StatefulWidget {
  final String word;
  final String sentence;
  final String source;
  final bool sentenceStart;
  final ScrollController controller;

  const WordSheet({
    super.key,
    required this.word,
    required this.sentence,
    required this.source,
    this.sentenceStart = false,
    required this.controller,
  });

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  late final Future<DictResult> _dict = _dictionary.lookup(
    widget.word,
    sentenceStart: widget.sentenceStart,
  );
  Future<String>? _explanation;
  bool _saved = false;

  Future<void> _explain() async {
    final key = await _store.getApiKey();
    if (!mounted) return;
    if (key == null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('API key needed'),
          content: const Text(
              'Grammar explanations use Claude. Add your Anthropic API key in Settings.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Settings')),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
      return;
    }
    setState(() {
      _explanation = _grammar.explain(
        apiKey: key,
        word: widget.word,
        sentence: widget.sentence,
      );
    });
  }

  Future<void> _save(DictResult? r) async {
    final main = r?.main;
    if (main == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No dictionary entry — nothing to put on a card.')));
      return;
    }
    await _cards.add(Flashcard.fromEntry(
      main,
      example: widget.sentence,
      source: widget.source,
    ));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${main.headword}" added to your flashcards')),
    );
  }

  @override
  void initState() {
    super.initState();
    // Show the bookmark as filled if the base word is already a card.
    _dict.then((r) async {
      final main = r.main;
      if (main != null && await _cards.contains(Flashcard.keyFor(main.word)) && mounted) {
        setState(() => _saved = true);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<DictResult>(
      future: _dict,
      builder: (context, snap) {
        return ListView(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.word, style: theme.textTheme.headlineMedium),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add to flashcards',
                  icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_add_outlined),
                  onPressed: _saved ? null : () => _save(snap.data),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.sentence,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 16),
            Text('Wörterbuch', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (snap.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (snap.hasError)
              Text('Dictionary lookup failed: ${snap.error}')
            else if (snap.data!.isEmpty)
              const Text('No dictionary entry found. Try the grammar explanation below.')
            else ...[
              ..._dictionaryViews(snap.data!),
              Text('Source: de.wiktionary.org (CC BY-SA)', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 20),
            Text('Grammatik', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_explanation == null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Explain grammar in this sentence'),
                  onPressed: _explain,
                ),
              )
            else
              FutureBuilder<String>(
                future: _explanation,
                builder: (context, g) {
                  if (g.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Asking Claude…'),
                      ]),
                    );
                  }
                  if (g.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g.error}', style: TextStyle(color: theme.colorScheme.error)),
                        TextButton(onPressed: _explain, child: const Text('Try again')),
                      ],
                    );
                  }
                  return SelectableText(g.data!, style: theme.textTheme.bodyMedium);
                },
              ),
          ],
        );
      },
    );
  }
}

List<Widget> _dictionaryViews(DictResult r) {
  final own = r.fullEntries;
  final forms = r.entries.where((e) => e.isInflectedForm).toList();
  final viaLemma = [
    for (final f in forms) _FormNote(entry: f),
    for (final e in r.lemmaEntries) _EntryView(entry: e),
  ];
  final ownViews = [for (final e in own) _EntryView(entry: e)];
  final first = r.lemmaFirst ? viaLemma : ownViews;
  final second = r.lemmaFirst ? ownViews : (r.lemmaEntries.isEmpty ? <Widget>[] : viaLemma);
  return [
    ...first,
    if (first.isNotEmpty && second.isNotEmpty) const _AlsoDivider(),
    ...second,
  ];
}

class _AlsoDivider extends StatelessWidget {
  const _AlsoDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text('Auch möglich', style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

/// "ging → 1. Person Singular Indikativ Präteritum Aktiv des Verbs gehen"
class _FormNote extends StatelessWidget {
  final GermanEntry entry;
  const _FormNote({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = entry.grammarNotes.isEmpty
        ? ['${entry.wordType} von ${entry.lemma}']
        : entry.grammarNotes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Form: ${entry.word} → ${entry.lemma}', style: theme.textTheme.labelLarge),
            for (final n in notes.take(4))
              Text('• $n', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EntryView extends StatelessWidget {
  final GermanEntry entry;
  const _EntryView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forms = <(String, String)>[
      if (entry.pluralWithArticle != null) ('Plural', entry.pluralWithArticle!),
      if (entry.genitiveWithArticle != null) ('Genitiv', entry.genitiveWithArticle!),
      if (entry.verbForms != null) ('Formen', entry.verbForms!),
      if (entry.adjectiveForms != null) ('Steigerung', entry.adjectiveForms!),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in entry.genders) GenderBadge(g),
              Text(entry.word, style: theme.textTheme.titleLarge),
              Text(entry.wordType,
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          if (forms.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final (label, value) in forms)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$label: ',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ])),
              ),
          ],
          if (entry.english.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('🇬🇧 ${entry.english.take(8).join(', ')}',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
          if (entry.meanings.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final (i, m) in entry.meanings.take(5).indexed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${i + 1}. $m', style: theme.textTheme.bodyMedium),
              ),
            if (entry.meanings.length > 5)
              Text('… ${entry.meanings.length - 5} weitere Bedeutungen',
                  style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
