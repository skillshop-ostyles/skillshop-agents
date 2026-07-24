# secret-lifecycle-auditor

**Trigger:** `/secret-lifecycle` | **Risk:** read-only | **Audience:** Senior

> Secret lifecycle auditor: inventories every secret-shaped key/value across .env, k8s manifests, Vault configs, IAM re...

Secret lifecycle auditor: inventories every secret-shaped key/value across .env, k8s manifests, Vault configs, IAM refs, terraform. Per secret: age from git log -S, masked value (first-8/last-4), reachability-check against installed dependencies, type guess from key prefix. LLM judges rotation cadence and emits prioritized rotate-now / rotate-soon / remove-dead list.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/secret-lifecycle-auditor $HOME/.claude/skills/security/secret-lifecycle-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/secret-lifecycle-auditor $HOME\.claude\skills\security\secret-lifecycle-auditor
```

## Usage

```
/secret-lifecycle                    # interactive - prompts for target
/secret-lifecycle <project-dir>      # scan specified project
/secret-lifecycle -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: lifecycle-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


