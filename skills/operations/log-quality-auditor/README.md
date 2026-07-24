# log-quality-auditor

**Trigger:** `/log-audit` | **Risk:** read-only | **Audience:** Both

> Log quality auditor: inventory every log statement, check for structure, correlation IDs, levels, PII risk, then LLM ...

Log quality auditor: inventory every log statement, check for structure, correlation IDs, levels, PII risk, then LLM judges operational quality.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/log-quality-auditor $HOME/.claude/skills/operations/log-quality-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/log-quality-auditor $HOME\.claude\skills\operations\log-quality-auditor
```

## Usage

```
/log-audit                    # interactive - prompts for target
/log-audit <project-dir>      # scan specified project
/log-audit -help              # show full usage and stop
```

## Output

Markdown report: quality-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


