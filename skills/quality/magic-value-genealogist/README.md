# magic-value-genealogist

**Trigger:** `/magic-values` | **Risk:** read-only | **Audience:** Both

> Magic value genealogist: extracts numeric and uppercase-string literals from non-test source files, filters trivials ...

Magic value genealogist: extracts numeric and uppercase-string literals from non-test source files, filters trivials (0/1/24/60/...), groups by literal value, traces each first occurrence to its introducing commit and author via git blame, clusters semantically duplicated constants that should be unified.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/quality/magic-value-genealogist $HOME/.claude/skills/quality/magic-value-genealogist
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/quality/magic-value-genealogist $HOME\.claude\skills\quality\magic-value-genealogist
```

## Usage

```
/magic-values                    # interactive - prompts for target
/magic-values <project-dir>      # scan specified project
/magic-values -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: values-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


