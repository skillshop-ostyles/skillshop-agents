# runbook-automator

**Trigger:** `/runbook` | **Risk:** read-only | **Audience:** Both

> Runbook automator: generates a deployment runbook from docker-compose.yml, package.json scripts, CI/CD config, health...

Runbook automator: generates a deployment runbook from docker-compose.yml, package.json scripts, CI/CD config, healthcheck endpoints, Dockerfile, and README shell commands. Collector scans all five surfaces; LLM assembles a structured runbook with setup, dev workflow, deployment, healthcheck, crash recovery, CI/CD description, and troubleshooting.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/runbook-automator $HOME/.claude/skills/understanding/runbook-automator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/runbook-automator $HOME\.claude\skills\understanding\runbook-automator
```

## Usage

```
/runbook                    # interactive - prompts for target
/runbook <project-dir>      # scan specified project
/runbook -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: runbook-automator-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


