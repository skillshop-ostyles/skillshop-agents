# input-validation-audit

**Trigger:** `/input-audit` | **Risk:** read-only | **Audience:** Senior > Vibe

> Input validation audit: statically detects all input surfaces (HTTP params, CLI args, env vars, file reads, stdin) ac...

Input validation audit: statically detects all input surfaces (HTTP params, CLI args, env vars, file reads, stdin) across a codebase, classifies their validation state (none/weak/adequate), and flags high-risk gaps. Produces an evidence-backed report with severity, location, and remediation suggestions.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/input-validation-audit $HOME/.claude/skills/security/input-validation-audit
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/input-validation-audit $HOME\.claude\skills\security\input-validation-audit
```

## Usage

```
/input-audit                    # interactive - prompts for target
/input-audit <project-dir>      # scan specified project
/input-audit -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: validation-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


