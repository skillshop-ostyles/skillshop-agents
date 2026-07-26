# elevate

**Trigger:** `/elevate` | **Risk:** read-only | **Audience:** Both

> Audits any project for software quality, refactoring readiness, testing, and CI/CD, then automatically elevates it to...

Audits any project for software quality, refactoring readiness, testing, and CI/CD, then automatically elevates it to enterprise level across 7 dimensions (tests+coverage, lint/format, CI/CD, secrets, docs, type-safety/strict, dependency-audit). Generic across stacks and CI systems, runs locally too.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/_meta/elevate $HOME/.claude/skills/_meta/elevate
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/_meta/elevate $HOME\.claude\skills\_meta\elevate
```

## Usage

```
/elevate                    # interactive - prompts for target
/elevate <project-dir>      # scan specified project
/elevate -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: elevate-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


