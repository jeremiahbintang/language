/// Parses German Wiktionary (de.wiktionary.org) wikitext into learner-friendly
/// entries: article and plural for nouns, principal parts for verbs, comparison
/// for adjectives, German meanings and English translations.
class GermanEntry {
  final String word;

  /// Wortart, e.g. "Substantiv", "Verb", "Adjektiv", "Konjugierte Form".
  final String wordType;

  // Nouns
  final List<String> genders; // m, f, n
  final String? plural; // null if unknown, '—' if no plural
  final String? genitive;

  // Verbs
  final String? present3; // er/sie/es geht
  final String? preterite; // ging
  final String? participle; // gegangen
  final String? auxiliary; // haben / sein

  // Adjectives
  final String? comparative;
  final String? superlative;

  /// German definitions from {{Bedeutungen}}.
  final List<String> meanings;

  /// English translations from {{Übersetzungen}}.
  final List<String> english;

  /// For inflected forms: base word, and notes like "Genitiv Singular des Substantivs Haus".
  final String? lemma;
  final List<String> grammarNotes;

  /// Place or person name (Toponym, Vorname, Nachname, …).
  final bool isName;

  const GermanEntry({
    required this.word,
    required this.wordType,
    this.genders = const [],
    this.plural,
    this.genitive,
    this.present3,
    this.preterite,
    this.participle,
    this.auxiliary,
    this.comparative,
    this.superlative,
    this.meanings = const [],
    this.english = const [],
    this.lemma,
    this.grammarNotes = const [],
    this.isName = false,
  });

  bool get isNoun => genders.isNotEmpty || wordType == 'Substantiv';
  bool get isVerb => wordType == 'Verb';
  bool get isInflectedForm => lemma != null;

  /// "die Leitplanke", or "der/das Joghurt" for nouns; the bare word otherwise.
  String get headword {
    if (genders.isEmpty) return word;
    return '${genders.map(articleFor).join('/')} $word';
  }

  /// "die Leitplanken"; null when unknown, "kein Plural" when none.
  String? get pluralWithArticle {
    final p = plural;
    if (p == null) return null;
    if (p == '—' || p == '-' || p.isEmpty) return 'kein Plural';
    return 'die $p';
  }

  String? get genitiveWithArticle {
    final g = genitive;
    if (g == null || genders.isEmpty) return null;
    return '${genders.first == 'f' ? 'der' : 'des'} $g';
  }

  /// "geht · ging · ist gegangen"
  String? get verbForms {
    if (present3 == null && preterite == null && participle == null) {
      return null;
    }
    final aux = switch (auxiliary) {
      'sein' => 'ist ',
      'haben' => 'hat ',
      _ => '',
    };
    return [
      if (present3 != null) present3!,
      if (preterite != null) preterite!,
      if (participle != null) '$aux$participle',
    ].join(' · ');
  }

  /// "schön · schöner · am schönsten"
  String? get adjectiveForms {
    if (comparative == null && superlative == null) return null;
    return [
      word,
      if (comparative != null) comparative!,
      if (superlative != null) 'am $superlative',
    ].join(' · ');
  }
}

String articleFor(String genus) => switch (genus) {
  'm' => 'der',
  'f' => 'die',
  'n' => 'das',
  _ => genus,
};

/// Returns the entries of the German-language section, or [] if there is none.
List<GermanEntry> parseGermanEntries(String title, String wikitext) {
  final section = _germanSection(wikitext);
  if (section == null) return [];

  final entries = <GermanEntry>[];
  // Split into part-of-speech blocks at level-3 headings.
  final headings = RegExp(
    r'^===\s*([^=].*?)\s*===\s*$',
    multiLine: true,
  ).allMatches(section).toList();
  for (var i = 0; i < headings.length; i++) {
    final h = headings[i];
    final end = i + 1 < headings.length
        ? headings[i + 1].start
        : section.length;
    final block = section.substring(h.end, end);
    final entry = _parseBlock(title, h.group(1)!, block);
    if (entry != null) entries.add(entry);
  }

  // Pre-reform spellings ("daß", "Wittwe") point to the modern word.
  final old = RegExp(
    r'\{\{Alte Schreibweise\|([^|}]+)(?:\|([^|}]+))?',
  ).firstMatch(section);
  if (old != null) {
    final modern = old.group(1)!.trim();
    final reform = old.group(2)?.trim();
    entries.add(
      GermanEntry(
        word: title,
        wordType: 'Alte Schreibweise',
        lemma: modern,
        grammarNotes: [
          'Alte Schreibweise${reform == null ? '' : ' (vor der $reform)'} – heute: $modern',
        ],
      ),
    );
  }
  return entries;
}

String? _germanSection(String text) {
  final start = RegExp(
    r'^==\s*[^=].*\{\{Sprache\|Deutsch\}\}.*==\s*$',
    multiLine: true,
  ).firstMatch(text);
  if (start == null) return null;
  final next = RegExp(
    r'^==\s*[^=].*==\s*$',
    multiLine: true,
  ).allMatches(text, start.end).firstOrNull;
  return text.substring(start.end, next?.start ?? text.length);
}

