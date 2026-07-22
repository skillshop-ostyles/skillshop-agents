# AGENTS — Skill Program

A curated collection of **LLM-powered developer skills** — executable knowledge
packages that solve real coding pain points. Each skill is a `SKILL.md` instruction
file plus deterministic collector scripts (`scripts/*.ps1`) that a coding agent
(TBD, Sonnet, or any LLM) can run against a target project.

Two things in one repo:

1. **The Skill Program** (`skills/`) — skills organized in thematic clusters,
   each installable individually into `~/.claude/skills/`.
2. **The Skill Shop** (`shop/`) — a local marketplace and specialty store
   (Express + SQLite, localhost-only) that offers skills as products: single
   installs, bundles, faceted search, and a rule-based advisor. See
   [`shop/README.md`](shop/README.md).

## Skills at a Glance

| Cluster | Focus | Skills | Sprints |
|---|---|---|---|
| [_meta](skills/_meta/) | Repository lifecycle tooling | 2 | — |
| [quality](skills/quality/) | Code smells, patterns, refactoring signals | 7 + 4 planned | 30-34 |
| [understanding](skills/understanding/) | Knowledge preservation, onboarding, architecture | 2 + 1 planned | 35 |
| [security](skills/security/) | Protection, compliance, trust boundaries | 5 + 2 planned | 30 (cross), 36 |
| [data](skills/data/) | Schemas, migrations, test coverage | 2 | — |
| [runtime](skills/runtime/) | Performance, reproduction, production mirroring | 2 | — |
| [operations](skills/operations/) | Deployment, resilience, maintainability | 2 + 1 planned | 38 |
| [ai-ml](skills/ai-ml/) | LLM apps, ML pipelines | 2 planned | 39-40 |

Total: **22 existing + 10 planned = 32 skills** across **8 clusters**.

## Install a Skill

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/spec-luegendetektor ~/.claude/skills/
```

Use the Shop for guided installation (path guards, update tracking, advisor):

```bash
cd shop
npm install
npm run import
npm start    # http://127.0.0.1:4711
```

## Repository Structure

```
.
├── README.md            This file — cluster tour
├── CLAUDE.md            Project bible (local instance)
├── ops/                 The "bible": rules, manifest, tracking, sprint specs
│   ├── BIBEL.md         Master rules for the skill program
│   ├── SHOP-BIBEL.md    Master rules for the shop
│   ├── manifest.md      Scope, cluster taxonomy, constraints
│   ├── tracking.md      Sprint status (source of truth)
│   └── sprints/         Full specification per sprint
├── skills/<cluster>/    Thematic directories with skill folders
└── shop/                The skill shop (Node + Express + SQLite)
```

## Rules

- **`~/.claude/` is off-limits** — no script or installer ever modifies it
  (case-insensitive path guard, tested).
- Simplicity First; surgical changes; every fix with a test.
- Honesty principle: status from `ops/tracking.md`, no fake reviews,
  no fabricated numbers.

## License

[MIT](LICENSE).
