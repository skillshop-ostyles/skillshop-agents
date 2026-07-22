# Sprint 02 — spec-luegendetektor (/spec-check)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

Specs, Tickets und Anforderungsdokumente widersprechen sich, lassen Kernfragen offen
und enthalten stille Annahmen — und niemand merkt es, bis das Falsche gebaut wurde.
Menschen überlesen Widersprüche, die 40 Seiten auseinander liegen. Ein LLM kann ein
gesamtes Anforderungs-Korpus in einem Zug auf Konsistenz, Vollständigkeit und
Testbarkeit prüfen — das war vorher schlicht nicht machbar.

## 2. Nutzen

Vorher: Widersprüche fallen im Sprint-Review oder in Prod auf; jede späte Entdeckung
kostet das Zehnfache. Nachher: Prüfbericht VOR Entwicklungsbeginn mit konkreten
Klärungsfragen an den Product Owner. Profiteure: Devs (bauen nicht das Falsche),
POs (bekommen präzise Rückfragen statt vager Bedenken).

## 3. Scope / Nicht-Scope

**Scope:** Analyse von Text-Dateien (md, txt, sowie als Text lesbare Ticket-Exporte)
in einem angegebenen Verzeichnis oder als explizite Datei-Liste.
**Nicht-Scope:** Kein Zugriff auf Live-Ticket-Systeme (Jira-API etc.). Keine
PDF-/Word-Konvertierung (falls nötig, User um Text-Export bitten). Bewertet nicht die
fachliche Richtigkeit — nur innere Konsistenz, Lücken, Testbarkeit.

## 4. Skill-Spezifikation

Ordner: `spec-luegendetektor/`

Frontmatter:

