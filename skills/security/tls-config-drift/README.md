# tls-config-drift

**Trigger:** `/ssl-drift` | **Risk:** read-only | **Audience:** Senior

> TLS config drift scanner: harvests every TLS-version constant, cipher-suite array, cert-pinning call, mTLS flag, cert...

TLS config drift scanner: harvests every TLS-version constant, cipher-suite array, cert-pinning call, mTLS flag, cert-validation callback, and FIPS-mode setting. LLM analyses each statement as acceptable, misconfigured, or downgrade-prone when an element is missing.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/tls-config-drift $HOME/.claude/skills/security/tls-config-drift
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/tls-config-drift $HOME\.claude\skills\security\tls-config-drift
```

## Usage

```
/ssl-drift                    # interactive - prompts for target
/ssl-drift <project-dir>      # scan specified project
/ssl-drift -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


