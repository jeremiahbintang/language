import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/models.dart';
import '../services/news_service.dart';
import 'reader_screen.dart';
import '../services/errors.dart';

/// Today's top stories and commentaries, a few at a time.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _service = NewsService();
  int _generation = 0; // bump to reload both sections

  Future<void> _refresh() async => setState(() => _generation++);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _PagedSection(
            key: ValueKey('top$_generation'),
            title: 'Top-Nachrichten',
            icon: Icons.newspaper_outlined,
            load: (page) async => page == 0 ? _service.fetchTopStories() : [],
          ),
          const SizedBox(height: 24),
          _PagedSection(
            key: ValueKey('opinion$_generation'),
            title: 'Kommentare',
            icon: Icons.record_voice_over_outlined,
            load: (page) => _service.fetchCommentaries(page: page),
          ),
        ],
      ),
    );
  }
}

/// Shows [step] items at first and [step] more per "Mehr anzeigen" tap,
/// fetching further pages from [load] when the loaded ones run out.
class _PagedSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Future<List<ReadingItem>> Function(int page) load;

  /// Items revealed initially and per "Mehr anzeigen" tap.
  static const step = 3;

  const _PagedSection({
    super.key,
    required this.title,
    required this.icon,
    required this.load,
  });

  @override
  State<_PagedSection> createState() => _PagedSectionState();
}

class _PagedSectionState extends State<_PagedSection> {
  final _items = <ReadingItem>[];
  final _titles = <String>{};
  int _shown = 0;
  int _nextPage = 0;
  bool _exhausted = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _showMore();
  }

  Future<void> _showMore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch pages until there are enough new items (a page can be empty
      // after filtering) or the source runs dry.
      var emptyPages = 0;
      while (!_exhausted &&
          _items.length < _shown + _PagedSection.step &&
          emptyPages < 3) {
        final page = await widget.load(_nextPage++);
        final fresh = page.where((i) => _titles.add(i.title)).toList();
        if (page.isEmpty) _exhausted = true;
        if (fresh.isEmpty) emptyPages++;
        _items.addAll(fresh);
      }
      _shown = (_shown + _PagedSection.step).clamp(0, _items.length);
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _hasMore => _shown < _items.length || !_exhausted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(widget.title, style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in _items.take(_shown))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NewsCard(item: item),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              kIsWeb
                  ? 'tagesschau.de can\'t be loaded directly in the browser '
                        '(no CORS). Use the Android app, or add a proxy.'
                  : friendlyError(_error!),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _showMore,
              child: const Text('Retry'),
            ),
          )
        else if (_hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.expand_more),
              label: const Text('Mehr anzeigen'),
              onPressed: _showMore,
            ),
          )
        else if (_items.isEmpty)
          const Text('Nothing here right now.'),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final ReadingItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ReaderScreen(item: item))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.label != null || item.subtitle != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            if (item.label != null)
                              TextSpan(
                                text: '${item.label!.toUpperCase()}  ',
                                style: TextStyle(
                                  color: theme.colorScheme.tertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (item.subtitle != null)
                              TextSpan(text: item.subtitle),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(item.title, style: theme.textTheme.titleMedium),
                    if (item.teaser != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.teaser!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.imageUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 76, height: 76),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
