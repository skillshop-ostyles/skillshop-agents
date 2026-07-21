# Sprint 10 — migrations-chirurg (/migrate)

Regeln: `ops/BIBEL.md` gilt vollständig. Letzter Sprint — höchste Fehlerkosten
(Datenverlust), deshalb strengste Ausgabe-Disziplin.

## 1. Problem

Schema-Migrationen sind Operationen am offenen Herzen: Forward-Skript, Rollback,
Datenvalidierung, Verlust-Risiken — alles von Hand, alles fehleranfällig, und der
Rollback wird traditionell "vergessen", bis man ihn um 3 Uhr nachts braucht. Die
eigentliche Arbeit ist nicht das DDL, sondern das DENKEN: Welche Daten gehen bei
diesem Diff verloren? Welche Reihenfolge vermeidet Constraint-Brüche? Was muss vorher
und nachher gemessen werden? Genau dieses Denken kann ein LLM systematisch leisten.

## 2. Nutzen

Vorher: Migration schreiben 1 h, Rollback + Validierung meist gar nicht. Nachher:
aus zwei Schema-Ständen entstehen Forward-Migration, getesteter Rollback,
Validierungs-Queries und ein Risiko-Protokoll mit expliziten
Datenverlust-Warnungen — als Paket. Profiteure: jeder, der DB-Änderungen deployt;
On-Call (Rollback existiert); Datenqualität (Validierung existiert).

## 3. Scope / Nicht-Scope

**Scope:** Zwei Schema-Stände als Dateien (SQL-DDL; Prisma-Schema; EF-Migrations-
Verzeichnis als Quelle des Ist-Stands). Diff per Skript, Generierung per LLM.
Ausgabe: Migrations-Paket als Dateien im ARBEITSVERZEICHNIS.
**Nicht-Scope:** NIEMALS Migrationen ausführen — nur generieren. Kein Zugriff auf
laufende Datenbanken. Ins Zielprojekt schreiben nur nach expliziter Freigabe des
Users (Paket wird zuerst außerhalb erzeugt und gezeigt). Keine Daten-Migration
großer ETL-Natur (nur schema-nahe Transformationen).

## 4. Skill-Spezifikation

Ordner: `migrations-chirurg/`

Frontmatter:

```yaml
---
name: migrations-chirurg
description: "Schema migration surgeon: diffs two schema states (SQL DDL or Prisma), then generates the complete package nobody writes by hand - forward migration, rollback, pre/post validation queries and a risk protocol with explicit data-loss warnings. NEVER executes anything against a database; generates files only. Trigger: /migrate"
trigger: /migrate
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-OldSchema` + `-NewSchema` (Dateien oder Verzeichnisse) + SQL-Dialekt
   (postgres|mysql|sqlite|mssql — Pflichtangabe, notfalls beim User erfragen; bei
   Prisma aus datasource-Block lesen). Bestätigen.
3. `scripts/schema-diff.ps1` ausführen.
4. LLM-Generierung gemäß § 6.
5. Paket in `migration-<datum>/` im Arbeitsverzeichnis ablegen, Risiko-Protokoll
   zusammenfassen, Datenverlust-Warnungen IMMER explizit nennen (auch wenn keine:
   "keine verlustbehafteten Operationen erkannt").

Usage:

```
/migrate                              # interaktiv
/migrate <alt> <neu> <dialekt>        # Diff + Paket generieren
/migrate --help
```

## 5. Collector-Skripte

### scripts/schema-diff.ps1

Parameter: `-OldSchema` (Pflicht), `-NewSchema` (Pflicht), `-Format`
(sql|prisma|auto, Default auto).

Read-only. Parst beide Stände zu einem normalisierten Modell und diffst:

