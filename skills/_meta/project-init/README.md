# project-init

**Trigger:** `/project-init` | **Risk:** read-only | **Audience:** Both

> Bootstraps a brand-new, empty project with a complete, optimized file & directory structure plus an interactive LLM o...

Bootstraps a brand-new, empty project with a complete, optimized file & directory structure plus an interactive LLM onboarding dialog. Use when the user wants to start a fresh/pristine project from scratch and have the LLM set it up via a guided, dynamic, stack-agnostic conversation covering all project areas (goal, stack, tooling, docs, secrets, platform).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/project-init $HOME/.claude/skills/_meta/project-init
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/project-init $HOME\.claude\skills\_meta\project-init
```

## Usage

```
/project-init                    # interactive - prompts for target
/project-init <project-dir>      # scan specified project
/project-init -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: project-init-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


