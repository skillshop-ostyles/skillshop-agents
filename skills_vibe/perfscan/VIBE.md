# /perfscan — Mach deine App schnell

## Was ist das?

Perfscan findet die 7 häufigsten Performance-Fehler in React/Next.js Projekten. Kein Profiler, kein Lighthouse — ein Befehl, 1 Minute, priorisiert nach Impact.

## Wie benutze ich es?

- `/perfscan` — ich zeig dir die HIGH Impact Funde zuerst
- `/perfscan high` — nur HIGH Impact (keyprops + effect + layoutshift)
- `/perfscan quick` — alle 7 Checks
- `/perfscan keyprops` — nur missing key-Check

## Was wird geprüft?

**HIGH Impact (sofort fixen):**
1. **key= fehlt** — `.map()` ohne key → React rendert alles neu
2. **useEffect ohne Dependencies** — läuft bei jedem Render → Loop Risiko
3. **Layout Shift** — `<img>`/`<Image>` ohne width/height → Seite springt

**MEDIUM Impact (prüfen):**
4. **Unoptimierte Bilder** — `<img>` statt `<Image>`, große Dateien
5. **Unnötige Client Components** — `'use client'` ohne Grund
6. **Bundle Size** — Zu große Dateien, zu viele Imports

**LOW Impact (nice to have):**
7. **Render Optimization** — Inline Funktionen, `style={{}}`, missing memo

## Was passiert mit meinem Code?

- Ohne Fix: nichts — ich lese nur
- Mit Fix: ich zeig dir jede Änderung vorher und frag nach

## Warum sollte ich das nutzen?

Weil 80% der Performance-Probleme in Vibe-Coder-Projekten dieselben 3 Ursachen haben. Perfscan findet sie in 1 Minute.
