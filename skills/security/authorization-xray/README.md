# authorization-xray

**Trigger:** `/authz`

Authorization X-ray for your own codebase (defensive audit). Inventories every HTTP endpoint and every recognizable protection layer (middleware chains, authorize decorators, inline role checks, router mounts), builds the permission matrix endpoint x required check, and reports unprotected mutating endpoints and inconsistent protection.

## Usage

```powershell
& .\scripts\authz-scan.ps1 -ProjectDir "C:\Projects\my-app"
```

Produces JSON with `endpoints`, `globalUse`, and `inlineChecks` arrays plus counts.

## Status

Implemented. Full specification: [`ops/sprints/sprint-18-authorization-xray.md`](../../ops/sprints/sprint-18-authorization-xray.md).
