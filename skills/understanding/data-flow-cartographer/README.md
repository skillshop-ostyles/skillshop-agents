# data-flow-cartographer

**Trigger:** `/dataflow` | **Risk:** read-only | **Audience:** Senior

> Traces data flow from input sources (API endpoints, events, files) through transformations to sinks (DB, APIs, logs, ...

Traces data flow from input sources (API endpoints, events, files) through transformations to sinks (DB, APIs, logs, filesystem). Generates Mermaid flow diagrams per data flow with origin, schema changes, validation gaps, and security relevance.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/data-flow-cartographer $HOME/.claude/skills/understanding/data-flow-cartographer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/data-flow-cartographer $HOME\.claude\skills\understanding\data-flow-cartographer
```

## Usage

```
/dataflow                    # interactive - prompts for target
/dataflow <project-dir>      # scan specified project
/dataflow -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: dataflow-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


