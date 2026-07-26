# ml-pipeline-determinism-check

**Trigger:** `/ml-determinism` | **Risk:** read-only | **Audience:** Both

> Find sources of non-determinism in ML training pipelines.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/ai-ml/ml-pipeline-determinism-check $HOME/.claude/skills/ai-ml/ml-pipeline-determinism-check
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/ai-ml/ml-pipeline-determinism-check $HOME\.claude\skills\ai-ml\ml-pipeline-determinism-check
```

## Usage

```
/ml-determinism                    # interactive - prompts for target
/ml-determinism <project-dir>      # scan specified project
/ml-determinism -help              # show full usage and stop
```

## Output

Markdown report: determinism-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


