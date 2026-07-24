# backup-coverage-scanner

**Trigger:** `/backup-scan` | **Risk:** read-only | **Audience:** Both

> Backup coverage scanner: inventory every stateful resource, trace backup configuration for each, then LLM identifies ...

Backup coverage scanner: inventory every stateful resource, trace backup configuration for each, then LLM identifies critical gaps.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/backup-coverage-scanner $HOME/.claude/skills/operations/backup-coverage-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/backup-coverage-scanner $HOME\.claude\skills\operations\backup-coverage-scanner
```

## Usage

```
/backup-scan                    # interactive - prompts for target
/backup-scan <project-dir>      # scan specified project
/backup-scan -help              # show full usage and stop
```

## Output

Markdown report: coverage-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


