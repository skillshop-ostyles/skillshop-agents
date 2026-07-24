# training-data-leakage-detector

**Trigger:** `/train-leak` | **Risk:** read-only | **Audience:** Both

> Training data leakage detector: find cross-contamination between train/test splits in ML pipelines.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/training-data-leakage-detector $HOME/.claude/skills/ai-ml/training-data-leakage-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/training-data-leakage-detector $HOME\.claude\skills\ai-ml\training-data-leakage-detector
```

## Usage

```
/train-leak                    # interactive - prompts for target
/train-leak <project-dir>      # scan specified project
/train-leak -help              # show full usage and stop
```

## Output

Markdown report: leakage-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


