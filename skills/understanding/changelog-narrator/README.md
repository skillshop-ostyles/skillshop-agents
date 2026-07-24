# changelog-narrator

**Trigger:** `/changelog` | **Risk:** read-only | **Audience:** Both

> Changelog narrator: reads the diff between two tags/commits, clusters changes into logical groups (features, bugfixes...

Changelog narrator: reads the diff between two tags/commits, clusters changes into logical groups (features, bugfixes, refactoring, dependencies), and writes a semantic changelog with breaking changes, migration notes, and deployment risk. Collector extracts git diff and clusters by module; LLM classifies each change as feature/bugfix/chore/refactor/breaking, writes migration notes, and assesses deployment risk.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/changelog-narrator $HOME/.claude/skills/understanding/changelog-narrator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/changelog-narrator $HOME\.claude\skills\understanding\changelog-narrator
```

## Usage

```
/changelog                    # interactive - prompts for target
/changelog <project-dir>      # scan specified project
/changelog -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: changelog-narrator-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


