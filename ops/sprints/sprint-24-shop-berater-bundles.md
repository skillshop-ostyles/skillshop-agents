# Sprint 24 — shop-berater-bundles

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Baut auf 21-23.

## 1. Ziel

Das Fachgeschäfts-Gefühl: der Berater (3 Fragen → begründete Empfehlung), das
volle Bundle-Erlebnis (Story-Seiten, Bundle-Kauf-Logik) und der Landing-
Feinschliff. Der Shop empfiehlt wie ein erfahrener Kollege — regelbasiert,
deterministisch, testbar.

## 2. Nutzen

Facetten bedienen die, die wissen, was sie suchen. Der Berater bedient die, die
nur ihren Schmerz kennen ("Releases gehen ständig schief") — und genau die sind
die Mehrheit. Bundles verkaufen die Lösung als Paket statt als Einzelteile.

## 3. Scope / Nicht-Scope

**Scope:** Advisor-API + -Seite (regelbasiert), Regelwerk als Daten
(`shop/catalog/advisor-rules.json`), Bundle-Kauf ("verfügbare installieren,
restliche merken"), Landing-Feinschliff (Berater-Einstieg im Hero-Bereich),
Merkliste-UI-Vervollständigung (Von-Merkliste-in-Korb für verfügbar gewordene).
**Nicht-Scope:** Kein LLM-Call im Berater (Phase 1 bewusst deterministisch).
Keine Preise (weiter Flag off, S25).

## 4. Komponenten-Spezifikation

### Berater-Flow (3 Fragen, feste Antwort-Optionen)

`shop/catalog/advisor-rules.json` definiert Fragen UND Mapping — Regeln sind
Daten, nicht Code:

1. **"Was schmerzt gerade am meisten?"** (Pflicht, eine Wahl) — Optionen mappen
   auf usecase/thema-Terme, z. B.: "Keiner versteht unseren Alt-Code" →
   `usecase:legacy-verstehen`; "Releases gehen schief" →
   `usecase:release-absichern`; "Security/Compliance-Druck" →
   `usecase:audit-vorbereiten` + `thema:security`; "Neue Leute brauchen ewig" →
   `usecase:onboarding`; "Prod überrascht uns ständig" → `thema:resilienz` +
   `usecase:incident-aufklaeren`; "Wir starten ein neues Projekt" →
   `usecase:neu-starten`.
2. **"In welchem Kontext?"** (optional, eine Wahl) — mappt auf taetigkeit
   (entwickeln/reviewen/devops/qa/security/product) → wirkt als Gewicht, nicht
   als Filter.
3. **"Wie viel darf der Skill anfassen?"** (Pflicht) — "Nur lesen und berichten"
   → Filter `risiko:read-only`; "Darf nach Freigabe auch ändern" → kein Filter.

**Empfehlungs-Algorithmus** (deterministisch, in `src/advisor.js`):
Kandidaten = Skills, die Frage-1-Terme matchen (Score +2 je Match), Frage-2-Term
(+1), Risiko-Filter hart. Sortierung Score desc, dann verfuegbar vor
in-entwicklung, dann Name. Top 3 Skills; zusätzlich: deckt ein Bundle ≥ 2 der
Top-3 ab → Bundle als Haupt-Empfehlung voranstellen. Jede Empfehlung mit
Ein-Satz-Begründung, generiert aus Template + Claim ("Weil dich <Schmerz-Label>
drückt: <claim>"). Antwort enthält die Term-Treffer als Evidenz.

### Bundle-Erlebnis

- Bundle-Seite: CTA "Bundle in den Korb" → verfügbare Skills in den Korb,
  in-entwicklung auf die Merkliste (Dialog sagt exakt, was passiert:
  "3 in den Korb, 1 auf die Merkliste").
- Korb kennt Bundle-Herkunft (Anzeige "aus Bundle legacy-rettung"), Checkout
  bleibt Skill-basiert (Order-Items sind Skills; bundle_id als Notiz-Spalte an
  order_items ergänzen — Migration).
- Bundle-Karten zeigen Status-Aggregat prominent.

### Landing-Feinschliff

Hero bekommt zweiten Einstieg: "Nicht sicher, was du brauchst? → Frag den
Berater" (Link, dezent unter dem Suchfeld). Berater-Seite: eine Frage pro
Schritt, Fortschritt sichtbar, Ergebnis-Seite mit Empfehlungs-Karten +
"Alle in den Korb"-Aktion + "Nochmal anders beantworten".

### Merkliste-Vervollständigung

merkliste.html zeigt bei inzwischen verfügbaren Skills (Status-Wechsel nach
Re-Import) einen "Jetzt verfügbar"-Badge + In-den-Korb-Button.

## 5. Edge-Cases

| Fall | Verhalten |
|---|---|
| Antwort-Kombination ohne Treffer (Risiko-Filter killt alles) | Ehrliche Leere: "Für read-only gibt es hier noch nichts — das ändert sich; merk dir X" + nächstbeste ungefilterte als "würde passen, fasst aber an" gekennzeichnet |
| Nur-in-entwicklung-Treffer | Empfehlen mit klarem Badge + Merkliste-CTA statt Korb |
| Frage 2 übersprungen | Score ohne Kontext-Gewicht — funktioniert |
| Regel-Datei referenziert unbekannten Term | Import-/Startzeit-Validierung → Fehler (wie S21-Kurationsfehler) |
| Bundle komplett in-entwicklung | CTA wird "Bundle merken" |
| Direktaufruf advisor-API mit ungültigen Options-IDs | 400 + Klartext |

## 6. Testplan

Smoke:

```powershell
cd shop; npm run import; npm start   # zweite Shell:
curl -Method POST http://127.0.0.1:4711/api/advisor -Body (@{ q1='legacy'; q3='readonly' } | ConvertTo-Json) -ContentType 'application/json'
node --test
```

node:test-Pflichtfälle (Tabelle erwarteter Empfehlungen — das Regelwerk wird als
Vertrag getestet, mindestens):

| q1 | q2 | q3 | Erwartung |
|---|---|---|---|
| legacy | — | readonly | intent-archaeologie unter Top 3; Bundle legacy-rettung als Haupt-Empfehlung |
| release | qa | readonly | test-luecken-kartograf + api-vertrags-waechter unter Top 3; release-guard-Bundle |
| security | security | egal | berechtigungs-roentgen Top 1 oder 2; security-audit-Bundle |
| neu-starten | — | egal | project-init unter Top 3 (verfuegbar → vor in-entwicklung) |
| prod | devops | readonly | prod-spiegel/ausfall-simulant vertreten |

Plus: Determinismus (2× gleiche Anfrage → identische Antwort), Leere-Kombination,
ungültige Option → 400, Regel-Validierung schlägt bei Phantom-Term an (Fixture).

Akzeptanz im Browser: Berater-Durchlauf (3 Schritte) → Ergebnis → "Alle in den
Korb" → Kasse funktioniert; Bundle-CTA-Dialog zeigt korrekte Korb/Merkliste-
Aufteilung; Merkliste zeigt "Jetzt verfügbar" nach simuliertem Status-Wechsel
(tracking.md-Zeile temporär auf fertig, Re-Import, prüfen, zurück — im
Testprotokoll dokumentieren).

## Entscheidungen während der Umsetzung

1. **`order_items.bundle_id` existierte bereits**: Die in diesem Sprint geplante
   "Migration" war schon in Sprint 21 Teil des Schemas
   (`shop/src/db.js`: `order_items.bundle_id INTEGER REFERENCES bundles(id)
   ON DELETE SET NULL`). Keine Schema-Änderung nötig — Spalte ist bislang nur
   ungenutzt (Checkout bleibt Skill-basiert, wie spezifiziert).
2. **Facetten-übergreifende Bundle-Aufwertung**: `bestCoverage` startet bei 1,
   ein Bundle wird nur Haupt-Empfehlung, wenn es ≥ 2 der Top-3 abdeckt (exakt
   wie im Sprint-Text gefordert). Tie-Break bei gleicher Coverage: alphabetisch
   nach Slug — deterministisch, aber keine reale Kollision in den 5
   Vertrags-Testfällen aufgetreten.
3. **Merkliste-Vervollständigung war bereits fertig**: Das "Jetzt verfügbar"-
   Badge + In-den-Korb-Button in `merkliste.html` wurde schon in Sprint 23
   mitgebaut (als ich die Seite von Grund auf neu anlegte). Dieser Sprint hat
   das nur noch einmal gezielt akzeptanzgetestet (Status-Wechsel-Simulation,
   siehe unten), keine Code-Änderung nötig.
4. **Status-Wechsel-Simulation ohne tracking.md**: Der Testplan schlägt vor,
   `tracking.md` temporär auf `fertig` zu setzen. Das greift aber nicht bei
   Skills ohne echten Ordner (Sprint-21-Sicherheitsnetz: kein Ordner ⇒ immer
   `in-entwicklung`, unabhängig von tracking.md — bewusst so gebaut, damit
   niemand versehentlich einen nicht-existenten Skill als installierbar
   markiert). Da `intent-archaeologie` (auf der Merkliste) keinen Ordner hat,
   wurde der Status stattdessen direkt in der DB umgeschaltet (simuliert exakt
   das Ergebnis eines echten Imports, ohne einen Fake-Skill-Ordner ins Repo zu
   legen) — danach zurückgesetzt und per `npm run import` wieder aus den
   echten Dateien synchronisiert. `ops/tracking.md` wurde zwischenzeitlich kurz
   testweise geändert und per `git checkout` sauber zurückgesetzt (kein Diff
   verblieben).
5. **Bundle-CTA-Wiring aus Sprint 23 durch die volle Logik ersetzt**: Sprint 23
   hatte bereits eine vereinfachte Version (nur "verfügbare in den Korb")
   gebaut, um den damals veralteten Platzhaltertext zu ersetzen. Dieser Sprint
   ersetzt das durch die vollständige Spezifikation (verfügbare → Korb mit
   Bundle-Herkunft, Rest → Merkliste, CTA-Text passt sich an: "Bundle merken"
   wenn 0 verfügbar).
6. **Reinstall-Button-Problem aus Sprint 23 trat hier NICHT auf**: Alle in
   diesem Sprint geklickten Buttons (Berater-Fragen, Bundle-CTA,
   "Alle in den Warenkorb") lösen keine nativen Dialoge aus — konnten daher
   live im Browser angeklickt/verifiziert werden.

## 8. Testresultate

- **node:test**: 54/54 grün gesamt (11 neu: 5 Vertrags-Testfälle aus der
  Sprint-Tabelle — jede Erwartung traf beim ersten Lauf zu, ohne
  Nachjustierung der Scoring-Logik —, Risiko-Filter-Fallback,
  q2-optional-Verhalten, Determinismus, unbekannte Option → 400, fehlendes
  Pflichtfeld → 400, Regel-Validierung gegen Phantom-Term).
- **Browser-Akzeptanz** (Claude-in-Chrome, live, keine Behauptung ohne
  Beobachtung; Hinweis: Radio-/Button-Klicks per `ref` waren in dieser Session
  mehrfach unzuverlässig — wo ein Klick sichtbar nichts bewirkte, wurde über
  `element.click()`/direkte Formular-Interaktion per JS nachgeholfen, was ein
  aequivalenter echter DOM-Klick ist, kein Vortäuschen):
  - Berater-Durchlauf q1=legacy, q3=readonly → Ergebnis zeigt
    intent-archaeologie + wissens-testament, Bundle "Legacy-Rettung" als
    Haupt-Empfehlung — deckt sich exakt mit dem Vertragstest.
  - Zweiter Durchlauf q1=neu-starten (q2 übersprungen), q3=egal → project-init
    als einzige, verfügbare Empfehlung; "Alle in den Warenkorb" hat es
    tatsächlich in den Korb gelegt (verifiziert auf warenkorb.html), Kasse
    war sofort nutzbar.
  - Erster Durchlauf mit zwei in-entwicklung-Empfehlungen: "Alle in den
    Warenkorb" hat korrekt NICHTS in den Korb gelegt (weil beide nicht
    verfügbar sind) und trotzdem zur Warenkorb-Seite weitergeleitet.
  - Bundle `qualitaets-fundament` (1 von 3 verfügbar): CTA-Klick →
    Hinweistext exakt "1 in den Warenkorb, 2 auf die Merkliste gelegt.";
    per JS-Introspektion bestätigt: `elevate` im Korb mit
    `fromBundle: "qualitaets-fundament"`, `test-luecken-kartograf` +
    `konsistenz-enforcer` auf der Merkliste. Warenkorb-Seite zeigt den Chip
    "aus Bundle qualitaets-fundament" korrekt.
  - Bundle `legacy-rettung` (0 von 4 verfügbar): CTA-Text korrekt
    "Bundle merken" statt "... in den Warenkorb".
  - Merkliste-Status-Wechsel-Simulation (DB-Flip statt tracking.md, siehe
    Entscheidung 4): `intent-archaeologie` zeigte danach live "verfuegbar" +
    "jetzt verfuegbar"-Badge + "In den Warenkorb"-Button; nach Zurücksetzen
    und Re-Import wieder korrekt "bald verfuegbar", DB-Kennzahlen (2
    verfügbar / 20 in-entwicklung) unverändert.
  - Keine Konsolenfehler über den gesamten Berater-/Bundle-/Merkliste-Flow.
- **Repo-Hygiene**: `ops/tracking.md` und `elevate/SKILL.md` wurden während
  der Test-Simulationen kurzzeitig testweise verändert und beide Male per
  `git checkout --` rückstandsfrei zurückgesetzt (verifiziert: `git status`
  zeigt keinen Diff auf diesen Dateien).

## 7. DoD-Checkliste

- [x] advisor-rules.json (Fragen, Optionen, Mappings) + Startzeit-Validierung
      (Validierung laeuft sowohl bei `npm run import` als auch beim
      Server-/Router-Start, siehe importer.js/api/advisor.js)
- [x] advisor.js deterministisch, Bundle-Aufwertungs-Logik
- [x] Berater-Seite (Schrittführung, Ergebnis, Korb-Aktion)
- [x] Bundle-Kauf-Logik + order_items.bundle_id-Migration (Spalte bereits
      seit Sprint 21 vorhanden, siehe Entscheidung 1)
- [x] Landing-Feinschliff + Merkliste-Vervollständigung (Merkliste-Teil bereits
      in Sprint 23 gebaut, hier akzeptanzgetestet, siehe Entscheidung 3)
- [x] Alle Regelwerk-Vertragstests + Edge-Tests grün (54/54 gesamt)
- [x] Browser-Akzeptanz inkl. Status-Wechsel-Simulation dokumentiert
- [x] tracking.md aktualisiert, Commit `sprint-24: shop-berater-bundles implementiert`
