# third-party-trust

**Trigger:** `/third-party-trust` | **Risk:** read-only | **Audience:** Senior

> Third-party trust boundary analyzer: inventories every outbound HTTP/RPC call (fetch, axios, got, requests, curl, Inv...

Third-party trust boundary analyzer: inventories every outbound HTTP/RPC call (fetch, axios, got, requests, curl, Invoke-RestMethod). For each, identifies literal-vs-template URL, classifies known-trusted vs unknown domain, detects auth-header presence in call window, flags webhook handlers missing signature verification.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/third-party-trust $HOME/.claude/skills/security/third-party-trust
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/third-party-trust $HOME\.claude\skills\security\third-party-trust
```

## Usage

```
/third-party-trust                    # interactive - prompts for target
/third-party-trust <project-dir>      # scan specified project
/third-party-trust -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: trust-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


