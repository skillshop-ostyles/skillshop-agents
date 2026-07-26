# invariant-miner

**Trigger:** `/invariants` | **Risk:** read-only | **Audience:** Senior

> Invariant miner: scans for code signals that imply hidden invariants (array[0] without guards, division by computed v...

Invariant miner: scans for code signals that imply hidden invariants (array[0] without guards, division by computed values, JSON.parse assumptions, Async state-readiness patterns) and presents them to the LLM with context for each. The LLM extracts invariant sentences and judges guaranteed-by-construction vs fragile.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/quality/invariant-miner $HOME/.claude/skills/quality/invariant-miner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/quality/invariant-miner $HOME\.claude\skills\quality\invariant-miner
```

## Usage

```
/invariants                    # interactive - prompts for target
/invariants <project-dir>      # scan specified project
/invariants -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: invariant-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