GermanEntry? _parseBlock(String title, String heading, String block) {
  final wordType = RegExp(
    r'\{\{Wortart\|([^|}]+)',
  ).firstMatch(heading)?.group(1)?.trim();
  if (wordType == null) return null;

  final noun = _templateParams(block, 'Deutsch Substantiv Übersicht');
  final verb = _templateParams(block, 'Deutsch Verb Übersicht');
  final adj = _templateParams(block, 'Deutsch Adjektiv Übersicht');

  var genders = <String>[];
  String? plural;
  String? genitive;
  if (noun != null) {
    genders = noun.entries
        .where((e) => e.key.startsWith('Genus'))
        .map((e) => e.value)
        .where((v) => v.isNotEmpty)
        .toList();
    plural = _first(noun, 'Nominativ Plural');
    genitive = _first(noun, 'Genitiv Singular');
  }
  if (genders.isEmpty && wordType == 'Substantiv') {
    // Fall back to {{m}} / {{f}} / {{n}} in the heading.
    genders = RegExp(
      r'\{\{([mfn])\}\}',
    ).allMatches(heading).map((m) => m.group(1)!).toList();
  }

  final lemma = RegExp(
    r'\{\{Grundformverweis[^|}]*\|([^|}]+)',
  ).firstMatch(block)?.group(1)?.trim();

  return GermanEntry(
    word: title,
    wordType: wordType,
    genders: genders.toSet().toList(),
    plural: plural,
    genitive: genitive,
    present3: verb == null ? null : verb['Präsens_er, sie, es'],
    preterite: verb == null ? null : verb['Präteritum_ich'],
    participle: verb == null ? null : verb['Partizip II'],
    auxiliary: verb == null ? null : verb['Hilfsverb'],
    comparative: adj?['Komparativ'],
    superlative: adj?['Superlativ'],
    meanings: _listSection(block, 'Bedeutungen'),
    english: _englishTranslations(block),
    lemma: lemma,
    grammarNotes: _listSection(block, 'Grammatische Merkmale'),
    isName: RegExp(
      r'\{\{Wortart\|(Toponym|Vorname|Nachname|Eigenname)',
    ).hasMatch(heading),
  );
}

String? _first(Map<String, String> params, String prefix) {
  final v =
      params[prefix] ??
      params.entries.where((e) => e.key.startsWith(prefix)).firstOrNull?.value;
  return (v == null || v.isEmpty) ? null : v;
}

/// Reads `{{Name\n|key=value\n...}}` parameters (one per line).
Map<String, String>? _templateParams(String block, String name) {
  final start = block.indexOf('{{$name');
  if (start < 0) return null;
  var depth = 0;
  var end = start;
  for (var i = start; i < block.length - 1; i++) {
    if (block.startsWith('{{', i)) {
      depth++;
      i++;
    } else if (block.startsWith('}}', i)) {
      depth--;
      i++;
      if (depth == 0) {
        end = i + 1;
        break;
      }
    }
  }
  final body = block.substring(start, end);
  final params = <String, String>{};
  for (final line in body.split('\n')) {
    if (!line.startsWith('|')) continue;
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    params[line.substring(1, eq).trim()] = cleanWikitext(
      line.substring(eq + 1),
    );
  }
  return params;
}

/// Lines under a `{{Section}}` marker, up to the next blank line or marker.
List<String> _listSection(String block, String name) {
  final start = block.indexOf('{{$name}}');
  if (start < 0) return [];
  final lines = block.substring(start + name.length + 4).split('\n');
  final out = <String>[];
  for (final raw in lines.skip(1)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('{{') && !line.startsWith('{{K|')) {
      break;
    }
    if (!line.startsWith(':') && !line.startsWith('*')) break;
    var text = line.replaceFirst(RegExp(r'^[:*]+\s*'), '');
    if (text.startsWith('{{K|')) {
      // A context label on its own line, e.g. *{{K|intrans.}}: skip.
      if (RegExp(r'^\{\{K\|[^}]*\}\}:?$').hasMatch(text)) continue;
    }
    text = cleanWikitext(text);
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}

List<String> _englishTranslations(String block) {
  final out = <String>[];
  for (final line in RegExp(
    r'^\*\{\{en\}\}:(.*)$',
    multiLine: true,
  ).allMatches(block)) {
    for (final m in RegExp(r'\{\{Ü\|en\|([^|}]+)').allMatches(line.group(1)!)) {
      final t = m.group(1)!.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }
  }
  return out;
}

/// Strips wiki markup: links, bold/italic, refs, and most templates.
String cleanWikitext(String s) {
  var t = s;
  t = t.replaceAll(RegExp(r'<ref[^>]*/>'), '');
  t = t.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true), '');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  // Links first: they can sit inside templates ([[auf#Präposition|auf]]).
  t = t.replaceAllMapped(
    RegExp(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]'),
    (m) => m.group(1)!,
  );
  // Context labels {{K|intrans.|ft=warten auf …}} → "(intrans., warten auf …)".
  // Positional labels and the free-text "ft" are kept; other named params
  // (Prä=, Kas=, spr=) only drive formatting on the site.
  t = t.replaceAllMapped(RegExp(r'\{\{K\|([^{}]*)\}\}'), (m) {
    final parts = m
        .group(1)!
        .split('|')
        .map((p) => p.startsWith('ft=') ? p.substring(3) : p)
        .where((p) => p.isNotEmpty && !p.contains('='))
        .toList();
    return '(${parts.join(', ')})';
  });
  // Abbreviation templates like {{ugs.}} → "ugs."
  t = t.replaceAllMapped(
    RegExp(r'\{\{([^|{}]{1,12}\.)\}\}'),
    (m) => m.group(1)!,
  );
  // Drop remaining templates (repeat for nesting).
  for (var i = 0; i < 3; i++) {
    t = t.replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '');
  }
  t = t.replaceAllMapped(
    RegExp(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]'),
    (m) => m.group(1)!,
  );
  t = t.replaceAll(RegExp(r"'{2,}"), '');
  t = t.replaceFirst(RegExp(r'^\[\d+[a-z]?(?:[,–-]\s*\d+)*\]\s*'), '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
