# embedding-quality-scanner

**Trigger:** `/embed-quality` | **Risk:** read-only | **Audience:** Both

> Embedding quality scanner: audit chunking strategy, model selection, and embedding configuration.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/ai-ml/embedding-quality-scanner $HOME/.claude/skills/ai-ml/embedding-quality-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/ai-ml/embedding-quality-scanner $HOME\.claude\skills\ai-ml\embedding-quality-scanner
```

## Usage

```
/embed-quality                    # interactive - prompts for target
/embed-quality <project-dir>      # scan specified project
/embed-quality -help              # show full usage and stop
```

## Output

Markdown report: quality-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


