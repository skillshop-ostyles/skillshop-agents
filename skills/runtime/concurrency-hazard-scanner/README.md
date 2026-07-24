# concurrency-hazard-scanner

**Trigger:** `/concurrency` | **Risk:** read-only | **Audience:** Both

> Concurrency hazard scanner: map shared mutable state across async boundaries, LLM judges each pattern as safe/racy/de...

Concurrency hazard scanner: map shared mutable state across async boundaries, LLM judges each pattern as safe/racy/deadlock-prone.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/runtime/concurrency-hazard-scanner $HOME/.claude/skills/runtime/concurrency-hazard-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/runtime/concurrency-hazard-scanner $HOME\.claude\skills\runtime\concurrency-hazard-scanner
```

## Usage

```
/concurrency                    # interactive - prompts for target
/concurrency <project-dir>      # scan specified project
/concurrency -help              # show full usage and stop
```

## Output

Markdown report: concurrency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


