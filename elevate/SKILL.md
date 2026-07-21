---
name: elevate
description: "Audits any project for software quality, refactoring readiness, testing, and CI/CD, then automatically elevates it to enterprise level across 7 dimensions (tests+coverage, lint/format, CI/CD, secrets, docs, type-safety/strict, dependency-audit). Generic across stacks and CI systems, runs locally too. Trigger: /elevate"
trigger: /elevate
---

# /elevate

Audit a project and automatically elevate it to enterprise quality. Generic across
stacks and CI systems. Each of the 7 enterprise dimensions is audited, then applied
only for the ones the user individually approves.

## What this is for

- A young or existing project that needs enterprise-grade quality.
- Covers: refactoring readiness, code quality, testing, CI/CD pipelines.
- Generic: detects the stack automatically, supports multiple CI systems, and
  can run locally (no remote CI required).

## SCHUTZREGEL — niemals `~/.claude/`

Das Zielverzeichnis darf unter keinen Umständen `C:\Users\ostol\.claude\` (oder
dessen Unterordner) sein. Dieser Pfad ist heilig und darf von diesem Skill
NIEMALS verändert werden. Lehnt der User `~/.claude/` als Ziel vor, brich sofort
ab. `scripts/audit.ps1` und `scripts/apply.ps1` blockieren solche Pfade technisch
von selbst (GetFullPath-Vergleich + exit 1).

## What You Must Do When Invoked

If the user invoked `/elevate --help` or `/elevate -h` (no other args), print the
`## Usage` section verbatim and stop.

Otherwise follow the steps below in order. Do not skip steps.

### Step 1 — Establish target directory

Ask the user for the absolute path of the project to elevate. Confirm it exists and
is a project (not `~/.claude/`). Show what was detected, then:

```
Target directory: <path>
Detected:         <stack or "unknown">
Proceed? (yes/no)
```

Only continue after explicit confirmation.

### Step 2 — Run the audit

```powershell
& "<SKILL_DIR>/scripts/audit.ps1" -ProjectDir "<path>"
```

The script prints a JSON audit covering all 7 enterprise dimensions:

- **a) Tests + Coverage** — test framework present? coverage configured?
- **b) Lint / Format** — linter/formatter config present?
- **c) CI/CD** — CI file present (.github/workflows, .gitlab-ci.yml, azure-pipelines.yml)?
- **d) Secrets-Management** — .env gitignored? no hard-coded secrets?
- **e) Docs** — README, CONTRIBUTING, ADR present?
- **f) Type-Safety / Strict** — strict mode / type-check enabled?
- **g) Dependency-Audit** — lockfile present? audit command available?

Each dimension gets a status: `ok` | `missing` | `partial`, plus a score.

Present a concise summary table to the user (dimension / status / proposed action).

### Step 3 — Choose CI system

Ask which CI system to target (only this one will be generated):

```
CI-System: (1) GitHub Actions  (2) GitLab CI  (3) Azure DevOps  (4) lokal only
```

Default if user is unsure: **GitHub Actions + local** (the local script always
runs regardless, as a CI mirror).

### Step 4 — Approve each dimension individually

For EACH dimension a–g that is not `ok`, ask the user individually:

```
Dimension <X> (<name>): <proposed action>. Anlegen? (yes/no)
```

Do NOT batch approvals. Only write files for dimensions the user approved.

### Step 5 — Apply approved changes

Build an answers object and run:

```powershell
& "<SKILL_DIR>/scripts/apply.ps1" -ProjectDir "<path>" -ConfigFile "<path/to/elevate.json>"
```

Where `elevate.json` lists approved dimensions + chosen CI system, e.g.:

```json
{
  "stack": "node-ts",
  "ci": "github-actions",
  "approve": {
    "a": true,
    "b": true,
    "c": true,
    "d": true,
    "e": false,
    "f": true,
    "g": true
  }
}
```

`apply.ps1` writes ONLY the approved dimension artifacts:
- CI: the chosen system's template from `scripts/templates/`
- Lint/Format config matching the stack
- Test skeleton + coverage config
- `.gitignore` secrets hygiene
- `CONTRIBUTING.md` + ADR template (if docs approved)
- Strict / type-safety flags
- Dependency-audit script

### Step 6 — Local mirror

Regardless of chosen CI, run the local mirror so the user can verify before push:

```powershell
& "<SKILL_DIR>/scripts/ci-local.ps1" -ProjectDir "<path>"
```

This executes lint + test + dependency-audit locally (best-effort; skips what is
not installed, reporting clearly).

### Step 7 — Report

Print a concise summary:

```
Projekt <path> auf Enterprise-Level gehoben
  Angenommen:  a,b,c,d,f,g
  Uebersprungen: e
  CI: github-actions (+ lokal spiegelbar)
  Naechster Schritt: 'ci-local.ps1' lokal ausfuehren / Commit + Push.
```

## Usage

```
/elevate                 # audit + elevate current directory
/elevate <path>          # audit + elevate <path>
/elevate --help          # show this usage block and stop
```
