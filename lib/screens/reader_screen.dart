import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/card_store.dart';
import '../services/models.dart';
import '../services/text_utils.dart';
import '../widgets/word_sheet.dart';
import '../services/errors.dart';

class ReaderScreen extends StatefulWidget {
  final ReadingItem item;
  const ReaderScreen({super.key, required this.item});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<ReadingText> _future = widget.item.load();
  double _fontSize = 19;

  /// Forms of saved flashcard words, highlighted in the text.
  Set<String> _marked = const {};

  @override
  void initState() {
    super.initState();
    _loadMarked();
  }

  Future<void> _loadMarked() async {
    final forms = await CardStore().highlightForms();
    if (mounted) setState(() => _marked = forms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            icon: const Icon(Icons.text_decrease),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize - 1).clamp(14, 30)),
          ),
          IconButton(
            tooltip: 'Larger text',
            icon: const Icon(Icons.text_increase),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize + 1).clamp(14, 30)),
          ),
        ],
      ),
      body: FutureBuilder<ReadingText>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friendlyError(snap.error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          setState(() => _future = widget.item.load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _ReaderBody(
            text: snap.data!,
            fontSize: _fontSize,
            marked: _marked,
            onSheetClosed: _loadMarked,
          );
        },
      ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  final ReadingText text;
  final double fontSize;
  final Set<String> marked;
  final VoidCallback onSheetClosed;
  const _ReaderBody({
    required this.text,
    required this.fontSize,
    required this.marked,
    required this.onSheetClosed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        if (text.subtitle != null)
          Text(
            text.subtitle!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        const SizedBox(height: 4),
        Text(text.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Quelle: ${text.source}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 20),
        Text(
          'Tap any word for its meaning and grammar.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        for (final p in text.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TappableParagraph(
              paragraph: p,
              fontSize: fontSize,
              source: text.title,
              marked: marked,
              onSheetClosed: onSheetClosed,
            ),
          ),
      ],
    );
  }
}

/// A paragraph where every word is tappable.
class TappableParagraph extends StatefulWidget {
  final String paragraph;
  final double fontSize;
  final String source;

  /// Lowercase word forms to highlight (saved flashcards).
  final Set<String> marked;
  final VoidCallback? onSheetClosed;

  const TappableParagraph({
    super.key,
    required this.paragraph,
    required this.fontSize,
    required this.source,
    this.marked = const {},
    this.onSheetClosed,
  });

  @override
  State<TappableParagraph> createState() => _TappableParagraphState();
}

class _TappableParagraphState extends State<TappableParagraph> {
  late List<Token> _tokens;
  final _recognizers = <int, TapGestureRecognizer>{};
  int? _selected;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant TappableParagraph old) {
    super.didUpdateWidget(old);
    if (old.paragraph != widget.paragraph) {
      _disposeRecognizers();
      _build();
    }
  }

  void _build() {
    _tokens = tokenize(widget.paragraph);
    for (var i = 0; i < _tokens.length; i++) {
      if (_tokens[i].isWord) {
        _recognizers[i] = TapGestureRecognizer()..onTap = () => _onTap(i);
      }
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _onTap(int i) async {
    final t = _tokens[i];
    setState(() => _selected = i);
    final sentence = sentenceAt(widget.paragraph, t.start);
    final startsSentence = sentence
        .replaceFirst(RegExp(r'^[^\p{L}]+', unicode: true), '')
        .startsWith(t.text);
    await showWordSheet(
      context,
      word: t.text,
      sentence: sentence,
      source: widget.source,
      sentenceStart: startsSentence,
      separable: separableCandidates(widget.paragraph, t.start),
    );
    if (mounted) setState(() => _selected = null);
    widget.onSheetClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(fontSize: widget.fontSize, height: 1.6);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < _tokens.length; i++)
            TextSpan(
              text: _tokens[i].text,
              recognizer: _recognizers[i],
              style: i == _selected
                  ? TextStyle(backgroundColor: scheme.primaryContainer)
                  : _tokens[i].isWord &&
                        widget.marked.contains(_tokens[i].text.toLowerCase())
                  ? TextStyle(
                      backgroundColor: scheme.tertiaryContainer,
                      decoration: TextDecoration.underline,
                      decorationColor: scheme.tertiary,
                      decorationThickness: 2,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
