# healthcheck-mapper

**Trigger:** `/healthcheck` | **Risk:** read-only | **Audience:** Both

> Healthcheck mapper: inventory all health/readiness/liveness endpoints, map against service dependencies, LLM judges e...

Healthcheck mapper: inventory all health/readiness/liveness endpoints, map against service dependencies, LLM judges each as adequate/weak/missing.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/operations/healthcheck-mapper $HOME/.claude/skills/operations/healthcheck-mapper
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/operations/healthcheck-mapper $HOME\.claude\skills\operations\healthcheck-mapper
```

## Usage

```
/healthcheck                    # interactive - prompts for target
/healthcheck <project-dir>      # scan specified project
/healthcheck -help              # show full usage and stop
```

## Output

Markdown report: healthcheck-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


