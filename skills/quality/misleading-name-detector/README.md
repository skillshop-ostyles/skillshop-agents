# misleading-name-detector

**Trigger:** `/name-lies` | **Risk:** read-only | **Audience:** Both

> Misleading name detector: harvests every prefixed function with reader/mutator/predicate cues (get*/find*/fetch*/set*...

Misleading name detector: harvests every prefixed function with reader/mutator/predicate cues (get*/find*/fetch*/set*/write*/is*/has*/can*/...) and extracts the first 600 chars of brace-balanced body. LLM judges whether the code does what the name promises. Severity scales with call count and visibility.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/misleading-name-detector $HOME/.claude/skills/quality/misleading-name-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/misleading-name-detector $HOME\.claude\skills\quality\misleading-name-detector
```

## Usage

```
/name-lies                    # interactive - prompts for target
/name-lies <project-dir>      # scan specified project
/name-lies -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: lies-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


