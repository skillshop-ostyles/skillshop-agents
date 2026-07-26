# runtime-type-mismatch

**Trigger:** `/type-mismatch` | **Risk:** read-only | **Audience:** Both

> Runtime type mismatch detector: find every runtime type assumption, LLM judges which will fail in production.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/runtime-type-mismatch $HOME/.claude/skills/runtime/runtime-type-mismatch
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/runtime-type-mismatch $HOME\.claude\skills\runtime\runtime-type-mismatch
```

## Usage

```
/type-mismatch                    # interactive - prompts for target
/type-mismatch <project-dir>      # scan specified project
/type-mismatch -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: mismatch-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


