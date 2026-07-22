# Cluster quality — Code Quality, Patterns, and Refactoring Signals

Skills in this cluster detect, classify, and reason about **code quality**:
smells, inconsistencies, dead code, refactoring opportunities, and the relationship
between documentation, intent, and the code as it actually exists.

These skills are the first line of defense for "this code works, but should it look
like this?" — they support both senior engineers who refactor deliberately and
vibe-coders who want to know whether their generated code is structurally sound.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|---|---|---|---|
| [intent-archaeologie](../quality/intent-archaeologie/) | /intent | Senior > Vibe | Reconstruct the original *why* of existing code from git history: commit messages, PR discussions, and the evolution of the code itself. Produces an intent narrative per file/module with evidence. |
| [spec-luegendetektor](../quality/spec-luegendetektor/) | /spec-check | Senior > Vibe | Detect lies in specifications and tickets: contradictions, gaps, ambiguities, silent assumptions, and unstated preconditions. |
| [seiteneffekt-radar](../quality/seiteneffekt-radar/) | /blast | Senior | Predict the blast radius of a planned change by mapping all code locations that reference the symbols about to change. |
| [konsistenz-enforcer](../quality/konsistenz-enforcer/) | /consist | Senior | Find semantically identical business rules implemented in divergent ways across a codebase (e.g. "eligible for discount" expressed in five different modules). |
| [totpfad-bestatter](../quality/totpfad-bestatter/) | /bury | Senior | Identify provably dead code with evidence (unreachable, no callers, removed from all entry points) — supports opt-in removal. |
| [doku-drift-detektor](../quality/doku-drift-detektor/) | /doc-drift | Senior > Vibe | Statically check documentation claims against code reality (wrong function names, outdated parameter lists, missing return types). |
| [vokabular-waechter](../quality/vokabular-waechter/) | /vocab | Both | Detect synonyms and homonyms for the same domain concept across a codebase, propose a canonical vocabulary. |
| [code-smell-erkennung](../quality/code-smell-erkennung/) | /code-smell | Both | Statically detects 10 code-smell families: long methods, deep nesting, god classes, feature envy, data clumps, message chains, shotgun surgery, refused bequest, primitive obsession, speculative generality. |

## Cross-Links

Some security-relevant smell detection is grouped with the security cluster
for thematic coherence, but is also highly relevant to quality:

- [security-smell-scanner](../security/security-smell-scanner/) (Sprint 30) —
  security anti-patterns (SQL injection shape, XSS sinks, IDOR patterns,
  insecure defaults). Lives under `security/` but also linked here because the
  same detection patterns surface as general code smells.
