# POLISH DIALOG PROTOCOL — COACHING MODE

STRICT: YOU MUST follow this decision tree exactly. This is COACHING, not gating. No pass/fail framing.

## PHASE 0 — WELCOME

Triggered by: `/polish` (no arguments)

```
POLISH v1 — räum AI-Rückstände auf
────────────────────────────────────────
Ich durchsuche dein Projekt nach 6 typischen
KI-Hinterlassenschaften. Dauert ~1 Minute.

[1] Komplett-Durchlauf (alle 6 Checks)
[2] Einzel-Check auswählen
[3] Quick-Check (consolelog + anytype + deadimport)
[4] Hilfe: Was ist ein AI-Rückstand?
[0] Exit

Was soll ich prüfen? (0-4):
```

### [4] HELP
"AI-Rückstände sind Überbleibsel aus KI-generiertem Code: `console.log`, `any`-Typen, fehlende Keys, hardcodierte Werte, ungenutzte Imports, und halluzinierte Pakete. `/polish` findet sie für dich."

Return to PHASE 0 menu.

## PHASE 1 — EXECUTION

Run selected checks in order. Show progress:

```
Check 1/6: consolelog ... [running]
  → 2 gefunden
Check 2/6: anytype ... [running]
  → 0 gefunden (sauber)
...
```

After ALL checks complete, show:

```
POLISH RESULT
────────────────────────────────────────
  consolelog:  2 Funde
  anytype:     0 Funde (sauber)
  nofallback:  1 Fund
  magic:       3 Funde
  deadimport:  0 Funde (sauber)
  aismell:     1 Fund
  ─────────────────────────
  6 Checks | 3 sauber | 4 Funde

[1] Funde durchgehen (Coaching)
[2] Report anzeigen
[3] Alle fixbaren Funde automatisch fixen
[4] Erklärung: Was bedeuten die Funde?
[0] Fertig
```

## PHASE 2 — COACHING (per finding)

For each finding, show:

```
─── Finding N/M ─────────────────────────
📋 <type>: <file>:<line>
────────────────────────────────────
Diagnose: <what the script found>
────────────────────────────────────
Erklärung: <why it matters — 1 sentence>
────────────────────────────────────
Umsetzung:
  1. <step 1>
  2. <step 2>
  3. <step 3>

[F] Fix (auto-korrigieren)
[R]  Ersetzen durch <alternative>        (check-spezifisch)
[U]  unknown vorschlagen                 (check-spezifisch)
[S]  Überspringen
[N]  Nächster Fund
[P]  Vorheriger Fund
[0]  Ergebnis-Übersicht
```

Show only the options relevant to the current check type.

### [F] FIX MODE

Before writing:
1. Show the exact change
2. Ask: `"Soll ich das anwenden? [y/n]"`
3. Only write on `y`

After fix: "Erledigt. Weiter zum nächsten? [y/n]"

## PHASE 3 — SUMMARY

```
POLISH COMPLETE
────────────────────────────────────────
  6 Checks | 3 sauber | 4 Funde | 2 gefixt

[1] Report speichern (polish-report.md)
[2] Nochmal prüfen
[3] Erklärung: Wie verhindere ich das in Zukunft?
[0] Fertig
```

### [3] PREVENTION TIPS
- "Check `console.log` vor jedem Commit"
- "Nutze `unknown` statt `any` — TypeScript zwingt dich zum Prüfen"
- "Schreib in deinen Prompt: 'keine Debug-Logs, keine any-Types'"

### [0] DONE
```
✅ Polish abgeschlossen. 4 Funde, 2 gefixt.
Dein Code sieht jetzt aus wie von jemandem der Ahnung hat.
```

## DIRECT MODE (skip PHASE 0)

- `/polish quick` → run all 6 → jump to PHASE 2
- `/polish consolelog` → run single check → show results → jump to DONE
- `/polish anytype` → run single check → show results → jump to DONE
- `/polish nofallback` → run single check → show results → jump to DONE
- `/polish magic` → run single check → show results → jump to DONE
- `/polish deadimport` → run single check → show results → jump to DONE
- `/polish aismell` → run single check → show results → jump to DONE
