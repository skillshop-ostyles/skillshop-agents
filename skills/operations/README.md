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

## Cross-Links

- `runtime/` - `prod-mirror` observes production behavior; `failure-simulator` predicts failure behavior.
- `security/` - `config-cartographer` covers configuration surface that ops engineers deploy.
