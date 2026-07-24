# error-handling-overview

**Trigger:** `/errors-overview` | **Risk:** read-only | **Audience:** Both

> Strategic overview of how a project handles errors: catch-type taxonomy (log/rethrow/swallow/recover/fallback), globa...

Strategic overview of how a project handles errors: catch-type taxonomy (log/rethrow/swallow/recover/fallback), global handlers, error class hierarchy, clustered weaknesses.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/error-handling-overview $HOME/.claude/skills/understanding/error-handling-overview
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/error-handling-overview $HOME\.claude\skills\understanding\error-handling-overview
```

## Usage

```
/errors-overview                    # interactive - prompts for target
/errors-overview <project-dir>      # scan specified project
/errors-overview -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: strategy-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


