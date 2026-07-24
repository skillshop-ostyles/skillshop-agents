# spec-lie-detector

**Trigger:** `/spec-check` | **Risk:** read-only | **Audience:** Both

> Requirements lie detector: reads a corpus of specs/tickets (text files) and finds contradictions, gaps, ambiguities, ...

Requirements lie detector: reads a corpus of specs/tickets (text files) and finds contradictions, gaps, ambiguities, silent assumptions and untestable statements - each finding with quote, location, severity and a concrete clarification question.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/spec-lie-detector $HOME/.claude/skills/quality/spec-lie-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/spec-lie-detector $HOME\.claude\skills\quality\spec-lie-detector
```

## Usage

```
/spec-check                    # interactive - prompts for target
/spec-check <project-dir>      # scan specified project
/spec-check -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: check-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


