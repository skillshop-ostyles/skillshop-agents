# failure-simulator

**Trigger:** `/failsim`

Failure simulator on code level. Inventories every external touchpoint (HTTP clients, DB access, filesystem, queues, caches) with its surrounding error handling, then for a chosen failure scenario mentally executes the failure path at each touchpoint and reports the resulting behavior — retry, degradation, crash or silent loss — plus inconsistencies and hardening recommendations.

## Usage

```powershell
& .\scripts\failpoint-scan.ps1 -ProjectDir "C:\Projects\my-app"
```

Produces JSON with `failpoints` array (type, file, line, context, error-handling flags).

## Status

Implemented. Full specification: [`ops/sprints/sprint-16-failure-simulator.md`](../../ops/sprints/sprint-16-failure-simulator.md).
