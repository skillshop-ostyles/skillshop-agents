# dockerfile-best-practices

**Trigger:** `/dockerfile-audit` | **Risk:** read-only | **Audience:** Both

> Dockerfile best-practices auditor: statically scans Dockerfiles for 18 common anti-patterns including unpinned base i...

Dockerfile best-practices auditor: statically scans Dockerfiles for 18 common anti-patterns including unpinned base images, root execution, missing HEALTHCHECK, excessive layers, package cache bloat, and hardcoded secrets. Produces an evidence-backed report with severity and remediation.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/dockerfile-best-practices $HOME/.claude/skills/operations/dockerfile-best-practices
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/dockerfile-best-practices $HOME\.claude\skills\operations\dockerfile-best-practices
```

## Usage

```
/dockerfile-audit                    # interactive - prompts for target
/dockerfile-audit <project-dir>      # scan specified project
/dockerfile-audit -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: dockerfile-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


