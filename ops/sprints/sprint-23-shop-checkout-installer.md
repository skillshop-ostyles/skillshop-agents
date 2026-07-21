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

## Entscheidungen während der Umsetzung

1. **Hash-Rollback-Testbarkeit**: Die Verifikations-/Rollback-Logik wurde als
   eigene Funktion `verifyInstalledCopy(destDir, expectedHash, skillName)`
   extrahiert statt in `install()` verschachtelt zu bleiben. Ein echter
   Kopierfehler (Disk voll, Lock) ist im Test nicht deterministisch
   provozierbar; die extrahierte Funktion macht den Rollback-Pfad trotzdem
   direkt und deterministisch testbar (manuell korrumpierter Zielordner +
   falscher erwarteter Hash → Rollback + Fehler). Das ist reine Dekomposition,
   keine Testhaken in der Produktions-API.
2. **Bundle-CTA minimal vorgezogen**: `bundle.html` stammt aus Sprint 22 mit
   Platzhaltertext "Warenkorb folgt in Sprint 23". Nach diesem Sprint existiert
   der Warenkorb — den alten, jetzt falschen Hinweis stehen zu lassen wäre
   irreführend gewesen. Der Button legt jetzt die *verfügbaren* Skills des
   Bundles in den Korb (Wiederverwendung von `Shop.cart.add`, keine neue API).
   Die volle Bundle-Kauf-Erfahrung (Dialog "X in den Korb, Y auf die
   Merkliste", Merkliste-Integration für nicht verfügbare Skills) bleibt
   bewusst Sprint 24 vorbehalten (SHOP-BIBEL/Sprint-24-Scope).
3. **Reinstall-Bestätigung nutzt `window.confirm()`**: Browser-Automatisierung
   darf laut Sicherheitsregeln keine nativen Dialoge auslösen (sie blockieren
   die Session). Der Re-Install-Button in `bibliothek.html` wurde daher in der
   Live-Browser-Akzeptanz NICHT angeklickt; der Re-Install-Fluss wurde
   stattdessen über einen direkten API-Aufruf ausgelöst und danach live in der
   Bibliothek verifiziert (Badge verschwindet). Zusätzlich deckt
   `test/checkout.test.js` denselben Endpunkt automatisiert ab.
4. **Keine Deinstallation**: bewusst nicht implementiert (Sprint-Scope). Im
   Bibliothek-UI explizit erklärt: "Der Shop installiert nur additiv. Einen
   Skill wieder zu entfernen, machst du direkt im Zielprojekt ... — der Shop
   räumt dort nichts automatisch weg."

## 8. Testresultate

- **node:test**: 43/43 grün gesamt (12 Installer-Tests neu: Guard exakt +
  Unterordner + Tilde-Schreibweise + AGENTS-intern, NO_TARGET, erfolgreiche
  Installation mit Hash-Vergleich gegen Quelle, EXISTS ohne overwrite,
  Overwrite ersetzt vollständig, NO_SOURCE für geplante Skills,
  verifyInstalledCopy Rollback bei Hash-Mismatch, verifyInstalledCopy Erfolg;
  11 Checkout/Library/Watchlist-Tests neu: erfolgreiche Installation + Library-
  Eintrag, in-entwicklung-Skill server-seitig abgelehnt (nichts geschrieben),
  gemischte gültige/ungültige Items → kompletter Abbruch vor jedem Schreiben,
  `~/.claude`- und AGENTS-Guard über die echte API mit Dateisystem-Nachweis,
  Sequenz-Abbruch nach Fehler mit ehrlicher installed/failed/skipped-Antwort,
  Reinstall überschreibt + neue Order, Update-Badge-Logik, `present:false` nach
  manuellem Löschen, Merkliste add/list/remove, unbekannter Skill abgelehnt).
- **End-zu-End-Akzeptanz im Browser** (Claude-in-Chrome, live, keine
  Behauptung ohne Beobachtung): Produktseite `elevate` → "In den Warenkorb"
  → Korb-Badge zeigt 1 → Warenkorb-Seite zeigt Item → Kasse mit Ziel im
  Scratchpad-Ordner → Installiert-Ergebnis mit Trigger-Tipp → Bibliothek zeigt
  Ziel + Skill + Status "aktuell". Dateisystem-Nachweis: kompletter
  `elevate`-Ordner (SKILL.md + scripts/ + scripts/templates/) korrekt unter
  `<ziel>\.claude\skills\elevate\` gefunden.
- **Update-Zyklus live**: `elevate/SKILL.md` temporär um einen Marker-Kommentar
  ergänzt, Re-Import, Bibliothek zeigt "Update verfügbar" korrekt. Re-Install
  über direkten API-Call ausgelöst (siehe Entscheidung 3), Bibliothek zeigt
  danach wieder "aktuell" mit neuem Zeitstempel. Marker anschließend per
  `git checkout -- elevate/SKILL.md` vollständig zurückgesetzt, erneuter
  Import bestätigt sauberen Ausgangszustand (0 Warnungen).
- **Merkliste live**: Merken-Button auf einer in-entwicklung-Seite
  (`intent-archaeologie`) geklickt, `merkliste.html` zeigt den Skill korrekt
  mit "bald verfügbar"-Badge, Ansehen-/Entfernen-Buttons funktionsfähig.
- Keine Konsolenfehler über den gesamten Flow (mehrfach mit
  `read_console_messages` geprüft).
- **Negativ-/Guard-Tests über die echte laufende API** (nicht nur Unit):
  Checkout gegen `~/.claude` → 400 + `SCHUTZ`-Fehler, Verzeichnisinhalt von
  `~/.claude` vorher/nachher identisch (diff leer).

## 7. DoD-Checkliste

- [x] installer.js mit Guard, Verifikation, Rollback — isoliert getestet
- [x] Checkout-/Library-/Watchlist-API gemäß Contract, serverseitige Validierung
- [x] 3 neue Seiten + Korb-/Merken-Anbindung in Karten/Produktseite
- [x] Alle node:test-Pflichtfälle grün (43/43 gesamt)
- [x] End-zu-End-Akzeptanz inkl. Update-Zyklus dokumentiert
- [x] Alle Negativ-/Guard-Tests über die API bestanden (Dateisystem-Nachweis)
- [x] Keine-Deinstallation-Entscheidung im Bibliothek-UI dokumentiert
- [x] tracking.md aktualisiert, Commit `sprint-23: shop-checkout-installer implementiert`
