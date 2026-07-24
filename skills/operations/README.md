# Cluster operations - Deployment, Resilience, and Maintainability

Skills in this cluster help **operate** the system reliably: what breaks,
how to prevent it, and how to prepare for the inevitable. They serve the
intersection of dev and ops - SREs, platform engineers, and anyone who gets
paged.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [timebomb-scanner](../operations/timebomb-scanner/) | /timebomb | Senior | Find hardcoded data, expiring assumptions, and rotting workarounds - things that will break silently when the clock runs out. |
| [failure-simulator](../operations/failure-simulator/) | /failsim | Senior | Statically trace failure paths: given a failure scenario (network partition, DB outage, rate limit), walk every code path that would execute and document the actual behavior. |
| [dockerfile-best-practices](../operations/dockerfile-best-practices/) | /dockerfile-audit | Both | Static audit of Dockerfiles for 18 best-practice violations: unpinned images, root execution, missing HEALTHCHECK, excessive layers, package cache bloat, hardcoded secrets. |
| [deployment-drift-detector](../operations/deployment-drift-detector/) | /deploy-drift | Senior | Extract deployed config vs source-of-truth manifests; LLM judges each drift by business criticality. |
| [dependency-graveyard](../operations/dependency-graveyard/) | /dep-graveyard | Senior | Inventory every dependency, check registry health; LLM classifies each as healthy/aging/zombie/dead. |
| [ci-debt-analyzer](../operations/ci-debt-analyzer/) | /ci-debt | Both | Read CI configuration, measure pipeline health; LLM identifies the biggest time waste and recommends fixes. |
| [log-quality-auditor](../operations/log-quality-auditor/) | /log-audit | Both | Inventory every log statement; LLM judges structured logging, correlation ID coverage, and PII risk. |
| [backup-coverage-scanner](../operations/backup-coverage-scanner/) | /backup-scan | Senior | Inventory every stateful resource; LLM identifies critical backup gaps before the incident. |
| [leak-detector](../operations/leak-detector/) | /leak-scan | Senior | Trace resource acquisition/release; LLM classifies each as clean/leaky/uncertain. |
| [healthcheck-mapper](../operations/healthcheck-mapper/) | /healthcheck | Both | Audit health/readiness/liveness endpoints against service dependencies; LLM judges coverage. |
| [env-drift-tracker](../operations/env-drift-tracker/) | /env-drift | Senior | Compare config across environments; LLM flags dangerous drifts. |

## Cross-Links

- `runtime/` - `prod-mirror` observes production behavior; `failure-simulator` predicts failure behavior.
- `security/` - `config-cartographer` covers configuration surface that ops engineers deploy.
- `data/` - `migration-safety-inspector` checks migration reversibility; `rollback-readiness` (O9, planned) assesses holistic rollback readiness.
- `quality/` - `performance-anti-pattern-detector` finds structural perf issues; `capacity-early-warning` (O11, planned) judges numeric limits.
- `understanding/` - `runbook-automator` generates runbooks; `runbook-auditor` (O10, planned) audits existing ones.
