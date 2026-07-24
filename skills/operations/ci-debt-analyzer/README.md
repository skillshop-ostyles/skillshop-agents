# ci-debt-analyzer

**Trigger:** `/ci-debt` | **Risk:** read-only | **Audience:** Both

> CI debt analyzer: read CI configuration (GitHub Actions, GitLab CI, Jenkins, CircleCI), measure pipeline health, then...

CI debt analyzer: read CI configuration (GitHub Actions, GitLab CI, Jenkins, CircleCI), measure pipeline health, then LLM judges what is costing the team most.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/ci-debt-analyzer $HOME/.claude/skills/operations/ci-debt-analyzer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/ci-debt-analyzer $HOME\.claude\skills\operations\ci-debt-analyzer
```

## Usage

```
/ci-debt                    # interactive - prompts for target
/ci-debt <project-dir>      # scan specified project
/ci-debt -help              # show full usage and stop
```

## Output

Markdown report: debt-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


