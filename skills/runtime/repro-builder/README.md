# repro-builder

**Trigger:** `/repro` | **Risk:** read-only | **Audience:** Both

> Turns a vague bug report into a minimal, runnable reproduction: extracts hypotheses from the report text, snapshots t...

Turns a vague bug report into a minimal, runnable reproduction: extracts hypotheses from the report text, snapshots the environment, generates a repro test/script, EXECUTES it and iterates (max 5 attempts) until the bug demonstrably reproduces - or documents precisely which information is missing. The repro lives outside the target project.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/repro-builder $HOME/.claude/skills/runtime/repro-builder
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/repro-builder $HOME\.claude\skills\runtime\repro-builder
```

## Usage

```
/repro                    # interactive - prompts for target
/repro <project-dir>      # scan specified project
/repro -help              # show full usage and stop
```

## Output

Markdown report: repro-builder-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


