# Contributing to AGENTS

First off, thanks for taking the time to contribute.

## How to Contribute a Skill

1. Choose a cluster (`quality/`, `security/`, `understanding/`, `data/`, `operations/`, `runtime/`, `ai-ml/`, `_meta/`).
2. Create `skills/<cluster>/<skill-name>/SKILL.md` with:
   - YAML frontmatter (`name`, `description`, `trigger`)
   - Trigger starting with `/` (lowercase-kebab-case)
   - Numbered workflow steps
   - Read-only protection guard
   - JSON output contract (evidence schema)
3. Write `scripts/<collector>.ps1`:
   - `[CmdletBinding()]` + `[Parameter(Mandatory)]`
   - `$ErrorActionPreference = 'Stop'`
   - UTF-8 output encoding
   - Console summary with `=== TITLE ===` markers
   - JSON output on stdout (`ConvertTo-Json -Depth 5`)
   - Comment-based help (`<# .SYNOPSIS #>`)
4. Add `README.md` mirroring the trigger/description from SKILL.md.
5. Run `elevate/scripts/ci-local.ps1` from repo root to verify anatomy compliance.
6. Open a pull request.

## Code Style

- **PowerShell 5.1** — no PS7-specific features (e.g., ternary `?:`, `||`, `??`).
- **No em-dashes (`--`)** — use regular hyphen (`-`) everywhere.
- **All user-facing output in English.**
- **No silent catch blocks** — always emit `Write-Error` or `Write-Warning`.

## PR Checklist

- [ ] Smoke test passes (`ci-local.ps1`)
- [ ] No secrets, tokens, or absolute paths committed
- [ ] Output is valid JSON with no trailing whitespace
- [ ] Console summary uses `=== TITLE ===` format
- [ ] `--help` or `-$help` switch returns without error
