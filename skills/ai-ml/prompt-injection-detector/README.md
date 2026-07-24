# prompt-injection-detector

**Trigger:** `/prompt-inspect` | **Risk:** read-only | **Audience:** Senior > Vibe

> Prompt injection vulnerability scanner: statically detects LLM API call sites, traces untrusted data flowing into sys...

Prompt injection vulnerability scanner: statically detects LLM API call sites, traces untrusted data flowing into system prompts and user messages, and classifies injection countermeasures (none/weak/adequate).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/prompt-injection-detector $HOME/.claude/skills/ai-ml/prompt-injection-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/prompt-injection-detector $HOME\.claude\skills\ai-ml\prompt-injection-detector
```

## Usage

```
/prompt-inspect                    # interactive - prompts for target
/prompt-inspect <project-dir>      # scan specified project
/prompt-inspect -help              # show full usage and stop
```

## Output

Markdown report: injection-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


