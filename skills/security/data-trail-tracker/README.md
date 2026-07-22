# data-trail-tracker

**Trigger:** `/data-trail-tracker`

"Where is all the personal data?" - the GDPR question no team can fully answer.

Maps PII fields and their sinks - logs, third-party APIs, exports - purely via
field names, never via actual data.

## Usage

```powershell
scripts/pii-scan.ps1 -ProjectDir <path> [-PassThru]
```

Returns JSON with `piiCandidates` (structure, field, file, source) and `sinks`
(log, external, export, storage, deletion).

## Status

Implemented. See `ops/tracking.md` for overall skill program status.
