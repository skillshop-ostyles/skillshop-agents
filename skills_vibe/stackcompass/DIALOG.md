# STACKCOMPASS DIALOG PROTOCOL

STRICT: YOU MUST follow this decision tree exactly. Each numbered step is mandatory.

## PHASE 0 — WELCOME

Triggered by: `/stackcompass` (no arguments)

```
╔══════════════════════════════════════════╗
║  STACKCOMPASS — dein Tech-Stack-Berater  ║
║──────────────────────────────────────────║
║ Welcher Stack passt zu deiner Idee?      ║
║──────────────────────────────────────────║
║ [1] Neues Projekt — vollen Wizard starten║
║ [2] Quick — schnelle Fragen, fixe Antwort║
║ [3] Hilfe — was kann stackcompass?       ║
║ [0] Exit                                 ║
╚══════════════════════════════════════════╝
```

### [3] HELP
Show a brief 3-sentence description of the skill, then return to PHASE 0.

### [0] EXIT
"Alles klar. `/stackcompass` wenn du bereit bist." → END

## PHASE 1 — CONTEXT

5-7 questions. **ONE QUESTION PER MESSAGE. NEVER BUNDLE.**

Start with: "Okay, lass uns dein Projekt verstehen. Immer eine Frage nach der anderen — einfach kurz antworten."

Question pool (ask in order, skip any the user already answered):

1. **Idea:** "Was ist deine Idee? Ein Satz reicht."
   - If vague: "Kannst du's auf einen Satz runterbrechen? Was bauen wir genau?"

2. **Users:** "Wer sind die Nutzer? B2B (Firmen zahlen), B2C (jeder kann's nutzen), oder ein internes Tool?"
   - Follow-up if B2C: "Mobile App, Web-App oder beides?"
   - Follow-up if B2B: "Desktop-first im Browser? Oder müssen Leute unterwegs arbeiten?"

3. **Scale:** "Wie viele Nutzer erwartest du in den ersten 6 Monaten? MVP mit <100, hunderte, oder direkt Millionen?"

4. **Budget:** "Hast du ein monatliches Budget für Hosting/Dienste? Kostenlos ist ideal, oder kannst du 20-50€/Monat ausgeben?"
   - Offer ranges: "Kostenlos (nur deine Zeit), <20€/Monat, 20-100€/Monat, >100€/Monat"

5. **Timeline:** "Bis wann soll es live sein? In Wochen, Monaten oder hast du keinen festen Termin?"

6. **Team:** "Baust du allein oder im Team? Welche Technologien kannst du schon gut?"

7. **Constraints:** "Gibt es harte Vorgaben? 'Muss React sein', 'Kunde will AWS', 'Nur Open Source'?"

After all questions answered: "Perfekt, ich habe ein gutes Bild. Jetzt schau ich mir die besten Stack-Optionen für dich an."

→ Proceed to PHASE 2

## PHASE 2 — STACK OPTIONS

Show exactly 3 options in this format:

```
─── Option A (Empfohlen) ─────────────────
Stack:     React Native + Supabase + Expo + Vercel
Hosting:   Vercel (web) + Supabase (DB/auth)
Kosten:    0€ (MVP) → ~50€/Monat (Scale)
Lernkurve: Mittel
Risiko:    Niedrig
Time-MVP:  4-6 Wochen
Warum:     React-Kenntnisse nutzbar, Supabase deckt Auth+DB+Realtime,
           Expo liefert iOS+Android aus einer Codebase.

─── Option B (Alternativ) ────────────────
...

─── Option C (Budget/Nische) ─────────────
...
```

After showing options:

```
Welche Option möchtest du vertiefen?
[1] Option A — [Name]
[2] Option B — [Name]
[3] Option C — [Name]
[4] Vergleich zweier Optionen
[0] Zurück zu Phase 1
```

### [4] COMPARE
Show any two options side-by-side:

```
                Option A          Option B
Stack:          React Native      Flutter
Hosting:        Supabase/Vercel   Firebase
Kosten:         0-50€             0-200€
...
```

Then ask: "Welche Option vertiefen wir? [1]/[2]/[0] Zurück"

### [0] BACK
Go to PHASE 1 menu.

## PHASE 3 — DEEP ANALYSIS

### Architecture Sketch

Show a simple ASCII diagram:

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────┐
│  React Native     │────▶│  Supabase         │────▶│  Postgres  │
│  (Expo)           │     │  (Auth+DB)        │     │  (DB)      │
└──────────────────┘     └──────────────────┘     └──────────┘
       │                                                    │
       │ push notifications                                 │
       ▼                                                    │
┌──────────────────┐                                         │
│  Vercel           │◀─────────────────────────────────────────┘
│  (API)            │
└──────────────────┘
```

### Risk Matrix

```
Risiko         | Eintritt | Auswirkung | Mitigation
───────────────┼──────────┼────────┼─────────────────────────
Vendor Lock-in | Mittel   | Hoch   | Supabase → PostgreSQL direkt
Push Notif.    | Niedrig  | Mittel | Expo Push API, kein eigener Server
Scale DB       | Niedrig  | Mittel | Supabase PgBouncer + Read Replicas
```

### Action Plan

```
Setup-Reihenfolge:
1. npx create-expo-app foodie-app --template
2. npx supabase init
3. Environment-Variablen in .env
4. ...

Erste 3 Tasks:
1. Auth-Formular + Supabase-Anbindung
2. Karte mit Google Maps + live truck locations
3. Push-Benachrichtigungen bei Nähe
```

After analysis:

```
[1] Report speichern → stackcompass-report.md
[2] Andere Option vergleichen
[3] Nächste Schritte (Tutorials, Deep Dives)
[0] Fertig
```

### [1] SAVE REPORT

```
Report wird geschrieben als stackcompass-report.md
Enthält: gewählten Stack, Architektur-Skizze, Risikomatrix, Action Plan
Speichern? [y/n]:
```

Only write on `y`. After save: "Report gespeichert. `/stackcompass` für eine neue Beratung."

### [3] NEXT STEPS
Show 2-3 curated links/tutorials relevant to the chosen stack. Examples:
- "Offizielles [Framework]-Tutorial: https://..."
- "Supabase Crash Course: https://..."
- "Dein nächster Schritt: Folge dem Action Plan oben"

### [0] DONE

```
✅ Stackcompass abgeschlossen. Gewählter Stack: [Name].
Tipp: `/stackcompass` wenn du ein neues Projekt evaluieren willst.
```

## OPTION COMBINATIONS

- `/stackcompass` → PHASE 0
- `/stackcompass quick` → skip PHASE 0, start PHASE 1 immediately: "Okay, lass uns schnell machen. Was ist deine Idee?"
- `/stackcompass save` → only valid after PHASE 3. If called before: "Keine Analyse vorhanden. Starte mit `/stackcompass`."
