---
name: migrations-chirurg
description: "Schema migration surgeon: diffs two schema states (SQL DDL or Prisma), then generates the complete package nobody writes by hand - forward migration, rollback, pre/post validation queries and a risk protocol with explicit data-loss warnings. NEVER executes anything against a database; generates files only. Trigger: /migrate"
trigger: /migrate
---

# /migrate

Schema-Migrationen sind Operationen am offenen Herzen. Diese hier kommt mit
Rollback, Validierung und einem Risiko-Protokoll — als generiertes Datei-Paket,
nie als Ausführung.

## What this is for

- Aus zwei Schema-Ständen entsteht das Paket, das sonst niemand von Hand
  schreibt: Forward-Migration, getesteter Rollback, Validierungs-Queries,
  Risiko-Protokoll mit expliziten Datenverlust-Warnungen.

## SCHUTZREGEL — niemals ausführen, niemals ohne Freigabe ins Zielprojekt

**Dieser Skill führt NIEMALS eine Migration gegen eine Datenbank aus.** Er
generiert ausschließlich Dateien. Kein Zugriff auf laufende Datenbanken.

Das Migrations-Paket wird IMMER zuerst in `migration-<datum>/` im aktuellen
**Arbeitsverzeichnis** erzeugt und dem User gezeigt — niemals direkt ins
Zielprojekt geschrieben. Nur nach expliziter Freigabe des Users darf das Paket
zusätzlich ins Zielprojekt kopiert werden (Edit-Aktion, kein Skript).

## What You Must Do When Invoked

Wenn `/migrate --help` oder `/migrate -h` (ohne weitere Argumente) aufgerufen
wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-OldSchema` + `-NewSchema` (Dateien oder Verzeichnisse) und den
SQL-Dialekt (postgres|mysql|sqlite|mssql — Pflichtangabe, notfalls erfragen; bei
Prisma aus dem `datasource`-Block lesen). Bestätigung einholen.

### Step 2 — Diff

```powershell
& "<SKILL_DIR>/scripts/schema-diff.ps1" -OldSchema "<alt>" -NewSchema "<neu>"
```

Format-Mix (Fehler, Exit-Code ≠ 0): Meldung weitergeben, stoppen. Identische
Schemas (0 Changes): "Keine Änderungen" melden — **kein leeres Paket erzeugen**.

### Step 3 — Rename-Klärung

Jeden `renameCandidate` dem User einzeln vorlegen (Rename = Daten erhalten;
Drop+Add = Daten weg — das ist der ganze Unterschied). Ohne User-Antwort: als
Drop+Add behandeln, aber im Risiko-Protokoll ROT markieren.

### Step 4 — Risiko-Klassifikation

Jede Änderung einstufen:

- **verlustfrei**: Tabelle/Spalte/Index hinzu, Spalte verbreitern.
- **verlustbehaftet**: Spalte/Tabelle entfernen, Typ verengen, NOT NULL auf
  Bestandsdaten, Unique auf Bestandsdaten.
- **sperr-riskant**: Operationen, die auf großen Tabellen lange Locks ziehen
  können (dialektspezifisch benennen).

### Step 5 — Paket generieren (5 Dateien, `migration-<datum>/`)

1. **`01-forward.sql`**: Reihenfolge constraint-sicher (erst Spalten, dann FKs;
   Drops zuletzt). Verlustbehaftete Schritte einzeln, mit
   Kommentar-Block-WARNUNG davor. NOT-NULL-Einführung als Dreischritt (Spalte
   nullable + Backfill-Platzhalter + NOT NULL setzen), Backfill als markiertes
   TODO mit Vorschlag.
2. **`02-rollback.sql`**: exakte Umkehrung in umgekehrter Reihenfolge. Nicht
   umkehrbare Schritte (gedropte Daten) als solche kommentieren — Rollback
   stellt das Schema wieder her, Daten nur via Backup (Hinweis-Block am Kopf).
3. **`03-validate-pre.sql`**: Zählwerte vor der Migration, Checks für neue
   Constraints (wie viele Bestandszeilen verletzen das künftige
   NOT NULL/Unique JETZT — vor der Migration ausführen), Orphan-Checks für
   neue FKs.
4. **`04-validate-post.sql`**: Zählwerte nach der Migration zum Vergleich.
5. **`00-protokoll.md`**: Diff-Zusammenfassung, Klassifikation jeder Änderung
   mit Evidenz (Diff-Eintrag), Datenverlust-Abschnitt PROMINENT (auch wenn
   leer: "keine verlustbehafteten Operationen erkannt" explizit nennen),
   empfohlene Reihenfolge (pre-validate → Backup → forward → post-validate),
   Offene Fragen (Renames ohne Antwort, unparsed-Statements).

`unparsed` nicht leer: die Rohtexte beider Stände lesen und manuell diffen,
im Protokoll als "manuell geprüft" kennzeichnen statt zu ignorieren.

Dialekt-Feature fehlt (z. B. sqlite kann kein `DROP COLUMN` vor 3.35):
dialektspezifische Alternative generieren (z. B. Tabellen-Rebuild) oder als
manuell zu erledigen markieren.

Evidenz-Pflicht: jede generierte Migration-Zeile muss auf einen Diff-Eintrag
rückführbar sein — nichts generieren, was der Diff nicht zeigt.

### Step 6 — Zusammenfassen

Pfad des Pakets nennen, Risiko-Protokoll zusammenfassen,
Datenverlust-Warnungen IMMER explizit nennen (auch wenn keine vorhanden sind).

## Usage

```
/migrate                              # interaktiv
/migrate <alt> <neu> <dialekt>        # Diff + Paket generieren
/migrate --help
```
