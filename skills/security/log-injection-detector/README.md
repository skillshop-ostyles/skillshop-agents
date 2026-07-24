# log-injection-detector

**Trigger:** `/log-injection` | **Risk:** read-only | **Audience:** Senior

> Log injection detector: harvests every console.log/logger.info/log.Error/etc call, classifies arguments for attacker-...

Log injection detector: harvests every console.log/logger.info/log.Error/etc call, classifies arguments for attacker-controlled input (CWE-117), CRLF injection surface, sensitive data leakage (passwords, tokens, secrets). LLM validates each finding as injectable and proposes sanitization (parameterized logging, newline stripping, sensitive-field redaction).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/log-injection-detector $HOME/.claude/skills/security/log-injection-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/log-injection-detector $HOME\.claude\skills\security\log-injection-detector
```

## Usage

```
/log-injection                    # interactive - prompts for target
/log-injection <project-dir>      # scan specified project
/log-injection -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: injection-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


