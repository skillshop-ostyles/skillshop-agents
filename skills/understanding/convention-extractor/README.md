# convention-extractor

**Trigger:** `/conventions` | **Risk:** read-only | **Audience:** Both

> Extracts implicit coding conventions from code patterns: naming style, import style, async patterns, error handling, ...

Extracts implicit coding conventions from code patterns: naming style, import style, async patterns, error handling, null handling. Quantifies each convention by consistency score and surfaces deviations.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/convention-extractor $HOME/.claude/skills/understanding/convention-extractor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/convention-extractor $HOME\.claude\skills\understanding\convention-extractor
```

## Usage

```
/conventions                    # interactive - prompts for target
/conventions <project-dir>      # scan specified project
/conventions -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: convention-extractor-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


