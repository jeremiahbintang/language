import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'dewiktionary_parser.dart';
import 'wikimedia.dart';

export 'dewiktionary_parser.dart' show GermanEntry, articleFor;

class DictResult {
  /// The form of the word that was found (e.g. "die" for a tapped "Die").
  final String word;

  /// Entries for the tapped form itself (for inflected forms: grammar notes).
  final List<GermanEntry> entries;

  /// Entries for the base form, when the tapped word is inflected.
  final List<GermanEntry> lemmaEntries;

  /// Whether the base-word reading should be shown before the word's own
  /// entries (e.g. "schönen" → schön rather than the rare verb "schönen").
  final bool lemmaFirst;

  const DictResult(
    this.word,
    this.entries,
    this.lemmaEntries, {
    this.lemmaFirst = false,
  });

  bool get isEmpty => entries.isEmpty && lemmaEntries.isEmpty;

  /// Complete entries for the word itself (not just "form of …" pointers).
  List<GermanEntry> get fullEntries =>
      entries.where((e) => !e.isInflectedForm).toList();

  /// The most useful complete entry for display and saving.
  GermanEntry? get main =>
      (lemmaFirst ? lemmaEntries.firstOrNull : null) ??
      fullEntries.where((e) => !e.isName).firstOrNull ??
      lemmaEntries.firstOrNull ??
      fullEntries.firstOrNull ??
      entries.firstOrNull;
}

/// A separable verb found in the sentence, e.g. "fängt … an" → anfangen.
class SeparableMatch {
  final String verbForm; // as written: "fängt"
  final String prefix; // "an"
  final GermanEntry entry; // anfangen

  const SeparableMatch(this.verbForm, this.prefix, this.entry);
}

/// German dictionary backed by de.wiktionary.org (gender, plural, verb forms,
/// German meanings, English translations). Falls back to en.wiktionary.org
/// only to find the base form of inflected words missing from de.wiktionary.
class DictionaryService {
  static const _deApi = 'https://de.wiktionary.org/w/api.php';
  static const _enDefinition =
      'https://en.wiktionary.org/api/rest_v1/page/definition/';

  final _cache = <String, List<GermanEntry>>{};

  /// Looks up [word]. At the start of a sentence a capitalized word may be an
  /// ordinary lowercase word ("Die"), so both spellings are considered.
  Future<DictResult> lookup(String word, {bool sentenceStart = false}) async {
    final lower = word.toLowerCase();
    final capitalized = word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase();
    final candidates = <String>{
      if (sentenceStart) lower,
      word,
      lower,
      capitalized,
    }.toList();

    final pages = await _fetchMany(candidates);
    final hits = candidates
        .where((c) => pages[c]?.isNotEmpty ?? false)
        .toList();
    final found = hits.firstOrNull ?? word;

    var entries = <GermanEntry>[...?pages[found]];
    if (sentenceStart) {
      // "Die"/"die", "Essen"/"essen": show both readings.
      for (final h in hits.skip(1).where((h) => h.toLowerCase() == lower)) {
        entries.addAll(pages[h]!);
      }
    }

    final hasFullEntry = entries.any((e) => !e.isInflectedForm && !e.isName);
    final forms = entries.where((e) => e.isInflectedForm).toList();
    var lemmas = forms
        .map((e) => e.lemma)
        .whereType<String>()
        .where((l) => l != found)
        .toSet()
        .toList();
    // Missing from de.wiktionary: ask en.wiktionary for the base form.
    if (!hasFullEntry && lemmas.isEmpty) {
      final enLemma = await _englishLemma(candidates);
      if (enLemma != null && enLemma != found) {
        lemmas = [enLemma];
        entries = entries.where((e) => !e.isName).toList();
      }
    }
    final lemmaEntries = <GermanEntry>[];
    if (lemmas.isNotEmpty) {
      final (full, steps) = await _followLemmas(
        lemmas.take(3).toList(),
        seen: {found},
      );
      lemmaEntries.addAll(full);
      // Intermediate forms ("wachsend": Partizip I of wachsen) are shown as
      // grammar notes, like the tapped form's own.
      entries.addAll(steps);
    }
    // When the word has its own entry, put the base word first only for
    // declined forms ("schönen" → schön), not for verb-conjugation matches
    // ("schön" as a colloquial form of the rare verb "schönen").
    final lemmaFirst =
        lemmaEntries.isNotEmpty &&
        (!hasFullEntry || forms.any((f) => f.wordType == 'Deklinierte Form'));
    return DictResult(found, entries, lemmaEntries, lemmaFirst: lemmaFirst);
  }

