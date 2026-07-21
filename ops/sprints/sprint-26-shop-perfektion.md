# Sprint 26 — shop-perfektion (Weg zu 100/100)

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Härtungs-Nachsprint
nach zwei unabhängigen Reviews des Shops (Sprints 21-25). Spec = die vereinigte
Fundliste beider Reviews. Jeder Fix bekommt einen Test, der ihn beweist.

## 1. Ziel

Alle Code-, Sicherheits-, Datenhygiene- und Test-Befunde restlos schließen. Der
schwerste Fund (case-insensitiver `~/.claude`-Guard-Bypass auf Windows) ist live
bewiesen. Nach diesem Sprint ist der Shop als Phase-1-Werkzeug defektfrei und deckt
jede Behauptung mit Tests. Die 20 fehlenden Skills bleiben bewusst außen vor.

## 2. Fund-Blöcke (Umsetzungsreihenfolge, Sicherheit zuerst)

- **A** Sicherheit: A1 Guard-Case-Bypass (JS), A2 gleiche Klasse in PS-Skripten,
  A3 Reinstall-Datenverlust (Backup-vor-Overwrite), A4 Host-Header-Check.
- **B** Datenhygiene: B1 Phantom-Orders, B2 verwaiste Install-Targets entfernbar,
  B3 stats.js-Footgun.
- **C** Wartbarkeit: C1 Nav-Header aus einer Quelle, C2 N+1-Preisabfragen,
  C3 Facetten-id-Escaping, C4 Advisor-Scoring dokumentieren.
- **D** Tests & Self-Elevate: D1 status-Param-Test, D2 Frontend-Unit-Tests,
  D3 Repo auf eigenen elevate-Standard, D4 Light-Mode-Toggle, D5 Radio-Klick klären.
- **E** Kosmetik: E1 echte Umlaute in der UI.

## 3. Entscheidungen und Funde während der Umsetzung

1. **A1 war real ausnutzbar** — vor dem Fix live bewiesen: `C:\USERS\OSTOL\.claude`,
   `.CLAUDE`, `c:\users\...` passierten den Guard. Fix: `isInsideOrEqual` mit
   case-insensitivem Vergleich auf win32 (`forCompare` lowercased nur auf Windows,
   POSIX bleibt case-sensitiv). Nach dem Fix: alle vier Varianten blockiert (verifiziert).
2. **A2** — in PowerShell ist `-eq` bereits case-insensitiv; der Leak steckte nur in
   `.StartsWith()` (.NET, case-sensitiv). Fix mit `[StringComparison]::OrdinalIgnoreCase`
   in `audit.ps1`, `apply.ps1`, `init.ps1`. Manueller Nachweis: alle Groß/Klein-Varianten
   blockiert.
3. **A3** — Reinstall löschte den Zielordner VOR der Kopie. Fix: Backup-vor-Overwrite
   (rename statt Sofort-Löschen, Restore bei Kopier-/Verifikationsfehler). Test mit
   `t.mock.method(fs,'cpSync')` erzwingt den Fehlerpfad und prüft, dass die alte Version
   (inkl. User-Edit) überlebt.
4. **B1** — Order wird jetzt erst nach ≥1 erfolgreicher Installation geschrieben, in
   einer `db.transaction`. Test beweist: komplett fehlgeschlagener Checkout → 0 Orders.
5. **Rot-Probe-Vorfall (aus Sprint 25) hier NICHT wiederholt** — die Guard-Tests wurden
   diesmal durch Fixture-Fälle abgesichert, nicht durch Deaktivieren des echten Guards.
6. **D5 ehrlich geklärt (kein Workaround)** — der Sprint-24-Radio-Fehlschlag war ein
   Automations-Artefakt: das `<label>` umschließt den `<input>`, ein echter Klick auf die
   Label-Mitte aktiviert das Radio nativ (live verifiziert mit MouseEvents auf die
   Label-Koordinaten, kein `.checked=true`). Das Label ist bereits ein großes Klickziel
   (12px-Padding, volle Breite). Kein Markup-Bug, keine Änderung nötig — dokumentiert
   statt zugedeckt.