1. **Parsing (bewusst pragmatisch, kein voller SQL-Parser — Simplicity First)**:
   - SQL: `CREATE TABLE`-Blöcke → Tabellen mit Spalten (Name, Typ, NULL/NOT NULL,
     DEFAULT), `PRIMARY KEY`/`FOREIGN KEY`/`UNIQUE`-Constraints, `CREATE INDEX`.
   - Prisma: `model`-Blöcke → Felder mit Typ/Attributen, `@relation`, `@unique`,
     `@@index`.
   - Nicht parsebare Statements → Liste `unparsed` (mit Zeile), NICHT verwerfen.
2. **Diff-Kategorien**: Tabelle hinzugefügt/entfernt; Spalte hinzugefügt/entfernt/
   geändert (Typ, Nullability, Default); Constraint/Index hinzugefügt/entfernt;
   Rename-VERDACHT (entfernte + hinzugefügte Spalte ähnlichen Typs in derselben
   Tabelle → `renameCandidates`, Entscheidung liegt beim LLM/User, nie automatisch).

JSON-Schema (Beispiel):

```json
{
  "format": "sql",
  "changes": [
    { "kind": "column-removed", "table": "orders", "column": "legacy_status", "type": "varchar(20)" },
    { "kind": "column-changed", "table": "users", "column": "email", "from": { "type": "varchar(100)", "nullable": true }, "to": { "type": "varchar(255)", "nullable": false } }
  ],
  "renameCandidates": [ { "table": "orders", "removed": "state", "added": "status", "sameType": true } ],
  "unparsed": [],
  "summary": { "tablesAdded": 1, "tablesRemoved": 0, "columnsRemoved": 1, "columnsChanged": 1 }
}
```

Fehlerverhalten: Datei fehlt / Format nicht erkennbar → exit 1 mit Meldung.
`unparsed` nicht leer → Warnung in Zusammenfassung (LLM muss die Roh-Stellen lesen).

## 6. LLM-Analyse-Steps (Generierung)

1. **Rename-Klärung zuerst**: jeden renameCandidate dem User vorlegen (Rename =
   Daten erhalten; Drop+Add = Daten weg — der Unterschied ist der ganze Punkt).
   Ohne User-Antwort: als Drop+Add behandeln, aber im Risiko-Protokoll ROT markieren.
2. **Risiko-Klassifikation** jeder Änderung:
   - `verlustfrei` (Tabelle/Spalte/Index hinzu, Spalte verbreitern)
   - `verlustbehaftet` (Spalte/Tabelle entfernen, Typ verengen, NOT NULL auf
     Bestandsdaten, Unique auf Bestandsdaten)
   - `sperr-riskant` (Operationen, die auf großen Tabellen lange Locks ziehen
     können — dialektspezifisch benennen)
3. **Forward-Migration** (`01-forward.sql` bzw. Prisma-Migrationstext):
   - Reihenfolge constraint-sicher (erst Spalten, dann FKs; Drops zuletzt).
   - Verlustbehaftete Schritte einzeln, mit Kommentar-Block WARNUNG davor.
   - NOT-NULL-Einführung als Dreischritt (Spalte nullable + Backfill-Platzhalter +
     NOT NULL setzen), Backfill als markiertes TODO mit Vorschlag.
4. **Rollback** (`02-rollback.sql`): exakte Umkehrung in umgekehrter Reihenfolge.
   Ehrlichkeit: Schritte, die NICHT umkehrbar sind (gedropte Daten), als solche
   kommentieren — der Rollback stellt Schema wieder her, Daten nur via Backup
   (Hinweis-Block am Kopf des Rollbacks).
5. **Validierung** (`03-validate-pre.sql`, `04-validate-post.sql`): Zählwerte vor/
   nach (Zeilen pro betroffener Tabelle), Checks für neue Constraints (wie viele
   Bestandszeilen verletzen das künftige NOT NULL/Unique JETZT — vor der Migration
   auszuführen!), Orphan-Checks für neue FKs.
6. **Risiko-Protokoll** (`00-protokoll.md`): Diff-Zusammenfassung, Klassifikation
   jeder Änderung mit Evidenz (Diff-Eintrag), Datenverlust-Abschnitt prominent,
   empfohlene Reihenfolge (pre-validate → Backup → forward → post-validate),
   Offene Fragen (Renames ohne Antwort, unparsed-Statements).
