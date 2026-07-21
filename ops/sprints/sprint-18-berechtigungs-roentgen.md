# Sprint 18 — berechtigungs-roentgen (/authz)

Regeln: `ops/BIBEL.md` gilt vollständig. Kontext: defensives Security-Audit der
EIGENEN Codebase — Befunde dienen der Härtung, der Report bleibt lokal.
Wiederverwendung: Routen-Muster aus Sprint 09/17 darf kopiert/angepasst werden.

## 1. Problem

"Wer darf was?" kann in gewachsenen Systemen niemand beantworten. Authorization-Checks
liegen verstreut: Middleware hier, Decorator da, Inline-`if (user.role...)` dort —
und der eine ungeschützte Mutations-Endpoint fällt erst beim Pentest (oder danach)
auf. Eine vollständige Permission-Matrix aus dem Code zu destillieren heißt: jede
Route finden, jede Schutz-Schicht zuordnen, Lücken und Inkonsistenzen erkennen —
Fleiß plus Semantik, also LLM-Terrain.

## 2. Nutzen

Vorher: Berechtigungs-Wissen implizit, Audits teuer, Lücken unsichtbar. Nachher:
Permission-Matrix (Endpoint × erforderliche Rolle/Prüfung), Liste ungeschützter
Mutations-Endpoints, Inkonsistenz-Befunde (gleiche Ressource, unterschiedliche
Prüfschärfe). Profiteure: Security-Reviews, Compliance-Nachweise, jeder neue
Endpoint ("wie schützen die anderen?").

## 3. Scope / Nicht-Scope

**Scope:** HTTP-Endpoints + erkennbare Schutz-Mechanismen: Middleware-Ketten,
Decorators/Attribute (`@UseGuards`, `[Authorize]`, `@login_required`),
Inline-Checks (`role`, `permission`, `isAdmin`, `session`), Router-Mount-Schutz.
Matrix + Lücken-/Inkonsistenz-Report.
**Nicht-Scope:** Keine Authentifizierungs-Tiefe (Token-Validierungs-Korrektheit,
Krypto — nur ob geprüft WIRD, nicht wie gut). Kein aktives Testen (keine Requests).
Keine Frontend-Guards (nur Server-Seite zählt als Schutz).

## 4. Skill-Spezifikation

Ordner: `berechtigungs-roentgen/`

Frontmatter:

```yaml
---
name: berechtigungs-roentgen
description: "Authorization X-ray for your own codebase (defensive audit): inventories every HTTP endpoint and every recognizable protection layer (middleware chains, authorize decorators, inline role checks, router mounts), builds the permission matrix endpoint x required check, and reports unprotected mutating endpoints and inconsistent protection of similar resources. Static, sends no requests. Read-only. Trigger: /authz"
trigger: /authz
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir`. Bestätigen. Hinweis an den User: Report enthält
   sicherheitsrelevante Befunde — lokal halten.
3. `scripts/authz-scan.ps1` ausführen.
4. LLM-Analyse gemäß § 6 (liest Middleware-/Guard-Definitionen und
   Registrierungs-Ketten vollständig).
5. Report `authz-report.md` ins Arbeitsverzeichnis; Kurzfassung: ungeschützte
   Mutations-Endpoints zuerst.

Usage:

```
/authz               # interaktiv
/authz <dir>         # Berechtigungs-Audit
/authz --help
```

## 5. Collector-Skripte

### scripts/authz-scan.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie Sprint 03).

Read-only. Drei Sammel-Ebenen:

1. **Endpoints**: Routen-Muster (Sprint 09/17) → Methode, Pfad, Datei:Zeile,
   Handler-Name; Flag `mutating` (POST/PUT/PATCH/DELETE).
2. **Schutz-Indikatoren an der Route** (gleiche Zeile + 3 Zeilen davor, Decorator-
   Konvention):
   - Decorator/Attribut: `@UseGuards|@Roles|@Authorize|\[Authorize|@login_required|
     @permission_required|@PreAuthorize|@Secured`.
   - Middleware-Argumente in der Routen-Registrierung: zweites+ Argument vor dem
     Handler (`router.post('/x', requireAuth, handler)`) — Argument-Namen erfassen.
   - `AllowAnonymous|@Public|skipAuth` → Flag `explicitlyPublic`.
3. **Schutz-Definitionen global**: Dateien mit `middleware|guard|auth`-Bezug im
   Namen ODER `app.use(`/`router.use(`-Zeilen (mit Argumenten und Mount-Pfad) —
   je Datei:Zeile + Text; Inline-Check-Stellen: `role|permission|isAdmin|
   hasRole|can\(|ability|policy` in Handler-Dateien (Datei:Zeile + Text).

JSON-Schema (Beispiel):

```json
{
  "endpoints": [
    { "method": "DELETE", "path": "/users/:id", "file": "src/api/users.ts", "line": 40,
      "handler": "deleteUser", "mutating": true,
      "routeGuards": ["requireAuth"], "decorators": [], "explicitlyPublic": false }
  ],
  "globalUse": [ { "file": "src/app.ts", "line": 15, "mountPath": "/api", "args": ["authMiddleware"] } ],
  "inlineChecks": [ { "file": "src/api/users.ts", "line": 44, "text": "if (!user.isAdmin) return res.status(403)" } ],
  "counts": { "endpoints": 34, "mutating": 18 }
}
```

