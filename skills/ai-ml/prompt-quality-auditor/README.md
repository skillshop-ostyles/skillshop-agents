# prompt-quality-auditor

**Trigger:** `/prompt-quality` | **Risk:** read-only | **Audience:** Both

> Prompt quality auditor: audit every prompt for clarity, safety, and injection resistance.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/prompt-quality-auditor $HOME/.claude/skills/ai-ml/prompt-quality-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/prompt-quality-auditor $HOME\.claude\skills\ai-ml\prompt-quality-auditor
```

## Usage

```
/prompt-quality                    # interactive - prompts for target
/prompt-quality <project-dir>      # scan specified project
/prompt-quality -help              # show full usage and stop
```

## Output

Markdown report: quality-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


