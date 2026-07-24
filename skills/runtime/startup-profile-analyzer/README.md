# startup-profile-analyzer

**Trigger:** `/startup` | **Risk:** read-only | **Audience:** Both

> Startup profile analyzer: trace the entire initialization chain, LLM judges each step as essential/lazy-loadable/susp...

Startup profile analyzer: trace the entire initialization chain, LLM judges each step as essential/lazy-loadable/suspicious.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/runtime/startup-profile-analyzer $HOME/.claude/skills/runtime/startup-profile-analyzer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/runtime/startup-profile-analyzer $HOME\.claude\skills\runtime\startup-profile-analyzer
```

## Usage

```
/startup                    # interactive - prompts for target
/startup <project-dir>      # scan specified project
/startup -help              # show full usage and stop
```

## Output

Markdown report: startup-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


