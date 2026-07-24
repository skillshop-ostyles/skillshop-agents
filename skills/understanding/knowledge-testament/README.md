# knowledge-testament

**Trigger:** `/testament` | **Risk:** read-only | **Audience:** Both

> Knowledge testament: mines git blame/log to map where one developer's exclusive knowledge lives (sole-author hotspots...

Knowledge testament: mines git blame/log to map where one developer's exclusive knowledge lives (sole-author hotspots, high-churn areas they own), generates a targeted interview asking exactly the questions nobody would know to ask, and writes a structured, code-linked testament document. towards the repo.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/knowledge-testament $HOME/.claude/skills/understanding/knowledge-testament
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/knowledge-testament $HOME\.claude\skills\understanding\knowledge-testament
```

## Usage

```
/testament                    # interactive - prompts for target
/testament <project-dir>      # scan specified project
/testament -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: knowledge-testament-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


