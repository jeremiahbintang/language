import 'package:deutsch_lesen/services/story_service.dart';
import 'package:deutsch_lesen/services/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tokenize keeps umlauts, ß and hyphenated words together', () {
    final words = tokenize(
      'Die Straße in Köln-Mülheim, daß „Grüße“!',
    ).where((t) => t.isWord).map((t) => t.text).toList();
    expect(words, ['Die', 'Straße', 'in', 'Köln-Mülheim', 'daß', 'Grüße']);
  });

  test('tokens reassemble to the original paragraph', () {
    const p = 'Er ging nach Hause. Dann schlief er ein!';
    expect(tokenize(p).map((t) => t.text).join(), p);
  });

  test('sentenceAt finds the sentence around an offset', () {
    const p = 'Er ging nach Hause. Dann schlief er ein! Ende.';
    expect(sentenceAt(p, p.indexOf('schlief')), 'Dann schlief er ein!');
    expect(sentenceAt(p, 0), 'Er ging nach Hause.');
    expect(sentenceAt(p, p.indexOf('Ende')), 'Ende.');
  });

  test('story of the day cycles through the list', () {
    final a = StoryService.storyOfTheDay(DateTime(2026, 11, 21));
    final b = StoryService.storyOfTheDay(DateTime(2026, 11, 22));
    expect(a, isNot(b));
    expect(StoryService.titles, contains(a));
  });

  group('separableCandidates', () {
    List<(String, String)> at(String p, String word, [int nth = 0]) {
      var i = -1;
      for (var k = 0; k <= nth; k++) {
        i = p.indexOf(word, i + 1);
      }
      return separableCandidates(p, i);
    }

    test('verb → prefix at the end of the clause', () {
      expect(at('Er fängt morgen an.', 'fängt'), [('fängt', 'an')]);
      expect(at('Ich rufe dich später zurück, wenn ich Zeit habe.', 'rufe'), [
        ('rufe', 'zurück'),
      ]);
    });

    test('prefix → verbs before it, nearest first', () {
      expect(at('Der Zug kam pünktlich an.', 'an').first, ('pünktlich', 'an'));
      expect(
        at('Der Zug kam pünktlich an.', 'an').map((c) => c.$1),
        contains('kam'),
      );
    });

    test('prefix before "und" ends its clause', () {
      const p = 'Er steht auf und geht weg.';
      expect(at(p, 'steht'), [('steht', 'auf'), ('steht', 'weg')]);
      expect(at(p, 'geht'), [('geht', 'weg')]);
      expect(at(p, 'weg').first, ('geht', 'weg'));
    });

    test('a preposition inside the clause is not a prefix', () {
      expect(at('Er wartet auf den Bus.', 'wartet'), isEmpty);
      expect(at('Er wartet auf den Bus.', 'auf'), isEmpty);
    });

    test('clause boundaries: comma and quotes', () {
      expect(at('„Kommst du mit?“, fragte sie.', 'Kommst'), [
        ('Kommst', 'mit'),
      ]);
      expect(at('Wenn er kommt, fangen wir an.', 'kommt'), isEmpty);
      expect(at('Wenn er kommt, fangen wir an.', 'fangen'), [('fangen', 'an')]);
    });
  });
}
