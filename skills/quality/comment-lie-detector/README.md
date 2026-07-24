# comment-lie-detector

**Trigger:** `/comment-lies` | **Risk:** read-only | **Audience:** Both

> Comment lie detector: extracts every behavioral-claim comment (returns / throws / always / never / must / thread-safe...

Comment lie detector: extracts every behavioral-claim comment (returns / throws / always / never / must / thread-safe / side-effect) with 30 lines of surrounding code context, then has the LLM judge whether the code does what the comment promises. Categorizes each comment as consistent / contradicts / outdated / unverifiable with confidence proven/likely/suspected.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/comment-lie-detector $HOME/.claude/skills/quality/comment-lie-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/comment-lie-detector $HOME\.claude\skills\quality\comment-lie-detector
```

## Usage

```
/comment-lies                    # interactive - prompts for target
/comment-lies <project-dir>      # scan specified project
/comment-lies -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: lie-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


