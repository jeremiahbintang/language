import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'text_utils.dart';

/// German news and commentary from the public tagesschau.de API.
///
/// Note: tagesschau.de does not send CORS headers, so this works in the
/// Android app but not in a browser without a proxy.
class NewsService {
  static const _api = 'https://www.tagesschau.de/api2u';

  /// The editors' top stories (homepage order), followed by other national
  /// stories as backup for "show more". Regional news, weather and
  /// commentaries are left out.
  Future<List<ReadingItem>> fetchTopStories() async {
    final results = await Future.wait([
      _getJson('$_api/homepage/'),
      _getJson('$_api/news/').catchError((_) => <String, dynamic>{}),
    ]);
    final homepage = _items(results[0]['news']);
    final national = _items(results[1]['news'])
        .where((n) => n['regionId'] == 0 || n['regionId'] == null);

    final seen = <String>{};
    final stories = <ReadingItem>[];
    for (final n in [...homepage, ...national]) {
      final id = n['sophoraId'] as String? ?? n['details'] as String;
      if (!seen.add(id) || _isWeather(n) || _isCommentary(n)) continue;
      stories.add(_toItem(n));
    }
    return stories;
  }

  /// Opinion pieces ("Kommentare"), newest first. [page] starts at 0.
  Future<List<ReadingItem>> fetchCommentaries({int page = 0}) async {
    final data = await _getJson(
        '$_api/search/?searchText=Kommentar&resultPage=$page&pageSize=20');
    return _items(data['searchResults'])
        .where(_isCommentary)
        .map((n) => _toItem(n, label: 'Kommentar'))
        .toList();
  }

  static List<Map<String, dynamic>> _items(dynamic list) => (list as List? ?? [])
      .cast<Map<String, dynamic>>()
      .where((n) => n['type'] == 'story' && n['details'] is String)
      .toList();

  static bool _isCommentary(Map<String, dynamic> n) {
    final tracking = n['tracking'];
    return tracking is List &&
        tracking.any((t) => t is Map && t['ctp'] == 'KOMMENTAR');
  }

  static bool _isWeather(Map<String, dynamic> n) =>
      (n['tags'] as List? ?? []).any((t) => t is Map && t['tag'] == 'Wetter');

  ReadingItem _toItem(Map<String, dynamic> n, {String? label}) {
    final details = n['details'] as String;
    final image = n['teaserImage']?['imageVariants']?['1x1-256'] as String?;
    return ReadingItem(
      title: n['title'] as String? ?? '',
      subtitle: n['topline'] as String?,
      teaser: n['firstSentence'] as String?,
      label: label,
      imageUrl: image,
      date: DateTime.tryParse(n['date'] as String? ?? ''),
      load: () => _fetchArticle(details, n['shareURL'] as String?),
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('News request failed (${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<ReadingText> _fetchArticle(String detailsUrl, String? shareUrl) async {
    final data = await _getJson(detailsUrl);
    final content = (data['content'] as List? ?? []).cast<Map<String, dynamic>>();

    final paragraphs = <String>[];
    for (final block in content) {
      final type = block['type'];
      if ((type == 'text' || type == 'headline') && block['value'] is String) {
        final text = htmlToText(block['value'] as String);
        if (text.isNotEmpty) paragraphs.add(text);
      }
    }

    return ReadingText(
      title: data['title'] as String? ?? '',
      subtitle: data['topline'] as String?,
      source: 'tagesschau.de',
      url: shareUrl,
      paragraphs: paragraphs,
    );
  }
}
