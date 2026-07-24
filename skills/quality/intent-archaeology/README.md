# intent-archaeology

**Trigger:** `/intent` | **Risk:** read-only | **Audience:** Both

> Reconstructs WHY code exists the way it does: mines git history (log -follow, blame, ticket references) for a file or...

Reconstructs WHY code exists the way it does: mines git history (log -follow, blame, ticket references) for a file or symbol, then has the LLM rebuild the intent story with commit-level evidence and confidence ratings.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/intent-archaeology $HOME/.claude/skills/quality/intent-archaeology
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/intent-archaeology $HOME\.claude\skills\quality\intent-archaeology
```

## Usage

```
/intent                    # interactive - prompts for target
/intent <project-dir>      # scan specified project
/intent -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: intent-archaeology-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


