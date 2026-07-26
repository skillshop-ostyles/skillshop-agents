# vocabulary-guardian

**Trigger:** `/vocab` | **Risk:** read-only | **Audience:** Both

> Ubiquitous language guard: harvests identifiers from code, schema and API definitions, has the LLM cluster synonyms t...

Ubiquitous language guard: harvests identifiers from code, schema and API definitions, has the LLM cluster synonyms that name the same domain concept (customer/client/account/kunde), reports naming divergences with all locations and proposes one canonical term per concept including rename impact estimate. Never renames anything.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/quality/vocabulary-guardian $HOME/.claude/skills/quality/vocabulary-guardian
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/quality/vocabulary-guardian $HOME\.claude\skills\quality\vocabulary-guardian
```

## Usage

```
/vocab                    # interactive - prompts for target
/vocab <project-dir>      # scan specified project
/vocab -help              # show full usage and stop
```

## Output

Markdown report: vocab-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


