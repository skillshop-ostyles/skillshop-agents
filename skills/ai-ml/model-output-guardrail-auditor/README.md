# model-output-guardrail-auditor

**Trigger:** `/guardrails` | **Risk:** read-only | **Audience:** Both

> Model output guardrail auditor: find unvalidated LLM outputs that cause crashes, data corruption, or bad decisions.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/model-output-guardrail-auditor $HOME/.claude/skills/ai-ml/model-output-guardrail-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/model-output-guardrail-auditor $HOME\.claude\skills\ai-ml\model-output-guardrail-auditor
```

## Usage

```
/guardrails                    # interactive - prompts for target
/guardrails <project-dir>      # scan specified project
/guardrails -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: guardrail-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


