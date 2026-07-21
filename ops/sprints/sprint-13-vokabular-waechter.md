# Sprint 13 — vokabular-waechter (/vocab)

Regeln: `ops/BIBEL.md` gilt vollständig. Abgrenzung zu Sprint 04
(konsistenz-enforcer): dort geht es um duplizierte LOGIK, hier um divergente SPRACHE
für dasselbe Konzept.

## 1. Problem

Dasselbe fachliche Ding heißt im System `customer`, `client`, `account` und in der
DB `kunde` — vier Namen, ein Konzept, und niemand weiß mehr, ob `client` vielleicht
doch etwas anderes ist. Diese Sprach-Drift erzeugt Bugs (falsche Zuordnung), macht
Suchen unmöglich und vergiftet jedes Onboarding. Eine Ubiquitous Language von Hand zu
extrahieren scheitert an der Masse der Bezeichner; Synonyme über Sprachgrenzen
(Code-Englisch, Domänen-Deutsch) erkennen kann nur ein LLM.

## 2. Nutzen

Vorher: implizites, widersprüchliches Vokabular; jede Diskussion beginnt mit
Begriffsklärung. Nachher: Glossar-Karte (Konzept → alle verwendeten Namen → Orte),
Divergenz-Report und kanonischer Namensvorschlag pro Konzept. Profiteure: Team-
Kommunikation, Domain-Modellierung, Suche/Refactoring, neue Devs.

## 3. Scope / Nicht-Scope

**Scope:** Bezeichner aus Code (Klassen, Funktionen, Variablen, Typen), Spalten-/
Tabellennamen aus Schema-Dateien, Schlüssel aus API-/DTO-Definitionen. Clusterung zu
Konzepten, Divergenz-Ausweis, Kanon-Vorschlag.
**Nicht-Scope:** KEINE Umbenennungen (nur Vorschlag + Impact-Schätzung).
UI-Anzeigetexte/i18n nur, wenn als Feld-/Schlüsselnamen vorliegend. Keine
Rechtschreibprüfung.

## 4. Skill-Spezifikation

Ordner: `vokabular-waechter/`

Frontmatter:

```yaml
---
name: vokabular-waechter
description: "Ubiquitous language guard: harvests identifiers from code, schema and API definitions, has the LLM cluster synonyms that name the same domain concept (customer/client/account/kunde), reports naming divergences with all locations and proposes one canonical term per concept including rename impact estimate. Never renames anything. Read-only. Trigger: /vocab"
trigger: /vocab
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir` + optional Domänen-Hinweis vom User (Freitext: worum geht
   es fachlich — hilft der Clusterung). Bestätigen.
3. `scripts/term-harvest.ps1` ausführen.
4. LLM-Analyse gemäß § 6.
5. Report `vocab-report.md` ins Arbeitsverzeichnis; Kurzfassung: Konzepte mit
   den meisten Synonymen zuerst.

Usage:

```
/vocab                     # interaktiv
/vocab <dir>               # Vokabular-Analyse
/vocab <dir> "<domäne>"    # mit Domänen-Hinweis
/vocab --help
```

## 5. Collector-Skripte

### scripts/term-harvest.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions` (Default wie Sprint 03, plus
sql,prisma,graphql,proto,json,yaml), `-Exclude` (Default wie Sprint 03, plus
`*.min.*`, `*generated*`), `-MinFrequency` (Default 2), `-TopN` (Default 400).

Read-only. Drei Ernte-Quellen:

1. **Code-Bezeichner**: Deklarations-Zeilen (class/interface/type/function/def/
   const/let/var/struct/enum — Muster-Familie) → Bezeichner extrahieren.
2. **Schema-Namen**: `CREATE TABLE`/Spalten aus *.sql, model/Felder aus *.prisma,
   type/Felder aus *.graphql, message/Felder aus *.proto.
3. **DTO-/API-Schlüssel**: Property-Namen aus Interface-/Type-Blöcken und
   JSON-Schema-Dateien.

Verarbeitung: Bezeichner in Terme zerlegen (camelCase, PascalCase, snake_case,
kebab-case splitten), lowercased zählen. Stoppwörter filtern (get,set,is,has,new,
id,data,info,item,list,map,util,helper,impl,tmp,obj,val,res,req — Liste im Skript,
erweiterbar). Pro Term: Gesamtfrequenz, Quellen-Verteilung (code/schema/api) und
bis zu 10 Beispiel-Fundstellen (Datei:Zeile, Original-Bezeichner).

JSON-Schema (Beispiel):

