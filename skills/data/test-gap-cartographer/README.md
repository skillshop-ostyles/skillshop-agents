# test-gap-cartographer

**Trigger:** `/testgap`

Semantic test gap mapper. Inventories the public code surface (exports, routes) and all existing tests, then maps which BEHAVIORS of each public symbol are covered by which test and which are not — reporting untested behaviors ranked by risk with proposed test case names.

## Usage

```powershell
& .\scripts\surface-inventory.ps1 -ProjectDir "C:\Projects\my-app"
& .\scripts\test-inventory.ps1 -ProjectDir "C:\Projects\my-app"
```

Produces JSON with `symbols`/`routes` (surface) and `testFiles`/`cases` (test inventory).

## Status

Implemented. Full specification: [`ops/sprints/sprint-15-test-gap-cartographer.md`](../../ops/sprints/sprint-15-test-gap-cartographer.md).
