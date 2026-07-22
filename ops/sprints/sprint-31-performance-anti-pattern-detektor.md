# Sprint 31 — performance-anti-pattern-detektor (/perf → quality/)

Regeln: `ops/BIBEL.md` gilt vollständig (Sprint 30+, englische Artefakte).
Physisch in `skills/quality/`. Zielgruppe: Senior.

## 1. Problem

Performance-Probleme entstehen selten durch eine einzelne langsame Funktion — sie entstehen durch wiederkehrende Muster: N+1-Queries in Schleifen, sync/async-Mix (Blocking-IO im Event-Loop), Hot-Loops mit unnötiger Arbeit, Listener-Leaks, unnötige Serialisierung in heißen Pfaden, Closure-Capture-Zyklen. Menschen übersehen sie im Review, weil sie in der Code-Struktur versteckt sind. Ein statischer Analyzer mit Pattern-Heuristiken + LLM-Kontext findet sie systematisch.

Vorher: Performance-Probleme werden erst in Prod gemessen (APM) oder in Stress-Tests gefunden. Nachher: Potenzielle Anti-Patterns sind im PR bekannt, bevor sie deployt werden.

## 2. Nutzen

- Systematische Pre-Prod-Erkennung der häufigsten Performance-Anti-Patterns
- Fokussiert auf Muster, die Linter nicht abdecken (strukturelle/semantische Patterns)
- Jeder Fund mit Kontext + Priorisierung, LLM schätzt Impact ab

## 3. Scope / Nicht-Scope

**Scope:** 8 Pattern-Familien:
1. **N+1 queries** — DB/API calls in forEach/map/for loops
2. **Sync-over-async** — blocking calls (.Result, .Wait(), GetAwaiter().GetResult(), sync over async) in async contexts
3. **Hot-loop allocation** — object/array creation in tight loops
4. **Listener leak** — event listeners/subscriptions added but never removed (addEventListener/on/connect without removeEventListener/off/disconnect)
5. **Unnecessary serialization** — JSON.stringify/parse in hot paths, repeated serialization of same data
6. **Large closure captures** — large objects captured in closures, preventing GC
7. **String concat in loop** — `+=`/`concat()` in loop (should use Array.join/StringBuilder)
8. **Redundant computation** — same computation repeated in loop without caching

**Nicht-Scope:** KEIN Profiling, KEINE Runtime-Messung, KEIN APM-Ersatz. KEIN Datenfluss-Graph. KEIN Netzwerk-Latency-Check.

## 4. Skill-Spezifikation

Ordner: `skills/quality/performance-anti-pattern-detektor/`

Frontmatter:

```yaml
---
name: performance-anti-pattern-detektor
description: "Performance anti-pattern detector: statically finds 8 families of structural performance problems (N+1 queries, sync-over-async, hot-loop allocation, listener leaks, unnecessary serialization, large closure captures, string concat in loop, redundant computation). Evidence-based report with severity and LLM impact assessment. Read-only. Trigger: /perf"
trigger: /perf
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stop.
2. Confirm: `-ProjectDir`.
3. Run `scripts/perf-scan.ps1`.
4. LLM analysis per § 6.
5. Report `perf-report.md` into working directory; hot paths first.

Usage:

```
/perf               # interactive
/perf <dir>         # scan directory
/perf --help
```

## 5. Collector Scripts

### scripts/perf-scan.ps1

Parameters: `-ProjectDir` (mandatory), `-Extensions`/`-Exclude` (Sprint 03 defaults).

Read-only. Scans source files for 8 pattern families. Produces JSON.

JSON output schema:

```json
{
  "findings": [
    {
      "id": 1,
      "pattern": "n-plus-one",
      "severity": "high",
      "file": "src/orders.ts",
      "line": 45,
      "evidence": "items.forEach(item => db.query(`SELECT * FROM details WHERE id = ${item.id}`))",
      "context": "...",
      "loopLines": 3,
      "estimatedCallCount": "unbounded",
      "suggestedFix": "Use a single batch query (WHERE id IN (...)) or a JOIN instead of per-item queries."
    }
  ],
  "counts": {
    "total": 12,
    "bySeverity": { "high": 2, "medium": 7, "low": 3 },
    "byPattern": { "n-plus-one": 2, "sync-over-async": 3, "hot-loop-alloc": 4, "listener-leak": 1, "string-concat-loop": 2 }
  },
  "summary": "Found 12 performance anti-pattern(s): 2 high, 7 medium, 3 low."
}
```

Error behavior: missing path → exit 1. No findings → empty array, exit 0.

## 6. LLM Analysis Steps

1. **Parse findings** from JSON. For each finding, examine the context snippet.
2. **Validate** each finding:
   - Is the loop truly a hot path (called from request handler, event, scheduled job)?
   - Is the N+1 actually avoidable (DB driver may batch internally)?
   - Is sync-over-async in a known synchronous-only context (Main, Console app)?
3. **Severity recalibration** based on reachability and estimated frequency.
4. **Report structure**:
   - Executive summary
   - Hot path findings (high severity, confirmed reachable) with evidence + fix
   - Medium findings grouped by pattern
   - Low / informational
   - False positives log
   - Open questions (uncertain reachability)

## 7. Edge Cases

| Case | Behavior |
|---|---|
| DB query with ORM batch loading (DataLoader, Include/ThenInclude) | NOT flagged — mark as `hasBatchLoad: true` if nearby Include/DataLoader pattern |
| Array.forEach with synchronous operation | NOT flagged — only flag if body contains async/DB/IO calls |
| Event listener in disposable class with Dispose/cleanup | Listener leak downgraded to low if cleanup exists in same class |
| String concat of known-small strings (<5 iterations) | Low severity unless in hot path |

## 8. Test Plan

Smoke: Fixture `performance-anti-pattern-detektor/tests/fixture/` with:
- 1 N+1 query (forEach + db.query inside)
- 1 sync-over-async (.Result in async method)
- 1 hot-loop alloc (new object in for loop)
- 1 string concat in loop
- 1 safe (DataLoader batched query — NOT flagged)

```powershell
& .\skills\quality\performance-anti-pattern-detektor\scripts\perf-scan.ps1 -ProjectDir ".\skills\quality\performance-anti-pattern-detektor\tests\fixture"
```

Expected: exit 0, JSON valid, 4 findings, 1 NOT flagged (batched query). LLM: N+1 validated, sync-over-async confirmed, string concat low.

Akzeptanz (dreamzzz-api): Complete run. Expected: plausible findings ≥3.

Negativ: invalid path → exit 1.

## 9. DoD Checklist

- [ ] SKILL.md complete
- [ ] perf-scan.ps1 (8 pattern families)
- [ ] Fixture created (4 true positives + 1 false positive)
- [ ] Smoke passed
- [ ] LLM analysis validated
- [ ] Acceptance run documented
- [ ] Negative test passed
- [ ] tracking.md updated, commit `sprint-31: performance-anti-pattern-detektor implementiert`
