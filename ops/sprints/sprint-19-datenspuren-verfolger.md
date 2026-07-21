# Sprint 19 — datenspuren-verfolger (/pii-trace)

Regeln: `ops/BIBEL.md` gilt vollständig. Masken-Regel (§ 2.5) gilt verschärft:
dieser Skill gibt NIEMALS echte personenbezogene Werte aus — er arbeitet
ausschließlich auf Feld-/Spalten-NAMEN und Code-Stellen.

## 1. Problem

"Wo überall liegen personenbezogene Daten?" — die DSGVO-Frage, die kein Team
vollständig beantworten kann. E-Mail, Name, Adresse fließen von Eingabe über Services
in Datenbanken, Logs, Exporte und Dritt-APIs; die Landkarte dieser Flüsse existiert
nirgends. Sie zu bauen heißt: PII-Felder identifizieren (semantisch — `contactInfo`
ist PII, `errorCount` nicht) und ihre Senken verfolgen. Die Semantik-Hälfte war der
Blocker — LLM-Terrain.

## 2. Nutzen

Vorher: Verarbeitungsverzeichnis wird aus Interviews zusammengeraten; "PII in Logs"
fällt beim Audit oder Breach auf. Nachher: Datenspuren-Karte (Feld → Quellen →
Senken) mit Befunden: PII in Log-Statements, PII an Dritt-APIs, PII-Felder ohne
erkennbare Lösch-/Anonymisierungs-Logik. Profiteure: Datenschutz-Beauftragte
(Zulieferung fürs Verarbeitungsverzeichnis), Security, jedes Audit.

## 3. Scope / Nicht-Scope

**Scope:** PII-Feld-Kandidaten aus Schemas/Models/DTOs (Namens-Semantik + Typ-Kontext),
Senken-Analyse: Log-Aufrufe, externe Calls, Datei-Exporte, DB-Schreibpfade.
Statische Fluss-Verfolgung auf Feld-Namens-Ebene.
**Nicht-Scope:** Keine echten Datenbestände anfassen (keine DB-Verbindung, keine
Prod-Daten). Keine Rechtsberatung (Report liefert technische Landkarte, keine
DSGVO-Konformitätsaussage — Formulierung im Report entsprechend). Kein Taint-Tracking
auf Variablen-Ebene (Feld-Namens-Heuristik + LLM-Lektüre, Grenzen ausweisen).

## 4. Skill-Spezifikation

Ordner: `datenspuren-verfolger/`

Frontmatter:

```yaml
---
name: datenspuren-verfolger
description: "PII trace mapper: identifies personal-data field candidates in schemas/models/DTOs (semantic naming + type context), traces their sinks across the codebase (log statements, third-party calls, file exports, storage writes) and builds the data-flow map nobody has - flagging PII in logs, PII sent to external APIs and PII fields without visible deletion logic. Works on field NAMES only, never touches real data. Read-only. Trigger: /pii-trace"
trigger: /pii-trace
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir`. Bestätigen. Hinweis: Ergebnis ist technische Zulieferung,
   keine Rechtsberatung.
3. `scripts/pii-scan.ps1` ausführen.
4. LLM-Analyse gemäß § 6.
5. Report `pii-trace-report.md` ins Arbeitsverzeichnis; Kurzfassung: PII-in-Logs-
   und Dritt-API-Befunde zuerst.

Usage:

```
/pii-trace               # interaktiv
/pii-trace <dir>         # Datenspuren-Karte erstellen
/pii-trace --help
```

## 5. Collector-Skripte

### scripts/pii-scan.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions` (Default wie Sprint 03 plus
sql,prisma,graphql,proto), `-Exclude` (Default wie Sprint 03), `-ExtraTerms`
(optional, String-Array für domänenspezifische PII-Begriffe).

Read-only. Zwei Phasen:

1. **PII-Feld-Kandidaten** aus Struktur-Definitionen (Model/DTO/Schema-Blöcke,
   CREATE TABLE, prisma models): Feldname matcht PII-Wortliste
   (email,mail,name,first,last,vorname,nachname,phone,tel,mobile,address,adresse,
   street,strasse,city,zip,plz,birth,geburt,dob,age,gender,geschlecht,iban,bic,
   account,ssn,sozialversicherung,steuer,tax.?id,passport,ausweis,ip.?addr,
   location,geo,lat,lng,photo,avatar,signature + `-ExtraTerms`). Pro Kandidat:
   Struktur-Name, Feldname, Datei:Zeile, Quelle (dto/sql/prisma/...).
2. **Senken-Stellen** (unabhängig von Phase 1, Zuordnung macht das LLM):
   - **log**: Log-Aufrufe (Muster Sprint 09), deren Argument-Text einen
     Kandidaten-Feldnamen ODER ein Objekt-Ganzes (`user`, `customer`,
     Struktur-Namen aus Phase 1) enthält.
   - **external**: HTTP-Aufrufe (Muster Sprint 16) mit Kandidaten-Feldnamen/
     Struktur-Namen im Umfeld (± 5 Zeilen).
   - **export**: Datei-Schreib-Aufrufe (writeFile, csv, xlsx, Set-Content) mit
     Kandidaten-Bezug im Umfeld.
   - **storage**: DB-Schreibmuster (INSERT/save/create/update) mit Kandidaten-Bezug.
   - **deletion**: Lösch-/Anonymisierungs-Signale (`delete|remove|anonymi|purge|
     retention|gdpr|dsgvo` in Funktions-/Dateinamen oder nahe Kandidaten-Feldern).

