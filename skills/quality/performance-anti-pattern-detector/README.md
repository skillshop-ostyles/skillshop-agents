# performance-anti-pattern-detector

**Trigger:** `/perf` | **Risk:** read-only | **Audience:** Senior

> Performance anti-pattern detector: statically finds 8 families of structural performance problems (N+1 queries, sync-...

Performance anti-pattern detector: statically finds 8 families of structural performance problems (N+1 queries, sync-over-async, hot-loop allocation, listener leaks, unnecessary serialization, large closure captures, string concat in loop, redundant computation). Evidence-based report with severity and LLM impact assessment.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/performance-anti-pattern-detector $HOME/.claude/skills/quality/performance-anti-pattern-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/performance-anti-pattern-detector $HOME\.claude\skills\quality\performance-anti-pattern-detector
```

## Usage

```
/perf                    # interactive - prompts for target
/perf <project-dir>      # scan specified project
/perf -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Console summary with key metrics | Markdown report: perf-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


