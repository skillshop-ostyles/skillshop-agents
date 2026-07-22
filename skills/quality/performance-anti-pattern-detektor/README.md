# performance-anti-pattern-detektor — /perf

Statically detect 8 families of structural performance anti-patterns:
N+1 queries, sync-over-async, hot-loop allocation, listener leaks,
unnecessary serialization, large closure captures, string concat in loops,
and redundant computation.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/performance-anti-pattern-detektor ~/.claude/skills/
```

## Usage

```
/perf                           # interactive
/perf /path/to/your/project     # scan directory
/perf --help
```

## Output

- `perf-report.md` — full report with executive summary, hot path findings,
  medium findings, false positives, and open questions.
- Console summary.

## Audience

**Senior** — findings require understanding of async/await, event loops,
and database query patterns to assess impact correctly.
