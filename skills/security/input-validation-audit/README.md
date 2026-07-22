# input-validation-audit

Systematically find every external input surface in your codebase and check whether validation exists. Supports 10 languages, 8 surface types.

## Installation

Copy `scripts/input-scan.ps1` to your project or reference it directly:

```powershell
& .\input-scan.ps1 -ProjectDir ".\my-project"
```

## Requirements

- PowerShell 5.1+

## Usage

```powershell
# Basic scan
& .\scripts\input-scan.ps1 -ProjectDir "C:\Projects\my-api"

# High-severity only
& .\scripts\input-scan.ps1 -ProjectDir "C:\Projects\my-api" -MinSeverity high

# Custom extension filter
& .\scripts\input-scan.ps1 -ProjectDir "C:\Projects\my-api" -Extensions "*.js,*.ts"
```

## What It Detects

| Surface Type | Examples |
|---|---|
| http-query | `req.query`, `request.GET`, `$_GET`, `@RequestParam` |
| http-body | `req.body`, `request.form`, `[FromBody]`, `@RequestBody` |
| http-params | `req.params`, `@PathVariable`, `c.Param` |
| http-headers | `req.headers`, `Request.Headers`, `r.Header` |
| cli-args | `process.argv`, `sys.argv`, `$args`, `os.Args` |
| env-var | `process.env`, `os.environ`, `$env:`, `getenv()` |
| file-read | `fs.readFile`, `open()`, `file_get_contents` |
| stdin | `readline`, `input()`, `Read-Host`, `Console.In` |

## Output

JSON on stdout, console summary after. The JSON includes:
- `findings`: each unvalidated/under-validated surface with context
- `inputSurfaces`: catalog of all detected surfaces
- `stats`: breakdown by type and severity

Pipe to a file for LLM analysis:
```powershell
& .\scripts\input-scan.ps1 -ProjectDir ".\my-project" | Select-Object -First 1 | ForEach-Object { $_ > scan.json }
```

## Trigger

`/input-audit` — read-only, network-free, safe for CI.
