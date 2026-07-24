# api-footgun-reviewer

**Trigger:** `/footguns` | **Risk:** read-only | **Audience:** Senior > Vibe

> API footgun reviewer: harvests exported function/method signatures, flags boolean-trap positions (multiple bare bool ...

API footgun reviewer: harvests exported function/method signatures, flags boolean-trap positions (multiple bare bool params in a row), same-type-adjacent swaps (from/to, save/loadUntil), and inconsistent family conventions (create*/update* with different param orders or arities). > Vibe.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/api-footgun-reviewer $HOME/.claude/skills/quality/api-footgun-reviewer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/api-footgun-reviewer $HOME\.claude\skills\quality\api-footgun-reviewer
```

## Usage

```
/footguns                    # interactive - prompts for target
/footguns <project-dir>      # scan specified project
/footguns -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: footgun-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


