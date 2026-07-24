# onboarding-pathfinder

**Trigger:** `/onboarding-pathfinder` | **Risk:** read-only | **Audience:** Both

> Analyzes the topology of a codebase and generates a didactically sequenced reading tour with comprehension questions ...

Analyzes the topology of a codebase and generates a didactically sequenced reading tour with comprehension questions and first safe tasks.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/onboarding-pathfinder $HOME/.claude/skills/understanding/onboarding-pathfinder
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/onboarding-pathfinder $HOME\.claude\skills\understanding\onboarding-pathfinder
```

## Usage

```
/onboarding-pathfinder                    # interactive - prompts for target
/onboarding-pathfinder <project-dir>      # scan specified project
/onboarding-pathfinder -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: onboarding-pathfinder-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