JSON-Schema (Beispiel):

```json
{
  "piiCandidates": [
    { "structure": "User", "field": "email", "file": "src/models/user.ts", "line": 8, "source": "dto" }
  ],
  "sinks": {
    "log": [ { "file": "src/auth/login.ts", "line": 52, "text": "logger.info('login', { user })", "matched": ["user"] } ],
    "external": [], "export": [], "storage": [], "deletion": []
  },
  "counts": { "candidates": 14, "log": 6, "external": 2, "export": 1, "storage": 9, "deletion": 1 }
}
```

Wichtig: `text` ist Code-Zeilentext (enthält nie echte Personendaten — es ist
Quellcode). Fehlerverhalten: Pfad fehlt → exit 1; 0 Kandidaten → exit 0 + Meldung
(SKILL.md: Ergebnis "keine PII-Strukturen erkennbar" ist ein gültiger Report).

## 6. LLM-Analyse-Steps

1. **Kandidaten härten**: Namens-Treffer semantisch prüfen (`firstName` ja,
   `className` nein, `age` im Cache-Kontext = TTL, nicht PII) — Fehltreffer
   aussortieren, im Anhang listen. PII-Sensitivitäts-Stufe je Feld: besonders
   sensibel (Gesundheit, Ausweis, IBAN) / normal / pseudonym-nah (IDs, IP).
2. **Fluss-Zuordnung**: pro Senken-Stelle lesen (Read), welche PII-Struktur/Felder
   tatsächlich fließen — ganzes Objekt geloggt (`{ user }`) = alle dessen
   PII-Felder. Konfidenz je Zuordnung (BIBEL § 4).
3. **Befund-Klassen**:
   - **PII in Logs** (Severity hoch bei besonders sensibel oder ganzem Objekt).
   - **PII an externe Empfänger** (Empfänger benennen soweit erkennbar — URL/Host
     aus dem Code).
   - **PII in Datei-Exporten** (Pfad/Format).
   - **Kein Lösch-Pfad erkennbar**: PII-Strukturen mit storage-Senke, aber ohne
     deletion-Signal (`vermutet`-Ebene — Löschung kann außerhalb liegen, sagen).
4. **Datenspuren-Karte**: Tabelle Struktur.Feld × Sensitivität × Senken (mit
   Datei:Zeile je Senke).
5. Report: Kurzfassung → Befunde nach Klasse/Severity → Karte →
   Aussortierte Fehltreffer → Grenzen der Analyse (kein Taint-Tracking, nur
   erkennbare Namens-Flüsse) → Offene Fragen. Formulierung durchgehend technisch,
   Disclaimer "keine Rechtsberatung" im Kopf.
6. Evidenz-Pflicht: jeder Fluss mit Quelle (Struktur-Definition Datei:Zeile) UND
   Senke (Datei:Zeile + Code-Zitat).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Feld heißt neutral, enthält PII (data, value, payload) | Bekannte Grenze — im Grenzen-Abschnitt nennen, nicht raten |
| Verschlüsselungs-Signale (encrypt, hash) nahe PII-Feld | Positiv vermerken (mindert Severity), Beleg zitieren |
| Test-/Seed-Daten mit erfundenen Personen | Als Senke irrelevant; Fixture-/Seed-Pfade erkennen und aussondern |
| Fremdsprachige Feldnamen | Wortliste deckt de/en; -ExtraTerms für weitere |
| Logging-Wrapper (eigene log()-Funktion) | Wrapper-Definition suchen; Aufrufe des Wrappers zählen als log-Senke |
| Sehr viele Kandidaten (> 100) | Besonders-sensibel + hoch-Befunde vollständig, Rest in Karte + Zählwerte |

## 8. Testplan

Smoke: Fixture `datenspuren-verfolger/tests/fixture/` mit: 1 Model (Felder: email,
firstName, iban, errorCount als Nicht-PII-Kontrolle), 1 Datei, die das ganze
User-Objekt loggt, 1 Datei mit HTTP-Post der email an eine externe URL, KEIN
Lösch-Code. Dann:

```powershell
& .\datenspuren-verfolger\scripts\pii-scan.ps1 -ProjectDir ".\datenspuren-verfolger\tests\fixture"
```

Erwartung: exit 0, JSON valide; email/firstName/iban als Kandidaten, errorCount
NICHT (bzw. vom LLM aussortiert); log- und external-Senke erfasst. LLM-Durchlauf:
PII-in-Logs-Befund (ganzes Objekt → alle Felder), externer-Empfänger-Befund mit
URL, Kein-Lösch-Pfad-Hinweis (harte Kriterien; errorCount darf im Endreport nicht
als PII stehen).

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: Karte plausibel; 3 Flüsse
stichprobenartig durch Lesen verifiziert; Fehltreffer-Aussortierung nachvollziehbar.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (Nie-echte-Daten-Regel + Kein-Rechtsberatungs-Disclaimer)
- [ ] pii-scan.ps1 (Wortliste, 5 Senken-Klassen, ExtraTerms)
- [ ] Fixture mit Kontroll-Feld angelegt
- [ ] Smoke bestanden; alle 3 Befunde korrekt, Kontroll-Feld sauber aussortiert
- [ ] Akzeptanz-Lauf dokumentiert (3 Fluss-Stichproben)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4 + Grenzen-Abschnitt vorhanden
- [ ] tracking.md aktualisiert, Commit `sprint-19: datenspuren-verfolger implementiert`
