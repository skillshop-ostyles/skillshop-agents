# data-trail-tracker

**Trigger:** `/data-trail-tracker` | **Risk:** read-only | **Audience:** Both

> Maps PII fields and their sinks - logs, third-party APIs, exports - purely via field names, never via actual data.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/data-trail-tracker $HOME/.claude/skills/security/data-trail-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/data-trail-tracker $HOME\.claude\skills\security\data-trail-tracker
```

## Usage

```
/data-trail-tracker                    # interactive - prompts for target
/data-trail-tracker <project-dir>      # scan specified project
/data-trail-tracker -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: trail-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


