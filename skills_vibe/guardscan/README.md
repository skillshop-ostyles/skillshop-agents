# guardscan

**Trigger:** `/guardscan` | **Risk:** read-only | **Audience:** Vibe

> Security primitive coach: 7 detectors for common vulnerabilities in fullstack apps. Interactive wizard + batch mode.

Guardscan checks your project for 7 common security issues — RLS policies, auth middleware, CSRF protection, secrets in code, env validation, client-side auth, security headers. Interactive coaching with fix mode.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/guardscan $HOME/.claude/skills_vibe/guardscan
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/guardscan $HOME\.claude\skills_vibe\guardscan
```

## Usage

```
/guardscan                  # interactive wizard
/guardscan quick            # all 7 checks at once
/guardscan rls              # Row-Level Security policies
/guardscan authmiddleware   # auth middleware checks
/guardscan csrf             # CSRF protection
/guardscan secrets          # secret leakage
/guardscan envvalidation    # env validation
/guardscan clientauth       # client-side auth
/guardscan headers          # security headers
/guardscan -help            # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code
