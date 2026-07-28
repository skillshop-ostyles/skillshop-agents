# Cluster Vibe — Interactive Coaching Skills for Vibe Coders

Skills in this cluster are designed specifically for **vibe coders** — developers who describe intent in natural language and ship fast with AI-generated code. Each skill combines an interactive dialog wizard (DIALOG.md) with deterministic collector scripts and coaching-style LLM interpretation.

What makes Vibe skills different:
- **Interactive wizards** — numbered menus, one question per message, fix mode with diff preview
- **Coaching per finding** — every result includes Diagnosis → Explanation → Implementation steps
- **Impact-prioritized** — findings ranked by severity, not alphabetically
- **German user guides** — VIBE.md explains each skill in conversational German
- **No silent writes** — read-only by default, every fix confirmed via `[y/n]`

## Skills in this Cluster

| Skill | Trigger | Type | Checks | Purpose |
|--|--|--|--|--|
| [shipcheck](shipcheck/) | `/shipcheck` | Script-based | 3 | Pre-ship coach: env, build, secrets |
| [polish](polish/) | `/polish` | Script-based | 6 | AI residue removal: console.log, any types, magic strings, dead imports |
| [blitzplan](blitzplan/) | `/blitzplan` | LLM-only | — | Lightweight design coach: 3-5 questions, clear spec, no code until approval |
| [guardscan](guardscan/) | `/guardscan` | Script-based | 7 | Security primitive coach: RLS, auth, CSRF, secrets, headers |
| [perfscan](perfscan/) | `/perfscan` | Script-based | 7 | Performance coach: re-renders, layout shifts, bundle size, images |
| [stackcompass](stackcompass/) | `/stackcompass` | LLM-only | — | Tech-stack advisor: 2-3 stack options with trade-offs and action plan |

## Quick Install (all skills)

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe <target>  # copy individual skill or entire cluster
```

## Shared Template

The `_shared/` directory contains the [SKILL-TEMPLATE.md](_shared/SKILL-TEMPLATE.md) used as the starting point for all Vibe skills.
