# config-cartographer

**Trigger:** `/config-map`

Maps a system's complete config surface: every env var, setting and flag — where it is defined (.env, config files, Dockerfile, docker-compose) versus where it is read in code. Reports read-but-never-defined keys (crash candidates), defined-but-never-read orphans, and divergent defaults. Never outputs values — keys only.

## Usage

```powershell
& .\scripts\config-harvest.ps1 -ProjectDir "C:\Projects\my-app"
```

Produces JSON with `definitions`, `reads`, and `dynamicReads` arrays plus counts.

## Status

Implemented. Full specification: [`ops/sprints/sprint-14-config-cartographer.md`](../../ops/sprints/sprint-14-config-cartographer.md).
