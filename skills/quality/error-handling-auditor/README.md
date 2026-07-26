# error-handling-auditor

**Trigger:** `/error-audit` | **Risk:** read-only | **Audience:** Both

> Error handling auditor: detects 8 anti-patterns (swallowed exceptions, generic catches, missing error handling, missi...

Error handling auditor: detects 8 anti-patterns (swallowed exceptions, generic catches, missing error handling, missing finally, error handling inconsistency, logging without context, ignored return codes, exception type abuse). Risk-tiered report with remediation suggestions.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/quality/error-handling-auditor $HOME/.claude/skills/quality/error-handling-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/quality/error-handling-auditor $HOME\.claude\skills\quality\error-handling-auditor
```

## Usage

```
/error-audit                    # interactive - prompts for target
/error-audit <project-dir>      # scan specified project
/error-audit -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: audit-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


