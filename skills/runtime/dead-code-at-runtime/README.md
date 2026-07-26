# dead-code-at-runtime

**Trigger:** `/dead-runtime` | **Risk:** read-only | **Audience:** Both

> Dead code at runtime detector: find feature flags, date gates, and env checks that make code unreachable in practice.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/dead-code-at-runtime $HOME/.claude/skills/runtime/dead-code-at-runtime
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/dead-code-at-runtime $HOME\.claude\skills\runtime\dead-code-at-runtime
```

## Usage

```
/dead-runtime                    # interactive - prompts for target
/dead-runtime <project-dir>      # scan specified project
/dead-runtime -help              # show full usage and stop
```

## Output

Markdown report: runtime-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


