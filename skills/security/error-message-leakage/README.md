# error-message-leakage

**Trigger:** `/error-leakage` | **Risk:** read-only | **Audience:** Both

> Error message leakage detector: harvests every HTTP-error-return and log-error-call, classifies what kind of informat...

Error message leakage detector: harvests every HTTP-error-return and log-error-call, classifies what kind of information leaks (stacktrace, SQL error message, env-vars, user input echo, request dump). LLM validates each finding as legitimate production-leak and proposes sanitization.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/error-message-leakage $HOME/.claude/skills/security/error-message-leakage
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/error-message-leakage $HOME\.claude\skills\security\error-message-leakage
```

## Usage

```
/error-leakage                    # interactive - prompts for target
/error-leakage <project-dir>      # scan specified project
/error-leakage -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: leakage-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


