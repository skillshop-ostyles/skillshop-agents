# skill-lifecycle

**Trigger:** `/skill-lifecycle` | **Risk:** read-only | **Audience:** Both

> Report on skill age, last modified, git activity, and deprecation status across all clusters.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/_meta/skill-lifecycle $HOME/.claude/skills/_meta/skill-lifecycle
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/_meta/skill-lifecycle $HOME\.claude\skills\_meta\skill-lifecycle
```

## Usage

```
/skill-lifecycle                    # interactive - prompts for target
/skill-lifecycle <project-dir>      # scan specified project
/skill-lifecycle -help              # show full usage and stop
```

## Output

Markdown report: lifecycle-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


