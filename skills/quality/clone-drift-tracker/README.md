# clone-drift-tracker

**Trigger:** `/clone-drift` | **Risk:** read-only | **Audience:** Senior

> Clone drift tracker: detects code blocks that USED to be clones (identical at past git ref) and have since drifted ap...

Clone drift tracker: detects code blocks that USED to be clones (identical at past git ref) and have since drifted apart. Mines git history to compare function-body hashes between HEAD and HEAD~N (default 100), and reports pairs whose semantics diverged on one side but not the other.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/clone-drift-tracker $HOME/.claude/skills/quality/clone-drift-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/clone-drift-tracker $HOME\.claude\skills\quality\clone-drift-tracker
```

## Usage

```
/clone-drift                    # interactive - prompts for target
/clone-drift <project-dir>      # scan specified project
/clone-drift -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