7. Evidenz-Pflicht: jede generierte Migration-Zeile muss auf einen Diff-Eintrag
   rückführbar sein; nichts generieren, was der Diff nicht zeigt.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Identische Schemas | "Keine Änderungen" — kein leeres Paket erzeugen |
| unparsed-Statements (Trigger, Views, Funktionen) | LLM liest die Rohtexte beider Stände und diffst manuell; im Protokoll als manuell-geprüft kennzeichnen |
| Typ-Verengung mit Datenprüfung möglich (varchar(255)→(100)) | pre-validate-Query generieren, die verletzende Zeilen zählt |
| Dialekt-Feature fehlt (sqlite kann kein DROP COLUMN vor 3.35) | Dialektspezifische Alternative (Tabellen-Rebuild) generieren oder als manuell markieren |
| Prisma alt vs. SQL neu (Format-Mix) | exit 1 in schema-diff — Mix nicht unterstützt, klar melden |
| Riesen-Schema (> 100 Tabellen) | Diff normal; Generierung nur für geänderte Objekte (ohnehin), Protokoll-Zusammenfassung kompakt |

## 8. Testplan

Fixture ist Teil des Sprints: `migrations-chirurg/tests/fixture/old.sql` +
`new.sql` (Beispiel-Paar, MUSS enthalten: 1 neue Tabelle, 1 gedropte Spalte,
1 Typ-Änderung mit NOT-NULL-Einführung, 1 Rename-Kandidat, 1 neuer Index).

Smoke:

```powershell
& .\migrations-chirurg\scripts\schema-diff.ps1 -OldSchema ".\migrations-chirurg\tests\fixture\old.sql" -NewSchema ".\migrations-chirurg\tests\fixture\new.sql"
```

Erwartung: exit 0, JSON valide, ALLE 5 eingebauten Änderungen korrekt kategorisiert,
Rename-Kandidat erkannt (harte Kriterien). Voller LLM-Durchlauf (Dialekt postgres):
Paket mit allen 5 Dateien; Forward enthält Warnung vor der gedropten Spalte;
Rollback kennzeichnet Nicht-Umkehrbarkeit; pre-validate zählt NOT-NULL-Verletzer.
Syntax-Check der generierten SQL: mindestens per sorgfältigem Review dokumentiert;
falls ein sqlite/psql-Binary lokal verfügbar ist, Parse-Probe fahren (best effort,
dokumentieren was möglich war).

Akzeptanz (dreamzzz-api): falls das Projekt Schema-Dateien/Migrations enthält
(suchen: *.sql, schema.prisma, Migrations/), zwei Stände diffen. Falls nicht
vorhanden: dokumentieren "kein Schema im Projekt — Akzeptanz vollständig über
Fixture erbracht" (zulässig; Fixture deckt alle Kern-Fälle ab).

Negativ: fehlende Datei → exit != 0; Format-Mix → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig, Nie-Ausführen-Regel und Freigabe-Pflicht ausformuliert
- [ ] schema-diff.ps1 (SQL + Prisma, alle Diff-Kategorien, renameCandidates, unparsed)
- [ ] Fixture-Paar mit allen 5 Pflicht-Änderungen angelegt
- [ ] Smoke bestanden (alle 5 erkannt, Rename-Kandidat gemeldet)
- [ ] LLM-Paket vollständig (5 Dateien), Warnungen/Nicht-Umkehrbarkeit vorhanden
- [ ] SQL-Prüfung dokumentiert (Review + Parse-Probe falls Binary verfügbar)
- [ ] Akzeptanz dokumentiert (dreamzzz oder begründeter Fixture-Fallback)
- [ ] Negativ-Tests bestanden
- [ ] Protokoll erfüllt BIBEL § 4 (jede Zeile auf Diff rückführbar)
- [ ] tracking.md aktualisiert, Commit `sprint-10: migrations-chirurg implementiert`
