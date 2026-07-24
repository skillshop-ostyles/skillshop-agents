# process-lifetime-tracker

**Trigger:** `/lifetime` | **Risk:** read-only | **Audience:** Both

> Process lifetime tracker: map every process/service/daemon, trace shutdown paths, LLM judges graceful shutdown readin...

Process lifetime tracker: map every process/service/daemon, trace shutdown paths, LLM judges graceful shutdown readiness.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/runtime/process-lifetime-tracker $HOME/.claude/skills/runtime/process-lifetime-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/runtime/process-lifetime-tracker $HOME\.claude\skills\runtime\process-lifetime-tracker
```

## Usage

```
/lifetime                    # interactive - prompts for target
/lifetime <project-dir>      # scan specified project
/lifetime -help              # show full usage and stop
```

## Output

Markdown report: lifetime-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


