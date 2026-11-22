import 'package:html/parser.dart' as html_parser;

/// Converts an HTML fragment to plain text, collapsing whitespace.
String htmlToText(String html) {
  final text = html_parser.parseFragment(html).text ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A word or a non-word chunk (spaces, punctuation) of a paragraph.
class Token {
  final String text;
  final bool isWord;
  final int start;
  const Token(this.text, this.isWord, this.start);
}

final _wordRe = RegExp(r"[\p{L}\p{M}]+(?:[-'’][\p{L}\p{M}]+)*", unicode: true);

List<Token> tokenize(String paragraph) {
  final tokens = <Token>[];
  var pos = 0;
  for (final m in _wordRe.allMatches(paragraph)) {
    if (m.start > pos) {
      tokens.add(Token(paragraph.substring(pos, m.start), false, pos));
    }
    tokens.add(Token(m.group(0)!, true, m.start));
    pos = m.end;
  }
  if (pos < paragraph.length) {
    tokens.add(Token(paragraph.substring(pos), false, pos));
  }
  return tokens;
}

/// Prefixes that split off separable verbs and move to the end of the clause
/// ("Er fängt morgen an" → anfangen).
const separablePrefixes = {
  'ab',
  'an',
  'auf',
  'aus',
  'bei',
  'dar',
  'durch',
  'ein',
  'empor',
  'entgegen',
  'fest',
  'fort',
  'frei',
  'gegenüber',
  'heim',
  'her',
  'herab',
  'heran',
  'herauf',
  'heraus',
  'herbei',
  'herein',
  'herüber',
  'herum',
  'herunter',
  'hervor',
  'hin',
  'hinab',
  'hinauf',
  'hinaus',
  'hinein',
  'hinüber',
  'hinunter',
  'hinzu',
  'kennen',
  'los',
  'mit',
  'nach',
  'nieder',
  'statt',
  'teil',
  'über',
  'um',
  'unter',
  'voran',
  'voraus',
  'vorbei',
  'vorüber',
  'vor',
  'weg',
  'weiter',
  'wieder',
  'zu',
  'zurecht',
  'zurück',
  'zusammen',
};

/// Words that join two main clauses; a prefix can stand right before them
/// ("Er steht auf und geht weg").
const _clauseJoiners = {'und', 'oder', 'aber', 'sondern', 'denn', 'doch'};

final _clauseBreak = RegExp(r'''[,;:.!?…–—()"„“”»«]''');

/// (verb form, prefix) pairs that might form a separable verb with the word
/// at [offset], nearest first. Each pair still has to be confirmed by the
/// dictionary (e.g. "fängt" + "an" → "anfangen" exists).
List<(String verbForm, String prefix)> separableCandidates(
  String paragraph,
  int offset,
) {
  // The clause around the tapped word, bounded by punctuation.
  var start = 0;
  var end = paragraph.length;
  for (final m in _clauseBreak.allMatches(paragraph)) {
    if (m.end <= offset) {
      start = m.end;
    } else if (m.start >= offset) {
      end = m.start;
      break;
    }
  }
  final words = tokenize(paragraph.substring(start, end))
      .where((t) => t.isWord)
      .map((t) => (text: t.text, pos: start + t.start))
      .toList();
  final tapped = words.indexWhere(
    (w) => offset >= w.pos && offset < w.pos + w.text.length,
  );
  if (tapped < 0) return [];

  // A prefix sits at the end of its clause: last word, or just before "und"…
  bool isPrefixAt(int i) =>
      i > 0 &&
      separablePrefixes.contains(words[i].text.toLowerCase()) &&
      (i == words.length - 1 ||
          _clauseJoiners.contains(words[i + 1].text.toLowerCase()));

  if (isPrefixAt(tapped)) {
    // Tapped the prefix: the verb is somewhere before it, usually close.
    return [
      for (var i = tapped - 1; i >= 0; i--)
        if (!_clauseJoiners.contains(words[i].text.toLowerCase()) &&
            !separablePrefixes.contains(words[i].text.toLowerCase()))
          (words[i].text, words[tapped].text.toLowerCase()),
    ].take(8).toList();
  }
  // Tapped a (possible) verb: look for a prefix after it.
  return [
    for (var i = tapped + 1; i < words.length; i++)
      if (isPrefixAt(i)) (words[tapped].text, words[i].text.toLowerCase()),
  ];
}

/// Returns the sentence of [paragraph] containing character [offset].
String sentenceAt(String paragraph, int offset) {
  // Sentence ends: . ! ? … followed by whitespace (optionally after quotes).
  final ends = RegExp(r'''[.!?…]["“”„'»«)]*\s+''');
  var start = 0;
  for (final m in ends.allMatches(paragraph)) {
    if (m.end <= offset) {
      start = m.end;
    } else {
      return paragraph.substring(start, m.end).trim();
    }
  }
  return paragraph.substring(start).trim();
}
