# Cluster runtime - Performance, Reproduction, and Production Mirroring

Skills in this cluster focus on **runtime behavior**: how the system actually
runs, how to reproduce bugs, and whether production reality matches code
expectations.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [prod-mirror](../runtime/prod-mirror/) | /mirror | Senior > Vibe | Compare code-level expectations against log reality: which assumptions the code makes about the world, and whether those assumptions hold in production. |
| [repro-builder](../runtime/repro-builder/) | /repro | Both | From a vague bug report, build a minimal, runnable reproduction. Sniffs the repo, suggests the config/environment/steps needed to trigger the bug. |

## Cross-Links

- `operations/` - `failure-simulator` extends runtime analysis by simulating failure paths.
- `data/` - `migration-surgeon` handles schema changes at rest; `prod-mirror` observes the consequences at runtime.
