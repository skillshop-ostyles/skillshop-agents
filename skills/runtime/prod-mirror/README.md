# prod-mirror

**Trigger:** `/mirror` | **Risk:** read-only | **Audience:** Both

> Production behavior mirror: ingests exported log files (text or JSON lines), statistically condenses them (frequencie...

Production behavior mirror: ingests exported log files (text or JSON lines), statistically condenses them (frequencies, error rates, hot paths), extracts the code's expectations (log statements, catch blocks, routes), then has the LLM report the deltas - dead features, swallowed errors firing daily, unexpected hot paths. Works fully offline on exported logs.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/prod-mirror $HOME/.claude/skills/runtime/prod-mirror
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/prod-mirror $HOME\.claude\skills\runtime\prod-mirror
```

## Usage

```
/mirror                    # interactive - prompts for target
/mirror <project-dir>      # scan specified project
/mirror -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: mirror-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


