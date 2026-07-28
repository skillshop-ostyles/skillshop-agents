# GUARDSCAN DIALOG PROTOCOL — IMPACT-PRIORITIZED

STRICT: YOU MUST follow this decision tree. Findings always shown by impact (HIGH first). Every finding MUST reference a real-world incident.

## PHASE 0 — WELCOME

Triggered by: `/guardscan` (no arguments)

```
GUARDSCAN v1 — dein Security-Coach
─────────────────────────────────────────
AI-generierter Code vergisst Sicherheits-
Primitive. Ich finde die 7 häufigsten
Lücken — priorisiert nach Impact.
Jeder Fund verweist auf einen realen
Sicherheitsvorfall.

[1] Quick-Scan (alle 7 Checks)
[2] Nur HIGH Impact (RLS + Secrets + Client Auth)
[3] Einzel-Check auswählen
[4] Hilfe: Was wird geprüft?
[0] Exit
```

### [4] HELP
Show 7 checks grouped by impact with one-line incident reference, then return to menu.

## PHASE 1 — EXECUTION

Run checks. Show progress with severity badge:

```
[🔴 HOCH]   1/3 rls ... [FAIL (2)]
[🔴 HOCH]   2/3 secrets ... [FAIL (1)]
[🔴 HOCH]   3/3 clientauth ... [FAIL (1)]
[🟠 MEDIUM] 4/3 csrf ... [FAIL (1)]
...
```

After ALL checks complete, show IMPACT-GROUPED summary:

```
GUARDSCAN RESULT
─────────────────────────────────────────
[🔴 HOCH]   4 Funde
  rls:         2 — Tabellen ohne RLS
  secrets:     1 — API-Key in Source
  clientauth:  1 — Auth nur client-seitig

[🟠 MEDIUM] 3 Funde
  csrf:            1 — Formular ohne CSRF
  authmiddleware:  1 — Route ohne Auth
  headers:         1 — Keine Security-Header

[🟡 NIEDRIG] 0 Funde

─────────────────────────────────────────
  7 checks | 0 pass | 7 Funde

[1] HIGH Impact Funden durchgehen (Coaching)
[2] ALLE Funde durchgehen
[3] Report anzeigen
[4] Alle fixbaren HIGH Funde automatisch fixen
[0] Fertig
```

## PHASE 2 — COACHING (per finding)

HIGH findings first, then MEDIUM, then LOW.

```
─── [🔴 HOCH] Finding 1/4 ────────────
rls: supabase/migrations/001_init.sql:15
───────────────────────────────────────────────
INCIDENT: Moltbook Juli 2025
───────────────────────────────────────────────
1.5 Millionen API-Keys exponiert, weil
Row Level Security auf user_tokens nie
aktiviert wurde. Ein Skiller scannte die
öffentliche Datenbank und kopierte alle
Tokens mit einem einzigen Query.
───────────────────────────────────────────────
DIAGNOSE: 'CREATE TABLE user_tokens' ohne
zugehöriges 'ALTER TABLE user_tokens
ENABLE ROW LEVEL SECURITY'
───────────────────────────────────────────────
FIX: ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;
     CREATE POLICY user_tokens_isolation ON user_tokens
     FOR ALL USING (auth.uid() = user_id);
───────────────────────────────────────────────
PRÄVENTION: Nach jedem CREATE TABLE sofort
RLS aktivieren + Policy definieren. Am besten
als Migration-Template.

[S] Überspringen         [N] Nächster Fund (HIGH)
[P] Vorheriger Fund      [0] Ergebnis-Übersicht
```

### SEVERITY BADGES

- `[🔴 HOCH]` — known production vulnerability, fix immediately
- `[🟠 MEDIUM]` — should fix before production deployment
- `[🟡 NIEDRIG]` — good practice, fix when convenient

### [F] FIX MODE

Only available for fixable checks. Before writing: show diff + ask `[y/n]`.

```
Fix: INSERT 'ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;'
nach CREATE TABLE in supabase/migrations/001_init.sql:13

--- a/supabase/migrations/001_init.sql
+++ b/supabase/migrations/001_init.sql
@@ -12,3 +12,4 @@
 CREATE TABLE user_tokens (
   id SERIAL PRIMARY KEY,
   user_id UUID REFERENCES users(id),
   token TEXT NOT NULL
 );
+ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;
+CREATE POLICY user_tokens_isolation ON user_tokens
+  FOR ALL USING (auth.uid() = user_id);

Fix anwenden? [y/n]
```

## PHASE 3 — SUMMARY

```
GUARDSCAN COMPLETE
─────────────────────────────────────────
  7 checks | 0 pass | 7 Funde | 2 gefixt
  [🔴 HOCH]  4 → 2 gefixt, 2 übersprungen
  [🟠 MEDIUM] 3 → 0 gefixt, 3 übersprungen

[1] Report speichern (guardscan-report.md)
[2] Nochmal prüfen
[3] Security-Checkliste für manuelle Prüfung
[0] Fertig
```

### [0] DONE
```
Guardscan abgeschlossen. 7 Funde, 2 gefixt.
Deine App hat jetzt RLS und keine Secrets mehr
im Source. Bleib sicher da draußen.
```

## DIRECT MODE

- `/guardscan quick` → run all 7 → jump to PHASE 2
- `/guardscan high` → run HIGH only → show → jump to DONE
- `/guardscan secrets` → single check → jump directly to that check's findings
