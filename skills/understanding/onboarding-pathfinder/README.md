# onboarding-pathfinder

**Trigger:** `/onboarding-pathfinder`

New devs deserve a guided tour, not a README and 'just ask'.

Analyzes the topology of a codebase and generates a didactically sequenced
reading tour with comprehension questions and first safe tasks.

## Usage

```powershell
scripts/onboard-scan.ps1 -ProjectDir <path>
```

Returns JSON with:
- `topology` — file counts by category
- `readingTour` — ordered steps with rationale
- `comprehension` — questions per file
- `firstSafeTasks` — ranked low-risk starter files

## Status

Implemented. See `ops/tracking.md` for overall skill program status.
