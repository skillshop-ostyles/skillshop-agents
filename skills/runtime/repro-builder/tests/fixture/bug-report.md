# Bug: Invoice from last day of month lands in following month

## Symptom

When an invoice is generated on the last day of the month (e.g. January 31),
the next due date shows a date in the month after next instead of the
immediately following month.

## Expected

`nextBillingDate('2024-01-31')` should return a date in February (at latest
the last day of February), not March.

## Observed

Customers report that the due date is displayed "one month too late",
especially for invoices from the 29th, 30th, or 31st of a month.

## Environment

Node.js, function `nextBillingDate` in `billing.js`.
