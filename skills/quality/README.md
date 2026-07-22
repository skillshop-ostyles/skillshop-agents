# Cluster quality - Code Quality, Patterns, and Refactoring Signals

Skills in this cluster detect, classify, and reason about **code quality**:
smells, inconsistencies, dead code, refactoring opportunities, and the relationship
between documentation, intent, and the code as it actually exists. Phase C
expanded the cluster from 11 to 21 skills (see `ops/phase-c-catalog.md`).

These skills are the first line of defense for "this code works, but should it look
like this?" - they support both senior engineers who refactor deliberately and
vibe-coders who want to know whether their generated code is structurally sound.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|--|
| [intent-archaeology](../quality/intent-archaeology/) | /intent | Senior > Vibe | Reconstruct the original *why* of existing code from git history: commit messages, PR discussions, and the evolution of the code itself. Produces an intent narrative per file/module with evidence. |
| [spec-lie-detector](../quality/spec-lie-detector/) | /spec-check | Senior > Vibe | Detect lies in specifications and tickets: contradictions, gaps, ambiguities, silent assumptions, and unstated preconditions. |
| [side-effect-radar](../quality/side-effect-radar/) | /blast | Senior | Predict the blast radius of a planned change by mapping all code locations that reference the symbols about to change. |
| [consistency-enforcer](../quality/consistency-enforcer/) | /consist | Senior | Find semantically identical business rules implemented in divergent ways across a codebase (e.g. "eligible for discount" expressed in five different modules). |
| [dead-code-burier](../quality/dead-code-burier/) | /bury | Senior | Identify provably dead code with evidence (unreachable, no callers, removed from all entry points) - supports opt-in removal. |
| [doc-drift-detector](../quality/doc-drift-detector/) | /doc-drift | Senior > Vibe | Statically check documentation claims against code reality (wrong function names, outdated parameter lists, missing return types). |
| [vocabulary-guardian](../quality/vocabulary-guardian/) | /vocab | Both | Detect synonyms and homonyms for the same domain concept across a codebase, propose a canonical vocabulary. |
| [code-smell-detection](../quality/code-smell-detection/) | /code-smell | Both | Statically detects 10 code-smell families: long methods, deep nesting, god classes, feature envy, data clumps, message chains, shotgun surgery, refused bequest, primitive obsession, speculative generality. |
| [performance-anti-pattern-detektor](../quality/performance-anti-pattern-detektor/) | /perf | Senior | Detects 8 performance anti-patterns: N+1 queries, sync-over-async, hot-loop allocation, listener leaks, string concat in loops, unnecessary serialization, large closure captures, redundant computation in loops. |
| [code-clone-detector](../quality/code-clone-detector/) | /code-clone | Senior | Finds code clones across a codebase: Type 1-3 (exact, renamed, modified) via deterministic fingerprinting, Type 4 (semantic) via LLM candidate selection. Reports clone clusters with density metrics. |
| [error-handling-auditor](../quality/error-handling-auditor/) | /error-audit | Senior | Audits error handling across a codebase: swallowed exceptions, generic catch blocks, missing error propagation, missing finally blocks, exception type abuse, logging without context, and ignored return codes. |
| [comment-lie-detector](../quality/comment-lie-detector/) | /comment-lies | Both | Every behavioral-claim comment ("returns null", "thread-safe") paired with 30 lines of surrounding code; LLM judges consistency / contradicts / outdated. |
| [test-honesty-auditor](../quality/test-honesty-auditor/) | /test-honesty | Both | Tests that cannot fail: zero-assertion, tautologies, mock-asserts-itself, rotting skips. Bucketized then LLM-judged for honesty. |
| [misleading-name-detector](../quality/misleading-name-detector/) | /name-lies | Both | `getUser()` that writes / `isValid()` returning a string / `tempFix()` from 2019. Prefix classification + body preview; LLM judges promise vs behavior. |
| [migration-limbo-detector](../quality/migration-limbo-detector/) | /migration-limbo | Senior | Half-finished migrations: axios AND fetch, moment AND date-fns. 18 built-in pattern pairs, custom pairs via -CustomPairs, git-timeline per side. |
| [clone-drift-tracker](../quality/clone-drift-tracker/) | /clone-drift | Senior | Code blocks USED to be clones and silently diverged. Body-hash comparison current vs `HEAD~N` (default 100). Requires git repo. |
| [magic-value-genealogist](../quality/magic-value-genealogist/) | /magic-values | Both | Numeric and uppercase-string literals outside tests with origin (git blame), informed-by author, intro commit. LLM judges unify/rethink/unexplained. |
| [wheel-reinvention-detector](../quality/wheel-reinvention-detector/) | /reinvented-wheels | Both | Short exported utility functions paired with installed libraries; LLM judges stdlib-equivalence and library-replacement. |
| [api-footgun-reviewer](../quality/api-footgun-reviewer/) | /footguns | Senior > Vibe | Internal function signatures: boolean traps, same-type adjacent, inconsistent family conventions. |
| [paranoia-profiler](../quality/paranoia-profiler/) | /paranoia | Senior | Every defensive guard cataloged with context. LLM judges paranoid (impossible case) vs naive (external input). |
| [invariant-miner](../quality/invariant-miner/) | /invariants | Senior | Hidden invariants statically inferred from code structure (array-index without guard, division-by-computed, JSON.parse-trust). LLM proposes assertions/docs. |

## Cross-Links

Some security-relevant smell detection is grouped with the security cluster
for thematic coherence, but is also highly relevant to quality:

- [security-smell-scanner](../security/security-smell-scanner/) -
  security anti-patterns (SQL injection shape, XSS sinks, IDOR patterns,
  insecure defaults). Lives under `security/` but also linked here because the
  same detection patterns surface as general code smells.
