# Sprint 23 — shop-checkout-installer

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Baut auf 21/22.
Sicherheitskritischster Shop-Sprint: hier wird geschrieben (Installation).

## 1. Ziel

Der Kauf: Warenkorb, Kasse, Installer, Bibliothek. "Kauf" = Installation der
gewählten Skills in ein Zielprojekt (`<ziel>/.claude/skills/<name>/`), als Order
in der DB verbucht. Dazu Merkliste (aktiv) und Update-Erkennung im Bestand.

## 2. Nutzen

Der Shop wird vom Schaufenster zum Geschäft: easy-to-have — vom Begehren zum
installierten, sofort nutzbaren Skill in unter einer Minute.

## 3. Scope / Nicht-Scope

**Scope:** Warenkorb (localStorage), Checkout-API + -Seite, Installer-Modul mit
Schutz-Guard, install_targets/orders/order_items, Bibliothek-Seite + API inkl.
Update-Badge + Re-Install, Merkliste (API + UI-Anbindung der Buttons aus S22).
**Nicht-Scope:** Keine Zahlung (amount bleibt 0, license bleibt NULL), keine
Deinstallation (bewusst: Löschen im Zielprojekt macht der User selbst — der Shop
schreibt nur additiv; im Bibliothek-UI dokumentieren).

## 4. Komponenten-Spezifikation

```
shop/src/
  installer.js            # Kernmodul (unten)
  api/checkout.js         # POST /api/checkout
  api/library.js          # GET /api/library, POST /api/library/reinstall
  api/watchlist.js        # GET/POST/DELETE /api/watchlist
shop/public/
  warenkorb.html          # Korb + Kasse (Ziel-Wahl, Validierungs-Feedback, Erfolg)
  bibliothek.html         # Bestand je Ziel, Update-Badges, Re-Install
  merkliste.html          # Merkliste
```

### installer.js (Kern, einzeln testbar)

`install(skillName, targetPath, { overwrite })`:

1. **Guard** (SHOP-BIBEL § 2.3, Portierung von BIBEL § 2.2): targetPath
   normalisieren (path.resolve, `~`-Expansion); liegt er in oder unter
   `%USERPROFILE%\.claude` → Fehler `SCHUTZ`, nichts geschrieben. Zusätzlich:
   targetPath darf nicht innerhalb des AGENTS-Repos liegen (der Shop verkauft
   nach außen, nicht in sich selbst) — Fehler mit Klartext.
2. Zielprojekt muss existieren (Verzeichnis); sonst Fehler (der Shop legt keine
   Projekte an). Skill muss `verfuegbar` sein; sonst Fehler.
3. Existiert `<ziel>/.claude/skills/<name>/` bereits und `overwrite` fehlt →
   Fehler `EXISTS` (UI fragt dann nach Re-Install-Bestätigung).
4. Kopieren: kompletter Skill-Ordner rekursiv (fs.cp), danach Verifikation:
   Datei-Anzahl + Ordner-Hash des Ziels == Quelle; bei Abweichung: Zielordner
   wieder entfernen (Rollback nur des selbst geschriebenen Ordners!) + Fehler.
5. Rückgabe: `{ name, targetPath, folderHash, files }`.

### Checkout (POST /api/checkout)

`{ targetPath, label?, items: [names] }` → Validierung ALLER Items vor der ersten
Schreiboperation (alles-oder-nichts auf Validierungsebene; die Installationen
selbst laufen sequenziell, ein Fehler mitten drin bricht ab, bereits installierte
bleiben — Antwort listet installed/failed/skipped ehrlich auf). install_target
upserten, Order + order_items (mit folder_hash_at_install) schreiben. Antwort
enthält "Was jetzt?"-Daten (Trigger je Skill).

### Bibliothek (GET /api/library)

Je install_target: Skills aus orders aggregiert (letzter Stand pro Skill+Ziel),
Live-Check: existiert der Ordner im Ziel noch? (`present: false` wenn manuell
gelöscht — kein Fehler, Badge "entfernt"). Update-Badge: aktueller folder_hash
des Quell-Skills != hash_at_install → "Update verfügbar". Re-Install =
`install(..., { overwrite: true })` + neue Order-Zeile.

### UI

