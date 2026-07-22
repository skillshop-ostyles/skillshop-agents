--
name: data-trail-tracker
description: "Maps PII fields and their sinks - logs, third-party APIs, exports - purely via field names, never via actual data. Trigger: /data-trail-tracker"
trigger: /data-trail-tracker
--

# /data-trail-tracker

"Where is all the personal data?" - the GDPR question no team can fully answer.

Scans codebase for PII field candidates (email, iban, phone, address, etc.) in
TS/JS, SQL, and Prisma model definitions, then traces where those fields flow:
log statements, external API calls, file exports, storage writes, and
deletion/anonymization signals.

## Usage

```powershell
scripts/pii-scan.ps1 -ProjectDir <path> [-PassThru]
```

Returns JSON with `piiCandidates` (structure, field, file, source) and `sinks`
(log, external, export, storage, deletion).
