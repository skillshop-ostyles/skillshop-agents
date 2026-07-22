# BIBEL — Skill-Programm AGENTS

Verbindliche Master-Spezifikation für die Umsetzung von 10 KI-Skills, je einer pro Sprint.
Ausführendes Modell: **Sonnet**. Diese Bibel ist nicht verhandelbar. Bei Widerspruch
zwischen Sprint-File und Bibel gilt die Bibel. Bei Widerspruch zwischen dieser Bibel und
der globalen Benutzer-Bibel (`C:\Users\ostol\.claude\CLAUDE.md`) gilt die globale.

---

## 1. Mission & Geltungsbereich

10 Skills, die jahrzehntealte Entwickler-Schmerzen lösen und erst durch LLMs möglich
wurden. Jeder Skill wird in genau einem Sprint gebaut, getestet und lokal committet.
Sprint-Files liegen in `ops/sprints/`, Status in `ops/tracking.md`.

Geltungsbereich: alles unterhalb `C:\Users\ostol\Desktop\AGENTS`. Nichts außerhalb wird
verändert (Ausnahme: Lese-Zugriff auf Test-Ziele, siehe § 6).

---

## 2. Nicht verhandelbare Regeln

1. **Remote nur mit expliziter Freigabe**: Das Repo hat seit 2026-07 einen privaten
   GitHub-Remote (`skillshop-ostyles/skill-shop-agents`, User-Entscheidung). `git push`
   nur nach explizitem User-Wunsch pro Aktion, nie automatisch/blanko. Öffentlich
   schalten ist ein separater, eigens freizugebender Schritt.
2. **Schutzregel `~/.claude/`**: Kein Skript und keine Session darf
   `C:\Users\ostol\.claude\` (oder Unterordner) verändern. Jedes Skript, das schreibt,
   trägt diesen Guard (Copy-Vorlage, unverändert übernehmen):

   ```powershell
   # SCHUTZ: ~/.claude/ niemals veraendern.
   function Normalize($p) {
       $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
       $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
       return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
   }
   $claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
   $targetPath = Normalize $ProjectDir
   if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\")) {
       Write-Error "SCHUTZ: ProjectDir liegt unter $claudeRoot. Abbruch."
       exit 1
   }
   ```

3. **Karpathy-Regeln** (globale Bibel): erst denken, dann coden; Simplicity First;
   chirurgische Änderungen; zielgetriebene Ausführung mit Erfolgskriterien.
4. **Sprachstil**: Deutsch, direkt, keine Floskeln, keine Emojis. Skript-Ausgaben und
   Reports auf Deutsch; Code-Bezeichner Englisch.
5. **Secrets**: niemals vollständig loggen — nur maskiert (erste 8 + letzte 4 Zeichen).
   Collector-Skripte, die Dateien einlesen, geben Inhalte von `.env`-artigen Dateien
   grundsätzlich NICHT aus.
6. **Read-only gegenüber Test-Zielen**: Skills analysieren fremde Projekte, sie
   verändern sie nicht — außer der Skill hat explizit schreibenden Zweck UND der User
   hat die konkrete Änderung freigegeben (gilt für totpfad-bestatter und
   migrations-chirurg; Details in deren Sprint-Files).

---

## 3. Skill-Anatomie (uniform, verbindlich)

Jeder Skill ist ein eigener Ordner unter `AGENTS\skills\` (Sprint 29: Umzug von
`AGENTS\<skill-name>\` nach `AGENTS\skills\<skill-name>\` für die öffentliche
GitHub-Präsentation):

```
skills\<skill-name>\
  SKILL.md
  README.md          (GitHub-Installationsanleitung, siehe skills/elevate/README.md)
  scripts\
    *.ps1
    templates\        (nur falls das Sprint-File Templates vorsieht)
```

### 3.1 SKILL.md

Exakt das Muster von `skills/elevate/SKILL.md`:

- Frontmatter: `name`, `description` (englisch, mit "Trigger: /<x>" am Ende), `trigger`.
- Abschnitt `## What this is for`.
- Abschnitt `## SCHUTZREGEL — niemals ~/.claude/` (bei Skills mit Schreib-Skripten).
- Abschnitt `## What You Must Do When Invoked` mit nummerierten Steps
  (`### Step 1 — ...`). Erster Satz regelt `--help`/`-h`: Usage-Block ausgeben, stopp.
