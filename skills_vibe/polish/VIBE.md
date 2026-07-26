# /polish — Räum AI-Rückstände auf

## Was ist das?

AI-generierter Code sieht gut aus — bis ein Profi draufschaut. Polish findet die typischen KI-Hinterlassenschaften: Debug-Logs, `any`-Typen, fehlende Fallbacks, hardcodierte Werte, tote Imports und halluzinierte Pakete.

## Wie benutze ich es?

- `/polish` — ich führ dich durch
- `/polish quick` — alle 6 Checks auf einmal
- `/polish consolelog` — nur console.log-Check
- `/polish anytype` — nur any-Check
- `/polish magic` — nur hardcodierte Werte

## Was wird geprüft?

1. **console.log** — Debug-Rückstände die in Production gehören
2. **any-Types** — TypeScript ausgeschaltet? "Compiliert ja" ist nicht genug
3. **Missing Fallbacks** — `.map()` ohne `key=`, kein ErrorBoundary, kein Loading-State
4. **Magic Values** — URLs, Ports, lange Strings direkt im Code
5. **Dead Imports** — Importiert aber nie benutzt (Klassiker bei KI-Code)
6. **AI Smells** — Halluzinierte Pakete, unnötige Abstraktionen, zu lange Dateien

## Was passiert mit meinem Code?

- Ohne Fix: nichts — ich lese nur
- Mit Fix: ich zeige dir jede Änderung vorher und frage nach

## Warum sollte ich das nutzen?

Weil KI-Code immer Spuren hinterlässt. Jeder Fund ist etwas, das ein Senior in deinem Code-Review ankreiden würde. Polish zeigt es dir bevor es wer anders sieht.