7. **E1 — echter Identifier-Korruptions-Fund während der Arbeit**: ein erster,
   wort-basierter Umlaut-Lauf über die Katalog-Copy verwandelte den Skill-Namen
   `test-luecken-kartograf` im Fließtext in `test-lücken-kartograf` (das Map-Wort
   `luecken` traf das Bindestrich-Fragment, weil `\b` Bindestriche als Grenze wertet).
   Sofort per `git checkout` zurückgesetzt. Korrekte Lösung: Skill-Namen-Fragmente
   (`archaeologie`, `luegendetektor`, `waechter`, `roentgen`, lowercase `luecken`) bewusst
   aus der Map ausgeschlossen; normale Wortgrenzen konvertieren dann legitime deutsche
   Komposita (`Anfänger-Sicht`), lassen aber die Identifier unversehrt. Verifiziert:
   0 korrupte Identifier, 0 verbleibende Anzeige-Transliterationen. Der Fund bestätigt
   genau das Review-Prinzip — automatisierte Massenänderungen brauchen einen
   Identifier-Schutz.

## 4. Testresultate

- **npm test**: 88/88 grün (von 68 auf 88; neu: A1-Case-Tabelle, A3-Backup-Restore x2,
  A4-Host-Header x4, B1-Phantom-Order, B2-Target-Löschung x2, B3-stats-Footgun,
  D1-status-Param, D2-Frontend-Unit x7).
- **npm run lint**: 0 Fehler, 0 Warnungen (ESLint fand echte Funde — ungenutzte Imports
  in `advisor.js` und `api-skills.test.js`, ein fehlendes Global — alle gefixt).
- **node bin/bench.js**: Median `/api/skills` 4.06 ms, `/api/facets` 2.94 ms (< 100 ms).
- **Browser (Claude-in-Chrome, live)**:
  - C1: Header auf allen geprüften Seiten aus EINER Quelle gerendert (`#site-header` per JS).
  - D4 Light Mode DEFINITIV verifiziert: Theme-Toggle System→Hell→Dunkel→System, bei
    "Hell" weißer Hintergrund (rgb(255,255,255)) live gemessen — die 3-Sprint-Lücke ist
    geschlossen.
  - D5: kompletter Berater-Durchlauf mit echten Label-Klicks bis zum Ergebnis.
  - E1: Umlaute korrekt gerendert (Hero-Subline „Fachgeschäft für…", Facetten-Label
    „Tätigkeit", Produkt-Copy „lauffähiges", „FÜHRT", „außerhalb", „präzise").
  - Keine Konsolenfehler.
  - End-zu-Ende-Kauf gegen den echten `elevate`-Ordner: 200, installiert, Bibliothek
    zeigt `present:true`, SKILL.md auf Platte nachgewiesen.

## 5. Abnahme-Protokoll (Update gegen SHOP-BIBEL §1-8 + Sicherheit)

Ergänzend zum Sprint-25-Protokoll, das weiterhin gilt:

| Punkt | Status | Beleg |
|---|---|---|
| §2.3 Installer-Schutzregel — CASE-KORREKT | ✅ jetzt lückenlos | A1/A2 gefixt + getestet; vorher auf Windows umgehbar |
| §2.4 Localhost-only — mit Host-Header-Guard | ✅ verstärkt | A4: mutierende Endpunkte 403 bei fremdem Host; GET frei |
| Reinstall-Datensicherheit | ✅ neu | A3 Backup-vor-Overwrite + Restore-Test |
| Order-Datenhygiene | ✅ neu | B1 keine Phantom-Orders (Transaktion) |
| Bibliothek-UX vollständig | ✅ neu | B2 verwaiste Targets entfernbar |
| CLI-Robustheit | ✅ neu | B3 stats.js/bench.js gegen fehlende DB abgesichert |
| Wartbarkeit (DRY) | ✅ | C1 Nav aus einer Quelle; C2 N+1 beseitigt |
| Repo-Self-Elevate | ✅ neu | .gitattributes (CRLF-Warnungen weg), .editorconfig, ESLint (0 Funde), Root-README |
| Frontend-Testabdeckung | ✅ neu | shop-core.js + 7 node:test-Fälle |
| Light Mode verifiziert | ✅ | D4 live (weißer BG bei Hell) |
| UI-/Copy-Konsistenz | ✅ | E1 durchgängige Umlaute, Identifier geschützt |

**Ergebnis: alle Review-Funde beider Reviews geschlossen; keine offenen Abweichungen.**

## 6. DoD-Checkliste

- [x] A1-A4 Sicherheit gefixt + je Test/Nachweis
- [x] B1-B3 Datenhygiene gefixt + Tests
- [x] C1-C4 Wartbarkeit
- [x] D1-D5 Tests, Self-Elevate, Light-Mode, Radio-Klärung
- [x] E1 Umlaute (mit Identifier-Schutz)
- [x] npm run lint 0 Fehler, npm test 88/88 grün, bench < 100ms
- [x] Browser-Nachweis (Theme, Nav, Umlaute, E2E-Kauf) dokumentiert
- [x] tracking.md aktuell, Commit `sprint-26: shop-perfektion implementiert`
