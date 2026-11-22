import 'dart:convert';

import 'package:http/http.dart' as http;

class GrammarException implements Exception {
  final String message;
  GrammarException(this.message);
  @override
  String toString() => message;
}

/// Explains the grammar of a German sentence via the Claude API (raw HTTP —
/// there is no official Dart SDK). Uses the user's own API key.
class GrammarService {
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const model = 'claude-opus-5-5';

  static const _system = '''
You are a patient German tutor for an English-speaking learner (around A2–B1).
The learner tapped a word while reading and wants to understand it in context.
Answer in English, concise, using Markdown-free plain text with short headings
in CAPS and "-" bullets. Cover:
WORD: the base form (with article and plural for nouns; infinitive and
principal parts for verbs), and its exact form here (case, number, gender,
person, tense, mood, as relevant) and why it has that form.
MEANING: what it means in this sentence.
SENTENCE: a natural English translation.
GRAMMAR: the structure — verb position, separable verbs, cases triggered by
prepositions or verbs, subordinate clauses, word order, idioms. Only what is
actually present; keep it short.
If the text uses older spelling (e.g. "daß", "Thür"), mention the modern spelling.''';

  Future<String> explain({
    required String apiKey,
    required String word,
    required String sentence,
  }) async {
    final http.Response res;
    try {
      res = await http.post(
        Uri.parse(_url),
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2026-10-21',
          // Re-run on another model if a safety classifier declines.
          'anthropic-beta': 'server-side-fallback-2026-07-01',
          // Needed for the web build (calls straight from the browser).
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 16000,
          'fallbacks': 'default',
          // Short tutoring answers don't need deep thinking.
          'output_config': {'effort': 'low'},
          'system': _system,
          'messages': [
            {
              'role': 'user',
              'content': 'Sentence: $sentence\nTapped word: $word',
            },
          ],
        }),
      );
    } catch (e) {
      throw GrammarException('Network error: $e');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final msg = body['error']?['message'] ?? 'HTTP ${res.statusCode}';
      throw GrammarException(switch (res.statusCode) {
        401 => 'Invalid API key. Check it in Settings.',
        429 => 'Rate limited — try again in a moment.',
        _ => 'Claude API error: $msg',
      });
    }
    if (body['stop_reason'] == 'refusal') {
      throw GrammarException('Claude declined to answer this one.');
    }
    final text = (body['content'] as List)
        .cast<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n')
        .trim();
    if (text.isEmpty) throw GrammarException('Empty response from Claude.');
    return text;
  }
}
