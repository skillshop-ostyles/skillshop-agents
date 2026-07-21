# Sprint 16 — ausfall-simulant (/failsim)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Catch-Analyse-Muster aus
Sprint 09 (`code-claims.ps1`) darf kopiert/angepasst werden.

## 1. Problem

"Was passiert, wenn die Datenbank weg ist?" — die ehrliche Antwort in fast jedem Team:
niemand weiß es. Fehlerbehandlung entsteht verstreut und inkonsistent; ob ein Timeout
zu Retry, Crash, stillem Datenverlust oder hängendem Request führt, entscheidet die
Stelle, nicht die Architektur. Chaos-Engineering beantwortet das empirisch, ist aber
teuer und riskant. Ein LLM kann das Gedankenexperiment systematisch führen: jeden
externen Berührungspunkt finden und den Fehlerpfad zu Ende denken — Ausfall-Simulation
auf Code-Ebene, ohne dass etwas ausfallen muss.

## 2. Nutzen

Vorher: Resilienz-Wissen = Erinnerung an vergangene Incidents. Nachher: pro
Ausfallszenario ein Verhaltens-Report: welcher Berührungspunkt reagiert wie
(Retry/Degradation/Crash/still), wo Verhalten inkonsistent oder gefährlich ist,
konkrete Härtungs-Empfehlungen. Profiteure: On-Call (weiß, was passieren wird),
Architektur-Reviews, SLO-Diskussionen.

## 3. Scope / Nicht-Scope

**Scope:** Externe Berührungspunkte im Code (HTTP-Clients, DB-Zugriffe, Dateisystem,
Queues/Messaging, Caches) inventarisieren; für ein gewähltes Ausfallszenario
(z. B. "DB nicht erreichbar", "API X liefert Timeouts", "Disk voll") den Fehlerpfad
statisch durchdenken. Read-only, reines Gedankenexperiment.
**Nicht-Scope:** KEIN Chaos-Engineering (nichts wird abgeschaltet, kein Prozess
gestartet). Keine Laufzeit-Messungen. Keine Infrastruktur-Analyse (K8s-Manifeste
nur als Kontext-Hinweis, wenn vorhanden).

## 4. Skill-Spezifikation

Ordner: `ausfall-simulant/`

Frontmatter:

```yaml
---
name: ausfall-simulant
description: "Failure simulator on code level: inventories every external touchpoint (HTTP clients, DB access, filesystem, queues, caches) with its surrounding error handling, then for a chosen failure scenario (DB down, API timeouts, disk full) mentally executes the failure path at each touchpoint and reports the resulting behavior - retry, degradation, crash or silent loss - plus inconsistencies and hardening recommendations. Pure thought experiment, nothing is ever shut down. Read-only. Trigger: /failsim"
trigger: /failsim
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir` + Ausfallszenario (Freitext; ohne Angabe: Inventar zeigen
   und Szenario-Vorschläge aus den gefundenen Berührungspunkt-Typen machen).
   Bestätigen.
3. `scripts/failpoint-scan.ps1` ausführen.
4. LLM-Simulation gemäß § 6 (liest die betroffenen Stellen vollständig).
5. Report `failsim-report-<szenario>.md` ins Arbeitsverzeichnis; Kurzfassung:
   gefährlichste Verhalten zuerst.

Usage:

```
/failsim                        # interaktiv (Inventar + Szenario-Wahl)
/failsim <dir> "<szenario>"     # z. B. "DB nicht erreichbar"
/failsim --help
```

## 5. Collector-Skripte

### scripts/failpoint-scan.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie Sprint 03),
`-ContextLines` (Default 6).

Read-only. Findet externe Berührungspunkte per Muster-Familie, je mit Datei:Zeile,
Typ und `-ContextLines` Zeilen Kontext davor/danach (für die Fehlerbehandlungs-Sicht):

1. **http**: `fetch(|axios|HttpClient|http.Get|requests.(get|post)|RestClient|
   Invoke-RestMethod|got(|urllib`.
2. **db**: `query(|execute(|find(|findOne|save(|SELECT |INSERT |connection|
   createPool|prisma.|dbContext.|session.`(Kontext muss DB-Bezug zeigen — grobe
   Heuristik, LLM sortiert Rauschen aus).
3. **fs**: `readFile|writeFile|open(|fopen|File.Read|File.Write|fs\.|os.Open|
   Get-Content|Set-Content`.
4. **queue**: `publish(|subscribe(|sendMessage|consume(|amqp|kafka|rabbit|sqs|bus\.`.
5. **cache**: `redis|memcache|cache.get|cache.set`.

Zusätzlich je Fundstelle Fehlerbehandlungs-Signale im Kontext erfassen:
`try/catch` vorhanden? `retry|backoff|timeout|circuit` im Umfeld? `await` ohne
try? → Flags `hasTryCatch`, `hasRetrySignal`, `hasTimeoutSignal`.

JSON-Schema (Beispiel):

