# tool-call-fidelity-checker

**Trigger:** `/tool-fidelity` | **Risk:** read-only | **Audience:** Both

> Check tool/function definitions for hallucination-prone schemas.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/tool-call-fidelity-checker $HOME/.claude/skills/ai-ml/tool-call-fidelity-checker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/tool-call-fidelity-checker $HOME\.claude\skills\ai-ml\tool-call-fidelity-checker
```

## Usage

```
/tool-fidelity                    # interactive - prompts for target
/tool-fidelity <project-dir>      # scan specified project
/tool-fidelity -help              # show full usage and stop
```

## Output

Markdown report: fidelity-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


