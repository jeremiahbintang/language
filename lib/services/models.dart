/// A piece of German text to read: a news article or a story.
class ReadingText {
  final String title;
  final String? subtitle;
  final String source;
  final String? url;
  final List<String> paragraphs;

  const ReadingText({
    required this.title,
    this.subtitle,
    required this.source,
    this.url,
    required this.paragraphs,
  });
}

/// An entry in a list of readable items, loaded lazily when opened.
class ReadingItem {
  final String title;
  final String? subtitle;

  /// First sentence, shown as a preview.
  final String? teaser;

  /// Badge such as "Kommentar".
  final String? label;
  final String? imageUrl;
  final DateTime? date;
  final Future<ReadingText> Function() load;

  const ReadingItem({
    required this.title,
    this.subtitle,
    this.teaser,
    this.label,
    this.imageUrl,
    this.date,
    required this.load,
  });
}
