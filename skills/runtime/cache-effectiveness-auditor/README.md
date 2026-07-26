# cache-effectiveness-auditor

**Trigger:** `/cache-audit` | **Risk:** read-only | **Audience:** Both

> Cache effectiveness auditor: inventory every caching pattern, extract strategy (TTL/invalidation/key design), LLM jud...

Cache effectiveness auditor: inventory every caching pattern, extract strategy (TTL/invalidation/key design), LLM judges if each cache is effective or harmful.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/cache-effectiveness-auditor $HOME/.claude/skills/runtime/cache-effectiveness-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/cache-effectiveness-auditor $HOME\.claude\skills\runtime\cache-effectiveness-auditor
```

## Usage

```
/cache-audit                    # interactive - prompts for target
/cache-audit <project-dir>      # scan specified project
/cache-audit -help              # show full usage and stop
```

## Output

Markdown report: effectiveness-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