- **Karten/Produktseite**: Install-Button legt in den Korb (localStorage,
  Badge im Header zählt); Merken-Button aktiv (POST watchlist).
- **Kasse**: Items prüfen, Ziel wählen (Pfad-Feld + Datalist der bekannten
  targets), Client-Vorvalidierung (leer? relative Pfade ablehnen), Server-Fehler
  je Item verständlich anzeigen. Erfolgs-Zustand: pro Skill Trigger-Zeile
  ("Tipp /intent in Claude Code im Zielprojekt").
- **Bibliothek**: Ziele als Abschnitte, Skills als Zeilen (Status, installiert am,
  Update-/entfernt-Badge, Re-Install-Button mit Bestätigung).

## 5. Edge-Cases

| Fall | Verhalten |
|---|---|
| targetPath = `~/.claude` oder Unterordner | Guard-Fehler, nichts geschrieben (Pflicht-Test) |
| targetPath innerhalb AGENTS | Fehler mit Klartext (Pflicht-Test) |
| targetPath auf Datei statt Verzeichnis | Fehler |
| in-entwicklung-Skill im Korb (manipulierte Request) | Server lehnt Item ab (Validierung serverseitig, nie nur UI) |
| Kopierfehler mitten im Ordner (Disk voll, Lock) | Rollback des Zielordners, Fehler; vorher installierte Items der Order bleiben + ehrliche Antwort |
| Skill im Ziel manuell verändert, dann Re-Install | overwrite ersetzt komplett; Hinweis in Bestätigung ("lokale Änderungen gehen verloren") |
| Netzwerkpfad/UNC als Ziel | Zulassen, aber Fehler sauber durchreichen (fs entscheidet) |
| localStorage voll/defekt | Korb-Fallback: leerer Korb + Hinweis, kein Crash |

## 6. Testplan

Smoke (Wegwerf-Ziel im Scratchpad):

```powershell
mkdir "$env:TEMP\shop-testziel" -Force
cd shop; npm run import; npm start   # zweite Shell:
curl -Method POST http://127.0.0.1:4711/api/checkout -Body (@{ targetPath = "$env:TEMP\shop-testziel"; items = @('elevate') } | ConvertTo-Json) -ContentType 'application/json'
curl http://127.0.0.1:4711/api/library | ConvertFrom-Json
node --test
```

Erwartung: elevate liegt vollständig unter `shop-testziel\.claude\skills\elevate\`
(Datei-Vergleich mit Quelle), Order in DB, Library zeigt den Bestand.

node:test-Pflichtfälle (installer.js isoliert + Checkout-API):
Guard `~/.claude` (exakt + Unterordner + `~`-Schreibweise), Ziel-in-AGENTS,
nicht existentes Ziel, in-entwicklung-Ablehnung, EXISTS-ohne-overwrite,
Re-Install-mit-overwrite, Hash-Verifikation (Fixture mit manipulierter Kopie →
Rollback), Update-Badge-Logik (Quell-Hash ändern → Badge).

Akzeptanz End-zu-End im Browser: Produktseite → Korb → Kasse → Erfolg →
Bibliothek zeigt Ziel; danach Quell-Skill minimal ändern (Testdatei), Re-Import,
Bibliothek zeigt Update-Badge, Re-Install, Badge weg. Ablauf dokumentieren.

Negativ: alle Guard-Fälle über die echte API (nicht nur Unit) — Antwort 400 +
Klartext, Dateisystem unverändert (vorher/nachher-Listing).

## 7. DoD-Checkliste

- [ ] installer.js mit Guard, Verifikation, Rollback — isoliert getestet
- [ ] Checkout-/Library-/Watchlist-API gemäß Contract, serverseitige Validierung
- [ ] 3 neue Seiten + Korb-/Merken-Anbindung in Karten/Produktseite
- [ ] Alle node:test-Pflichtfälle grün
- [ ] End-zu-End-Akzeptanz inkl. Update-Zyklus dokumentiert
- [ ] Alle Negativ-/Guard-Tests über die API bestanden (Dateisystem-Nachweis)
- [ ] Keine-Deinstallation-Entscheidung im Bibliothek-UI dokumentiert
- [ ] tracking.md aktualisiert, Commit `sprint-23: shop-checkout-installer implementiert`