  /// Checks (verb form, prefix) [candidates] in order and returns the first
  /// that makes a real separable verb ("kam" + "an" → ankommen).
  Future<SeparableMatch?> findSeparable(
    List<(String verbForm, String prefix)> candidates,
  ) async {
    if (candidates.isEmpty) return null;
    final forms = candidates.map((c) => c.$1.toLowerCase()).toSet().toList();
    final bases = {
      for (final (f, e) in await baseEntries(forms))
        if (e.wordType == 'Verb') f: e.word,
    };
    final compounds = <(String, String, String)>[
      for (final (form, prefix) in candidates)
        if (bases[form.toLowerCase()] case final base?)
          (form, prefix, '$prefix$base'),
    ];
    if (compounds.isEmpty) return null;
    final pages = await _fetchMany(compounds.map((c) => c.$3).toSet().toList());
    for (final (form, prefix, compound) in compounds) {
      final verb = pages[compound]
          ?.where((e) => e.wordType == 'Verb' && !e.isInflectedForm)
          .firstOrNull;
      if (verb != null) return SeparableMatch(form, prefix, verb);
    }
    return null;
  }

  /// Resolves many word forms (e.g. from a frequency list, often lowercased)
  /// to their base dictionary entries, in the order given. Forms without a
  /// usable entry, and names, are left out.
  Future<List<(String form, GermanEntry entry)>> baseEntries(
    List<String> forms,
  ) async {
    String cap(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
    final pages = await _fetchMany(
      {
        for (final f in forms) ...[f, cap(f)],
      }.toList(),
    );

    // First pass: pick each form's own entry, or note the base word it points to.
    final picks = <String, GermanEntry?>{};
    final lemmaOf = <String, String>{};
    for (final f in forms) {
      final own = pages[f]?.isNotEmpty ?? false
          ? pages[f]!
          : pages[cap(f)] ?? [];
      final full = own.where((e) => !e.isInflectedForm && !e.isName).toList();
      final declined = own.where(
        (e) => e.wordType == 'Deklinierte Form' && e.lemma != null,
      );
      final pointer = own
          .where((e) => e.isInflectedForm && e.lemma != null)
          .firstOrNull;
      if (full.isNotEmpty && declined.isEmpty) {
        picks[f] = full.first;
      } else if (declined.isNotEmpty) {
        lemmaOf[f] = declined.first.lemma!;
      } else if (pointer != null) {
        lemmaOf[f] = pointer.lemma!;
      }
    }

    // Second pass: fetch all base words at once, following chains like
    // "wachsende" → "wachsend" → "wachsen".
    var pending = Map.of(lemmaOf);
    for (var depth = 0; depth < 3 && pending.isNotEmpty; depth++) {
      final lemmaPages = await _fetchMany(pending.values.toSet().toList());
      final next = <String, String>{};
      for (final MapEntry(key: f, value: l) in pending.entries) {
        final page = lemmaPages[l] ?? [];
        final full = page
            .where((e) => !e.isInflectedForm && !e.isName)
            .firstOrNull;
        if (full != null) {
          picks[f] = full;
        } else if (page.where((e) => e.lemma != null).firstOrNull?.lemma
            case final l2? when l2 != l && l2 != f) {
          next[f] = l2;
        }
      }
      pending = next;
    }

    return [
      for (final f in forms)
        if (picks[f] case final e?)
          if (e.english.isNotEmpty || e.meanings.isNotEmpty) (f, e),
    ];
  }

  /// Fetches the base words [lemmas]. When a base word is itself only a form
  /// of another word (a participle, a declined form), that one is followed
  /// too, up to [depth] steps. Returns the complete entries found and the
  /// intermediate "form of" entries passed on the way.
  Future<(List<GermanEntry>, List<GermanEntry>)> _followLemmas(
    List<String> lemmas, {
    required Set<String> seen,
    int depth = 3,
  }) async {
    final full = <GermanEntry>[];
    final steps = <GermanEntry>[];
    var current = lemmas.where(seen.add).toList();
    for (var d = 0; d < depth && current.isNotEmpty; d++) {
      final pages = await _fetchMany(current);
      final next = <String>[];
      for (final l in current) {
        final page = pages[l] ?? [];
        final complete = page.where((e) => !e.isInflectedForm).toList();
        if (complete.isNotEmpty) {
          full.addAll(complete);
        } else {
          for (final e in page.where((e) => e.lemma != null)) {
            steps.add(e);
            if (seen.add(e.lemma!)) next.add(e.lemma!);
          }
        }
      }
      current = next;
    }
    return (full, steps);
  }

  /// Fetches several pages in one request; returns German entries per title.
  Future<Map<String, List<GermanEntry>>> _fetchMany(List<String> titles) async {
    // The API accepts at most 50 titles per request.
    if (titles.length > 50) {
      final merged = <String, List<GermanEntry>>{};
      for (var i = 0; i < titles.length; i += 50) {
        merged.addAll(
          await _fetchMany(titles.sublist(i, (i + 50).clamp(0, titles.length))),
        );
      }
      return merged;
    }
    final result = <String, List<GermanEntry>>{};
    final missing = <String>[];
    for (final t in titles) {
      final c = _cache[t];
      if (c != null) {
        result[t] = c;
      } else {
        missing.add(t);
      }
    }
    if (missing.isEmpty) return result;

    final uri = Uri.parse(_deApi).replace(
      queryParameters: {
        'action': 'query',
        'prop': 'revisions',
        'rvprop': 'content',
        'rvslots': 'main',
        'titles': missing.join('|'),
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      },
    );
    final res = await http.get(uri, headers: wikimediaHeaders);
    if (res.statusCode == 429) {
      throw Exception('Too many lookups — wait a few seconds and try again.');
    }
    if (res.statusCode != 200) {
      throw Exception('Dictionary request failed (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final query = data['query'] as Map<String, dynamic>? ?? {};

    // The API may normalize titles; map them back to what we asked for.
    final normalized = <String, String>{
      for (final n
          in (query['normalized'] as List? ?? []).cast<Map<String, dynamic>>())
        n['to'] as String: n['from'] as String,
    };
    for (final p
        in (query['pages'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final title = p['title'] as String;
      final asked = normalized[title] ?? title;
      final text =
          (p['revisions'] as List?)?.firstOrNull?['slots']?['main']?['content']
              as String?;
      final entries = text == null
          ? <GermanEntry>[]
          : parseGermanEntries(title, text);
      _cache[asked] = entries;
      result[asked] = entries;
    }
    for (final t in missing) {
      result.putIfAbsent(t, () => _cache[t] = const []);
    }
    return result;
  }

  /// Uses en.wiktionary "form of" definitions to find a base word.
  Future<String?> _englishLemma(List<String> candidates) async {
    for (final c in candidates) {
      final res = await http.get(
        Uri.parse(_enDefinition + Uri.encodeComponent(c)),
        headers: wikimediaHeaders,
      );
      if (res.statusCode != 200) continue;
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final e
          in (data['de'] as List? ?? []).cast<Map<String, dynamic>>()) {
        for (final d
            in (e['definitions'] as List).cast<Map<String, dynamic>>()) {
          final frag = html_parser.parseFragment(
            d['definition'] as String? ?? '',
          );
          final lemma = frag
              .querySelector('.form-of-definition-link a')
              ?.text
              .trim();
          if (lemma != null && lemma.isNotEmpty) return lemma;
        }
      }
    }
    return null;
  }
}
