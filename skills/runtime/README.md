# Cluster runtime - Performance, Reproduction, and Production Mirroring

Skills in this cluster focus on **runtime behavior**: how the system actually
runs, how to reproduce bugs, whether production reality matches code expectations,
and what happens at startup, shutdown, and under load. Phase C expanded the
cluster from 2 to 14 skills.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [prod-mirror](../runtime/prod-mirror/) | /mirror | Senior > Vibe | Compare code-level expectations against log reality: which assumptions the code makes about the world, and whether those assumptions hold in production. |
| [repro-builder](../runtime/repro-builder/) | /repro | Both | From a vague bug report, build a minimal, runnable reproduction. Sniffs the repo, suggests the config/environment/steps needed to trigger the bug. |
| [startup-profile-analyzer](../runtime/startup-profile-analyzer/) | /startup | Senior | Analyze the startup initialization chain: eager vs lazy loading, sync vs async, cascading delays. |
| [error-propagation-mapper](../runtime/error-propagation-mapper/) | /error-map | Senior | Map error propagation paths through the system: how errors bubble up, where they are caught, and where they are swallowed. |
| [concurrency-hazard-scanner](../runtime/concurrency-hazard-scanner/) | /concurrency | Senior | Find concurrency hazards: shared mutable state, non-atomic read-modify-write, missing synchronization. |
| [cache-effectiveness-auditor](../runtime/cache-effectiveness-auditor/) | /cache-audit | Senior | Audit cache configuration and usage patterns: miss rates, staleness, invalidation gaps, and caching at wrong layers. |
| [process-lifetime-tracker](../runtime/process-lifetime-tracker/) | /lifetime | Senior | Track process lifecycle patterns: graceful vs forced shutdown, cleanup guarantees, zombie process risks. |
| [schema-query-mismatch](../runtime/schema-query-mismatch/) | /schema-query | Senior | Find schema-query mismatches statically: missing columns, type mismatches, naming drift between code and schema. |
| [side-effect-ordering](../runtime/side-effect-ordering/) | /sideorder | Senior | Analyze side-effect ordering risks: temporal coupling, implicit ordering dependencies, callback chain hazards. |
| [mock-production-gap](../runtime/mock-production-gap/) | /mock-gap | Senior | Find mock-production divergences: mocked modules that behave differently from their real counterparts. |
| [runtime-type-mismatch](../runtime/runtime-type-mismatch/) | /type-mismatch | Senior | Find unvalidated runtime type assumptions: parsing without validation, unchecked casts, implicit type coercion. |
| [shutdown-gracefulness](../runtime/shutdown-gracefulness/) | /shutdown | Senior | Analyze shutdown hook implementation quality: timeout discipline, cleanup ordering, resource leak risks. |
| [dependency-runtime-availability](../runtime/dependency-runtime-availability/) | /runtime-deps | Senior | Find dynamic imports and resources that fail at runtime: optional dependencies assumed present, missing error handling on load failures. |
| [dead-code-at-runtime](../runtime/dead-code-at-runtime/) | /dead-runtime | Senior | Find feature flags, date gates, and environment checks that make code unreachable at runtime. |

## Cross-Links

- `operations/` - `failure-simulator` extends runtime analysis by simulating failure paths.
- `data/` - `migration-surgeon` handles schema changes at rest; `schema-query-mismatch` (runtime) observes the consequences at query time.
