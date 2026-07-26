# smoke-coverage

**Trigger:** `/smoke-coverage` | **Risk:** read-only | **Audience:** Both

> Audit smoke test coverage across all skills. Report which have tests, which don't, and which test scripts actually run.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/_meta/smoke-coverage $HOME/.claude/skills/_meta/smoke-coverage
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/_meta/smoke-coverage $HOME\.claude\skills\_meta\smoke-coverage
```

## Usage

```
/smoke-coverage                    # interactive - prompts for target
/smoke-coverage <project-dir>      # scan specified project
/smoke-coverage -help              # show full usage and stop
```

## Output

Markdown report: coverage-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


