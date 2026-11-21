import 'package:flutter/material.dart';

import '../services/grammar_service.dart';
import '../services/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SettingsStore();
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _store.getApiKey().then((k) {
      if (mounted && k != null) _controller.text = k;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _store.setApiKey(_controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Grammar explanations', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tapping "Explain grammar" sends the sentence to Claude '
            '(${GrammarService.model}). Paste an Anthropic API key from '
            'console.anthropic.com. Each explanation costs a fraction of a cent. '
            'The key is stored only on this device.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Anthropic API key',
              hintText: 'sk-ant-…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _controller.clear();
                _save();
              },
              child: const Text('Remove key'),
            ),
          ]),
          const SizedBox(height: 32),
          Text('Sources', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('News: tagesschau.de API\n'
              'Stories: Brüder Grimm via de.wikisource.org (public domain)\n'
              'Dictionary: de.wiktionary.org, en.wiktionary.org (CC BY-SA)\n'
              'Common words: FrequencyWords by Hermit Dave, OpenSubtitles 2018 (CC BY-SA 4.0)'),
        ],
      ),
    );
  }
}
