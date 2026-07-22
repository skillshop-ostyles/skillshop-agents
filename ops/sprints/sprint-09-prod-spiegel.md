# Sprint 09 — prod-spiegel (/mirror)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

Zwischen dem, was ein System laut Code tun SOLLTE, und dem, was es in Produktion
WIRKLICH tut, klafft immer eine Lücke: Features, die niemand nutzt; Fehlerpfade, die
täglich feuern, aber verschluckt werden; "unmögliche" Zustände, die ständig eintreten;
Hot Paths, die keiner für heiß hielt. Beides gleichzeitig zu lesen — den Code mit
seinen Erwartungen UND die Logs mit ihrer Realität — und die Deltas zu benennen,
überfordert Menschen schon bei mittlerer Systemgröße. Für ein LLM ist genau dieser
Abgleich machbar geworden.

## 2. Nutzen

Vorher: Prod-Realität kennt niemand ganz; Entscheidungen ("können wir Feature X
abschalten?") basieren auf Meinung. Nachher: Spiegel-Report mit belegten Deltas:
tote Features (0 Log-Spuren), verschluckte Fehler (Catch ohne Konsequenz, der real
feuert), unerwartete Hot Paths. Profiteure: Product (Abschalt-Entscheidungen), Devs
(echte Prioritäten), On-Call (bekannte stille Fehler werden sichtbar).

## 3. Scope / Nicht-Scope

**Scope:** Exportierte Log-Dateien (Text/JSON-Lines) lokal einlesen, statistisch
verdichten; Code-Erwartungen extrahieren (Log-Statements, Catch-Blöcke, Routen/
Kommandos); Abgleich per LLM. Lokal-tauglich: keine Live-Anbindung nötig.
**Nicht-Scope:** Kein Anschluss an Observability-Plattformen (User exportiert
selbst). Keine Metriken-/Tracing-Formate (nur Logs). Keine PII-Verarbeitung: Skript
maskiert E-Mail-Adressen und lange Ziffernfolgen in allen Ausgaben. Read-only.

## 4. Skill-Spezifikation

Ordner: `prod-spiegel/`

Frontmatter:

```yaml
---
name: prod-spiegel
description: "Production behavior mirror: ingests exported log files (text or JSON lines), statistically condenses them (frequencies, error rates, hot paths), extracts the code's expectations (log statements, catch blocks, routes), then has the LLM report the deltas - dead features, swallowed errors firing daily, unexpected hot paths. Works fully offline on exported logs. Read-only. Trigger: /mirror"
trigger: /mirror
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir` (Code) + `-LogDir` (exportierte Logs) + grobe Angabe des
   Log-Zeitraums (Freitext, für die Einordnung im Report). Bestätigen.
3. `scripts/log-ingest.ps1` ausführen.
4. `scripts/code-claims.ps1` ausführen.
5. LLM-Abgleich gemäß § 6, Report `mirror-report.md`.

Usage:

```
/mirror                          # interaktiv
/mirror <repo> <logdir>          # Abgleich Code vs. Logs
/mirror --help
```

## 5. Collector-Skripte

### scripts/log-ingest.ps1

Parameter: `-LogDir` (Pflicht), `-MaxLinesPerFile` (Default 200000), `-SampleSize`
(Default 20 Beispiel-Zeilen pro Muster).

Read-only. Verarbeitet `*.log`, `*.txt`, `*.jsonl`, `*.json` (JSON-Lines):

1. **Format-Erkennung** pro Datei: JSON-Lines (Zeile parst als JSON) oder Text.
2. **Normalisierung zu Mustern**: Zeitstempel, UUIDs, Zahlen, Quoted-Strings durch
   Platzhalter ersetzen (`<TS>`, `<UUID>`, `<N>`, `<STR>`) → gleichartige Zeilen
   fallen auf ein Muster zusammen.
3. **Aggregation**: pro Muster Häufigkeit, Level-Verteilung (falls erkennbar:
   error/warn/info/debug), erste/letzte Vorkommenszeit (falls Zeitstempel parsebar),
   bis zu `-SampleSize` Original-Beispiele (PII-maskiert: E-Mails →
   `<EMAIL>`, Ziffernfolgen ≥ 6 → `<NUM>`).
4. **Kennzahlen**: Gesamtzeilen, Fehlerquote, Top-50-Muster nach Häufigkeit,
   Top-20-Error-Muster.

JSON-Schema (Beispiel):

```json
{
  "files": 4, "totalLines": 512000, "truncated": true,
  "patterns": [
    { "pattern": "payment failed for order <UUID>: <STR>", "count": 8123, "level": "error", "first": "2026-06-01T02:11:00", "last": "2026-07-19T23:58:00", "samples": ["..."] }
  ],
  "errorRate": 0.031
}
```

### scripts/code-claims.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie Sprint 03).

Read-only. Extrahiert die "Erwartungen" des Codes:

1. **Log-Statements**: Zeilen mit `log.|logger.|console.|Log(...)`-Mustern inkl.
   Level und Message-Literal (Datei:Zeile).
2. **Catch-Blöcke**: `catch`-Zeilen + die 3 Folgezeilen (erkennt leere/verschluckende
   Catches: kein rethrow, kein Log im Kontext → Flag `swallowGuess: true`).
3. **Routen/Kommandos**: `(get|post|put|delete|patch)\s*\(\s*['"]`-Muster,
   Route-Decorators (`@Get`, `@app.route`, `[HttpGet]`), CLI-Command-Registrierungen.

JSON: drei Listen (`logStatements`, `catchBlocks`, `routes`) mit Datei:Zeile + Text.

Fehlerverhalten beider Skripte: fehlende Pfade → exit 1; leeres LogDir → Meldung +
exit 1 (ohne Logs ist der Skill sinnlos).

## 6. LLM-Analyse-Steps

Abgleich in vier Richtungen (jede aktiv durchführen):

1. **Code erwartet, Logs schweigen** → Kandidaten für tote Features: Routen und
   Log-Messages, deren Muster in den Logs nicht vorkommen. Vorsicht: Log-Level kann
   in Prod gefiltert sein (info/debug fehlen dann systematisch — prüfen, ob
   ÜBERHAUPT info-Zeilen im Log sind, sonst diese Richtung auf error/warn begrenzen
   und die Einschränkung ausweisen).
2. **Logs schreien, Code verschluckt** → Error-Muster mit hoher Frequenz, deren
   Ursprung ein `swallowGuess`-Catch oder ein Log ohne weitere Behandlung ist:
   die "stillen Dauerbrenner". Mapping Log-Muster ↔ Code-Stelle über
   Message-Literal-Ähnlichkeit (wörtlich > normalisiert > semantisch; Konfidenz
   entsprechend `belegt`/`wahrscheinlich`/`vermutet`).
3. **Unerwartete Hot Paths** → Top-Muster nach Häufigkeit, deren Code-Stellen
   unscheinbar wirken (z. B. Retry-Schleifen, Fallbacks) — benennen, was die
   Häufigkeit über das Systemverhalten aussagt.
4. **"Unmögliche" Zustände** → Log-Muster, die laut Code "should never happen"-
   Charakter haben (Message enthält never/unreachable/unexpected/impossible) und
   trotzdem zählbar feuern.
5. Report: Kurzfassung (Kennzahlen + 3 wichtigste Deltas) → die vier Delta-Kategorien
   mit Evidenz (Log-Muster + Count + Zeitraum, Code-Stelle Datei:Zeile) →
   Empfehlungen (konkret: "Catch in X:123 loggt nicht — Fehler seit 6 Wochen
   8123×") → Offene Fragen (alle `vermutet`-Mappings, Log-Level-Einschränkungen).
6. Evidenz-Pflicht: jedes Delta braucht BEIDE Seiten (Code-Stelle UND Log-Statistik)
   oder wird als einseitig gekennzeichnet.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Riesige Logs (> MaxLinesPerFile) | Kappen, `truncated: true`, Kennzahlen auf gelesenen Teil beziehen und ausweisen |
| Multiline-Einträge (Stacktraces) | Folgezeilen ohne Zeitstempel dem vorherigen Eintrag zuordnen (Text-Modus) |
| Gemischte Formate im LogDir | Pro Datei erkennen, gemeinsam aggregieren |
| Keine Zeitstempel parsebar | first/last null, Zeitraum-Aussagen entfallen, ausweisen |
| Logs von anderem Service (passen nicht zum Code) | LLM erkennt Mapping-Quote ~0 → Warnung "Logs passen evtl. nicht zum Projekt" statt Nonsens-Deltas |
| PII in Logs | Maskierung greift in samples; Report enthält NIE unmaskierte Beispiele |
| debug/info in Prod gefiltert | § 6.1-Einschränkung |

## 8. Testplan

Smoke: Fixture `prod-spiegel/tests/fixture/` mit Mini-Code (2 Dateien: eine Route +
ein Logger-Aufruf + ein verschluckender Catch) und `logs/app.log` (~200 Zeilen
synthetisch: ein Error-Muster 50×, das zum Catch passt; die Route kommt NICHT vor;
eine E-Mail-Adresse zum Maskierungs-Test). Dann:

```powershell
& .\prod-spiegel\scripts\log-ingest.ps1 -LogDir ".\prod-spiegel\tests\fixture\logs"
& .\prod-spiegel\scripts\code-claims.ps1 -ProjectDir ".\prod-spiegel\tests\fixture"
```

Erwartung: exit 0, JSON valide; Muster-Aggregation korrekt (50er-Muster oben),
E-Mail maskiert; code-claims findet Route, Log-Statement, Catch mit swallowGuess.
LLM-Durchlauf MUSS finden: totes Feature (Route ohne Log-Spur) + stiller
Dauerbrenner (Catch + 50× Error) — harte Akzeptanzkriterien.

Akzeptanz (dreamzzz-api): code-claims gegen das Projekt (Erwartung: Routen/Logs/
Catches plausibel, 3 Stichproben prüfen). Voller Spiegel nur, falls der User
Log-Exporte bereitstellt — sonst dokumentieren: "Akzeptanz Log-Seite auf Fixture
erbracht" (zulässig).

Negativ: leeres/fehlendes LogDir → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig
- [x] log-ingest.ps1 (Normalisierung, Aggregation, PII-Maskierung, Kappung)
- [x] code-claims.ps1 (Logs, Catches inkl. swallowGuess, Routen)
- [x] Fixture angelegt; Smoke bestanden inkl. Maskierungs-Test
- [x] LLM-Durchlauf findet beide eingebauten Deltas
- [x] Akzeptanz dokumentiert (mind. code-claims gegen dreamzzz, 3 Stichproben)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4 (beidseitige Evidenz je Delta)
- [x] tracking.md aktualisiert, Commit `sprint-09: prod-spiegel implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/prod-spiegel/` (BIBEL-§-3-Konvention seit
   Sprint 29).
2. **Zahlen-Normalisierung ohne Wortgrenze gefunden und behoben**: `\b\d+\b`
   matcht keine Zahlen mit direkt angehängter Einheit ("39ms" — zwischen "9" und
   "m" liegt kein Wortgrenzen-Übergang, beides sind Wortzeichen). Dadurch fielen
   gleichartige Zeilen NICHT auf ein Muster zusammen (30 statt 4 Muster in der
   Fixture). Fix: `\d+` ohne `\b`.
3. **PII-Maskierung auf den Pattern-Key ausgeweitet**: die Spec verlangt
   Maskierung "in ALLEN Ausgaben" (Nicht-Scope), ursprünglich aber nur in
   `samples` implementiert — der `pattern`-Schlüssel selbst (der als Freitext im
   LLM-Report landet) enthielt noch unmaskierte E-Mail-Adressen. Fix: `Get-PatternKey`
   maskiert E-Mails jetzt zuerst, bevor normalisiert wird.
4. **Routen-Regex-Falsch-Positive gefunden und behoben**: `\b(get|post|...)\(` ohne
   Anker am Zeilenanfang matcht jeden generischen Methodenaufruf (`Headers.get()`,
   `Map.get()` etc.), nicht nur Route-Registrierungen — 27 falsche Treffer beim
   Akzeptanz-Lauf gegen `dreamzzz-api_vs`. Fix: Anker `^\s*[\w.]*\b` verlangt, dass
   der Aufruf am (getrimmten) Zeilenanfang steht, wie es bei echten
   `app.get(...)`/`router.post(...)`-Registrierungen praktisch immer der Fall ist.
   Nach dem Fix: 0 Routen bei dreamzzz-api_vs — korrekt und ehrlich, da der
   Cloudflare Worker manuell über `url.pathname`-Vergleiche routet, nicht über
   Express-Stil/Decorators (außerhalb des Skill-Scopes, keine weitere
   Nacharbeit nötig).

## 11. Testergebnisse

**Smoke** (Fixture `skills/prod-spiegel/tests/fixture/`: `server.ts` mit toter
Route, einem Log-Statement, einem verschluckenden Catch + `logs/app.log`, 190
synthetische Zeilen mit einem 50×-Error-Muster, das zum Catch passt, plus einer
E-Mail-Adresse): `log-ingest.ps1` liefert nach dem Zahlen-Normalisierungs-Fix 4
Muster (statt fälschlich 30), Error-Muster korrekt mit `count: 50`, E-Mail korrekt
zu `<EMAIL>` maskiert (in Sample UND Pattern-Key). `code-claims.ps1` findet die
Route (`server.ts:5`), das Log-Statement (`server.ts:20`) und den Catch mit
`swallowGuess: true` (`server.ts:12`) — exakt wie erwartet.

Manuelle LLM-Analyse (hartes Akzeptanzkriterium): **beide eingebauten Deltas
gefunden** — totes Feature (`/api/legacy-report`, 0 Log-Spuren in 190 Zeilen,
Level-Abdeckung geprüft) und stiller Dauerbrenner (Catch `server.ts:12` +
50×-Error-Muster "gateway timeout", Mapping über wörtliche Teilübereinstimmung
"gateway timeout" zwischen geworfenem `Error` und Log-Text, Konfidenz
`wahrscheinlich`). Report-Struktur erfüllt BIBEL § 4.

**Akzeptanz** (`dreamzzz-api_vs/src`, `code-claims.ps1`): 63 Log-Statements, 58
Catch-Blöcke, 0 Routen (nach dem Regex-Fix — korrekt, s. o.). 3 Stichproben
(`entitlements.ts:98`, `gemini.ts:141` Log-Statements, `entitlements.ts:96`
Catch) per `sed -n` gegen die Quelle verifiziert — exakte Übereinstimmung. Kein
Log-Export für dreamzzz-api_vs vorhanden — Akzeptanz auf Code-Claims-Seite
erbracht, wie im Sprint-File als zulässig vorgesehen.

**Negativ**: leeres LogDir → `Write-Error` "Keine Log-Dateien gefunden" + Exit-Code
1. Nicht existentes LogDir → `Write-Error` + Exit-Code 1.
