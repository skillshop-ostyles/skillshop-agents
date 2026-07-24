# permission-chain

**Trigger:** `/permission-chain` | **Risk:** read-only | **Audience:** Senior

> Permission chain analyzer: extracts role definitions, role check sites, middleware mounts, and mutating routes. Ident...

Permission chain analyzer: extracts role definitions, role check sites, middleware mounts, and mutating routes. Identifies transitive chains (role A can reach endpoint E via routes R1,R2...), surfaces unprotected mutating routes (file-local check missing), detects divergent role-naming (same role defined differently in 3 files).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/permission-chain $HOME/.claude/skills/security/permission-chain
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/permission-chain $HOME\.claude\skills\security\permission-chain
```

## Usage

```
/permission-chain                    # interactive - prompts for target
/permission-chain <project-dir>      # scan specified project
/permission-chain -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: chain-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