Fehlerverhalten: Pfad fehlt → exit 1; 0 Endpoints → Meldung, exit 0 (SKILL.md:
sauber beenden — Skill braucht eine Server-API).

## 6. LLM-Analyse-Steps

1. **Schutz-Kette pro Endpoint auflösen**: globale Mounts (trifft der Mount-Pfad
   den Endpoint-Pfad?) + Routen-Guards + Decorators + Inline-Checks im Handler
   (Handler-Datei lesen!). Ergebnis je Endpoint: effektive Prüfungen mit Belegen.
   Guard-Implementierungen lesen und grob einordnen: prüft Authentifizierung
   (eingeloggt?) vs. Autorisierung (Rolle/Recht?).
2. **Matrix** bauen: Endpoint × (authn: ja/nein/unklar) × (authz: welche Rolle/
   Prüfung) × Evidenz.
3. **Befund-Klassen**:
   - **Ungeschützt + mutierend** (Severity hoch; `explicitlyPublic` gesondert —
     gewollt öffentlich ist kein Befund, aber listen zur Bestätigung).
   - **Nur authn, keine authz bei sensiblen Pfaden** (`/admin`, `/users/:id`-Muster:
     fremde-ID-Zugriff ohne Ownership-Check — IDOR-Verdacht, `vermutet`-Ebene,
     ehrlich kennzeichnen).
   - **Inkonsistenz**: gleichartige Ressourcen-Pfade mit unterschiedlicher
     Prüfschärfe (GET /orders geschützt, GET /orders/:id nicht o. ä.).
   - **Tote Rollen**: in Checks referenzierte Rollen, die nirgendwo vergeben/
     definiert erkennbar sind (Grep über Rollen-Literale).
4. Report: Kurzfassung (Endpoints, geschützt-Quote, hoch-Funde) → hoch-Befunde mit
   Evidenz → Matrix (Tabelle) → Inkonsistenzen → IDOR-Verdachte (klar als
   `vermutet`) → explizit Öffentliche (zur Bestätigung) → Offene Fragen.
5. Evidenz-Pflicht: "ungeschützt" NUR nach dokumentierter Prüfung aller 4 Ebenen
   (Mount, Guard, Decorator, Inline) — die Fehlanzeige jeder Ebene gehört in den
   Beleg. Falsche Ungeschützt-Meldungen zerstören das Vertrauen in den Skill.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Framework mit Default-Schutz (alles hinter Login-Gate) | Globale Mounts/Konfiguration aktiv suchen; wenn gefunden: Basis-Schutz in Matrix vermerken |
| Auth im Reverse-Proxy/Gateway (nicht im Code) | Nicht erkennbar → Report-Vorbehalt prominent: "Analyse sieht nur den Code" |
| Dynamische Routen-Registrierung | Abdeckungslücke ausweisen (wie Sprint 17) |
| WebSocket-/GraphQL-Endpoints | GraphQL: Resolver als Endpoints zweiter Klasse mitnehmen (best effort); WS nur inventarisieren |
| Mehrere Apps im Repo | Pro App gruppieren (Mount-/Datei-Struktur) |
| Rollen aus DB statt Code | Tote-Rollen-Analyse dann nicht möglich — ausweisen statt raten |

## 8. Testplan

Smoke: Fixture `berechtigungs-roentgen/tests/fixture/` mit Mini-Express-Stil-App
(3 Dateien): app.ts mit globalem Mount `app.use('/api', authMiddleware)` — aber
eine Route ist AUSSERHALB von /api registriert und mutierend (die eingebaute
Lücke); eine /api-Route mit zusätzlichem Rollen-Guard; eine explizit öffentliche
GET-Route. Dann:

```powershell
& .\berechtigungs-roentgen\scripts\authz-scan.ps1 -ProjectDir ".\berechtigungs-roentgen\tests\fixture"
```

Erwartung: exit 0, JSON valide, alle 3 Routen + Mount + Guards erfasst.
LLM-Durchlauf: die Außerhalb-Route als ungeschützt+mutierend gemeldet, die
/api-Route korrekt als geschützt (Mount-Auflösung!), die öffentliche GET-Route
NICHT als hoch-Befund (harte Kriterien: die Mount-Logik muss stimmen, 0 FP).

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: Matrix vollständig gegen die
Routen-Liste des Projekts; 3 Schutz-Urteile stichprobenartig durch Lesen der
Registrierungs-Kette verifiziert; jeder Ungeschützt-Befund mit 4-Ebenen-Beleg.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (defensiver Zweck + Lokal-Hinweis)
- [ ] authz-scan.ps1 (Endpoints, Routen-Guards, Decorators, globale Mounts, Inline-Checks)
- [ ] Fixture mit Mount-Lücke angelegt
- [ ] Smoke bestanden; Mount-Auflösung korrekt, 0 False Positives
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben, 4-Ebenen-Belege)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4 (Fehlanzeige-Belege bei Ungeschützt-Urteilen)
- [ ] tracking.md aktualisiert, Commit `sprint-18: berechtigungs-roentgen implementiert`
