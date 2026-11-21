import 'package:deutsch_lesen/services/story_service.dart';
import 'package:deutsch_lesen/services/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tokenize keeps umlauts, ß and hyphenated words together', () {
    final words = tokenize('Die Straße in Köln-Mülheim, daß „Grüße“!')
        .where((t) => t.isWord)
        .map((t) => t.text)
        .toList();
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
}
