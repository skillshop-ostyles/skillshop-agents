# token-budget-analyzer

**Trigger:** `/token-budget` | **Risk:** read-only | **Audience:** Both

> Analyze static code for token usage patterns, waste, and budget risks.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/ai-ml/token-budget-analyzer $HOME/.claude/skills/ai-ml/token-budget-analyzer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/ai-ml/token-budget-analyzer $HOME\.claude\skills\ai-ml\token-budget-analyzer
```

## Usage

```
/token-budget                    # interactive - prompts for target
/token-budget <project-dir>      # scan specified project
/token-budget -help              # show full usage and stop
```

## Output

Markdown report: budget-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


