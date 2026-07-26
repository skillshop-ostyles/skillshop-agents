# shutdown-gracefulness

**Trigger:** `/shutdown` | **Risk:** read-only | **Audience:** Both

> Shutdown gracefulness analyzer: check if shutdown hooks actually drain, flush, and complete in-flight work.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/shutdown-gracefulness $HOME/.claude/skills/runtime/shutdown-gracefulness
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/shutdown-gracefulness $HOME\.claude\skills\runtime\shutdown-gracefulness
```

## Usage

```
/shutdown                    # interactive - prompts for target
/shutdown <project-dir>      # scan specified project
/shutdown -help              # show full usage and stop
```

## Output

Markdown report: grade-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


