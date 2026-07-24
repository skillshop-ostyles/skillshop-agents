# code-clone-detector

**Trigger:** `/code-clone` | **Risk:** read-only | **Audience:** Both

> Code clone detector: finds exact (Type 1), parameterized (Type 2), near-miss (Type 3), and semantic (Type 4) clones. ...

Code clone detector: finds exact (Type 1), parameterized (Type 2), near-miss (Type 3), and semantic (Type 4) clones. Risk-tiered report with deduplication proposals.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/code-clone-detector $HOME/.claude/skills/quality/code-clone-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/code-clone-detector $HOME\.claude\skills\quality\code-clone-detector
```

## Usage

```
/code-clone                    # interactive - prompts for target
/code-clone <project-dir>      # scan specified project
/code-clone -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: clone-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


