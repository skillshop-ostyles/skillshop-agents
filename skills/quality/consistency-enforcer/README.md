# consistency-enforcer

**Trigger:** `/consist` | **Risk:** read-only | **Audience:** Both

> Finds duplicated BUSINESS LOGIC (not duplicated text): extracts rule candidates (validations, calculations, domain co...

Finds duplicated BUSINESS LOGIC (not duplicated text): extracts rule candidates (validations, calculations, domain constants, regexes, status logic) from a codebase, then has the LLM cluster semantically equal rules across different implementations and flag divergent ones with a single-source-of-truth proposal.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/consistency-enforcer $HOME/.claude/skills/quality/consistency-enforcer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/consistency-enforcer $HOME\.claude\skills\quality\consistency-enforcer
```

## Usage

```
/consist                    # interactive - prompts for target
/consist <project-dir>      # scan specified project
/consist -help              # show full usage and stop
```

## Output

Markdown report: consist-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


