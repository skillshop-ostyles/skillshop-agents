---
name: konsistenz-enforcer
description: "Finds duplicated BUSINESS LOGIC (not duplicated text): extracts rule candidates (validations, calculations, domain constants, regexes, status logic) from a codebase, then has the LLM cluster semantically equal rules across different implementations and flag divergent ones with a single-source-of-truth proposal. Read-only. Trigger: /consist"
trigger: /consist
---

# /consist

Findet semantisch gleiche Geschäftsregeln in unterschiedlichem Code (nicht
Text-Duplikate) und meldet Divergenzen zwischen ihren Implementierungen mit einem
Single-Source-of-Truth-Vorschlag.

## What this is for

- Dieselbe fachliche Regel — eine Preisberechnung, eine Altersgrenze, eine
  E-Mail-Validierung — lebt oft an vielen Stellen im System, jeweils leicht anders
  implementiert (`if (age >= 18)` vs. `isAdult(user)` vs. `MINIMUM_AGE = 18`).
  Klassische Clone-Detection ist blind dafür; semantische Gleichheit erkennen kann
  erst ein LLM.
- **Reiner Lese-Skill.** Kein automatisches Refactoring, nur ein Vorschlag.

## What You Must Do When Invoked

Wenn `/consist --help` oder `/consist -h` (ohne weitere Argumente) aufgerufen wird:
gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel und Fokus klären

Kläre: `-ProjectDir` und optional einen fachlichen Fokus (Freitext, z. B. "alles
rund um Preise" — engt die LLM-Clusterung ein, NICHT die Extraktion). Bestätigung
einholen.

### Step 2 — Kandidaten extrahieren

```powershell
& "<SKILL_DIR>/scripts/rule-candidates.ps1" -ProjectDir "<pfad>"
```

Liefert `candidates.Count: 0`: sauber melden ("keine Regel-Kandidaten gefunden"),
keinen leeren Pseudo-Report schreiben, stoppen.

### Step 3 — Analyse

1. Kandidaten sichten, offensichtliches Rauschen verwerfen (Loop-Indizes,
   Test-Zahlen, HTTP-Status-Codes in Framework-Code) — verworfene Kategorien im
   Report-Anhang nennen.
2. **Nach fachlicher Bedeutung clustern**, nicht nach Text: "alles, was
   Volljährigkeit prüft", "alles, was MwSt berechnet". Bei > 300 Kandidaten: erst
   nach Kategorie grob clustern, dann je Kategorie tief analysieren. Bei gesetztem
   Fokus: nur passende Cluster tief analysieren, Rest als Inventar listen.
3. Pro Cluster mit ≥ 2 Stellen:
   - Alle Stellen mit `Datei:Zeile` + Code-Ausschnitt.
   - **Konsistenz-Urteil**: `konsistent` (gleiche Semantik, gleiche Werte) oder
     `DIVERGENT` (z. B. `>= 18` vs. `> 18`; `0.19` vs. `19`) — präzise benennen,
     worin die Abweichung besteht und welches Fehlverhalten sie erzeugen kann.
   - **SSoT-Vorschlag**: wo die Regel künftig einzig leben sollte (existierende
     Konstante/Funktion bevorzugen, sonst Vorschlag mit Modul-Ort), Konfidenz
     angeben.
4. Test-Dateien NICHT ausschließen (kodieren oft die "wahre" Regel), aber im
   Cluster als Test markieren. Cross-Language-Cluster (z. B. Code + SQL) sind
   ausdrücklich gewollt.
5. Evidenz-Pflicht: keine Cluster-Behauptung ohne alle Fundstellen; Divergenz-Urteil
   nur mit direktem Code-Zitat beider Seiten (`ops/BIBEL.md` § 4).

### Step 4 — Report schreiben

Datei `consist-report.md` im aktuellen Arbeitsverzeichnis (**nicht** ins analysierte
Repo):

1. **Kurzfassung** — X Regeln mehrfach implementiert, davon Y divergent.
2. **Divergenzen** zuerst (Severity: divergente Werte = hoch).
3. **Konsistente Mehrfach-Implementierungen**.
4. **SSoT-Vorschläge**.
5. **Offene Fragen** (Cluster der Konfidenz-Stufe `vermutet`).

### Step 5 — Zusammenfassen

Pfad des Reports nennen, Kurzfassung direkt im Chat wiedergeben — Divergenzen
zuerst.

## Usage

```
/consist                  # interaktiv
/consist <dir>            # ganzes Verzeichnis
/consist <dir> "<fokus>"  # mit fachlichem Fokus
/consist --help
```
