# prompt-drift-tracker

**Trigger:** `/prompt-drift` | **Risk:** read-only | **Audience:** Both

> Track prompt changes across git history and flag drift that affects output quality or safety.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/prompt-drift-tracker $HOME/.claude/skills/ai-ml/prompt-drift-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/prompt-drift-tracker $HOME\.claude\skills\ai-ml\prompt-drift-tracker
```

## Usage

```
/prompt-drift                    # interactive - prompts for target
/prompt-drift <project-dir>      # scan specified project
/prompt-drift -help              # show full usage and stop
```

## Output

Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