```json
{
  "failpoints": [
    { "type": "db", "file": "src/orders/repo.ts", "line": 33, "text": "await pool.query(sql, params)",
      "context": ["..."], "hasTryCatch": false, "hasRetrySignal": false, "hasTimeoutSignal": false }
  ],
  "countsByType": { "http": 12, "db": 23, "fs": 4, "queue": 0, "cache": 2 },
  "scannedFiles": 180
}
```

Fehlerverhalten: Pfad fehlt → exit 1. 0 Failpoints → Meldung, exit 0 (Skill
sinnlos für dieses Projekt — SKILL.md: sauber beenden).

## 6. LLM-Analyse-Steps (Simulation)

1. **Szenario schärfen**: Freitext → betroffene Failpoint-Typen + Fehlermodus
   (nicht erreichbar / langsam / Fehler-Antworten / teilweise). "DB weg" betrifft
   db-Punkte mit Modus "Connection-Fehler + Timeouts".
2. **Pro betroffenem Failpoint den Pfad zu Ende denken** (Datei lesen, Aufrufkette
   nach oben verfolgen bis zur Systemgrenze — Route/Handler/Job):
   - Was wirft die Stelle im Fehlermodus? Wo landet die Exception?
   - Klassifikation des resultierenden Verhaltens:
     `robust` (Retry/Fallback/saubere Fehlerantwort) /
     `degradiert` (Funktion weg, aber kontrolliert) /
     `still` (Fehler verschluckt — Datenverlust-/Inkonsistenz-Kandidat) /
     `absturz` (unbehandelt bis top-level) /
     `haenger` (kein Timeout-Signal — Request/Job blockiert).
   - Konfidenz je Klassifikation (`belegt` = Pfad vollständig verfolgt;
     `wahrscheinlich` = Framework-Default angenommen, benennen welcher).
3. **Querschnitts-Befunde**: inkonsistentes Verhalten bei gleichartigen Punkten
   (Endpoint A retryt, B stürzt ab — beide reden mit derselben DB); fehlende
   Timeouts als Klasse; stille Punkte gesammelt.
4. Report: Kurzfassung (Szenario, n Punkte, Verhalten-Verteilung, gefährlichste 3)
   → Verhaltens-Tabelle (Failpoint, Datei:Zeile, Klassifikation, Konfidenz,
   Begründung in 1-2 Sätzen) → Querschnitts-Befunde → Härtungs-Empfehlungen
   (konkret, priorisiert: erst Hänger/still, dann Konsistenz) → Offene Fragen.
5. Evidenz-Pflicht: jede Klassifikation mit dem entscheidenden Code-Beleg
   (Datei:Zeile des Catch/fehlenden Catch/Timeout-Configs).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Globaler Error-Handler (Express-Middleware, Filter) | Aktiv danach suchen — er ändert die Klassifikation vieler Punkte; Fund dokumentieren |
| Framework-Magie (Auto-Retry in Client-Lib) | Als `wahrscheinlich` mit Lib-Name; nicht als belegt ausgeben |
| Sehr viele Failpoints (> 100) | Szenario grenzt ein; innerhalb des Szenarios alle, sonst Top-N nach Kritikalität + Zählwerte |
| Async fire-and-forget (kein await) | Eigene Warnklasse: Fehler landet nirgends — immer melden |
| Transaktionen | DB-Punkte in Transaktions-Kontext markieren (Teilschreiben-Risiko benennen) |
| Failpoint in totem Code | Nicht Scope dieses Skills — nicht filtern, aber /bury-Querverweis erlaubt |

## 8. Testplan

Smoke: Fixture `ausfall-simulant/tests/fixture/` mit 3 Mini-Dateien: (a) DB-Aufruf
ohne try/catch (→ absturz), (b) HTTP-Aufruf mit try/catch, aber leerem catch
(→ still), (c) HTTP-Aufruf mit Retry-Schleife und Timeout (→ robust). Dann:

```powershell
& .\ausfall-simulant\scripts\failpoint-scan.ps1 -ProjectDir ".\ausfall-simulant\tests\fixture"
```

Erwartung: exit 0, JSON valide, 3 Failpoints mit korrekten Typen und Flags.
LLM-Durchlauf (Szenario "alle externen Dienste liefern Timeouts"): die drei
Klassifikationen absturz/still/robust MÜSSEN korrekt vergeben werden (hartes
Kriterium).

Akzeptanz (dreamzzz-api): Inventar-Lauf + Simulation eines passenden Szenarios
("DB nicht erreichbar" falls DB-Punkte existieren, sonst passend wählen).
Erwartung: Lauf ohne Fehler; 3 Klassifikationen stichprobenartig durch Lesen der
Stellen verifiziert.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (Gedankenexperiment-Charakter klar)
- [ ] failpoint-scan.ps1 (5 Typ-Familien, Kontext, 3 Signal-Flags)
- [ ] Fixture mit 3 Verhaltens-Archetypen angelegt
- [ ] Smoke bestanden; alle 3 Klassifikationen korrekt
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4 (Beleg je Klassifikation, Framework-Annahmen gekennzeichnet)
- [ ] tracking.md aktualisiert, Commit `sprint-16: ausfall-simulant implementiert`
