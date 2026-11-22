import 'package:flutter/material.dart';

import '../services/models.dart';
import '../services/story_service.dart';
import 'reader_screen.dart';

class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = StoryService();
    final todayTitle = StoryService.storyOfTheDay();
    final today = ReadingItem(
      title: StoryService.displayTitle(todayTitle),
      subtitle: 'Brüder Grimm',
      load: () => service.fetchStory(todayTitle),
    );
    final stories = service.listStories();
    final theme = Theme.of(context);

    void open(ReadingItem item) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ReaderScreen(item: item)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => open(today),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Märchen des Tages',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    today.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Alle Märchen', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Original 1857 texts — expect older spellings like "daß" and "Thür".',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final s in stories)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(s),
          ),
      ],
    );
  }
}
