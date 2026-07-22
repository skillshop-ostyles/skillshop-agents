# Sprint 28 — shop-differenzierung

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Ausgangspunkt: Blick
auf die zwei Konkurrenten PromptBase und SkillsLLM (Konkurrenzanalyse, 2026-07-21).
Ehrliches Ergebnis: als Marktplatz nach Volumen sind wir nicht wettbewerbsfähig
(22 Skills, davon 2 gebaut, gegen tausende Einträge dort) und werden es auch nach
Fertigstellung aller 22 nicht sein — das Skill-Bauprogramm (M1) bleibt bewusst
außerhalb dieses Scopes. Dieser Sprint macht stattdessen die echten, belegbaren
Unterschiede sichtbar, die im UI bisher kleingehalten wurden.

## 1. Ziel

Drei echte Differenzierungsmerkmale sichtbar machen, ohne die Lücke (2/22 Skills)
zu verstecken: Berater (keiner der Konkurrenten hat eine geführte Empfehlung),
belegbare Sicherheit (Pfad-Guards, Backup-vor-Overwrite, Host-Header-Check, Tests)
und das Ehrlichkeits-Prinzip (Status aus `tracking.md`, keine Fake-Reviews). Kein
Payment, kein Astro, keine neuen Runtime-Dependencies, keine Änderung an
Installer/Checkout/Security-Code — reine Frontend-Differenzierung auf Basis der
bestehenden, gehärteten API.

## 2. Umsetzung (P0/P1, nach Priorität)

- **P0 Berater-Prominenz**: `index.html`-Hero zweigleisig (`.hero-paths`) —
  Suche und Berater als gleichwertige Einstiege statt Suchfeld + Kleingedrucktem.
  `berater.html` bekommt Zurück-Navigation (`renderQuestion()` zeigt einen
  „Zurück"-Button außer bei q1, vorherige Antwort wird aus `answers[qKey]`
  vorbelegt) statt nur Komplett-Neustart.
- **P0 Transparenz-Seite**: neu `public/transparenz.html`, verlinkt aus dem
  (jetzt zentralisierten) Footer aller Seiten, nicht aus der Haupt-Nav (hält
  „max. 2 Klicks" aus SHOP-BIBEL § 7 intakt). Abschnitt „Sicherheit" beschreibt
  die echten Guards **qualitativ, ohne hart-codierte Testanzahl** (eine feste
  Zahl würde nach dem nächsten Sprint veralten). Abschnitt „Fortschritt" holt
  `/api/skills` und zeigt die echte Zahl + beide Gruppen als Karten — reine
  Wiederverwendung des bestehenden Endpunkts.
- **P1 Katalog-Sortierung**: `<select id="sort-select">` in `katalog.html`,
  rein clientseitige Sortierung der bereits geladenen Liste über neue pure
  Funktion `sortSkills(skills, mode)` in `shop-core.js` (Relevanz/Name/Status).
  Kein API-Query-Param, kein Backend-Touch.
- **P1 Onboarding-Block**: kurzer „So funktioniert's"-Dreischritt auf der
  Landing zwischen Hero und Regalen, rein statisch.
- **P2 Berater Bundle-vs-Einzeln-Vergleich**: nicht umgesetzt — P0/P1 haben den
  Rahmen gefüllt, kein zwingender Bedarf identifiziert. Begründet zurückgestellt.

## 3. Entscheidungen während der Umsetzung

1. **Footer zentralisiert (nicht ursprünglich geplant, aber naheliegend)**:
   Beim Ergänzen des Transparenz-Links im Footer wäre sonst dieselbe
   8x-Kopierfalle wie bei der Nav vor Sprint 26 (C1) erneut aufgetreten. Statt
   den Link einzeln in 9 Dateien zu duplizieren: `renderFooter()` in `app.js`
   nach demselben Muster wie `renderHeader()` (Placeholder `<footer
   id="site-footer"></footer>`), auf allen Seiten inkl. `404.html` und der
   neuen `transparenz.html` eingesetzt. Eine Quelle statt neun.
2. **Keine Test-Count-Zahl auf der Transparenz-Seite**: bewusst weggelassen,
   um nicht selbst in die Falle veralteter Zahlen zu laufen, die wir den
   Konkurrenten (PromptBase: „500.000+ Nutzer", SkillsLLM: unbelegtes
   „Security-vetted") vorwerfen. Qualitative Beschreibung statt harter Zahl.
3. **Sortierung rein clientseitig**: bei max. 22 Skills ist ein API-Roundtrip
   für Sortierung unnötige Komplexität; `sortSkills()` sortiert die bereits
   geladene Liste, ausgelagert als pure, getestete Funktion in `shop-core.js`
   (gleiches UMD-Muster wie die bestehenden Core-Funktionen).
4. **Cache-Artefakt bei der Verifikation entdeckt und aufgeklärt**: das in
   Sprint 27 eingeführte `Cache-Control: public, max-age=600` auf statischen
   Assets sorgte während der Browser-Prüfung dafür, dass eine alte `app.css`
   ohne die neuen `.hero-paths`-Regeln ausgeliefert wurde (Hero erschien
   gestapelt statt nebeneinander). Kein Shop-Bug — reines Test-Artefakt durch
   harten Neustart des Servers bei laufendem Browser-Cache. Aufgeklärt via
   `fetch(url, {cache:'no-store'})`-Vergleich gegen `curl`, danach Hard-Reload
   (`Strg+Umschalt+R`) zur Verifikation. Für künftige Sessions: nach jedem
   Server-Neustart im selben Browser-Tab hart neuladen, nicht nur navigieren.

## 4. Verifikation

- `npm run lint` → 0 Fehler.
- `npm test` → 92/92 grün (4 neue `sortSkills()`-Tests: Relevanz-No-Op,
  Name-Sortierung, Status-Sortierung mit Name-Tiebreak, Immutabilität der
  Eingabe).
- Browser (Claude-in-Chrome, nach Hard-Reload zur Cache-Umgehung):
  - Landing: Dual-CTA-Hero rendert nebeneinander (Grid, nicht gestapelt),
    Onboarding-Dreischritt sichtbar, Footer mit Transparenz-Link, keine
    Konsolenfehler.
  - Katalog: Sortier-Dropdown ändert die Kartenreihenfolge sichtbar
    (Name A-Z und Status live geprüft, korrekte Ergebnisse).
  - Berater: Zurück-Button erscheint ab Schritt 2, Klick auf Zurück stellt die
    vorherige Antwort korrekt vorbelegt wieder her (`entwickeln` nach Rücksprung
    von q3 zu q2 bestätigt), voller Flow bis zum Ergebnis inkl. verlinkter
    Bundle-Karte funktioniert weiterhin.
  - Transparenz: lädt „2 von 22" live aus `/api/skills`, 22 Karten (beide
    Gruppen) korrekt als Links gerendert, Hell- und Dunkelmodus beide geprüft,
    keine Konsolenfehler.
  - 404-Seite: Footer inkl. Transparenz-Link korrekt zentral gerendert.
- `git status` clean nach Commit, kein Remote.

## DoD

- [x] Alle Änderungen auf das Sprint-Ziel zurückführbar, kein Backend-/
      Security-Code angefasst
- [x] Neue pure Funktion getestet (`sortSkills`)
- [x] Footer-Zentralisierung vermeidet erneute 8x-Kopierfalle
- [x] Browser-Verifikation aller neuen/geänderten Seiten, Hell+Dunkel
- [x] `ops/tracking.md` aktualisiert
- [ ] P2 (Berater Bundle-vs-Einzeln-Vergleich) — bewusst nicht umgesetzt, siehe § 2
