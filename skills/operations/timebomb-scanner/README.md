# timebomb-scanner

**Trigger:** `/timebomb` | **Risk:** read-only | **Audience:** Both

> Time bomb scanner: finds hardcoded dates, expiry deadlines, cert references, 32-bit time usage and 'temporary' marker...

Time bomb scanner: finds hardcoded dates, expiry deadlines, cert references, 32-bit time usage and 'temporary' markers rotting since years (git age via blame), then has the LLM classify each finding as live bomb / rotten provisional / false alarm and produce a defusal list ranked by detonation date.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/timebomb-scanner $HOME/.claude/skills/operations/timebomb-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/timebomb-scanner $HOME\.claude\skills\operations\timebomb-scanner
```

## Usage

```
/timebomb                    # interactive - prompts for target
/timebomb <project-dir>      # scan specified project
/timebomb -help              # show full usage and stop
```

## Output

Markdown report: timebomb-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


