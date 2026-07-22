# Bug: Rechnung vom Monatsletzten landet im Folgemonat

## Symptom

Wenn eine Rechnung am letzten Tag des Monats gestellt wird (z. B. 31. Januar),
zeigt das nächste Fälligkeitsdatum ein Datum im übernächsten Monat statt im
direkt folgenden Monat.

## Erwartung

`nextBillingDate('2024-01-31')` sollte ein Datum im Februar liefern (spätestens
der Monatsletzte Februar), nicht im März.

## Beobachtet

Kunden berichten, dass die Fälligkeit "einen Monat zu spät" angezeigt wird,
speziell bei Rechnungen vom 29., 30. oder 31. eines Monats.

## Umgebung

Node.js, Funktion `nextBillingDate` in `billing.js`.
