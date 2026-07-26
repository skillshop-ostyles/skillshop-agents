# mock-production-gap

**Trigger:** `/mock-gap` | **Risk:** read-only | **Audience:** Both

> Mock-production gap detector: compare test mocks against real implementations, LLM judges dangerous divergences.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/mock-production-gap $HOME/.claude/skills/runtime/mock-production-gap
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/mock-production-gap $HOME\.claude\skills\runtime\mock-production-gap
```

## Usage

```
/mock-gap                    # interactive - prompts for target
/mock-gap <project-dir>      # scan specified project
/mock-gap -help              # show full usage and stop
```

## Output

Markdown report: gap-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


