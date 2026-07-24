# dead-code-burier

**Trigger:** `/bury` | **Risk:** read-only | **Audience:** Both

> Dead-path undertaker: identifies provably unreachable code by combining static reachability (unreferenced exports/fil...

Dead-path undertaker: identifies provably unreachable code by combining static reachability (unreferenced exports/files), optional runtime evidence (coverage reports, logs) and git age, then produces a burial list ranked by evidence strength. NEVER deletes automatically - prepares patches for individual user approval only.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/dead-code-burier $HOME/.claude/skills/quality/dead-code-burier
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/dead-code-burier $HOME\.claude\skills\quality\dead-code-burier
```

## Usage

```
/bury                    # interactive - prompts for target
/bury <project-dir>      # scan specified project
/bury -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: bury-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


