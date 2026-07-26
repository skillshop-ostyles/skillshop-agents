# deployment-drift-detector

**Trigger:** `/deploy-drift` | **Risk:** read-only | **Audience:** Both

> Deployment drift detector: extracted deployed config (kubectl, terraform show, docker inspect) vs source-of-truth man...

Deployment drift detector: extracted deployed config (kubectl, terraform show, docker inspect) vs source-of-truth manifests, then LLM judges each drift's criticality in business context.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/operations/deployment-drift-detector $HOME/.claude/skills/operations/deployment-drift-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/operations/deployment-drift-detector $HOME\.claude\skills\operations\deployment-drift-detector
```

## Usage

```
/deploy-drift                    # interactive - prompts for target
/deploy-drift <project-dir>      # scan specified project
/deploy-drift -help              # show full usage and stop
```

## Output

Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


