# type-confusion-bypass-detector

**Trigger:** `/bypass-detector` | **Risk:** read-only | **Audience:** Senior

> Type confusion bypass detector: traces validation paths from input source to storage/execution sink, tests edge-case ...

Type confusion bypass detector: traces validation paths from input source to storage/execution sink, tests edge-case input shapes (str/int/obj/null/array), and LLM judges which input shape circumvents each validator and what happens at the query/execution sink.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/type-confusion-bypass-detector $HOME/.claude/skills/security/type-confusion-bypass-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/type-confusion-bypass-detector $HOME\.claude\skills\security\type-confusion-bypass-detector
```

## Usage

```
/bypass-detector                    # interactive - prompts for target
/bypass-detector <project-dir>      # scan specified project
/bypass-detector -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: bypass-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


