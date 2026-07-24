# rag-pipeline-consistency-auditor

**Trigger:** `/rag-consistency` | **Risk:** read-only | **Audience:** Both

> Audit RAG pipeline configuration for consistency issues that produce bad answers.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/rag-pipeline-consistency-auditor $HOME/.claude/skills/ai-ml/rag-pipeline-consistency-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/rag-pipeline-consistency-auditor $HOME\.claude\skills\ai-ml\rag-pipeline-consistency-auditor
```

## Usage

```
/rag-consistency                    # interactive - prompts for target
/rag-consistency <project-dir>      # scan specified project
/rag-consistency -help              # show full usage and stop
```

## Output

Markdown report: consistency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


