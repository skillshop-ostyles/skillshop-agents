# tech-debt-narrator

**Trigger:** `/tech-debt` | **Risk:** read-only | **Audience:** Senior

> Tech-debt narrator: finds suppress comments, TODOs, empty catches, workarounds, legacy imports, and type-loosening pa...

Tech-debt narrator: finds suppress comments, TODOs, empty catches, workarounds, legacy imports, and type-loosening patterns. Clusters them into logical groups and narrates repayment strategies with effort estimates. Collector scans for 6 debt types with file-level git age; LLM clusters, narrates, and estimates.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/tech-debt-narrator $HOME/.claude/skills/understanding/tech-debt-narrator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/tech-debt-narrator $HOME\.claude\skills\understanding\tech-debt-narrator
```

## Usage

```
/tech-debt                    # interactive - prompts for target
/tech-debt <project-dir>      # scan specified project
/tech-debt -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: debt-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


