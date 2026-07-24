# fine-tune-dependency-check

**Trigger:** `/finetune-deps` | **Risk:** read-only | **Audience:** Both

> Find fine-tuned model references and check base model deprecation status.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/fine-tune-dependency-check $HOME/.claude/skills/ai-ml/fine-tune-dependency-check
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/fine-tune-dependency-check $HOME\.claude\skills\ai-ml\fine-tune-dependency-check
```

## Usage

```
/finetune-deps                    # interactive - prompts for target
/finetune-deps <project-dir>      # scan specified project
/finetune-deps -help              # show full usage and stop
```

## Output

Markdown report: dependency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


