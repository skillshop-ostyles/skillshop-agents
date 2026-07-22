# Cluster quality - Code Quality, Patterns, and Refactoring Signals

Skills in this cluster detect, classify, and reason about **code quality**:
smells, inconsistencies, dead code, refactoring opportunities, and the relationship
between documentation, intent, and the code as it actually exists.

These skills are the first line of defense for "this code works, but should it look
like this?" - they support both senior engineers who refactor deliberately and
vibe-coders who want to know whether their generated code is structurally sound.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|--|
| [intent-archaeology](../quality/intent-archaeology/) | /intent-archaeology | Senior > Vibe | Reconstruct the original *why* of existing code from git history: commit messages, PR discussions, and the evolution of the code itself. Produces an intent narrative per file/module with evidence. |
| [spec-lie-detector](../quality/spec-lie-detector/) | /spec-lie-detector | Senior > Vibe | Detect lies in specifications and tickets: contradictions, gaps, ambiguities, silent assumptions, and unstated preconditions. |
| [side-effect-radar](../quality/side-effect-radar/) | /side-effect-radar | Senior | Predict the blast radius of a planned change by mapping all code locations that reference the symbols about to change. |
| [consistency-enforcer](../quality/consistency-enforcer/) | /consistency-enforcer | Senior | Find semantically identical business rules implemented in divergent ways across a codebase (e.g. "eligible for discount" expressed in five different modules). |
| [dead-code-burier](../quality/dead-code-burier/) | /dead-code-burier | Senior | Identify provably dead code with evidence (unreachable, no callers, removed from all entry points) - supports opt-in removal. |
| [doc-drift-detector](../quality/doc-drift-detector/) | /doc-drift-detector | Senior > Vibe | Statically check documentation claims against code reality (wrong function names, outdated parameter lists, missing return types). |
| [vocabulary-guardian](../quality/vocabulary-guardian/) | /vocabulary-guardian | Both | Detect synonyms and homonyms for the same domain concept across a codebase, propose a canonical vocabulary. |
| [code-smell-detection](../quality/code-smell-detection/) | /code-smell | Both | Statically detects 10 code-smell families: long methods, deep nesting, god classes, feature envy, data clumps, message chains, shotgun surgery, refused bequest, primitive obsession, speculative generality. |

## Cross-Links

Some security-relevant smell detection is grouped with the security cluster
for thematic coherence, but is also highly relevant to quality:

- [security-smell-scanner](../security/security-smell-scanner/) (Sprint 30) -
  security anti-patterns (SQL injection shape, XSS sinks, IDOR patterns,
  insecure defaults). Lives under `security/` but also linked here because the
  same detection patterns surface as general code smells.
