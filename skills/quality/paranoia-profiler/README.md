# paranoia-profiler

**Trigger:** `/paranoia` | **Risk:** read-only | **Audience:** Senior

> Paranoia profiler: catalogs every defensive guard (null/undefined/empty/try-catch/typeof/instanceof) with its context...

Paranoia profiler: catalogs every defensive guard (null/undefined/empty/try-catch/typeof/instanceof) with its context. LLM judges each guard for impossibility (paranoid zone), under-defense on external input (naive zone), or calibrated (good fit).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/paranoia-profiler $HOME/.claude/skills/quality/paranoia-profiler
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/paranoia-profiler $HOME\.claude\skills\quality\paranoia-profiler
```

## Usage

```
/paranoia                    # interactive - prompts for target
/paranoia <project-dir>      # scan specified project
/paranoia -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: paranoia-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


