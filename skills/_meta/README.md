# Cluster _meta — Repository Lifecycle

Skills in this cluster manage the **lifecycle of the AGENTS skill repository itself**
rather than analyzing external user projects. They are tooling for repository authors,
not for end-user code analysis.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|---|---|---|---|
| [elevate](../_meta/elevate/) | /elevate | Repo authors | Audit a PowerShell-based skill repository for skill-anatomy compliance (SKILL.md, scripts, protection guards, JSON output contract) and apply a curated set of best-practice improvements with safe rollback. |
| [project-init](../_meta/project-init/) | /project-init | Repo authors | Bootstrap a new AGENTS skill project from scratch: directory layout, SKILL.md skeleton, scripts stub, and tests-fixture scaffold. |

## Conventions

- Skills in `_meta/` are **read-write against the AGENTS repository itself**. They
  intentionally bypass the `~/.claude/` protection guard for paths outside
  the user home (this is the only cluster allowed to do so).
- They follow the same skill anatomy as all other skills
  (`SKILL.md` + `README.md` + `scripts/*.ps1`).
- They are excluded from the consumer-facing shop (Sprints 21-29) — they
  serve the skill authors, not the end users.

## Cross-Links

None. `_meta/` is the only cluster that does not analyze user code.
