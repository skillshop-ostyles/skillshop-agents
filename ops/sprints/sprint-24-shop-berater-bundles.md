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

## 7. DoD-Checkliste

- [ ] advisor-rules.json (Fragen, Optionen, Mappings) + Startzeit-Validierung
- [ ] advisor.js deterministisch, Bundle-Aufwertungs-Logik
- [ ] Berater-Seite (Schrittführung, Ergebnis, Korb-Aktion)
- [ ] Bundle-Kauf-Logik + order_items.bundle_id-Migration
- [ ] Landing-Feinschliff + Merkliste-Vervollständigung
- [ ] Alle Regelwerk-Vertragstests + Edge-Tests grün
- [ ] Browser-Akzeptanz inkl. Status-Wechsel-Simulation dokumentiert
- [ ] tracking.md aktualisiert, Commit `sprint-24: shop-berater-bundles implementiert`
