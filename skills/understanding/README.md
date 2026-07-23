# Cluster understanding - Knowledge, Onboarding, and Architecture Comprehension

Skills in this cluster help developers **understand the system**: what it does,
who knows what, how new team members get up to speed, and how the architecture
is structured. They bridge the gap between "the code compiles" and "I know what
this codebase does."

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [knowledge-testament](../understanding/knowledge-testament/) | /testament | Both | Preserve a developer's head knowledge via interview + code mining before they leave or switch context. Produces a structured knowledge inventory with ownership evidence. |
| [onboarding-pathfinder](../understanding/onboarding-pathfinder/) | /onboarding-pathfinder | Both | Generate a guided reading tour of the codebase for new developers: entry points, data flow, key abstractions, where to make a first change. |
| [architecture-visualizer](../understanding/architecture-visualizer/) | /arch-vis | Both | Generate a machine-readable dependency graph from source code imports, flag layer violations and circular dependencies, and compute structural health score. |
| [domain-narrator](../understanding/domain-narrator/) | /explain | Both | Extract business-domain clusters from code: group modules by semantic responsibility, write plain-English domain descriptions. |
| [api-surface-documenter](../understanding/api-surface-documenter/) | /api-survey | Both | Full API surface inventory: REST routes, event handlers, CLI commands, library exports. Classify stability and generate reference. |
| [error-handling-overview](../understanding/error-handling-overview/) | /errors-overview | Both | Strategic map of error handling: catch types, global handlers, error class hierarchy, swallowed exceptions. |
| [convention-extractor](../understanding/convention-extractor/) | /conventions | Both | Extract implicit coding conventions from code patterns: naming, imports, async style, error handling, null handling. |
| [test-strategy-designer](../understanding/test-strategy-designer/) | /test-strategy | Senior | Analyse test pyramid distribution, classify test types, identify untested modules and overpriced integration tests. |
| [config-surface-documenter](../understanding/config-surface-documenter/) | /config-docs | Both | Generate human-readable configuration reference from code: env vars, config files, CLI flags with descriptions and defaults. |
| [integration-landscape](../understanding/integration-landscape/) | /integrations | Senior | Map every external integration: protocol, auth type, fallback status, retry policy, outage impact. |
| [tech-debt-narrator](../understanding/tech-debt-narrator/) | /tech-debt | Senior | Cluster tech-debt items into logical groups, narrate repayment strategies with effort estimates. |
| [data-flow-cartographer](../understanding/data-flow-cartographer/) | /dataflow | Senior | Trace data from input sources through transformations to sinks; generate Mermaid flow diagrams. |
| [runbook-automator](../understanding/runbook-automator/) | /runbook | Both | Generate deployment runbook from docker-compose, CI config, healthcheck endpoints, and npm scripts. |
| [changelog-narrator](../understanding/changelog-narrator/) | /changelog | Both | Generate semantic changelog from git diff: classify features/fixes/breaking-changes, write migration notes. |

## Cross-Links

- `quality/` - shared structural analysis patterns.
