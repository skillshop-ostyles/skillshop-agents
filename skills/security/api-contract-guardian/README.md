# api-contract-guardian

**Trigger:** `/api-diff` | **Risk:** read-only | **Audience:** Senior

> API contract guard: extracts the API surface (HTTP routes with params, DTO fields, exported signatures - preferring O...

API contract guard: extracts the API surface (HTTP routes with params, DTO fields, exported signatures - preferring OpenAPI files when present) from two git states of a repo, diffs them, classifies every change as breaking / non-breaking / additive, and writes a ready-to-ship consumer migration note per breaking change.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/api-contract-guardian $HOME/.claude/skills/security/api-contract-guardian
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/api-contract-guardian $HOME\.claude\skills\security\api-contract-guardian
```

## Usage

```
/api-diff                    # interactive - prompts for target
/api-diff <project-dir>      # scan specified project
/api-diff -help              # show full usage and stop
```

## Output

Markdown report: diff-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


