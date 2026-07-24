# session-state-anomaly

**Trigger:** `/session-anomaly` | **Risk:** read-only | **Audience:** Senior

> Session state anomaly scanner: finds every session-generation, session-id usage, post-auth session-regeneration, post...

Session state anomaly scanner: finds every session-generation, session-id usage, post-auth session-regeneration, post-logout cleanup, and refresh-token rotation site. LLM per finding: regen? invalidate? rotated? What attack arises if not?

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/session-state-anomaly $HOME/.claude/skills/security/session-state-anomaly
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/session-state-anomaly $HOME\.claude\skills\security\session-state-anomaly
```

## Usage

```
/session-anomaly                    # interactive - prompts for target
/session-anomaly <project-dir>      # scan specified project
/session-anomaly -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: state-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


