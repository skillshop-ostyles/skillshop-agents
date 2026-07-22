# api-contract-guardian

**Trigger:** `/api-diff`

API contract guard. Extracts the API surface (HTTP routes, DTO fields, exported signatures — preferring OpenAPI files when present) from two git states of a repo, diffs them, classifies every change as breaking / non-breaking / additive, and writes a ready-to-ship consumer migration note per breaking change.

## Usage

```powershell
& .\scripts\api-surface.ps1 -ProjectDir "C:\Projects\my-app" -Ref "v1.4.0"
& .\scripts\api-surface.ps1 -ProjectDir "C:\Projects\my-app"
```

Produces JSON with `routes`, `dtos`, `signatures` arrays plus counts.

## Status

Implemented. Full specification: [`ops/sprints/sprint-17-api-contract-guardian.md`](../../ops/sprints/sprint-17-api-contract-guardian.md).
