import 'package:flutter/material.dart';

import 'news_screen.dart';
import 'settings_screen.dart';
import 'stories_screen.dart';
import 'words_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _wordsKey = GlobalKey<WordsScreenState>();

  static const _titles = ['Heute', 'Geschichten', 'Karteikarten'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const NewsScreen(),
          const StoriesScreen(),
          WordsScreen(key: _wordsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 2) _wordsKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), label: 'News'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Stories'),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Cards'),
        ],
      ),
    );
  }
}
