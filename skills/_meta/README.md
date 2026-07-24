# Cluster _meta - Repository Lifecycle

Skills in this cluster manage the **lifecycle of the AGENTS skill repository itself**
rather than analyzing external user projects. They are tooling for repository authors,
not for end-user code analysis. Phase C expanded the cluster from 2 to 12 skills.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [elevate](../_meta/elevate/) | /elevate | Repo authors | Audit a PowerShell-based skill repository for skill-anatomy compliance (SKILL.md, scripts, protection guards, JSON output contract) and apply a curated set of best-practice improvements with safe rollback. |
| [project-init](../_meta/project-init/) | /project-init | Repo authors | Bootstrap a new AGENTS skill project from scratch: directory layout, SKILL.md skeleton, scripts stub, and tests-fixture scaffold. |
| [bibel-gate](../_meta/bibel-gate/) | /bibel-gate | Repo authors | Pre-commit BIBEL compliance gate: check changed skills for rule violations, run smoke tests, verify JSON contract. Exit 1 on failure. |
| [skill-dedup](../_meta/skill-dedup/) | /skill-dedup | Repo authors | Detect functional overlap between skills via description similarity and script pattern matching. |
| [impact](../_meta/impact/) | /impact | Repo authors | Given a BIBEL.md diff, trace each changed rule to every skill that would need updating. |
| [manifest-audit](../_meta/manifest-audit/) | /manifest-audit | Repo authors | Verify ops/tracking.md, README.md, and actual filesystem are in sync across all clusters. |
| [smoke-coverage](../_meta/smoke-coverage/) | /smoke-coverage | Repo authors | Audit smoke test coverage across all skills: which have fixtures, which don't, which test scripts actually run. |
| [cluster-purity](../_meta/cluster-purity/) | /cluster-purity | Repo authors | Detect skills that may belong to a different cluster based on description, trigger, and script patterns. |
| [trigger-audit](../_meta/trigger-audit/) | /trigger-audit | Repo authors | Validate trigger uniqueness, naming convention, and README documentation across all skills. |
| [benchmark](../_meta/benchmark/) | /benchmark | Repo authors | Run each collector script against its fixture, measure time and output size, detect regressions. |
| [bibel-migrate](../_meta/bibel-migrate/) | /bibel-migrate | Repo authors | Auto-generate migration patches when BIBEL.md conventions change. |
| [skill-lifecycle](../_meta/skill-lifecycle/) | /skill-lifecycle | Repo authors | Report on skill age, last modified, git activity, and deprecation status across all clusters. |

## Conventions

- Skills in `_meta/` are **read-write against the AGENTS repository itself**. They
  intentionally bypass the `~/.claude/` protection guard for paths outside
  the user home (this is the only cluster allowed to do so).
- They follow the same skill anatomy as all other skills
  (`SKILL.md` + `README.md` + `scripts/*.ps1`).
- They serve the skill authors, not the end users.
- META skills have no smoke test fixtures (they test against the real repo).

## Cross-Links

All `_meta/` skills reference the canonical rules in `ops/BIBEL.md`.
`manifest-audit` and `trigger-audit` cross-reference every cluster's README.md.
