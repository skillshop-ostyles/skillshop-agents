# test-honesty-auditor

**Trigger:** `/test-honesty` | **Risk:** read-only | **Audience:** Both

> Test honesty auditor: statically detects 6 categories of tests-that-cannot-fail (zero-assertion tests, tautological a...

Test honesty auditor: statically detects 6 categories of tests-that-cannot-fail (zero-assertion tests, tautological assertions, tests that assert on their own mocks, try-around-assert swallowing, rotting disabled/skipped tests, ambiguous disabled-state). Auto-bucketizes each test, then LLM judges which actually pin down behavior vs. which pass by accident. Risk-tiered report with proposed minimal fixes.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/test-honesty-auditor $HOME/.claude/skills/quality/test-honesty-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/test-honesty-auditor $HOME\.claude\skills\quality\test-honesty-auditor
```

## Usage

```
/test-honesty                    # interactive - prompts for target
/test-honesty <project-dir>      # scan specified project
/test-honesty -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: honesty-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


