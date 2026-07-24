# dependency-runtime-availability

**Trigger:** `/runtime-deps` | **Risk:** read-only | **Audience:** Both

> Dependency runtime availability checker: find dynamic imports and runtime resource references that fail in production.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/runtime/dependency-runtime-availability $HOME/.claude/skills/runtime/dependency-runtime-availability
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/runtime/dependency-runtime-availability $HOME\.claude\skills\runtime\dependency-runtime-availability
```

## Usage

```
/runtime-deps                    # interactive - prompts for target
/runtime-deps <project-dir>      # scan specified project
/runtime-deps -help              # show full usage and stop
```

## Output

Markdown report: dependency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


