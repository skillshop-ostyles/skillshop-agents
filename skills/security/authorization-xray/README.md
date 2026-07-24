# authorization-xray

**Trigger:** `/authz` | **Risk:** read-only | **Audience:** Senior

> Authorization X-ray for your own codebase (defensive audit): inventories every HTTP endpoint and every recognizable p...

Authorization X-ray for your own codebase (defensive audit): inventories every HTTP endpoint and every recognizable protection layer (middleware chains, authorize decorators, inline role checks, router mounts), builds the permission matrix endpoint x required check, and reports unprotected mutating endpoints and inconsistent protection of similar resources. Static, sends no requests.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/authorization-xray $HOME/.claude/skills/security/authorization-xray
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/authorization-xray $HOME\.claude\skills\security\authorization-xray
```

## Usage

```
/authz                    # interactive - prompts for target
/authz <project-dir>      # scan specified project
/authz -help              # show full usage and stop
```

## Output

Markdown report: authz-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


