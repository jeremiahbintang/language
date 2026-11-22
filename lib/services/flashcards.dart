import 'package:fsrs/fsrs.dart' as fsrs;

import 'dewiktionary_parser.dart';
import 'text_utils.dart' show separablePrefixes;

/// How well the learner remembered a card.
enum Grade { again, hard, good, easy }

enum CardState { fresh, learning, review, known }

/// A vocabulary card plus its spaced-repetition state.
///
/// Scheduling uses FSRS (Free Spaced Repetition Scheduler), the algorithm
/// behind Anki's modern scheduler, via the official `fsrs` package.
class Flashcard {
  /// Stable key, e.g. "leitplanke".
  final String id;

  /// Base form without article: "Leitplanke", "gehen".
  final String word;

  /// With article for nouns: "die Leitplanke".
  final String headword;
  final String wordType;
  final List<String> genders;

  /// "Pl. die Leitplanken", "geht · ging · ist gegangen", "schön · schöner · am schönsten".
  final String? forms;
  final String english;

  /// First German definition.
  final String? meaning;

  /// Sentence where the word was met, if saved while reading.
  final String? example;
  final String source;
  final DateTime added;

  /// FSRS memory state; null until the first review.
  fsrs.Card? srs;

  /// Marked "Kenne ich schon": never scheduled.
  bool known;

  /// Forms of the word met while reading ("Hauses", "ging"), lowercase.
  final List<String> seenForms;

  Flashcard({
    required this.id,
    required this.word,
    required this.headword,
    required this.wordType,
    this.genders = const [],
    this.forms,
    required this.english,
    this.meaning,
    this.example,
    required this.source,
    required this.added,
    this.srs,
    this.known = false,
    List<String>? seenForms,
  }) : seenForms = seenForms ?? [];

  static String keyFor(String word) => word.trim().toLowerCase();

  factory Flashcard.fromEntry(
    GermanEntry e, {
    String? example,
    String? seenForm,
    required String source,
    DateTime? now,
  }) {
    final forms = e.pluralWithArticle != null
        ? 'Pl. ${e.pluralWithArticle}'
        : e.verbForms ?? e.adjectiveForms;
    return Flashcard(
      id: keyFor(e.word),
      word: e.word,
      headword: e.headword,
      wordType: e.wordType,
      genders: e.genders,
      forms: forms,
      english: e.english.take(5).join(', '),
      meaning: e.meanings.firstOrNull,
      example: example,
      source: source,
      added: now ?? DateTime.now(),
      seenForms: [if (seenForm != null) seenForm.toLowerCase()],
    );
  }

  CardState get state {
    if (known) return CardState.known;
    final s = srs;
    if (s == null) return CardState.fresh;
    return s.state == fsrs.State.review ? CardState.review : CardState.learning;
  }

  DateTime get due => (srs?.due ?? added).toLocal();

  /// Lowercase word forms to recognise in a text: the base word, its listed
  /// forms (plural, verb parts, comparison), common endings, and forms seen
  /// while reading. Separable prefixes ("an" in "fängt an") are left out so
  /// they don't light up everywhere.
  Set<String> get surfaceForms {
    final base = word.toLowerCase();
    final out = <String>{base, ...seenForms};
    for (final part in (forms ?? '').split(RegExp(r'[\s·]+'))) {
      final p = part.toLowerCase();
      if (p.isEmpty ||
          _formNoise.contains(p) ||
          separablePrefixes.contains(p)) {
        continue;
      }
      out.add(p);
    }
    if (genders.isNotEmpty) {
      // Genitive and dative plural: Hauses, Häusern, Familien.
      for (final f in out.toList()) {
        out.addAll(['${f}s', '${f}es', '${f}n', '${f}en']);
      }
    } else if (wordType == 'Adjektiv') {
      for (final f in out.toList()) {
        out.addAll(['${f}e', '${f}en', '${f}er', '${f}es', '${f}em']);
      }
    }
    return out;
  }

  static const _formNoise = {
    'pl.',
    'der',
    'die',
    'das',
    'ist',
    'hat',
    'am',
    'kein',
    'plural',
  };

  bool isDue(DateTime now) => srs != null && !known && !due.isAfter(now);

