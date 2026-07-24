# llm-cost-controller

**Trigger:** `/llm-cost` | **Risk:** read-only | **Audience:** Senior

> LLM cost controller: audits all LLM API calls in a codebase, detects cost anti-patterns (expensive models, unlimited ...

LLM cost controller: audits all LLM API calls in a codebase, detects cost anti-patterns (expensive models, unlimited tokens, no caching, batchable calls), and estimates monthly spend with optimization savings.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/llm-cost-controller $HOME/.claude/skills/ai-ml/llm-cost-controller
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/llm-cost-controller $HOME\.claude\skills\ai-ml\llm-cost-controller
```

## Usage

```
/llm-cost                    # interactive - prompts for target
/llm-cost <project-dir>      # scan specified project
/llm-cost -help              # show full usage and stop
```

## Output

Markdown report: cost-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


