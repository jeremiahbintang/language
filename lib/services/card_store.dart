import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dictionary_service.dart';
import 'flashcards.dart';

class DeckStats {
  final int due;
  final int newAvailable;
  final int newToday;
  final int learning;
  final int review;
  final int known;
  final int total;

  const DeckStats({
    required this.due,
    required this.newAvailable,
    required this.newToday,
    required this.learning,
    required this.review,
    required this.known,
    required this.total,
  });
}

/// All flashcards, stored on the device as one JSON list.
class CardStore {
  static const _cardsKey = 'flashcards_v1';
  static const _legacyWordsKey = 'saved_words';
  static const _newDayKey = 'new_cards_day';
  static const _newCountKey = 'new_cards_count';
  static const _newLimitKey = 'new_cards_per_day';
  static const _reviewLogKey = 'review_log_v1';
  static const defaultNewPerDay = 10;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Flashcard>> all() async {
    final p = await _prefs;
    await _migrateSavedWords(p);
    final raw = p.getString(_cardsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<Flashcard> cards) async {
    final p = await _prefs;
    await p.setString(
      _cardsKey,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  Future<bool> contains(String id) async =>
      (await all()).any((c) => c.id == id);

  /// Adds cards whose id is not in the deck yet; returns how many were added.
  Future<int> addAll(Iterable<Flashcard> cards) async {
    final deck = await all();
    final ids = deck.map((c) => c.id).toSet();
    final fresh = cards.where((c) => ids.add(c.id)).toList();
    if (fresh.isEmpty) return 0;
    await _write([...deck, ...fresh]);
    return fresh.length;
  }

  /// Adds a card, or fills in a missing example sentence on an existing one.
  Future<void> add(Flashcard card) async {
    final deck = await all();
    final i = deck.indexWhere((c) => c.id == card.id);
    if (i < 0) {
      deck.add(card);
    } else {
      // Already a card: keep its progress, fill in example and seen forms.
      final old = deck[i];
      final newForms = card.seenForms.where((f) => !old.seenForms.contains(f));
      if ((old.example != null || card.example == null) && newForms.isEmpty) {
        return;
      }
      final merged = old.toJson()
        ..['example'] = old.example ?? card.example
        ..['seen'] = [...old.seenForms, ...newForms];
      deck[i] = Flashcard.fromJson(merged);
    }
    await _write(deck);
  }

  /// Remembers that [form] of card [id] was met while reading, so it gets
  /// highlighted in texts.
  Future<void> addSeenForm(String id, String form) async {
    final f = form.toLowerCase();
    final deck = await all();
    final i = deck.indexWhere((c) => c.id == id);
    if (i < 0 || deck[i].seenForms.contains(f)) return;
    deck[i].seenForms.add(f);
    await _write(deck);
  }

  /// Word forms of saved cards (excluding ones marked "Kenne ich schon").
  Future<Set<String>> highlightForms() async => {
    for (final c in await all())
      if (!c.known) ...c.surfaceForms,
  };

  Future<void> update(Flashcard card) async {
    final deck = await all();
    final i = deck.indexWhere((c) => c.id == card.id);
    if (i < 0) return;
    deck[i] = card;
    await _write(deck);
  }

  Future<void> remove(String id) async {
    final deck = await all();
    deck.removeWhere((c) => c.id == id);
    await _write(deck);
  }

  /// Fills in article, forms and translations for cards saved by older app
  /// versions (they have no word type). Keeps progress and example sentence.
  /// Returns how many cards were updated.
  Future<int> enrichIncomplete(DictionaryService dict) async {
    final deck = await all();
    final incomplete = deck.where((c) => c.wordType.isEmpty).take(20).toList();
    if (incomplete.isEmpty) return 0;
    final found = await dict.baseEntries(
      incomplete.map((c) => c.word).toList(),
    );
    final byWord = {for (final (f, e) in found) f: e};
    var updated = 0;
    for (var i = 0; i < deck.length; i++) {
      final old = deck[i];
      final e = byWord[old.word];
      if (old.wordType.isNotEmpty || e == null) continue;
      final fresh = Flashcard.fromEntry(
        e,
        example: old.example,
        source: old.source,
      );
      final merged = fresh.toJson()
        ..['id'] = old.id
        ..['added'] = old.added.toIso8601String();
      for (final k in ['srs', 'known']) {
        merged[k] = old.toJson()[k];
      }
      deck[i] = Flashcard.fromJson(merged);
      updated++;
    }
    if (updated > 0) await _write(deck);
    return updated;
  }

  // --- Review history (for optimising FSRS parameters later) --------------

  Future<void> logReview(ReviewRecord r) async {
    final p = await _prefs;
    final log = p.getStringList(_reviewLogKey) ?? [];
    log.add(jsonEncode(r.toJson()));
    await p.setStringList(_reviewLogKey, log);
  }

  Future<List<ReviewRecord>> reviewLog() async {
    final p = await _prefs;
    return (p.getStringList(_reviewLogKey) ?? [])
        .map(
          (s) => ReviewRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  // --- Daily limit for new cards -------------------------------------------

  Future<int> newPerDay() async =>
      (await _prefs).getInt(_newLimitKey) ?? defaultNewPerDay;

  Future<void> setNewPerDay(int n) async =>
      (await _prefs).setInt(_newLimitKey, n);

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<int> newIntroducedToday() async {
    final p = await _prefs;
    return p.getString(_newDayKey) == _today()
        ? p.getInt(_newCountKey) ?? 0
        : 0;
  }

  Future<void> countNewIntroduced() async {
    final p = await _prefs;
    final n = await newIntroducedToday();
    await p.setString(_newDayKey, _today());
    await p.setInt(_newCountKey, n + 1);
  }

  // --- Sessions -------------------------------------------------------------

  /// Cards to study now: due reviews first, then today's share of new cards.
  Future<List<Flashcard>> sessionQueue({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final deck = await all();
    final due = deck.where((c) => c.isDue(t)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    final newLeft = (await newPerDay()) - (await newIntroducedToday());
    final fresh = deck
        .where((c) => c.state == CardState.fresh)
        .take(newLeft.clamp(0, 1000))
        .toList();
    return [...due, ...fresh];
  }

  Future<DeckStats> stats({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final deck = await all();
    final newToday = await newIntroducedToday();
    final freshCount = deck.where((c) => c.state == CardState.fresh).length;
    final newLeft = ((await newPerDay()) - newToday).clamp(0, freshCount);
    return DeckStats(
      due: deck.where((c) => c.isDue(t)).length,
      newAvailable: newLeft,
      newToday: newToday,
      learning: deck.where((c) => c.state == CardState.learning).length,
      review: deck.where((c) => c.state == CardState.review).length,
      known: deck.where((c) => c.state == CardState.known).length,
      total: deck.length,
    );
  }

  /// Converts words saved by earlier versions of the app into cards.
  Future<void> _migrateSavedWords(SharedPreferences p) async {
    final raw = p.getString(_legacyWordsKey);
    if (raw == null) return;
    final existing = p.getString(_cardsKey);
    final deck = existing == null
        ? <Flashcard>[]
        : (jsonDecode(existing) as List)
              .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
              .toList();
    final ids = deck.map((c) => c.id).toSet();
    for (final w in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
      final headword = (w['lemma'] as String?) ?? (w['word'] as String);
      final word = headword.split(' ').last;
      if (!ids.add(Flashcard.keyFor(word))) continue;
      deck.add(
        Flashcard(
          id: Flashcard.keyFor(word),
          word: word,
          headword: headword,
          wordType: '',
          english: w['meaning'] as String? ?? '',
          example: w['sentence'] as String?,
          source: w['source'] as String? ?? '',
          added:
              DateTime.tryParse(w['savedAt'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }
    await p.setString(
      _cardsKey,
      jsonEncode(deck.map((c) => c.toJson()).toList()),
    );
    await p.remove(_legacyWordsKey);
  }
}
