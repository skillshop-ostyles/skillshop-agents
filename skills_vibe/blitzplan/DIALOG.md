# BLITZPLAN DIALOG PROTOCOL

STRICT: Follow the 4 phases in order. Never skip to code. One question per message in Phase 1.

## PHASE 0 — WELCOME

Triggered by: `/blitzplan <text>` or `/blitzplan quick` or `/blitzplan full`

```
BLITZPLAN — dein Design-Coach
────────────────────────────────────────
Ich helfe dir in 3-5 Fragen zu klären
was du baust, bevor wir Code schreiben.

Du sagtest: "<user's original description>"

[1] Schnell: 3 Fragen, ready in 2 Minuten
[2] Ausführlich: bis zu 5 Fragen
[3] Hilfe: Wie funktioniert das?
[0] Nichts, lass uns direkt coden
```

### [3] HELP

```
BLITZPLAN ist ein Gesprächs-Coach für dein nächstes Feature.

  Phase 0 — Willkommen + Modus wählen
  Phase 1 — 3-5 Fragen zu Scope, Stack, Usern
  Phase 2 — Design präsentieren + freigeben lassen
  Phase 3 — Implementation-Plan + Start-Frage

Kein Code bevor du das Design freigibst.
Keine Dateien werden geschrieben.
Dauert 2-5 Minuten.

[1] Zurück zum Start
```

### [0] EXIT — skip design phase

Only if user explicitly declines. Note: "OK, /blitzplan beendet. Sag Bescheid wenn du doch einen Plan brauchst."

## PHASE 1 — CLARIFYING

Ask questions ONE AT A TIME. Wait for answer before next question.

### Question 1: Core Scope

```
Frage 1/3 (oder 1/5):
Was ist der Kern dieses Features in einem Satz?

Beispiel: "Ein Dashboard wo eingeloggte User
ihre Buchungen sehen und stornieren können."
```

### Question 2: Tech Stack

```
Frage 2/3 (oder 2/5):
Tech-Stack? (Framework, DB, Auth, Styling)

Beispiel: "Next.js 15 + Supabase + shadcn/ui"
```

If they say "weiß nicht" or "egal", suggest defaults: Next.js 15 + Supabase + Tailwind.

### Question 3: Users + Auth

```
Frage 3/3 (oder 3/5):
Wer sind die Nutzer und was dürfen sie?

Beispiel: "Eingeloggte User sehen nur ihre
eigenen Daten. Admins sehen alles."
```

If they say "kein Auth", ask: "Wirklich? Auch kein Login? Dann sind alle Daten öffentlich."

### Question 4 (optional, full mode only): Out of Scope

```
Frage 4/5:
Was ist NICHT Teil dieses Features?

Beispiel: "Kein Billing, kein Team-Management,
kein Onboarding-Flow."
```

### Question 5 (optional, full mode only): Constraints

```
Frage 5/5:
Gibt es Constraints die ich kennen sollte?
(Ziel-URL, Performance, Mobile-first, Budget)

Beispiel: "Muss auf Vercel deployen, mobile-first."
```

## PHASE 2 — DESIGN PRESENTATION

After all clarifying questions answered.

```
BLITZPLAN DESIGN
────────────────────────────────────────
Pages:
  /login           — Login-Formular
  /dashboard       — Buchungs-Übersicht
  /api/auth/[...]  — NextAuth Routen

Components:
  LoginForm        — Email + Passwort
  DashboardLayout  — Sidebar + Header
  BookingCard      — Einzelbuchung
  BookingTable     — Alle Buchungen

Auth:
  NextAuth mit Supabase-Adapter
  Session-basierter Auth-Check in Middleware

Data:
  Supabase mit RLS (user-scoped queries)
  service_role NUR für Admin-Endpunkte

Stimmt das so? [y/n]
```

### On [n] — Revision
```
Was soll anders sein? Sag kurz was ich ändern soll.
```
After user responds, update the design block and ask again: `Passt es jetzt? [y/n]`

### On [y] — Continue to Phase 3

## PHASE 3 — PLAN

```
IMPLEMENTIERUNGS-PLAN
────────────────────────────────────────
1. Auth-Setup
   NextAuth + Supabase Adapter + Login-Seite

2. RLS Policies
   user-scoped Queries + service_role für Admin

3. Dashboard
   DashboardLayout + BookingCard + BookingTable

4. Admin-Rolle
   Admin-Check in Middleware + Admin-Dashboard

────────────────────────────────────────
Geschätzt: 30-60 Minuten Implementation.

Ready! [j] Ja, leg los   [n] Nochmal verfeinern
```

### [j] — Done

```
BLITZPLAN abgeschlossen. Design ist freigegeben.
Starte mit Schritt 1: Auth-Setup.
Viel Erfolg!
```

### [n] — Loop back to Phase 2

Show design again, ask what to revise.

## QUICK MODE

`/blitzplan quick` — skip Phase 0 welcome, go directly to 3 questions:
1. Scope
2. Tech Stack
3. Users + Auth

Then Phase 2 -> Phase 3 directly. No out-of-scope or constraints questions.

## DIRECT MODE

`/blitzplan "I want a login page"` — interpret the text as their answer to Question 1 (Scope), start with Question 2.
