import 'package:deutsch_lesen/services/dewiktionary_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Trimmed excerpts of real de.wiktionary.org pages.
const leitplanke = r"""
== Leitplanke ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{f}} ===

{{Deutsch Substantiv Übersicht
|Genus=f
|Nominativ Singular=Leitplanke
|Nominativ Plural=Leitplanken
|Genitiv Singular=Leitplanke
|Genitiv Plural=Leitplanken
|Bild=2007 10 22 - 29A@Dustin - Guardrail on NE corner.JPG|mini|1|Leitplanke
}}

{{Bedeutungen}}
:[1] Sicherheitsbegrenzung einer Straßenaußenseite

{{Herkunft}}
:[[Determinativkompositum]], zusammengesetzt aus ''[[leiten]]''

==== {{Übersetzungen}} ====
{{Ü-Tabelle|1|G=Sicherheitsbegrenzung|Ü-Liste=
*{{en}}: {{Ü|en|crash barrier}}, {{Ü|en|guardrail}}
*{{fr}}: {{Ü|fr|glissière de sécurité}} {{f}}
}}
""";

const gehen = r"""
{{Siehe auch|[[Gehen]]}}
== gehen ({{Sprache|Deutsch}}) ==
=== {{Wortart|Verb|Deutsch}}, {{unreg.}}, {{intrans.}} ===

{{Deutsch Verb Übersicht
|Präsens_ich=gehe
|Präsens_er, sie, es=geht
|Präteritum_ich=ging
|Partizip II=gegangen
|Hilfsverb=sein
}}

{{Bedeutungen}}
*{{K|intrans.}}
:[1] sich [[schreiten]]d, schrittweise fortbewegen
:[2] einen Ort oder eine Zusammenkunft verlassen

==== {{Übersetzungen}} ====
*{{en}}: {{Ü|en|walk}}, {{Ü|en|go}}
*{{en}}: {{Ü|en|go}}, {{Ü|en|leave}}
*{{en}}: {{Ü|en|}}
""";

const ging = r"""
== ging ({{Sprache|Deutsch}}) ==
=== {{Wortart|Konjugierte Form|Deutsch}} ===

{{Grammatische Merkmale}}
*1. Person Singular Indikativ Präteritum Aktiv des Verbs '''[[gehen]]'''
*3. Person Singular Indikativ Präteritum Aktiv des Verbs '''[[gehen]]'''

{{Grundformverweis Konj|gehen}}
""";

const die = r"""
== die ({{Sprache|Deutsch}}) ==
=== {{Wortart|Artikel|Deutsch}} ===
{{Bedeutungen}}
:[1] bestimmter Artikel im Femininum
== die ({{Sprache|Englisch}}) ==
=== {{Wortart|Verb|Englisch}} ===
{{Bedeutungen}}
:[1] sterben
""";

void main() {
  test('noun: gender, plural, genitive, English', () {
    final e = parseGermanEntries('Leitplanke', leitplanke).single;
    expect(e.wordType, 'Substantiv');
    expect(e.genders, ['f']);
    expect(e.headword, 'die Leitplanke');
    expect(e.pluralWithArticle, 'die Leitplanken');
    expect(e.genitiveWithArticle, 'der Leitplanke');
    expect(e.english, ['crash barrier', 'guardrail']);
    expect(e.meanings, ['Sicherheitsbegrenzung einer Straßenaußenseite']);
  });

  test('verb: principal parts with auxiliary, deduped translations', () {
    final e = parseGermanEntries('gehen', gehen).single;
    expect(e.verbForms, 'geht · ging · ist gegangen');
    expect(e.english, ['walk', 'go', 'leave']);
    expect(e.meanings.first, 'sich schreitend, schrittweise fortbewegen');
    expect(e.meanings.length, 2);
  });

  test('inflected form links to its base word', () {
    final e = parseGermanEntries('ging', ging).single;
    expect(e.lemma, 'gehen');
    expect(e.isInflectedForm, isTrue);
    expect(
      e.grammarNotes.first,
      '1. Person Singular Indikativ Präteritum Aktiv des Verbs gehen',
    );
  });

  test('only the German section is parsed', () {
    final entries = parseGermanEntries('die', die);
    expect(entries.map((e) => e.wordType), ['Artikel']);
  });

  test('page without German section yields nothing', () {
    expect(
      parseGermanEntries('x', '== x ({{Sprache|Englisch}}) ==\n'),
      isEmpty,
    );
  });

  test('old spelling points to the modern word', () {
    final e = parseGermanEntries(
      'daß',
      '== daß ({{Sprache|Deutsch}}) ==\n{{Alte Schreibweise|dass|Reform 1996}}\n',
    ).single;
    expect(e.lemma, 'dass');
    expect(e.isInflectedForm, isTrue);
    expect(
      e.grammarNotes.single,
      'Alte Schreibweise (vor der Reform 1996) – heute: dass',
    );
  });

  test('context labels keep free text and resolve links inside', () {
    expect(
      cleanWikitext(
        r"[1] {{K|intrans.|Prä=auf|Kas=Akkusativ|ft=warten [[auf#Präposition|auf]] das Ereignis ([[Akkusativ]])}} [[Zeit]] [[verstreichen]] lassen",
      ),
      '(intrans., warten auf das Ereignis (Akkusativ)) Zeit verstreichen lassen',
    );
    expect(
      cleanWikitext('[2] {{K|trans.}} technische [[Apparat]]e [[pflegen]]'),
      '(trans.) technische Apparate pflegen',
    );
  });
}
