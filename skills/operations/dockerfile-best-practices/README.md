# dockerfile-best-practices

Static analyzer for Dockerfiles that detects 18 common best-practice violations. Helps keep images secure, lean, and maintainable.

## Installation

Copy `scripts/dockerfile-scan.ps1` to your project or reference it directly:

```powershell
& .\dockerfile-scan.ps1 -ProjectDir ".\my-project"
```

## Requirements

- PowerShell 5.1+

## Usage

```powershell
# Basic scan
& .\scripts\dockerfile-scan.ps1 -ProjectDir "C:\Projects\my-app"

# Custom exclusions
& .\scripts\dockerfile-scan.ps1 -ProjectDir "C:\Projects\my-app" -Exclude "node_modules,.git,dist"
```

## Checks (18 total)

| Severity | Checks |
|---|---|
| high | tag-pinning, root-user, apt-update-without-install, hardcoded-secret |
| medium | apt-no-recommends, apt-cache-cleanup, pip-no-cache, npm-no-production, cmd-shell-form, copy-entire-context |
| low | healthcheck-missing, expose-missing, workdir-before-copy, add-vs-copy, high-layer-count, labels-missing, multi-stage-potential, shell-form-run |

## Output

JSON on stdout, console summary after. Pipe to a file for LLM analysis:
```powershell
& .\scripts\dockerfile-scan.ps1 -ProjectDir ".\my-project" | Select-Object -First 1 | ForEach-Object { $_ > dockerfile-scan.json }
```

## Trigger

`/dockerfile-audit` — read-only, network-free, safe for CI.
