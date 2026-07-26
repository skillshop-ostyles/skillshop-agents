# SHIPCHECK DIALOG PROTOCOL

STRICT: YOU MUST follow this decision tree exactly. Each numbered step is mandatory.

## PHASE 0 — WELCOME

Triggered by: `/shipcheck` (no arguments)

```
SHIPCHECK v1 — dein Ship-Coach
────────────────────────────────────────
Ich prüfe dein Projekt auf 3 kritische Bereiche,
bevor du shipped. Dauert ~30 Sekunden.

[1] Quick-Check (alle 3 — env + build + secrets)
[2] Einzel-Check auswählen
[3] Hilfe: Was wird geprüft?
[0] Exit

Welcher Bereich? (0-3):
```

### [3] HELP
Show brief description of all 3 checks, then return to PHASE 0 menu.

### [0] EXIT
"Alles klar. `/shipcheck` wenn du bereit bist." → END

## PHASE 1 — EXECUTION

### [1] QUICK-CHECK
Run all 3 scripts in order. Show progress:

```
Check 1/3: envscan ... [running]
Check 1/3: envscan ... [done]
Check 2/3: build ... [running]
...
```

After each check: **brief** result line with pass/fail count. Do NOT enter per-finding detail yet.

### [2] SINGLE CHECK
```
Welchen Check?
[1] env — Environment Variables
[2] build — Build Health
[3] secrets — Secret Leakage
[0] Zurück
```

Run selected script. Show result + coaching.

## PHASE 2 — RESULTS

After all checks complete, show SUMMARY:

```
SHIPCHECK RESULT
────────────────────────────────────────
  env:      2 fail, 3 pass
  build:    0 fail, 1 pass
  secrets:  1 fail, 0 pass
  ─────────────────────────
  3 checks | 4 pass | 3 fail

[1] Details zu allen Fehlern anzeigen
[2] Fehler einzeln durchgehen (coaching)
[3] Report speichern (shipcheck-report.md)
[4] Nochmal prüfen
[5] Hilfe zu einem Fehler
[0] Fertig
```

### [1] ALL DETAILS
List every finding with diagnosis + explanation + implementation in compact form. End with PHASE 2 menu again.

### [2] COACHING
For each failed finding, show:

```
─── Finding 1/3 ──────────────────────
❌ env: DATABASE_URL fehlt
Diagnose: .env.example enthält DATABASE_URL, aber .env nicht.
─────────────────────────────────────
Erklärung: Deine App braucht eine DB-URL für Prisma.
Ohne diesen Eintrag crasht jeder DB-Zugriff mit 500.
─────────────────────────────────────
Umsetzung:
  1. Öffne .env
  2. Füge ein: DATABASE_URL=postgres://user:pass@host:5432/db
  3. Starte dev server neu

[F] Jetzt fixen  [N] Nächstes  [P] Vorheriges  [0] Ergebnis-Übersicht
```

### [F] FIX MODE
Before writing ANY file:
1. Show the exact change: diff or full new value
2. Ask: `"Soll ich das anwenden? [y/n]"`
3. Only write on `y`

```
Vorschlag: DATABASE_URL fehlt in .env
→ Inhalt: DATABASE_URL=postgres://localhost:5432/myapp
→ Datei: /project/.env (anhängen)

Anwenden? [y/n]:
```

After fix: "Erledigt. Erneut prüfen? [y/n]"

## PHASE 3 — SUMMARY

```
SHIPCHECK COMPLETE
────────────────────────────────────────
  3 checks | 4 pass | 3 fail | 1 fixed
  Report: shipcheck-report.md (if saved)

[1] Nochmal prüfen
[2] Report öffnen
[0] Fertig
```

### [0] DONE
```
✅ Shipcheck abgeschlossen. 3 Probleme gefunden, 1 gefixt.
Tipp: Regelmäßiger Check fängt Fehler bevor sie weh tun.
```

## OPTION COMBINATIONS

If user provides an argument, skip PHASE 0:

- `/shipcheck quick` → run all 3 → jump to PHASE 2
- `/shipcheck env` → run check-env only → show result + coaching → jump to DONE
- `/shipcheck build` → run check-build only → show result + coaching → jump to DONE
- `/shipcheck secrets` → run check-secrets only → show result + coaching → jump to DONE
