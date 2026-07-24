# rate-limit-shape-analyzer

**Trigger:** `/rate-shape` | **Risk:** read-only | **Audience:** Senior

> Rate-limit shape analyzer: inventories rate-limit decorators per-route (express-rate-limit, flask-limiter, DRF thrott...

Rate-limit shape analyzer: inventories rate-limit decorators per-route (express-rate-limit, flask-limiter, DRF throttle, Spring). Per endpoint, classifies whether it has a decorator, on what limit (max, window, per-tier), and whether mutating endpoints that should be limited are.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/rate-limit-shape-analyzer $HOME/.claude/skills/security/rate-limit-shape-analyzer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/rate-limit-shape-analyzer $HOME\.claude\skills\security\rate-limit-shape-analyzer
```

## Usage

```
/rate-shape                    # interactive - prompts for target
/rate-shape <project-dir>      # scan specified project
/rate-shape -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: shape-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