```json
{
  "terms": [
    { "term": "customer", "frequency": 87, "sources": { "code": 70, "schema": 10, "api": 7 },
      "samples": [ { "file": "src/customer/service.ts", "line": 10, "identifier": "CustomerService" } ] },
    { "term": "client", "frequency": 34, "sources": { "code": 30, "schema": 0, "api": 4 },
      "samples": [ { "file": "src/billing/invoice.ts", "line": 22, "identifier": "clientId" } ] }
  ],
  "totalIdentifiers": 2400,
  "truncatedToTopN": true
}
```

Nur Terme mit Frequenz ≥ MinFrequency, sortiert absteigend, auf TopN gekappt.
Fehlerverhalten: Pfad fehlt → exit 1.

## 6. LLM-Analyse-Steps

1. **Konzept-Clusterung**: Terme zu Domänen-Konzepten gruppieren — Synonyme
   (customer/client/account), Übersetzungspaare (kunde/customer),
   Schreibvarianten (order_item/orderItem zählen NICHT als Divergenz — gleiche
   Wortwahl, nur Konvention). Domänen-Hinweis des Users einbeziehen. Technik-Terme
   (parser, handler, config) als "technisches Vokabular" aussondern — nur
   Domänen-Konzepte tief analysieren.
2. **Divergenz-Prüfung pro Cluster**: Sind es WIRKLICH dasselbe Konzept? Beispiel-
   Fundstellen lesen (Read bei Unsicherheit). Ehrlich unterscheiden:
   - `synonym-divergenz` (gleiche Sache, verschiedene Namen — der Hauptbefund),
   - `homonym-warnung` (gleicher Name, verschiedene Dinge — noch gefährlicher!),
   - `legitim-verschieden` (client = API-Client, customer = Käufer → kein Befund,
     aber im Glossar dokumentieren).
3. **Kanon-Vorschlag** je Divergenz-Cluster: dominanten/präzisesten Term wählen
   (Frequenz + Schema-Verankerung als Kriterien, Begründung nennen), Impact grob
   schätzen (Anzahl Fundstellen der Nicht-Kanon-Terme; Kategorien: klein < 20 /
   mittel / groß > 100).
4. Report: Kurzfassung (X Konzepte, Y mit Divergenz, Z Homonym-Warnungen) →
   **Glossar-Tabelle** (Konzept, kanonischer Vorschlag, alle Namen mit Frequenz) →
   Divergenzen im Detail (Fundstellen-Beispiele, Kanon-Begründung, Impact) →
   Homonym-Warnungen → technisches Vokabular (nur Liste) → Offene Fragen (alle
   `vermutet`-Clusterungen).
5. Evidenz-Pflicht: jede Cluster-Zuordnung mit ≥ 2 Beispiel-Fundstellen; Homonym-
   Warnungen mit beiden Bedeutungs-Belegen.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Framework-Namen (React-Props, Django-Felder) | Technisches Vokabular, aussondern |
| Sehr kleines Projekt (< 50 Bezeichner) | Normal laufen lassen, Aussagekraft-Hinweis im Report |
| Gemischtsprachige Codebase (dt./engl.) | Kernfall! Übersetzungspaare aktiv suchen |
| Abkürzungen (cust, usr, acct) | Als Synonym-Kandidaten der Vollformen clustern |
| Ein-Buchstaben-/Kurzbezeichner | Durch Stoppwort-/MinFrequency-Filter bzw. Split-Länge ≥ 3 ausschließen |
| Generierter Code | Exclude greift |

## 8. Testplan

Smoke: Fixture `vokabular-waechter/tests/fixture/` mit 3 Dateien: dieselbe Entität
als `Customer` (Klasse), `client` (Variablen in anderer Datei), `kunde` (SQL-Spalte
in schema.sql); zusätzlich ein Homonym (`order` als Bestellung UND als Sortierung).
Dann:

```powershell
& .\vokabular-waechter\scripts\term-harvest.ps1 -ProjectDir ".\vokabular-waechter\tests\fixture" -MinFrequency 1
```

Erwartung: exit 0, JSON valide, alle 4 Terme geerntet mit korrekten Quellen.
LLM-Durchlauf: customer/client/kunde als EIN Konzept geclustert, Homonym `order`
als Warnung gemeldet (harte Kriterien).

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: Glossar-Tabelle plausibel,
3 Cluster-Zuordnungen stichprobenartig gegen Fundstellen verifiziert; Divergenz-
Funde projektabhängig (keine Pflicht, aber falls gemeldet: Belege müssen stimmen).

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (inkl. Nie-Umbenennen-Regel)
- [ ] term-harvest.ps1 (3 Quellen, Split, Stoppwörter, Frequenz, Kappung)
- [ ] Fixture mit Synonym-Trio + Homonym angelegt
- [ ] Smoke bestanden; Cluster + Homonym-Warnung korrekt
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4 (≥ 2 Belege je Cluster)
- [ ] tracking.md aktualisiert, Commit `sprint-13: vokabular-waechter implementiert`
