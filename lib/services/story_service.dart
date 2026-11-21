import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'wikimedia.dart';

/// Public-domain Grimm fairy tales (1857 edition) from German Wikisource.
///
/// The 1857 texts use older spelling (e.g. "daß", "Thür").
class StoryService {
  static const _api = 'https://de.wikisource.org/w/api.php';

  /// Well-known tales written in standard German (many others are dialect).
  static const titles = [
    'Der süße Brei (1857)',
    'Die Sternthaler (1857)',
    'Rothkäppchen (1857)',
    'Die Bremer Stadtmusikanten (1857)',
    'Frau Holle (1857)',
    'Der Wolf und die sieben jungen Geislein (1857)',
    'Rumpelstilzchen (1857)',
    'Dornröschen (1857)',
    'Hänsel und Grethel (1857)',
    'Der Froschkönig oder der eiserne Heinrich (1857)',
    'Rapunzel (1857)',
    'Aschenputtel (1857)',
    'Sneewittchen (1857)',
    'Schneeweißchen und Rosenroth (1857)',
    'Das Lumpengesindel (1857)',
  ];

  static String displayTitle(String title) =>
      title.replaceAll(RegExp(r'\s*\(\d{4}\)$'), '');

  /// A different story each day, cycling through [titles].
  static String storyOfTheDay([DateTime? now]) {
    final d = now ?? DateTime.now();
    final day = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(2024))
        .inDays;
    return titles[day % titles.length];
  }

  List<ReadingItem> listStories() => [
        for (final t in titles)
          ReadingItem(
            title: displayTitle(t),
            subtitle: 'Brüder Grimm',
            load: () => fetchStory(t),
          ),
      ];

  Future<ReadingText> fetchStory(String title) async {
    final paragraphs = await _cachedParagraphs(title) ?? await _download(title);
    return ReadingText(
      title: displayTitle(title),
      subtitle: 'Brüder Grimm, Kinder- und Hausmärchen (1857)',
      source: 'de.wikisource.org',
      url: 'https://de.wikisource.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
      paragraphs: paragraphs,
    );
  }

  // The texts never change, so keep each story on the device after first load.
  static String _cacheKey(String title) => 'story:$title';

  Future<List<String>?> _cachedParagraphs(String title) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getStringList(_cacheKey(title));
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _download(String title) async {
    final uri = Uri.parse(_api).replace(queryParameters: {
      'action': 'parse',
      'page': title,
      'prop': 'text',
      'format': 'json',
      'formatversion': '2',
      'disablelimitreport': '1',
      'origin': '*',
    });
    var res = await http.get(uri, headers: wikimediaHeaders);
    if (res.statusCode == 429) {
      // Wikisource throttles its parse endpoint; wait once and retry.
      final wait = int.tryParse(res.headers['retry-after'] ?? '') ?? 3;
      await Future.delayed(Duration(seconds: wait.clamp(1, 10)));
      res = await http.get(uri, headers: wikimediaHeaders);
    }
    if (res.statusCode == 429) {
      throw Exception('Wikisource is busy — try again in a minute.');
    }
    if (res.statusCode != 200) {
      throw Exception('Story request failed (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final html = data['parse']?['text'] as String?;
    if (html == null) throw Exception('Story "$title" not found');

    final doc = html_parser.parseFragment(html);
    // Drop the metadata box, navigation and footnotes.
    for (final sel in ['#textdaten', 'table', '.noprint', 'sup', '.reference', 'style']) {
      for (final el in doc.querySelectorAll(sel)) {
        el.remove();
      }
    }
    final paragraphs = doc
        .querySelectorAll('p')
        .map((p) => p.text.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((t) => t.length > 1)
        .toList();

    if (paragraphs.isNotEmpty) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setStringList(_cacheKey(title), paragraphs);
      } catch (_) {}
    }
    return paragraphs;
  }
}
