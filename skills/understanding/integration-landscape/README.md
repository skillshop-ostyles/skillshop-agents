# integration-landscape

**Trigger:** `/integrations` | **Risk:** read-only | **Audience:** Senior

> Maps every external integration from code: HTTP APIs, databases, message queues, storage. Classifies protocol, auth t...

Maps every external integration from code: HTTP APIs, databases, message queues, storage. Classifies protocol, auth type, criticality, retry/fallback coverage.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/understanding/integration-landscape $HOME/.claude/skills/understanding/integration-landscape
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/understanding/integration-landscape $HOME\.claude\skills\understanding\integration-landscape
```

## Usage

```
/integrations                    # interactive - prompts for target
/integrations <project-dir>      # scan specified project
/integrations -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: integration-landscape-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


