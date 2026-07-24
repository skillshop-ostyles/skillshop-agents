# test-strategy-designer

**Trigger:** `/test-strategy` | **Risk:** read-only | **Audience:** Senior

> Test strategy analyzer: classifies tests into Unit/Integration/E2E, builds the test pyramid profile (ideal 60/30/10),...

Test strategy analyzer: classifies tests into Unit/Integration/E2E, builds the test pyramid profile (ideal 60/30/10), identifies untested modules, detects overly expensive tests, and recommends optimization priority.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/test-strategy-designer $HOME/.claude/skills/understanding/test-strategy-designer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/test-strategy-designer $HOME\.claude\skills\understanding\test-strategy-designer
```

## Usage

```
/test-strategy                    # interactive - prompts for target
/test-strategy <project-dir>      # scan specified project
/test-strategy -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: strategy-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


