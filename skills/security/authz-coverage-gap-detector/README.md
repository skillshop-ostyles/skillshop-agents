# authz-coverage-gap-detector

**Trigger:** `/authz-coverage` | **Risk:** read-only | **Audience:** Senior

> Finds mutating endpoints that lack explicit authorization, relying solely on middleware inheritance - the dangerous g...

Finds mutating endpoints that lack explicit authorization, relying solely on middleware inheritance - the dangerous gaps where middleware failure leaves endpoints unprotected.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/authz-coverage-gap-detector $HOME/.claude/skills/security/authz-coverage-gap-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/authz-coverage-gap-detector $HOME\.claude\skills\security\authz-coverage-gap-detector
```

## Usage

```
/authz-coverage                    # interactive - prompts for target
/authz-coverage <project-dir>      # scan specified project
/authz-coverage -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: coverage-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


