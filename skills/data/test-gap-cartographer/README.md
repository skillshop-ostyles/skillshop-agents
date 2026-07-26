# test-gap-cartographer

**Trigger:** `/testgap` | **Risk:** read-only | **Audience:** Senior

> Semantic test gap mapper: inventories the public code surface (exports, routes) and all existing tests, then has the ...

Semantic test gap mapper: inventories the public code surface (exports, routes) and all existing tests, then has the LLM map which BEHAVIORS of each public symbol are covered by which test and which are not - reporting untested behaviors (edge cases, error paths, boundaries) ranked by risk, with proposed test case names. Static, never runs tests.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/test-gap-cartographer $HOME/.claude/skills/data/test-gap-cartographer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/test-gap-cartographer $HOME\.claude\skills\data\test-gap-cartographer
```

## Usage

```
/testgap                    # interactive - prompts for target
/testgap <project-dir>      # scan specified project
/testgap -help              # show full usage and stop
```

## Output

Markdown report: testgap-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


