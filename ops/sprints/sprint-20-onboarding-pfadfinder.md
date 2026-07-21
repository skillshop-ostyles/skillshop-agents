# Sprint 20 — onboarding-pfadfinder (/onboard)

Regeln: `ops/BIBEL.md` gilt vollständig. Letzter Sprint der zweiten Staffel —
Synthese-Skill: nutzt Muster aus S01 (Churn), S03 (Referenz-Graph), S15 (Oberfläche).

## 1. Problem

Neue Entwickler wandern wochenlang orientierungslos durch die Codebase: Wo fange ich
an? Was ist Kern, was Peripherie? Welche Konzepte muss ich verstanden haben, bevor
Datei X Sinn ergibt? Die "geführte Tour" existiert nie, weil sie zu schreiben
bedeutet, die Codebase aus Anfänger-Sicht zu durchdenken — und wer sie schreiben
könnte, hat diese Sicht längst verloren (Fluch des Wissens). Ein LLM hat beide
Sichten gleichzeitig: es versteht die Struktur UND kann sie didaktisch sequenzieren.

## 2. Nutzen

Vorher: Onboarding = README + "frag halt". Erste produktive Woche: Woche 3. Nachher:
generierte Lese-Tour in Stationen (Reihenfolge, Kernkonzepte, Verständnisfragen,
erste sichere Aufgabe), spezifisch für DIESE Codebase und auf Wunsch für einen
Schwerpunkt (Backend/Frontend/ein Modul). Profiteure: neue Devs, Mentoren (Struktur
statt Improvisation), Teams mit Fluktuation.

## 3. Scope / Nicht-Scope

**Scope:** Topologie-Analyse (Entry-Points, Modul-Struktur, Abhängigkeits-Richtung,
Git-Churn als Wichtigkeits-Signal), daraus generierte Tour als Markdown-Dokument:
Stationen mit Lesezielen, Schlüsseldateien, Verständnisfragen, plus Vorschläge für
eine erste sichere Aufgabe.
**Nicht-Scope:** Keine Umgebungs-Einrichtung (Setup-Anleitung bleibt Sache des
README — aber /doc-drift-Querverweis, wenn das README tot ist). Keine Änderungen am
Zielprojekt (die Tour wird NICHT ins Repo geschrieben, außer der User will es
explizit). Kein allgemeiner Programmierkurs — nur diese Codebase.

## 4. Skill-Spezifikation

Ordner: `onboarding-pfadfinder/`

Frontmatter:

```yaml
---
name: onboarding-pfadfinder
description: "Onboarding pathfinder: analyzes a codebase's topology (entry points, module structure, dependency direction, git churn as importance signal) and generates a guided reading tour for new developers - ordered stations with reading goals, key files, comprehension check questions and suggested first safe tasks, tailored to this codebase and an optional focus area. Read-only. Trigger: /onboard"
trigger: /onboard
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir` + optional Schwerpunkt (Freitext: "Backend", "nur Modul X",
   "Datenfluss") + Erfahrungslevel der Zielperson (junior/senior — bestimmt
   Erklärtiefe, Default: mid). Bestätigen.
3. `scripts/topology.ps1` ausführen.
4. LLM-Tour-Generierung gemäß § 6 (liest die Schlüsseldateien wirklich).
5. `onboarding-tour.md` ins Arbeitsverzeichnis; Kurzfassung: Stationen-Übersicht.

Usage:

```
/onboard                          # interaktiv
/onboard <dir>                    # Tour für das ganze Projekt
/onboard <dir> "<schwerpunkt>"    # z. B. "Backend" oder "Modul billing"
/onboard --help
```

## 5. Collector-Skripte

### scripts/topology.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie
Sprint 03), `-ChurnMonths` (Default 12), `-TopChurn` (Default 30).

Read-only. Vier Signale:

1. **Entry-Points**: main/index/app/program/server-Dateien; `package.json`
   main/bin/scripts; Dockerfile CMD/ENTRYPOINT; erkennbare CLI-Registrierungen.
2. **Modul-Struktur**: Verzeichnisbaum bis Tiefe 3 (ohne Excludes) mit Datei- und
   Zeilen-Zählung pro Verzeichnis.
3. **Abhängigkeits-Richtung**: Import-Kanten auf Verzeichnis-Ebene aggregiert
   (Import-Zeilen parsen, relative Pfade auf Verzeichnis gemappt) → Kantenliste
   mit Gewicht. Daraus ableitbar (fürs LLM): was ist "unten" (viel importiert,
   importiert wenig = Kern/Utils) vs. "oben" (Feature-Ebene).
4. **Churn**: `git log --since=<ChurnMonths> --name-only` aggregiert → Top-N
   Dateien nach Änderungs-Häufigkeit (= wo die Musik spielt). Kein Git → leer.

JSON-Schema (Beispiel):

```json
{
  "entryPoints": [ { "file": "src/index.ts", "reason": "package.json main" } ],
  "tree": [ { "dir": "src/billing", "files": 14, "lines": 2200 } ],
  "importEdges": [ { "from": "src/billing", "to": "src/core", "weight": 23 } ],
  "churn": [ { "file": "src/billing/invoice.ts", "changes": 31 } ],
  "gitAvailable": true
}
```

