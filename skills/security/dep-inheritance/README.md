# dep-inheritance

**Trigger:** `/deps-audit` | **Risk:** read-only | **Audience:** Both

> Dependency inheritance audit: for every direct dependency answers the questions nobody asks - why is it here (from ac...

Dependency inheritance audit: for every direct dependency answers the questions nobody asks - why is it here (from actual usage sites), how deep is the coupling, how replaceable is it, and what is the concrete exit plan. Parses manifests/lockfiles, scans usage, optionally enriches with registry metadata (offline-safe).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/dep-inheritance $HOME/.claude/skills/security/dep-inheritance
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/dep-inheritance $HOME\.claude\skills\security\dep-inheritance
```

## Usage

```
/deps-audit                    # interactive - prompts for target
/deps-audit <project-dir>      # scan specified project
/deps-audit -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: inheritance-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


