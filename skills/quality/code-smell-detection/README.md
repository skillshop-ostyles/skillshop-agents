# code-smell-detection

**Trigger:** `/code-smell` | **Risk:** read-only | **Audience:** Both

> Code smell detector: statically identifies 10 families of structural code quality issues (long methods, deep nesting,...

Code smell detector: statically identifies 10 families of structural code quality issues (long methods, deep nesting, god classes, feature envy, primitive obsession, data clumps, shotgun surgery, message chains, refused bequest, speculative generality). Evidence-based report with metrics and LLM validation.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/code-smell-detection $HOME/.claude/skills/quality/code-smell-detection
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/code-smell-detection $HOME\.claude\skills\quality\code-smell-detection
```

## Usage

```
/code-smell                    # interactive - prompts for target
/code-smell <project-dir>      # scan specified project
/code-smell -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: smell-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


