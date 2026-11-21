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
