# Deutsch Lesen

A personal German reading app (Flutter, Android + web). Read daily news or a
fairy tale, tap any word to see its dictionary meaning and grammatical form,
and ask Claude to explain the grammar of the sentence. Saved words are kept
on the device for future flashcards. No login; everything is stored locally.

## Sources

| What | Source | Notes |
|---|---|---|
| News | [tagesschau.de API](https://www.tagesschau.de/api2u/news/) | No CORS, so news works in the APK only (web needs a proxy) |
| Stories | Brüder Grimm, 1857 edition, via [de.wikisource.org](https://de.wikisource.org) | Public domain, old spelling ("daß"); cached on device after first load |
| Dictionary | [de.wiktionary.org](https://de.wiktionary.org) (+ en.wiktionary fallback) | CC BY-SA; article, plural, verb forms, English translations |
| Common words | [FrequencyWords](https://github.com/hermitdave/FrequencyWords) (OpenSubtitles 2018) | CC BY-SA 4.0; forms reduced to base words via Wiktionary |
| Flashcards | [FSRS](https://github.com/open-spaced-repetition/dart-fsrs) scheduler | 90% target retention; review history kept for later optimisation |
| Grammar | Claude API (`claude-opus-5-5`) | Optional; needs your Anthropic API key in Settings |

More vocabulary sources (Leipzig Corpora, DWDS, DeReWo, Goethe lists, Tatoeba…) with licences and integration notes: [docs/vocabulary-sources.md](docs/vocabulary-sources.md).

## Run

```sh
flutter pub get
flutter run                    # on a connected Android device / emulator
flutter run -d chrome          # web
flutter build apk --release    # → build/app/outputs/flutter-apk/app-release.apk
flutter build web --release    # → build/web
```

## Layout

- `lib/services/` – news, stories, dictionary, Claude grammar, local storage
- `lib/screens/` – news list, stories, reader, saved words, settings
- `lib/widgets/word_sheet.dart` – the bottom sheet shown when a word is tapped