```yaml
---
name: spec-luegendetektor
description: "Requirements lie detector: reads a corpus of specs/tickets (text files) and finds contradictions, gaps, ambiguities, silent assumptions and untestable statements - each finding with quote, location, severity and a concrete clarification question. Read-only. Trigger: /spec-check"
trigger: /spec-check
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Quelle klären: `-SpecDir` (Verzeichnis) oder Datei-Liste. Bestätigen.
3. `scripts/intake.ps1` ausführen → Datei-Inventar als JSON.
4. Alle inventarisierten Dateien vollständig lesen (Read-Tool), LLM-Analyse gemäß § 6.
5. Report `spec-check-report.md` ins aktuelle Arbeitsverzeichnis, Kernbefunde
   zusammenfassen, die 3 wichtigsten Klärungsfragen zuerst nennen.

Usage:

```
/spec-check                    # interaktiv: Spec-Verzeichnis erfragen
/spec-check <dir>              # alle Text-Dateien unter <dir> prüfen
/spec-check <datei1> <datei2>  # explizite Dateien prüfen
/spec-check --help             # Usage anzeigen, stopp
```

## 5. Collector-Skripte

### scripts/intake.ps1

Parameter: `-SpecDir` (Pflicht, alternativ `-Files` als String-Array), `-MaxFileKB`
(optional, Default 512).

Read-only. Sammelt rekursiv `*.md`, `*.txt` (bei `-Files`: exakt diese). Pro Datei:
Pfad, Größe, Zeilenanzahl, erste Überschrift (falls vorhanden). Dateien über
`-MaxFileKB` werden gelistet, aber als `oversized: true` markiert (LLM liest sie
dann abschnittsweise). `.env`-artige Dateien und alles mit `secret`/`token`/
`credential` im Namen werden ausgeschlossen und als `excluded` gelistet (BIBEL § 2.5).

JSON-Schema (Beispiel):

```json
{
  "root": "C:\\specs",
  "files": [
    { "path": "C:\\specs\\checkout.md", "sizeKB": 14, "lines": 220, "firstHeading": "Checkout Flow", "oversized": false }
  ],
  "excluded": [],
  "count": 1
}
```

Fehlerverhalten: Verzeichnis existiert nicht → exit 1. Keine passenden Dateien →
leeres Array, Hinweis in Zusammenfassung, exit 0 (SKILL.md: dann User fragen, stopp).

## 6. LLM-Analyse-Steps

Fund-Kategorien (jede Kategorie aktiv absuchen, nicht nur was auffällt):

1. **Widerspruch** — zwei Stellen fordern Unvereinbares (beide zitieren).
2. **Lücke** — ein referenzierter Fall ist nirgends definiert (Fehlerfälle,
   Grenzwerte, Berechtigungen, Leerzustände sind die üblichen Verdächtigen).
3. **Ambiguität** — mehrdeutige Formulierung, die ≥ 2 Implementierungen zulässt
   (beide Lesarten ausformulieren).
4. **Stille Annahme** — die Spec funktioniert nur, wenn etwas Ungesagtes gilt.
5. **Nicht testbar** — Aussage ohne messbares Kriterium ("schnell", "benutzerfreundlich").

Pro Fund: Kategorie, Severity (`hoch` = falsches Produkt droht / `mittel` = Nacharbeit
droht / `niedrig` = Stilfrage), wörtliches Zitat + `Datei:Zeile` (bei Widersprüchen
beide Stellen), eine konkrete, geschlossen formulierte Klärungsfrage.

Report-Struktur: Kurzfassung (Fund-Zählung je Kategorie/Severity) → Funde sortiert
nach Severity → Abschnitt "Klärungsfragen (kopierfertig für den PO)" → "Offene
Fragen" für Unsicheres (BIBEL § 4: Konfidenz-Stufen gelten auch hier — ein
"Widerspruch" der Stufe `vermutet` gehört in Offene Fragen, nicht in die Fundliste).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Leeres Verzeichnis | intake meldet 0 Dateien; User fragen, stopp |
| Eine einzige kleine Datei | Normal prüfen; Kategorien Widerspruch = innerhalb der Datei |
| Sehr großes Korpus (> 30 Dateien) | Zuerst Inventar zeigen, User wählt Teilmenge oder bestätigt Komplettlauf |
| Oversized-Datei | Abschnittsweise lesen (Read mit offset/limit), im Report vermerken |
| Nicht-Text-Dateien im Verzeichnis | Ignorieren, in `excluded` listen |
| Secrets-artige Dateien | Ausschließen, listen, Inhalt niemals lesen |

## 8. Testplan

Smoke: Test-Fixture anlegen unter `spec-luegendetektor/tests/fixture/` mit 2 kleinen
md-Dateien, die einen absichtlichen Widerspruch + eine Lücke + eine nicht testbare
Aussage enthalten (Fixture gehört zum Sprint-Deliverable). Dann:

```powershell
& .\spec-luegendetektor\scripts\intake.ps1 -SpecDir ".\spec-luegendetektor\tests\fixture"
```

Erwartung: exit 0, JSON valide, 2 Dateien inventarisiert. Danach LLM-Durchlauf:
der eingebaute Widerspruch MUSS gefunden werden (das ist das harte Akzeptanzkriterium
dieses Sprints), Zitat + Fundstellen korrekt.

Akzeptanz (dreamzzz-api): README/Docs-Dateien des Projekts als Korpus (nur lesen).
Erwartung: Lauf ohne Fehler; Funde plausibel, jede mit korrektem Zitat (stichprobenartig
3 Zitate gegen die Quelldatei prüfen).

Negativ: nicht existentes Verzeichnis → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig
- [x] intake.ps1 inkl. Secrets-Ausschluss und Oversized-Markierung
- [x] Test-Fixture mit eingebauten Fehlern angelegt
- [x] Smoke bestanden; eingebauter Widerspruch wird gefunden, Zitate stimmen
- [x] Akzeptanz-Lauf dokumentiert (3 Zitat-Stichproben verifiziert)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4
- [x] tracking.md aktualisiert, Commit `sprint-02: spec-luegendetektor implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/spec-luegendetektor/` (BIBEL-§-3-Konvention seit
   Sprint 29), Sprint-29-Platzhalter für SKILL.md/README.md durch die echte
   Implementierung ersetzt.
2. **`-Files`-Erkennung von Nicht-.md/.txt-Dateien**: bei explizit genannten Dateien
   (`-Files`) wendet `intake.ps1` bewusst KEINEN Extensions-Filter an ("exakt diese"
   laut Sprint-File) — nur bei `-SpecDir` wird nach `.md`/`.txt` gefiltert.
3. **`Get-ChildItem -Include` vermieden**: `-Include` mit `-Recurse` + `-LiteralPath`
   ist ein bekannter PowerShell-Stolperstein (filtert nicht zuverlässig ohne
   Wildcard-Pfad). Stattdessen `Get-ChildItem -Recurse -File | Where-Object
   Extension -in`, robuster und leichter nachvollziehbar.

## 11. Testergebnisse

**Smoke** (Test-Fixture `skills/spec-luegendetektor/tests/fixture/`, 2 Dateien mit
eingebautem Widerspruch + Lücke + nicht testbarer Aussage): `intake.ps1` liefert
`count: 2`, `excluded: 0`, Überschriften korrekt erkannt. Secrets-Ausschluss separat
mit einer `secret-keys.md`-Testdatei bestätigt (`excluded: 1`, Inhalt nie gelesen).

Manuelle LLM-Analyse gegen die Fixture (das harte Akzeptanzkriterium): der eingebaute
Widerspruch wurde gefunden — `checkout.md:5-6` ("nur EINMAL ... Kombination ... nicht
vorgesehen") vs. `payment.md:5-6` ("können mit anderen Rabattcodes kombiniert
werden"), plus die Lücke (Bestellbestätigungs-E-Mail-Fehlschlag nirgends definiert)
und die nicht-testbare Aussage ("schnell und benutzerfreundlich"). Report erfüllt
BIBEL § 4 (jeder Fund `belegt` mit Zitat + Datei:Zeile, keine `vermutet`-Funde in
diesem einfachen Fixture-Fall, Abschnitt "Offene Fragen" trotzdem vorhanden und
korrekt leer).

**Akzeptanz** (`dreamzzz-api_vs/.agents/skills/stripe-best-practices/references/`,
5 echte Stripe-Referenzdokumente, nur gelesen): `intake.ps1` liefert `count: 5`.
LLM-Analyse fand 3 Funde (kein Widerspruch — plausibel bei einautorigen,
offiziellen Anleitungstexten): Ambiguität in `security.md:20` (Env-Var-Richtlinie
zweideutig lesbar), Lücke in `payments.md:56` (Tokens-API-Zeile der
Migrations-Tabelle ohne Migrationsleitfaden-Link, im Gegensatz zu allen anderen
Zeilen), nicht testbar in `payments.md:50` ("specific need and absolutely no other
way" ohne Kriterium). Alle 3 Zitate stichprobenartig per `grep -n` gegen die
Quelldateien verifiziert — exakte Übereinstimmung (Zeilen 20/56/50).

**Negativ**: nicht existentes Verzeichnis → `Write-Error` "SpecDir existiert nicht"
+ Exit-Code 1, kein unkontrollierter Stack-Trace.
