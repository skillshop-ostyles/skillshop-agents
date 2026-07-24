# runbook-auditor

**Trigger:** `/runbook-audit` | **Risk:** read-only | **Audience:** Both

> Runbook auditor: read runbook files, extract verifiable claims, check each against current codebase. LLM judges corre...

Runbook auditor: read runbook files, extract verifiable claims, check each against current codebase. LLM judges correctness and completeness.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/runbook-auditor $HOME/.claude/skills/operations/runbook-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/runbook-auditor $HOME\.claude\skills\operations\runbook-auditor
```

## Usage

```
/runbook-audit                    # interactive - prompts for target
/runbook-audit <project-dir>      # scan specified project
/runbook-audit -help              # show full usage and stop
```

## Output

Markdown report: quality-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


