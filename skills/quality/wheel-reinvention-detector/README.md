# wheel-reinvention-detector

**Trigger:** `/reinvented-wheels` | **Risk:** read-only | **Audience:** Both

> Wheel reinvention detector: harvests exported short utility functions (≤40 lines, no class state) and pairs each with...

Wheel reinvention detector: harvests exported short utility functions (≤40 lines, no class state) and pairs each with the project's installed libraries (package.json, requirements.txt) plus language stdlib hints. LLM judges whether each candidate semantically duplicates an existing stdlib or library API, names the replacement, and notes behavioral differences.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/wheel-reinvention-detector $HOME/.claude/skills/quality/wheel-reinvention-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/wheel-reinvention-detector $HOME\.claude\skills\quality\wheel-reinvention-detector
```

## Usage

```
/reinvented-wheels                    # interactive - prompts for target
/reinvented-wheels <project-dir>      # scan specified project
/reinvented-wheels -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: wheels-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


