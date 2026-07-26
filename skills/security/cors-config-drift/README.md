# cors-config-drift

**Trigger:** `/cors-drift` | **Risk:** read-only | **Audience:** Senior

> CORS config drift scanner: harvests every Access-Control-Allow-Origin header, cors()-middleware call, @cross_origin d...

CORS config drift scanner: harvests every Access-Control-Allow-Origin header, cors()-middleware call, @cross_origin decorator, options-handler with cors config, and per-route origin/credentials settings. LLM analyses each per-route CORS posture: credentials+wildcard = fatal, permissive origin patterns, preflight gaps.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/cors-config-drift $HOME/.claude/skills/security/cors-config-drift
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/cors-config-drift $HOME\.claude\skills\security\cors-config-drift
```

## Usage

```
/cors-drift                    # interactive - prompts for target
/cors-drift <project-dir>      # scan specified project
/cors-drift -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


