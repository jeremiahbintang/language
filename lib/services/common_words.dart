import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'card_store.dart';
import 'dictionary_service.dart';
import 'flashcards.dart';

/// Adds the most frequent German words as flashcards, in frequency order.
///
/// Source: FrequencyWords by Hermit Dave (OpenSubtitles 2018, CC BY-SA 4.0),
/// https://github.com/hermitdave/FrequencyWords. The list contains inflected
/// forms ("ging", "gehst"), which are reduced to base words via Wiktionary.
class CommonWords {
  static const _url =
      'https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/de/de_50k.txt';
  static const _listKey = 'common_words_list';
  static const _posKey = 'common_words_pos';
  static const _maxWords = 10000;
  static const _batch = 25;

  final DictionaryService _dict;
  final CardStore _store;

  CommonWords(this._dict, this._store);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Position in the frequency list (0 = the most frequent word).
  Future<int> position() async => (await _prefs).getInt(_posKey) ?? 0;

  Future<void> setPosition(int rank) async =>
      (await _prefs).setInt(_posKey, rank);

  Future<List<String>> _words() async {
    final p = await _prefs;
    final cached = p.getStringList(_listKey);
    if (cached != null) return cached;

    final res = await http.get(Uri.parse(_url));
    if (res.statusCode != 200) {
      throw Exception('Could not download the word list (${res.statusCode})');
    }
    final letters = RegExp(r'^[a-zäöüß]{2,}$');
    final words = <String>[];
    for (final line in res.body.split('\n')) {
      final w = line.split(' ').first.trim();
      if (letters.hasMatch(w)) words.add(w);
      if (words.length >= _maxWords) break;
    }
    await p.setStringList(_listKey, words);
    return words;
  }

  /// Adds up to [count] new cards for the next frequent words not yet in the
  /// deck. Returns the cards added.
  Future<List<Flashcard>> addNext(int count) async {
    final words = await _words();
    var pos = await position();
    final deckIds = (await _store.all()).map((c) => c.id).toSet();
    final added = <Flashcard>[];

    while (added.length < count && pos < words.length) {
      final chunk = words.sublist(pos, (pos + _batch).clamp(0, words.length));
      final entries = await _dict.baseEntries(chunk);
      final byForm = {for (final (f, e) in entries) f: e};

      var used = chunk.length;
      for (var i = 0; i < chunk.length; i++) {
        final e = byForm[chunk[i]];
        if (e == null) continue;
        final card = Flashcard.fromEntry(
          e,
          source: 'Häufige Wörter #${pos + i + 1}',
        );
        if (!deckIds.add(card.id)) continue;
        added.add(card);
        if (added.length >= count) {
          used = i + 1;
          break;
        }
      }
      pos += used;
    }

    await _store.addAll(added);
    await setPosition(pos);
    return added;
  }
}
