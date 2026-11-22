import 'dart:convert';

import 'package:deutsch_lesen/services/card_store.dart';
import 'package:deutsch_lesen/services/flashcards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Flashcard card(String word, {DateTime? added}) => Flashcard(
  id: Flashcard.keyFor(word),
  word: word,
  headword: word,
  wordType: 'Substantiv',
  english: 'x',
  source: 'test',
  added: added ?? DateTime(2026, 11, 21, 9),
);

void main() {
  final now = DateTime(2026, 11, 21, 9);

  group('Scheduler (FSRS)', () {
    Duration after(Flashcard c, DateTime t) => c.due.difference(t);

    test(
      'new card: Gut → 10 min learning step, Gut again → graduates to days',
      () {
        final c = card('Haus');
        Scheduler.answer(c, Grade.good, now, fuzz: false);
        expect(c.state, CardState.learning);
        expect(after(c, now), const Duration(minutes: 10));

        final later = now.add(const Duration(minutes: 10));
        Scheduler.answer(c, Grade.good, later, fuzz: false);
        expect(c.state, CardState.review);
        expect(after(c, later).inDays, greaterThanOrEqualTo(1));
      },
    );

    test('new card: Nochmal → 1 min, Leicht → straight to review', () {
      final a = card('A');
      Scheduler.answer(a, Grade.again, now, fuzz: false);
      expect(after(a, now), const Duration(minutes: 1));

      final e = card('E');
      Scheduler.answer(e, Grade.easy, now, fuzz: false);
      expect(e.state, CardState.review);
      expect(after(e, now).inDays, greaterThan(7)); // FSRS-6 default: ~2 weeks
    });

    test(
      'successful reviews grow the interval; a lapse sends it to relearning',
      () {
        final c = card('Haus');
        var t = now;
        Scheduler.answer(c, Grade.easy, t, fuzz: false);
        final intervals = <int>[];
        for (var i = 0; i < 3; i++) {
          t = c.due;
          Scheduler.answer(c, Grade.good, t, fuzz: false);
          intervals.add(after(c, t).inDays);
        }
        expect(intervals[1], greaterThan(intervals[0]));
        expect(intervals[2], greaterThan(intervals[1]));

        t = c.due;
        final stabilityBefore = c.stabilityDays!;
        Scheduler.answer(c, Grade.again, t, fuzz: false);
        expect(c.state, CardState.learning); // relearning
        expect(after(c, t), const Duration(minutes: 10));
        expect(c.stabilityDays, lessThan(stabilityBefore));
      },
    );

    test('Leicht > Gut > Schwer for the next interval of a review card', () {
      final c = card('Haus');
      Scheduler.answer(c, Grade.easy, now, fuzz: false);
      final t = c.due;
      final hard = Scheduler.preview(c, Grade.hard, t).difference(t);
      final good = Scheduler.preview(c, Grade.good, t).difference(t);
      final easy = Scheduler.preview(c, Grade.easy, t).difference(t);
      expect(hard, lessThan(good));
      expect(good, lessThan(easy));
    });

    test('preview does not change the card', () {
      final c = card('Haus');
      Scheduler.preview(c, Grade.easy, now);
      expect(c.state, CardState.fresh);
      expect(c.srs, isNull);
    });

    test('retrievability is ~90% when a review card falls due', () {
      final c = card('Haus');
      Scheduler.answer(c, Grade.easy, now, fuzz: false);
      expect(Scheduler.retrievability(c, c.due), closeTo(0.9, 0.03));
    });

    test('json round trip keeps the FSRS state', () {
      final c = card('Haus');
      Scheduler.answer(c, Grade.easy, now, fuzz: false);
      final back = Flashcard.fromJson(jsonDecode(jsonEncode(c.toJson())));
      expect(back.toJson(), c.toJson());
      expect(back.state, CardState.review);
    });

    test('progress from the old SM-2 scheduler is converted', () {
      final old = {
        'id': 'haus',
        'word': 'Haus',
        'headword': 'das Haus',
        'wordType': 'Substantiv',
        'english': 'house',
        'source': 'x',
        'added': '2026-11-01T09:00:00.000',
        'state': 'review',
        'reps': 3,
        'ease': 2.5,
        'intervalDays': 10.0,
        'due': '2026-11-25T04:00:00.000',
        'lastReview': '2026-11-15T09:00:00.000',
      };
      final c = Flashcard.fromJson(old);
      expect(c.state, CardState.review);
      expect(c.stabilityDays, 10);
      expect(c.due, DateTime(2026, 11, 25, 4));
      expect(
        Flashcard.fromJson({...old, 'state': 'known'}).state,
        CardState.known,
      );
      expect(
        Flashcard.fromJson({...old, 'state': 'fresh'}).state,
        CardState.fresh,
      );
    });

    test('card ids for FSRS are stable', () {
      expect(Scheduler.cardIdFor('haus'), Scheduler.cardIdFor('haus'));
      expect(Scheduler.cardIdFor('haus'), isNot(Scheduler.cardIdFor('maus')));
    });

    test('describe', () {
      expect(Scheduler.describe(const Duration(minutes: 10)), '10 Min');
      expect(Scheduler.describe(const Duration(days: 4)), '4 T');
      expect(Scheduler.describe(const Duration(days: 21)), '3 Wo');
      expect(Scheduler.describe(const Duration(days: 90)), '3 Mo');
    });
  });

  group('CardStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'queue: due cards first, then new cards up to the daily limit',
      () async {
        final store = CardStore();
        await store.setNewPerDay(2);
        final review = card('Baum');
        Scheduler.answer(
          review,
          Grade.easy,
          now.subtract(const Duration(days: 60)),
        );
        await store.addAll([card('A'), card('B'), card('C'), review]);

        final q = await store.sessionQueue(now: now);
        expect(q.map((c) => c.word), ['Baum', 'A', 'B']);

        await store.countNewIntroduced();
        final q2 = await store.sessionQueue(now: now);
        expect(q2.map((c) => c.word), ['Baum', 'A']);
      },
    );

    test('reviews are logged', () async {
      final store = CardStore();
      final c = card('Haus');
      await store.logReview(Scheduler.answer(c, Grade.good, now));
      final log = await store.reviewLog();
      expect(log.single.cardId, 'haus');
      expect(log.single.rating, 3);
    });

    test('duplicates are ignored', () async {
      final store = CardStore();
      expect(await store.addAll([card('Haus'), card('haus')]), 1);
      expect(await store.addAll([card('Haus')]), 0);
    });

    test('words saved by older versions become cards', () async {
      SharedPreferences.setMockInitialValues({
        'saved_words': jsonEncode([
          {
            'word': 'Hauses',
            'lemma': 'das Haus',
            'meaning': 'Pl. die Häuser — house',
            'sentence': 'Er kam aus dem Hause.',
            'source': 'Frau Holle',
            'savedAt': '2026-11-20T10:00:00.000',
          },
        ]),
      });
      final cards = await CardStore().all();
      expect(cards.single.word, 'Haus');
      expect(cards.single.headword, 'das Haus');
      expect(cards.single.example, 'Er kam aus dem Hause.');
    });
  });

  group('surfaceForms', () {
    test('noun: plural and case endings, article left out', () {
      final c = Flashcard(
        id: 'haus',
        word: 'Haus',
        headword: 'das Haus',
        wordType: 'Substantiv',
        genders: ['n'],
        forms: 'Pl. die Häuser',
        english: 'house',
        source: 'x',
        added: DateTime(2026),
      );
      expect(
        c.surfaceForms,
        containsAll(['haus', 'häuser', 'häusern', 'hauses']),
      );
      expect(c.surfaceForms, isNot(contains('die')));
    });

    test('separable verb: prefix alone is not highlighted', () {
      final c = Flashcard(
        id: 'anfangen',
        word: 'anfangen',
        headword: 'anfangen',
        wordType: 'Verb',
        forms: 'fängt an · fing an · hat angefangen',
        english: 'begin',
        source: 'x',
        added: DateTime(2026),
      );
      expect(
        c.surfaceForms,
        containsAll(['anfangen', 'fängt', 'fing', 'angefangen']),
      );
      expect(c.surfaceForms, isNot(contains('an')));
      expect(c.surfaceForms, isNot(contains('hat')));
    });

    test('adjective endings and seen forms', () {
      final c = Flashcard(
        id: 'schön',
        word: 'schön',
        headword: 'schön',
        wordType: 'Adjektiv',
        forms: 'schön · schöner · am schönsten',
        english: 'beautiful',
        source: 'x',
        added: DateTime(2026),
        seenForms: ['schönste'],
      );
      expect(
        c.surfaceForms,
        containsAll(['schön', 'schönen', 'schöner', 'schönsten', 'schönste']),
      );
      expect(c.surfaceForms, isNot(contains('am')));
    });
  });

  group('highlights', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'saving again merges seen forms; known cards are not highlighted',
      () async {
        final store = CardStore();
        final a = card('Haus');
        await store.add(a);
        await store.add(
          Flashcard.fromJson({
            ...a.toJson(),
            'seen': ['hauses'],
          }),
        );
        await store.addSeenForm('haus', 'Häusern');
        expect((await store.all()).single.seenForms, ['hauses', 'häusern']);
        expect(
          await store.highlightForms(),
          containsAll(['haus', 'hauses', 'häusern']),
        );

        final k = (await store.all()).single..known = true;
        await store.update(k);
        expect(await store.highlightForms(), isEmpty);
      },
    );
  });
}
