# AGENTS - Skill Program

A curated collection of **LLM-powered developer skills** - executable knowledge
packages that solve real coding pain points. Each skill is a `SKILL.md` instruction
file plus deterministic collector scripts (`scripts/*.ps1`) that a coding agent
(TBD, Sonnet, or any LLM) can run against a target project.

A single repo with one focus:

## Skills at a Glance

| Cluster | Focus | Skills | Sprints |
|--|--|--|--|
| [_meta](skills/_meta/) | Repository lifecycle tooling | 2 | - |
| [quality](skills/quality/) | Code smells, patterns, refactoring signals | 12 | 30-34 |
| [understanding](skills/understanding/) | Knowledge preservation, onboarding, architecture | 3 | 35 |
| [security](skills/security/) | Protection, compliance, trust boundaries | 7 | 30 (cross), 36 |
| [data](skills/data/) | Schemas, migrations, test coverage | 2 | - |
| [runtime](skills/runtime/) | Performance, reproduction, production mirroring | 2 | - |
| [operations](skills/operations/) | Deployment, resilience, maintainability | 3 | 38 |
| [ai-ml](skills/ai-ml/) | LLM apps, ML pipelines | 2 | 39-40 |

Phase A (sprints 01-20) and Phase B (sprints 30-40) complete.

## Install a Skill

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/intent-archaeology ~/.claude/skills/
```

## Repository Structure

```
.
+-- README.md            This file - cluster tour
+-- CLAUDE.md            Project bible (local instance)
+-- ops/                 The "bible": rules, manifest, tracking, sprint specs
�   +-- BIBEL.md         Master rules for the skill program
�   +-- manifest.md      Scope, cluster taxonomy, constraints
�   +-- tracking.md      Sprint status (source of truth)
�   +-- sprints/         Full specification per sprint
+-- skills/<cluster>/    Thematic directories with skill folders
```

## Rules

- **`~/.claude/` is off-limits** - no script or installer ever modifies it
  (case-insensitive path guard, tested).
- Simplicity First; surgical changes; every fix with a test.
- Honesty principle: status from `ops/tracking.md`, no fake reviews,
  no fabricated numbers.

## License

[MIT](LICENSE).
