# side-effect-ordering

**Trigger:** `/sideorder` | **Risk:** read-only | **Audience:** Both

> Side-effect ordering analyzer: map operation chains in request handlers, LLM judges if ordering is safe or an inciden...

Side-effect ordering analyzer: map operation chains in request handlers, LLM judges if ordering is safe or an incident waiting to happen.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/runtime/side-effect-ordering $HOME/.claude/skills/runtime/side-effect-ordering
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/runtime/side-effect-ordering $HOME\.claude\skills\runtime\side-effect-ordering
```

## Usage

```
/sideorder                    # interactive - prompts for target
/sideorder <project-dir>      # scan specified project
/sideorder -help              # show full usage and stop
```

## Output

Markdown report: ordering-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


