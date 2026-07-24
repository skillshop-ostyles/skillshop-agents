# llm-call-observability-gap

**Trigger:** `/llm-obs` | **Risk:** read-only | **Audience:** Both

> Find LLM API calls that lack observability — no logging, error handling, timeout, or cost tracking.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/llm-call-observability-gap $HOME/.claude/skills/ai-ml/llm-call-observability-gap
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/llm-call-observability-gap $HOME\.claude\skills\ai-ml\llm-call-observability-gap
```

## Usage

```
/llm-obs                    # interactive - prompts for target
/llm-obs <project-dir>      # scan specified project
/llm-obs -help              # show full usage and stop
```

## Output

Markdown report: observability-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


