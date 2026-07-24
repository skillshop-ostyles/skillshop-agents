# leak-detector

**Trigger:** `/leak-scan` | **Risk:** read-only | **Audience:** Both

> Leak detector: trace resource acquisition and release across code paths, LLM classifies each as clean/leaky/uncertain.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/leak-detector $HOME/.claude/skills/operations/leak-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/leak-detector $HOME\.claude\skills\operations\leak-detector
```

## Usage

```
/leak-scan                    # interactive - prompts for target
/leak-scan <project-dir>      # scan specified project
/leak-scan -help              # show full usage and stop
```

## Output

Markdown report: leak-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