  /// Days until the next review for review cards (for display).
  double? get stabilityDays => srs?.stability;

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'headword': headword,
    'wordType': wordType,
    'genders': genders,
    'forms': forms,
    'english': english,
    'meaning': meaning,
    'example': example,
    'source': source,
    'added': added.toIso8601String(),
    'known': known,
    'seen': seenForms,
    'srs': srs?.toMap(),
  };

  factory Flashcard.fromJson(Map<String, dynamic> j) {
    final added = DateTime.parse(j['added'] as String);
    final id = j['id'] as String;
    final srsMap = j['srs'] as Map<String, dynamic>?;
    return Flashcard(
      id: id,
      word: j['word'] as String,
      headword: j['headword'] as String? ?? j['word'] as String,
      wordType: j['wordType'] as String? ?? '',
      genders: (j['genders'] as List? ?? []).cast<String>(),
      forms: j['forms'] as String?,
      english: j['english'] as String? ?? '',
      meaning: j['meaning'] as String?,
      example: j['example'] as String?,
      source: j['source'] as String? ?? '',
      added: added,
      srs: srsMap != null ? _srsFromMap(srsMap) : _fromSm2(id, j),
      known: j['known'] as bool? ?? j['state'] == 'known',
      seenForms: (j['seen'] as List? ?? []).cast<String>(),
    );
  }

  /// fsrs' fromMap expects doubles; JSON may hand back ints (e.g. 3 for 3.0).
  static fsrs.Card _srsFromMap(Map<String, dynamic> m) => fsrs.Card.fromMap({
    ...m,
    'stability': (m['stability'] as num?)?.toDouble(),
    'difficulty': (m['difficulty'] as num?)?.toDouble(),
  });

  /// Converts progress saved by the earlier SM-2 scheduler.
  static fsrs.Card? _fromSm2(String id, Map<String, dynamic> j) {
    final state = j['state'] as String?;
    if (state == null || state == 'fresh' || state == 'known') return null;
    final due =
        DateTime.tryParse(j['due'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final last = DateTime.tryParse(j['lastReview'] as String? ?? '')?.toUtc();
    if (state == 'learning') {
      return fsrs.Card(
        cardId: Scheduler.cardIdFor(id),
        due: due,
        lastReview: last,
      );
    }
    // At 90% retention, FSRS stability ≈ the interval in days. Map SM-2 ease
    // (1.3 hard … 2.5 default … 3+ easy) onto FSRS difficulty (10 … 1).
    final interval = (j['intervalDays'] as num?)?.toDouble() ?? 1;
    final ease = (j['ease'] as num?)?.toDouble() ?? 2.5;
    return fsrs.Card(
      cardId: Scheduler.cardIdFor(id),
      state: fsrs.State.review,
      stability: interval < 1 ? 1 : interval,
      difficulty: (11 - (ease - 1.3) / 0.25).clamp(1, 10).toDouble(),
      due: due,
      lastReview: last ?? due.subtract(Duration(days: interval.round())),
    );
  }
}

/// One answered card, kept so FSRS parameters can later be optimised for
/// this learner (the FSRS optimiser needs the review history).
class ReviewRecord {
  final String cardId;
  final int rating; // 1 again … 4 easy
  final DateTime at;

  const ReviewRecord(this.cardId, this.rating, this.at);

  Map<String, dynamic> toJson() => {
    'c': cardId,
    'r': rating,
    't': at.toIso8601String(),
  };

  factory ReviewRecord.fromJson(Map<String, dynamic> j) => ReviewRecord(
    j['c'] as String,
    j['r'] as int,
    DateTime.parse(j['t'] as String),
  );
}

/// FSRS scheduling with Anki-like defaults: 90% target retention, learning
/// steps of 1 and 10 minutes, relearning step of 10 minutes.
class Scheduler {
  static const desiredRetention = 0.9;

  static final _fsrs = fsrs.Scheduler(desiredRetention: desiredRetention);

  /// Same model without random "fuzz", so button labels are stable.
  static final _preview = fsrs.Scheduler(
    desiredRetention: desiredRetention,
    enableFuzzing: false,
  );

  static fsrs.Rating _rating(Grade g) => switch (g) {
    Grade.again => fsrs.Rating.again,
    Grade.hard => fsrs.Rating.hard,
    Grade.good => fsrs.Rating.good,
    Grade.easy => fsrs.Rating.easy,
  };

  /// fsrs needs an int id; Dart's String.hashCode isn't stable across runs,
  /// so use FNV-1a.
  static int cardIdFor(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static fsrs.Card _srsOf(Flashcard c, DateTime now) =>
      c.srs ?? fsrs.Card(cardId: cardIdFor(c.id), due: now.toUtc());

  /// When the card would be due if answered with [grade] (for button labels).
  static DateTime preview(Flashcard c, Grade grade, DateTime now) {
    final r = _preview.reviewCard(
      _srsOf(c, now),
      _rating(grade),
      reviewDateTime: now.toUtc(),
    );
    return r.card.due.toLocal();
  }

  /// Updates [c] after an answer and returns the record to log.
  static ReviewRecord answer(
    Flashcard c,
    Grade grade,
    DateTime now, {
    bool fuzz = true,
  }) {
    final scheduler = fuzz ? _fsrs : _preview;
    final r = scheduler.reviewCard(
      _srsOf(c, now),
      _rating(grade),
      reviewDateTime: now.toUtc(),
    );
    c.srs = r.card;
    return ReviewRecord(c.id, _rating(grade).value, now);
  }

  /// Estimated chance of remembering the card right now (0–1), or null if new.
  static double? retrievability(Flashcard c, DateTime now) {
    final s = c.srs;
    if (s == null || s.lastReview == null) return null;
    return _fsrs.getCardRetrievability(s, currentDateTime: now.toUtc());
  }

  /// "1 Min", "10 Min", "1 T", "3 Wo", "2 Mo"
  static String describe(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} Min';
    if (d.inHours < 20) return '${d.inHours} Std';
    final days = (d.inHours / 24).round();
    if (days < 14) return '$days T';
    if (days < 60) return '${(days / 7).round()} Wo';
    if (days < 365) return '${(days / 30).round()} Mo';
    return '${(days / 365).toStringAsFixed(1)} J';
  }
}