Fehlerverhalten: Pfad fehlt → exit 1.

## 6. LLM-Analyse-Steps (Tour-Generierung)

1. **Verstehen, dann sequenzieren**: Entry-Points und die 5-10 wichtigsten Dateien
   (Kern-Verzeichnisse + Top-Churn) WIRKLICH lesen. Die fachliche Geschichte des
   Systems formulieren (Was tut es? Für wen?) — Station 0 der Tour.
2. **Stationen bilden** (didaktische Reihenfolge, nicht Verzeichnis-Reihenfolge):
   - Prinzip: erst das Was (Domäne, Kernmodelle), dann das Wie (zentrale Flüsse
     Entry → Kern), dann Randthemen. Abhängigkeits-Richtung nutzen: "unten"
     (Kern/Modelle) vor "oben" (Features).
   - Pro Station: Lernziel (1 Satz), Schlüsseldateien in Lese-Reihenfolge
     (Datei:Zeile-Anker für den Einstiegspunkt), was man danach verstanden haben
     muss, 2-3 Verständnisfragen MIT im Dokument versteckten Antworten
     (aufklappbar via `<details>`), geschätzte Zeit.
   - 5-9 Stationen; Schwerpunkt-Angabe filtert/vertieft.
3. **Erste sichere Aufgaben** (2-3 Vorschläge): kleine, echte Verbesserungen mit
   niedrigem Blast-Radius — Kandidaten aus: TODO-Kommentaren in wenig-gekoppelten
   Dateien, fehlenden Kleinigkeiten, die beim Lesen auffielen. Je Aufgabe: Ort,
   erwarteter Umfang, warum sicher (`vermutet`-Kennzeichnung wo nötig, Querverweis
   /blast für die Prüfung).
4. **Ehrlichkeits-Abschnitt**: was die Tour NICHT abdeckt (nicht gelesene Bereiche,
   Setup, Infrastruktur), Stolpersteine, die beim Lesen auffielen (mit Fundstelle).
5. Evidenz-Pflicht: jede Struktur-Aussage aus Topologie-Daten oder Lektüre
   (Datei:Zeile); Churn-Aussagen mit Zahlen; nichts über Code behaupten, der nicht
   gelesen wurde (Stationen decken nur Gelesenes ab — Rest heißt explizit
   "nicht Teil der Tour").

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Kein Git | Churn entfällt; Wichtigkeit nur aus Struktur + Import-Graph, ausweisen |
| Monorepo mit mehreren Apps | Schwerpunkt-Pflicht: User wählt App (Vorschlagsliste aus Tree) |
| Sehr kleines Projekt (< 20 Dateien) | Kompakt-Tour (3 Stationen), kein künstliches Aufblasen |
| Zirkuläre Import-Kanten | Als Stolperstein in den Ehrlichkeits-Abschnitt (mit Kante) |
| Generierter/Vendor-Code dominiert Zeilenzahl | Excludes greifen; im Tree trotzdem erwähnen ("dist/ ignoriert") |
| README existiert und ist gut | Tour verweist statt dupliziert (Doku-Respekt; /doc-drift falls zweifelhaft) |

## 8. Testplan

Smoke (AGENTS-Repo selbst — echtes, bekanntes Ziel):

```powershell
& .\onboarding-pfadfinder\scripts\topology.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS"
```

Erwartung: exit 0, JSON valide; Tree zeigt Skill-Ordner + ops/, Churn zeigt die
Sprint-Commits, Entry-Points leer oder plausibel (kein Fehler bei "kein
klassisches Programm" — wichtiger Robustheits-Test).

LLM-Durchlauf gegen AGENTS: Tour muss die ops/BIBEL.md als frühe Station enthalten
(das Repo ERKLÄRT sich über sie — prüft, ob die Sequenzierung inhaltlich denkt
statt nur strukturell) und die Verständnisfragen müssen aus dem echten Inhalt
stammen (Stichprobe: 3 Fragen beantwortbar aus den genannten Schlüsseldateien).

Akzeptanz (dreamzzz-api): Komplettlauf (Level mid). Erwartung: Stationen decken
die Kern-Verzeichnisse ab; 3 Datei:Zeile-Anker stichprobenartig geprüft (existieren
und passen zum Lernziel); erste-Aufgaben-Vorschläge zeigen auf echte Stellen.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (Tour wird nicht ungefragt ins Zielrepo geschrieben)
- [ ] topology.ps1 (4 Signale, Tiefe-3-Tree, Import-Aggregation, Churn)
- [ ] Smoke bestanden (inkl. Robustheit bei Entry-Point-losem Repo)
- [ ] AGENTS-Tour: BIBEL als frühe Station, 3 Fragen-Stichproben bestanden
- [ ] Akzeptanz-Lauf dokumentiert (3 Anker-Stichproben)
- [ ] Negativ-Test bestanden
- [ ] Tour erfüllt BIBEL § 4 (nur Gelesenes wird behauptet) + Ehrlichkeits-Abschnitt
- [ ] tracking.md aktualisiert, Commit `sprint-20: onboarding-pfadfinder implementiert`
