# shipcheck

**Trigger:** `/shipcheck` | **Risk:** read-only / write-on-approval | **Audience:** Vibe

> Pre-ship coach: checks env, build, secrets across your fullstack project. Interactive wizard + batch mode.

Before you ship: 3 critical checks in 30 seconds. Shipcheck validates environment variables, build health, and secret leakage — then coaches you through fixing each finding.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/shipcheck $HOME/.claude/skills_vibe/shipcheck
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/shipcheck $HOME\.claude\skills_vibe\shipcheck
```

## Usage

```
/shipcheck                  # interactive wizard
/shipcheck quick            # all 3 checks at once
/shipcheck env              # environment variables only
/shipcheck build            # build health only
/shipcheck secrets          # secret leakage only
/shipcheck -help            # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code
