# /shipcheck — Bevor du shipped

## Was ist das?

Shipcheck ist dein persönlicher Ship-Coach. Ein Befehl, 30 Sekunden, 3 Checks:

1. **env** — fehlen wichtige Environment-Variablen?
2. **build** — baut das Projekt fehlerfrei?
3. **secrets** — hast du aus Versehen API-Keys committed?

## Wie benutze ich es?

- `/shipcheck` — ich führe dich durch den Wizard
- `/shipcheck quick` — alles auf einmal, kein Menü
- `/shipcheck env` — nur env-Check
- `/shipcheck build` — nur Build-Check
- `/shipcheck secrets` — nur Secrets-Check

## Was passiert mit meinem Code?

- Ohne Fix: nichts — ich lese nur Dateien
- Mit Fix: ich zeige dir vorher jede Änderung und frage nach

## Warum sollte ich das nutzen?

Weil die 3 häufigsten Fehler beim schnellen Shippen sind:
- Fehlende `.env` → App crasht in Production
- Build-Fehler → Seite ist weiß
- Secrets im Code → GitHub benachrichtigt dich unsanft

Shipcheck findet sie bevor sie weh tun.
