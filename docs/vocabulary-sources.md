# Vocabulary sources (Wortschatz)

Word lists, dictionaries and sentence collections that could feed the
flashcards or the reader. "In use" means the app already depends on it.
Licences were checked in Nov 2026; re-check before shipping anything public.

## In use

### FrequencyWords (Hermit Dave) — common-words deck
- **What:** frequency lists for ~60 languages from the OpenSubtitles 2018 corpus. German: `de_50k.txt` (top 50,000 word forms with counts), `de_full.txt` (all).
- **Licence:** CC BY-SA 4.0 (content); code MIT.
- **Access:** raw text on GitHub, CORS-enabled:
  `https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/de/de_50k.txt`
- **Used in:** `lib/services/common_words.dart` (downloads once, keeps top 10,000, reduces forms to base words via Wiktionary).
- **Caveats:** inflected forms counted separately and lowercased; conversational/film bias; some names and English words.
- https://github.com/hermitdave/FrequencyWords

### Wiktionary — dictionary
- **de.wiktionary.org** (MediaWiki API, CORS with `origin=*`): gender, plural, verb/adjective forms, German meanings, English translations (`{{Ü|en|…}}`), inflected-form → base-word links, old spellings. Parser: `lib/services/dewiktionary_parser.dart`.
- **en.wiktionary.org** REST `page/definition/{word}`: fallback only, to find base words missing from de.wiktionary.
- **Licence:** CC BY-SA 4.0 (attribution in Settings).
- **Caveat:** rate-limits bursts (HTTP 429); batch titles (≤ 50 per request).

## Candidates

### Leipzig Corpora Collection (Wortschatz Leipzig) — news-based frequencies
- **What:** corpora per language and year from news, web and Wikipedia (sizes 10K–1M+ sentences). Downloads include sentences, word lists with frequencies, and co-occurrences.
- **Why:** better match for the news/commentary the app shows than subtitles.
- **Licence:** the terms-of-use page says downloadable text corpora are CC BY; the download page also says the data is copyright-protected and refers to the terms — read https://wortschatz.uni-leipzig.de/en/usage before redistributing.
- **Access:** https://wortschatz.uni-leipzig.de/en/download/German (pick e.g. `deu_news_2023_1M`). Tab-separated UTF-8 `.tar.gz`; format doc: https://www.wortschatz.uni-leipzig.de/public/documents/Format_Download_File-eng.pdf
- **Integration idea:** preprocess offline into a lemma list (same Wiktionary reduction as FrequencyWords), ship as an asset; the download page needs a browser, so don't fetch it from the app.
- **Cite:** Goldhahn, Eckart & Quasthoff (2012), *Building Large Monolingual Dictionaries at the Leipzig Corpora Collection: From 100 to 200 Languages*, LREC.

### DWDS (Digitales Wörterbuch der deutschen Sprache) — frequency class per word
- **What:** BBAW's German dictionary portal. Public JSON API, verified working:
  `https://www.dwds.de/api/frequency/?q=Haus` → `{"lemma":"Haus","frequency":5,...}` (frequency class 0–6, 6 = most common).
  Also `https://www.dwds.de/api/wb/snippet/?q=Haus` (dictionary snippet).
- **Why:** rank/filter any word by commonness (e.g. "only suggest class ≥ 4"), or show a commonness meter on the word sheet. Lemma-based, so no form reduction needed.
- **Licence/terms:** see https://www.dwds.de/d/api — check usage limits before calling it per word in bulk.

### DeReWo (IDS Mannheim) — lemma frequency lists from DeReKo
- **What:** corpus-based lemma and word-form lists (e.g. 100,000 most frequent lemmas) from the German Reference Corpus — written, mostly newspaper German. Versions 2007–2014.
- **Licence:** not freeware; non-commercial use only; must be passed on together with its documentation. Fine for a personal app, not for redistribution.
- **Access:** https://www.ids-mannheim.de/en/s/corpus-linguistics/projects/methods-of-analysis/corpus-based-lemma-and-word-form-lists/ (contact: derewo@ids-mannheim.de)

### SUBTLEX-DE — research-grade subtitle frequencies
- **What:** frequencies from 25.4M words of film/TV subtitles; shown to predict word familiarity well (Brysbaert et al. 2011, *Experimental Psychology* 58).
- **Licence:** CC BY-NC-ND 3.0 (non-commercial, no derivatives).
- **Access:** historically http://crr.ugent.be/archives/534 (old address — verify); listed on OSF: https://osf.io/479um/wiki
- **Note:** similar in spirit to FrequencyWords; only worth switching to for its cleaner data.

### Goethe-Institut word lists — exam vocabulary by CEFR level
- **What:** official word lists for Goethe-Zertifikat A1 (Start Deutsch 1 / Fit in Deutsch 1), A2 (~1,300 lexical units), B1 (with ÖSD and Uni Freiburg/CH). Organised by topic, then alphabetically.
- **Licence:** copyrighted PDFs — don't scrape or bundle. A user could import their own copy via a CSV/text import feature.
- **Access:** https://goethe.de/en/spr/prf/vor.html (exam preparation page; download from goethe.de, not third-party mirrors).
- **Integration idea:** "Import word list" screen (paste/CSV) → Wiktionary lookup → cards tagged A1/A2/B1.

### Kaikki.org / wiktextract — Wiktionary as bulk JSON
- **What:** machine-readable extraction of Wiktionary (all German entries with senses, forms, translations, sounds, examples) as JSONL. Per-word pages and full dumps.
- **Licence:** Wiktionary content, CC BY-SA (confirm on kaikki.org).
- **Access:** https://kaikki.org/dictionary/rawdata.html ; tool: https://github.com/tatuylonen/wiktextract
- **Why:** offline dictionary (no API calls, no 429s) — e.g. precompute a compact lemma DB for the top 20k words and ship it as an asset. Dumps are periodic, not live.

### Tatoeba — example sentences with translations
- **What:** crowd-sourced sentences with translations; downloadable German–English pairs ("sentences in language A translated into language B").
- **Licence:** CC BY 2.0 FR (some sentences CC0). Attribute "sentences from Tatoeba" with a link.
- **Access:** https://tatoeba.org/en/downloads (updated weekly)
- **Why:** add a short example sentence + translation to cards that weren't saved from reading.

### Wiktionary frequency lists (en.wiktionary)
- `Wiktionary:Frequency lists/German` (e.g. "Mixed web 3M"). Word forms, not lemmas; same reduction needed. Lower priority than the above.
