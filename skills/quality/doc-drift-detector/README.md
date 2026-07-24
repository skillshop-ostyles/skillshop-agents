# doc-drift-detector

**Trigger:** `/doc-drift` | **Risk:** read-only | **Audience:** Both

> Documentation drift detector: extracts verifiable claims from a repo's markdown docs (file paths, commands/scripts, c...

Documentation drift detector: extracts verifiable claims from a repo's markdown docs (file paths, commands/scripts, config keys, endpoints, versions, referenced symbols) and statically verifies each one against the actual code, reporting every stale claim with a concrete fix suggestion. Never executes documented commands.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/doc-drift-detector $HOME/.claude/skills/quality/doc-drift-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/doc-drift-detector $HOME\.claude\skills\quality\doc-drift-detector
```

## Usage

```
/doc-drift                    # interactive - prompts for target
/doc-drift <project-dir>      # scan specified project
/doc-drift -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


