# domain-narrator

**Trigger:** `/explain` | **Risk:** read-only | **Audience:** Both

> Domain narrator: reads all public symbols in a codebase, clusters them by call-graph density into business domains, a...

Domain narrator: reads all public symbols in a codebase, clusters them by call-graph density into business domains, and writes plain-English descriptions of what each domain does. Collector extracts public symbols and call graphs; LLM per cluster produces domain name, business responsibility (1-2 sentences), and business rules extracted from code.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/domain-narrator $HOME/.claude/skills/understanding/domain-narrator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/domain-narrator $HOME\.claude\skills\understanding\domain-narrator
```

## Usage

```
/explain                    # interactive - prompts for target
/explain <project-dir>      # scan specified project
/explain -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: domain-narrator-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


