# benchmark

**Trigger:** `/benchmark` | **Risk:** read-only | **Audience:** Both

> Run each collector script against its fixture, measure time and output size, detect regressions.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/benchmark $HOME/.claude/skills/_meta/benchmark
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/benchmark $HOME\.claude\skills\_meta\benchmark
```

## Usage

```
/benchmark                    # interactive - prompts for target
/benchmark <project-dir>      # scan specified project
/benchmark -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: benchmark-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