- Abschnitt `## Usage` mit Code-Block der Aufruf-Varianten.

### 3.2 Skripte

- `[CmdletBinding()] param(...)` mit `[Parameter(Mandatory = $true)]` für Pflicht-Parameter.
- `$ErrorActionPreference = 'Stop'` für Collector (Fehler sollen knallen),
  `'Continue'` nur für Best-Effort-Runner (wie `skills/elevate/scripts/ci-local.ps1`).
- Guard aus § 2.2 in jedem Skript, das schreibt. Reine Lese-Skripte brauchen ihn nicht,
  prüfen aber die Existenz des Zielpfads (`Test-Path` → `Write-Error` + `exit 1`).
- Pfad-Parameter heißen einheitlich `-ProjectDir`; weitere Parameter je Sprint-File.

### 3.3 Output-Contract

Jedes Analyse-Skript liefert BEIDES (Muster `skills/elevate/scripts/audit.ps1`):

1. **JSON** via `ConvertTo-Json -Depth 5` (oder tiefer, falls nötig) auf stdout —
   maschinenlesbar, Schema steht im Sprint-File.
2. **Konsolen-Zusammenfassung** danach (`=== TITEL ===` + eingerückte Zeilen) —
   menschenlesbar.

Reports, die der LLM-Teil erzeugt, werden als Markdown-Datei in ein vom User genanntes
Verzeichnis geschrieben (Default: aktuelles Arbeitsverzeichnis, Dateiname im Sprint-File
definiert) — niemals ungefragt ins analysierte Fremdprojekt.

---

## 4. Architektur-Prinzip: Collector vs. LLM

Der Kern aller 10 Skills. Strikte Trennung:

- **Deterministische Collector-Skripte** sammeln Evidenz: git log/blame, Datei-Scans,
  Manifest-Parsing, Log-Parsing. Sie sind testbar, reproduzierbar, urteilen nicht.
- **LLM-Analyse** (die Steps in SKILL.md) interpretiert die Evidenz: rekonstruiert,
  vergleicht, bewertet, formuliert.

**Zentrale Qualitätsregel: keine Behauptung ohne Beleg.** Jede Aussage in einem Report
trägt eine Evidenz-Referenz — Commit-Hash, `Datei:Zeile`, Log-Zeilennummer oder
Zitat mit Fundstelle. Zusätzlich trägt jede Aussage eine Konfidenz-Stufe:

| Stufe | Bedeutung |
|---|---|
| `belegt` | Direkt aus Evidenz ablesbar (Commit sagt es, Code zeigt es) |
| `wahrscheinlich` | Aus mehreren Evidenzstücken plausibel geschlossen |
| `vermutet` | Interpretation ohne harten Beleg — als offene Frage markieren |

Aussagen der Stufe `vermutet` gehören in einen eigenen Report-Abschnitt "Offene Fragen",
nie zwischen die belegten Befunde.

---

## 5. Sprint-Protokoll (Ablauf für Sonnet, je Sprint)

1. **Einlesen**: `ops/BIBEL.md`, das Sprint-File, `ops/tracking.md`. Dann in
   `tracking.md` den Sprint-Status auf `in Arbeit` setzen (mit Datum), committen ist
   hierfür noch nicht nötig.
2. **Bauen**: Skill-Ordner, SKILL.md, Skripte — exakt was das Sprint-File vorgibt,
   nichts darüber hinaus. Wiederverwendung: Skripte aus früheren Sprints dürfen
   **kopiert und angepasst** werden (Skills bleiben self-contained, keine
   Shared-Library — Simplicity First).
3. **Testen**: Testplan des Sprint-Files vollständig abfahren (Smoke, Akzeptanz,
   Negativ). Ergebnisse (Kommando + Ausgabe-Kern) im Sprint-File unter der
   DoD-Checkliste dokumentieren.
