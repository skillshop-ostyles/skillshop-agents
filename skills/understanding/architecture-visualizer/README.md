# architecture-visualizer

**Trigger:** `/arch-vis` | **Risk:** read-only | **Audience:** Both

> Architecture visualizer: maps module dependencies, detects layer violations, circular dependencies, entry points, and...

Architecture visualizer: maps module dependencies, detects layer violations, circular dependencies, entry points, and computes structural health score. Generates Mermaid diagrams.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/architecture-visualizer $HOME/.claude/skills/understanding/architecture-visualizer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/architecture-visualizer $HOME\.claude\skills\understanding\architecture-visualizer
```

## Usage

```
/arch-vis                    # interactive - prompts for target
/arch-vis <project-dir>      # scan specified project
/arch-vis -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: vis-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


