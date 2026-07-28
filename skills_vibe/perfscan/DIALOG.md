# PERFSCAN DIALOG PROTOCOL — IMPACT-PRIORITIZED

STRICT: YOU MUST follow this decision tree. Findings are always shown by impact (HIGH first).

## PHASE 0 — WELCOME

Triggered by: `/perfscan` (no arguments)

```
PERFSCAN v1 — dein Performance-Coach
────────────────────────────────────────
Ich suche nach 7 typischen React/Next.js
Performance-Fehlern. Priorisiert nach Impact.

[1] Quick-Check (alle 7 — 1 Minute)
[2] Nur HIGH Impact (keyprops + effect + layoutshift)
[3] Einzel-Check auswählen
[4] Hilfe: Was wird geprüft?
[0] Exit
```

### [4] HELP
Show brief description of 7 checks grouped by impact, then return to menu.

## PHASE 1 — EXECUTION

Run checks. Show progress with impact badge:

```
[🔥 HOCH]   1/3 keyprops ... [FAIL (2)]
[🔥 HOCH]   2/3 useeffect ... [PASS]
[🔥 HOCH]   3/3 layoutshift ... [FAIL (1)]
[⚡ MITTEL] 4/3 images ... [FAIL (1)]
...
```

After ALL checks complete, show IMPACT-GROUPED summary:

```
PERFSCAN RESULT
────────────────────────────────────────
[🔥 HOCH]   3 Funde
  keyprops:    2 — .map() ohne key=
  layoutshift: 1 — <img> ohne width/height

[⚡ MITTEL] 1 Fund
  images:      1 — <img> statt <Image>

[🔍 NIEDRIG] 0 Funde

────────────────────────────────────────
  7 checks | 4 pass | 4 Funde

[1] HIGH Impact Funden durchgehen (Coaching)
[2] ALLE Funde durchgehen
[3] Report anzeigen
[4] Alle fixbaren HIGH Funde automatisch fixen
[0] Fertig
```

## PHASE 2 — COACHING (per finding)

HIGH findings first, then MEDIUM, then LOW.

```
─── [🔥 HOCH] Finding 1/3 ─────────────
keyprops: src/app/users/page.tsx:25
────────────────────────────────────
Diagnose: .map() rendert JSX ohne key= Prop
────────────────────────────────────
Erklärung: Ohne key= kann React nicht erkennen
welche Listenelemente sich geändert haben →
es rendert ALLE neu, nicht nur das geänderte.
────────────────────────────────────
Umsetzung: <div key={user.id}> → stabiler Key
hilft React Items eindeutig zu identifizieren.

[K] key={user.id} hinzufügen
[S] Überspringen
[N] Nächster Fund (HIGH)
[P] Vorheriger Fund
[0] Ergebnis-Übersicht
```

### [F] FIX MODE

Before writing: show diff + ask `[y/n]`.

## PHASE 3 — SUMMARY

```
PERFSCAN COMPLETE
────────────────────────────────────────
  7 checks | 4 pass | 4 Funde | 2 gefixt
  [🔥 HOCH]  3 → 1 gefixt, 1 übersprungen
  [⚡ MITTEL] 1 → 1 gefixt

[1] Report speichern (perfscan-report.md)
[2] Nochmal prüfen
[3] Tipps: Performance verbessern
[0] Fertig
```

### [0] DONE
```
✅ Perfscan abgeschlossen. 4 Funde, 2 gefixt.
Deine App rendert jetzt effizienter.
```

## DIRECT MODE

- `/perfscan quick` → run all 7 → jump to PHASE 2
- `/perfscan high` → run HIGH only → show → jump to DONE
- `/perfscan keyprops` → single check → jump to DONE