4. **DoD**: Checkliste im Sprint-File abhaken (Markdown-Checkboxen editieren).
5. **Abschluss**: `tracking.md` auf `fertig` (mit Datum), lokaler Commit:
   `sprint-NN: <skill-name> implementiert`. Ein Sprint = mindestens ein Commit;
   mehrere Commits sind erlaubt, der letzte trägt die Abschluss-Message.

Ein Sprint gilt erst als fertig, wenn ALLE DoD-Punkte abgehakt sind. Teilfertige
Sprints bleiben `in Arbeit` mit Blocker-Eintrag in `tracking.md`.

---

## 6. Test-Protokoll

- **Smoke**: Jedes Collector-Skript läuft fehlerfrei gegen das AGENTS-Repo selbst
  (`C:\Users\ostol\Desktop\AGENTS`). Exit-Code 0, valides JSON (mit
  `ConvertFrom-Json` gegenprüfen).
- **Akzeptanz**: Lauf gegen das echte Projekt `C:\Users\ostol\Desktop\dreamzzz-api_vs\src`
  (Lese-Zugriff ist erlaubt, Schreiben nicht). Erwartetes Verhalten steht je Sprint-File.
  Falls das Projekt nicht mehr existiert oder für den Skill ungeeignet ist
  (z. B. kein Git): Eskalationsregel § 8.
- **Negativ-Tests** (immer beide):
  1. Nicht existenter Pfad → `Write-Error` + Exit-Code ≠ 0, keine Exception-Wand.
  2. `~/.claude/` als Ziel (bei Schreib-Skripten) → Guard greift, Exit-Code 1.
- JSON-Validierung: `<skript> ... | Select-Object -First 1` reicht nicht — das
  komplette JSON-Segment muss durch `ConvertFrom-Json` laufen. Praktisch: JSON in
  Datei umleiten und parsen (Skripte geben JSON zuerst aus, Zusammenfassung danach;
  fürs Parsen die Zusammenfassungs-Zeilen abtrennen oder das Skript mit einem
  `-JsonOnly`-Switch ausstatten, falls das Sprint-File es vorsieht).

---

## 7. Definition of Done (je Sprint, vollständig)

- [ ] Skill-Ordner vollständig (SKILL.md + alle Skripte aus dem Sprint-File)
- [ ] `--help`-Verhalten in SKILL.md definiert und Usage-Block vorhanden
- [ ] Schutz-Guard in allen Schreib-Skripten, Negativ-Test bestanden
- [ ] Alle Collector: valides JSON + Konsolen-Zusammenfassung (Smoke gegen AGENTS bestanden)
- [ ] Akzeptanz-Lauf gegen dreamzzz-api dokumentiert (Kommando + Kern-Output im Sprint-File)
- [ ] Report-Format erfüllt § 4 (Evidenz-Pflicht, Konfidenz-Stufen, "Offene Fragen"-Abschnitt)
- [ ] Edge-Cases des Sprint-Files implementiert oder begründet dokumentiert
- [ ] `ops/tracking.md` aktuell (Status `fertig` + Datum)
- [ ] Lokaler Commit `sprint-NN: <skill-name> implementiert`, Working Tree clean

---

## 8. Eskalationsregeln

Sonnet arbeitet autonom. Stoppen und den User fragen NUR wenn:

1. **Test-Daten fehlen**: Das Akzeptanz-Ziel existiert nicht oder ist ungeeignet und
   das Sprint-File nennt keinen Fallback.
2. **Teure Mehrdeutigkeit**: Das Sprint-File lässt mehrere Interpretationen zu und
   eine Fehlentscheidung würde substanzielle Nacharbeit bedeuten. Kleinigkeiten:
   sinnvolle Annahme treffen, Annahme im Sprint-File dokumentieren, weiterarbeiten.
3. **Scope-Konflikt**: Das Sprint-File verlangt etwas, das gegen § 2 verstößt.
   Dann gilt § 2, der Konflikt wird gemeldet.

Alles andere — Skript-Details, Formulierungen, Grenzwerte innerhalb der im Sprint-File
genannten Spannen — entscheidet Sonnet selbst und dokumentiert die Entscheidung im
Sprint-File unter einem Abschnitt `## Entscheidungen während der Umsetzung`.
