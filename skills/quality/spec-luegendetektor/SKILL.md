---
name: spec-luegendetektor
description: "Requirements lie detector: reads a corpus of specs/tickets (text files) and finds contradictions, gaps, ambiguities, silent assumptions and untestable statements - each finding with quote, location, severity and a concrete clarification question. Read-only. Trigger: /spec-check"
trigger: /spec-check
---

# /spec-check

Liest ein Korpus aus Specs/Tickets (Text-Dateien) und findet Widersprüche, Lücken,
Ambiguitäten, stille Annahmen und nicht testbare Aussagen — jeder Fund mit Zitat,
Fundstelle, Schweregrad und einer konkreten Klärungsfrage.

## What this is for

- Ein Anforderungs-Korpus VOR Entwicklungsbeginn auf innere Konsistenz prüfen, statt
  Widersprüche erst im Sprint-Review oder in Prod zu entdecken.
- Menschen überlesen Widersprüche, die 40 Seiten auseinander liegen — ein LLM prüft
  das gesamte Korpus in einem Zug.
- **Reiner Lese-Skill.** Bewertet nicht die fachliche Richtigkeit, nur innere
  Konsistenz, Lücken und Testbarkeit. Kein Zugriff auf Live-Ticket-Systeme, keine
  PDF-/Word-Konvertierung.

## What You Must Do When Invoked

Wenn `/spec-check --help` oder `/spec-check -h` (ohne weitere Argumente) aufgerufen
wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Quelle klären

Kläre: entweder `-SpecDir` (ein Verzeichnis, rekursiv nach `.md`/`.txt` durchsucht)
oder eine explizite Datei-Liste. Fehlt beides, erfragen. Zeige, was erkannt wurde:

```
Quelle: <Verzeichnis oder Datei-Liste>
Fortfahren? (yes/no)
```

Erst nach Bestätigung weiter.

### Step 2 — Inventar erstellen

```powershell
& "<SKILL_DIR>/scripts/intake.ps1" -SpecDir "<pfad>"
# oder: -Files "<datei1>","<datei2>"
```

JSON-Ausgabe einlesen. Bricht das Skript mit Exit-Code ≠ 0 ab: Meldung zeigen,
stoppen. Liefert `count: 0`: dem User mitteilen, dass keine passenden Dateien
gefunden wurden, stoppen (nicht raten).

Bei > 30 Dateien im Inventar: das Inventar zuerst zeigen (Pfade + Größen), User
wählt eine Teilmenge oder bestätigt den Komplettlauf.

### Step 3 — Alle Dateien lesen und analysieren

Jede inventarisierte Datei (nicht `excluded`) vollständig mit dem Read-Tool lesen
(bei `oversized: true` abschnittsweise per offset/limit). Dann für jede der 5
Fund-Kategorien aktiv suchen, nicht nur notieren, was zufällig auffällt:

1. **Widerspruch** — zwei Stellen fordern Unvereinbares (beide zitieren, beide
   Fundstellen nennen).
2. **Lücke** — ein referenzierter Fall ist nirgends definiert (Fehlerfälle,
   Grenzwerte, Berechtigungen, Leerzustände sind die üblichen Verdächtigen).
3. **Ambiguität** — mehrdeutige Formulierung, die ≥ 2 Implementierungen zulässt
   (beide Lesarten ausformulieren).
4. **Stille Annahme** — die Spec funktioniert nur, wenn etwas Ungesagtes gilt.
5. **Nicht testbar** — Aussage ohne messbares Kriterium ("schnell",
   "benutzerfreundlich").

Pro Fund: Kategorie, Severity (`hoch` = falsches Produkt droht, `mittel` = Nacharbeit
droht, `niedrig` = Stilfrage), wörtliches Zitat + `Datei:Zeile` (bei Widersprüchen
beide Stellen), eine konkrete, geschlossen formulierte Klärungsfrage.

Konfidenz-Stufen gelten auch hier (`ops/BIBEL.md` § 4): ein "Widerspruch" der Stufe
`vermutet` gehört in "Offene Fragen", nicht in die Fundliste.

### Step 4 — Report schreiben

Report-Struktur (Markdown), Datei `spec-check-report.md` im aktuellen
Arbeitsverzeichnis (**nicht** ins geprüfte Verzeichnis schreiben):

1. **Kurzfassung** — Fund-Zählung je Kategorie und Severity.
2. **Funde** — sortiert nach Severity (hoch → niedrig), pro Fund: Kategorie, Zitat(e)
   + Fundstelle(n), Klärungsfrage.
3. **Klärungsfragen (kopierfertig für den PO)** — nur die Fragen, ohne Kontext,
   direkt kopierbar.
4. **Offene Fragen** — alles der Konfidenz-Stufe `vermutet`.

### Step 5 — Zusammenfassen

Nenne dem User den Pfad des Reports. Fasse die 3 wichtigsten Klärungsfragen zuerst,
dann die Gesamtzahl der Funde je Severity.

## Usage

```
/spec-check                    # interaktiv: Spec-Verzeichnis erfragen
/spec-check <dir>              # alle Text-Dateien unter <dir> prüfen
/spec-check <datei1> <datei2>  # explizite Dateien prüfen
/spec-check --help             # Usage anzeigen, stopp
```
