# security-smell-scanner

**Trigger:** `/security-scan` | **Risk:** read-only | **Audience:** Senior > Vibe

> Security smell scanner: statically detects 10 families of security anti-patterns across a codebase (SQL injection, XS...

Security smell scanner: statically detects 10 families of security anti-patterns across a codebase (SQL injection, XSS, command injection, path traversal, hardcoded credentials, insecure defaults, IDOR, open redirect, TOCTOU, missing input validation). Produces an evidence-backed report with severity, location, and contextual analysis. > Vibe. Cross-link from quality/ cluster.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/security-smell-scanner $HOME/.claude/skills/security/security-smell-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/security-smell-scanner $HOME\.claude\skills\security\security-smell-scanner
```

## Usage

```
/security-scan                    # interactive - prompts for target
/security-scan <project-dir>      # scan specified project
/security-scan -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Console summary with key metrics | Markdown report: smell-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


